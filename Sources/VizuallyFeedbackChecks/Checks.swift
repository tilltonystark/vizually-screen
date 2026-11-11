import Foundation
import VizuallyFeedback

func check(_ condition: Bool, _ message: String) { precondition(condition, message) }
func sample(_ text: String = "Please align this control") -> FeedbackRecord {
  FeedbackRecord(
    targetID: "title", targetLabel: "Title", sourceFile: "Sample/View.swift", sourceLine: 12,
    context: FeedbackContext(route: "home", metadata: ["fixture": "safe"]),
    bounds: [10, 20, 100, 40], point: [0.5, 0.5], viewport: [640, 480], build: "test", comment: text
  )
}
actor FakeHTTP: FeedbackHTTPClient {
  enum Mode { case normal, offline, unavailable, loseFirstPost, missing }
  let mode: Mode
  var routes: [String] = []
  var annotations: [[String: Any]] = []
  var lost = false
  init(_ mode: Mode) { self.mode = mode }
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let route = "\(request.httpMethod ?? "GET") \(request.url!.path)"
    routes.append(route)
    if mode == .offline { throw URLError(.notConnectedToInternet) }
    if mode == .unavailable { return response(request, 503, [:]) }
    if route == "GET /sessions/old", mode == .missing { return response(request, 404, [:]) }
    if route == "POST /sessions" { return response(request, 201, ["id": "fixture-session"]) }
    if route.hasPrefix("GET /sessions/") {
      return response(request, 200, ["id": "fixture-session", "annotations": annotations])
    }
    if route == "POST /sessions/fixture-session/annotations" {
      var body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
      body["id"] = "fixture-\(annotations.count)"
      body["status"] = "pending"
      annotations.append(body)
      if mode == .loseFirstPost && !lost {
        lost = true
        throw URLError(.networkConnectionLost)
      }
      return response(request, 201, body)
    }
    fatalError("Unexpected fixture request: \(route)")
  }
  func mark(_ status: String) {
    for index in annotations.indices { annotations[index]["status"] = status }
  }
  func reply(_ text: String, role: String = "agent") {
    var thread = annotations[0]["thread"] as? [[String: String]] ?? []
    thread.append(["role": role, "content": text])
    annotations[0]["thread"] = thread
  }
  func snapshot() -> ([String], Int) { (routes, annotations.count) }
  private func response(_ request: URLRequest, _ status: Int, _ body: [String: Any]) -> (
    Data, HTTPURLResponse
  ) {
    (
      try! JSONSerialization.data(withJSONObject: body),
      HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    )
  }
}
actor DelayedTransport: FeedbackTransport {
  private var started = false
  private var continuation: CheckedContinuation<Void, Never>?
  func synchronize(
    configuration: FeedbackConfiguration, sessionID: String?, records: [FeedbackRecord]
  ) async -> FeedbackSyncResult {
    started = true
    await withCheckedContinuation { continuation = $0 }
    return FeedbackSyncResult(
      sessionID: "delayed",
      receipts: [FeedbackReceipt(recordID: records[0].id, agentID: "first", status: "acknowledged")]
    )
  }
  func waitUntilStarted() async { while !started { await Task.yield() } }
  func release() {
    continuation?.resume()
    continuation = nil
  }
}
@main struct FeedbackChecks {
  @MainActor static func main() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "feedback-checks-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    func config(_ name: String, endpoint: URL? = nil, legacy: Bool = false) -> FeedbackConfiguration
    {
      FeedbackConfiguration(
        projectID: "test.\(name)", appName: name,
        storageDirectory: root.appendingPathComponent(name), endpoint: endpoint,
        importLegacyRecords: legacy)
    }
    let original = sample()
    let copy = try JSONDecoder().decode(FeedbackRecord.self, from: JSONEncoder().encode(original))
    check(copy == original, "Feedback model/context roundtrip failed")
    var invalid = sample()
    invalid.bounds = []
    check(!invalid.isValid, "Malformed geometry accepted")
    invalid = sample()
    invalid.point = [.infinity, 0]
    check(!invalid.isValid, "Infinite coordinates accepted")

    let local = FeedbackStore(configuration: config("local"))
    check(local.add(original), "Local save failed")
    let reopened = FeedbackStore(configuration: config("local"))
    check(reopened.items == [original], "Reopen lost a comment")
    check(!reopened.connectionEnabled, "Offline configuration enabled transport")
    check(FeedbackStatus(reopened.items[0], connectionEnabled: false) == .saved,
      "Local-only comment should be shown as saved")
    var alien = config("local")
    alien.projectID = "another-project"
    let isolated = FeedbackStore(configuration: alien)
    check(
      isolated.items.isEmpty && isolated.error != nil, "Wrong project loaded another host's data")
    let before = try Data(contentsOf: local.url)
    check(!isolated.add(sample("must not overwrite")), "Wrong project overwrote archive")
    check(
      try Data(contentsOf: local.url) == before, "Rejected write changed another project's archive")

    let legacy = config("legacy", legacy: true)
    try FileManager.default.createDirectory(
      at: legacy.storageDirectory, withIntermediateDirectories: true)
    let legacyURL = legacy.storageDirectory.appendingPathComponent("feedback.json")
    try JSONEncoder().encode([original]).write(to: legacyURL)
    let migrated = FeedbackStore(configuration: legacy)
    check(migrated.items == [original], "Legacy comments were not imported")
    check(migrated.add(sample("new")), "Legacy migration could not save")
    let archive =
      try JSONSerialization.jsonObject(with: Data(contentsOf: legacyURL)) as! [String: Any]
    check(archive["version"] as? Int == 1, "Migration did not produce a versioned archive")
    check(FeedbackStore(configuration: legacy).items.count == 2, "Migration lost old comments")

    let corrupt = config("corrupt")
    try FileManager.default.createDirectory(
      at: corrupt.storageDirectory, withIntermediateDirectories: true)
    let corruptURL = corrupt.storageDirectory.appendingPathComponent("feedback.json")
    try Data("broken-json".utf8).write(to: corruptURL)
    let broken = FeedbackStore(configuration: corrupt)
    check(!broken.add(sample()), "Corrupt archive was overwritten")
    check(
      try String(contentsOf: corruptURL, encoding: .utf8) == "broken-json",
      "Original corrupt file lost")

    let endpoint = URL(string: "http://fixture.invalid")!
    for mode in [FakeHTTP.Mode.offline, .unavailable] {
      let client = FakeHTTP(mode)
      let result = await AgentationTransport(endpoint: endpoint, client: client).synchronize(
        configuration: config("failure"), sessionID: "existing", records: [original])
      let routes = await client.snapshot().0
      check(
        result.error != nil && result.sessionID == "existing", "Failed GET lost session identity")
      check(routes == ["GET /sessions/existing"], "Failed GET created an unrelated session")
    }
    let client = FakeHTTP(.loseFirstPost)
    let transport = AgentationTransport(endpoint: endpoint, client: client)
    let onlineConfig = config("uncertain", endpoint: endpoint)
    let online = FeedbackStore(configuration: onlineConfig, transport: transport)
    check(online.add(original), "Could not queue online feedback")
    await online.sendPending()
    check(
      online.items.count == 1 && online.items[0].agentID == nil
        && online.sessionID == "fixture-session" && online.error != nil,
      "Uncertain delivery lost local feedback or session")
    await online.sendPending()
    let sent = await client.snapshot()
    check(
      sent.1 == 1
        && sent.0.filter { $0 == "POST /sessions/fixture-session/annotations" }.count == 1,
      "Retry duplicated an accepted annotation")
    check(online.items[0].agentID == "fixture-0", "Retry did not reconcile receipt")
    func status(_ record: FeedbackRecord) -> FeedbackStatus {
      FeedbackStatus(record, connectionEnabled: true)
    }
    check(status(online.items[0]) == .queued, "Delivered comment skipped the queue")
    await client.mark("acknowledged")
    await client.reply("Waiting for input: This is not an agent request.", role: "human")
    await online.sendPending()
    check(status(online.items[0]) == .inProgress, "Human text changed workflow status")
    await client.reply("Waiting for input: Which control is affected?")
    await online.sendPending()
    let waiting = FeedbackStore(configuration: onlineConfig, transport: transport).items[0]
    check(status(waiting) == .waitingForInput && waiting.agentQuestion == "Which control is affected?",
      "Agent question and waiting status did not survive reopening")
    await client.reply("In progress: Reproduced the issue.")
    await online.sendPending()
    check(status(online.items[0]) == .inProgress && online.items[0].agentQuestion == nil,
      "Agent progress did not clear the question")
    await client.reply("Waiting for input: Does this fix it?")
    await client.mark("resolved")
    await online.sendPending()
    check(online.items[0].resolved && status(online.items[0]) == .resolved,
      "Remote completion did not take precedence over a prior question")
    let restored = FeedbackStore(configuration: onlineConfig, transport: transport)
    check(
      restored.sessionID == "fixture-session" && restored.items[0].resolved,
      "Session/status did not persist")
    await client.mark("dismissed")
    await online.sendPending()
    check(status(online.items[0]) == .dismissed, "Dismissed comment was shown as resolved")

    var formerlySent = sample()
    formerlySent.agentID = "old-annotation"
    let missing = FakeHTTP(.missing)
    let replacement = await AgentationTransport(endpoint: endpoint, client: missing).synchronize(
      configuration: config("replacement"), sessionID: "old", records: [formerlySent])
    check(
      replacement.replacedSession && replacement.receipts.count == 1,
      "Deleted session was not recovered")

    let gate = DelayedTransport()
    let concurrent = FeedbackStore(configuration: config("concurrent"), transport: gate)
    check(concurrent.add(original), "Could not queue first comment")
    let task = Task { await concurrent.sendPending() }
    await gate.waitUntilStarted()
    let newer = sample("Created during sync")
    check(concurrent.add(newer), "Could not add during sync")
    await gate.release()
    await task.value
    check(
      concurrent.items.count == 2 && concurrent.items[0].id == newer.id
        && concurrent.items[0].agentID == nil && concurrent.items[1].agentID == "first",
      "Sync overwrote newer local feedback")
    print(
      "PASS: public API, geometry validation, local/reopen isolation, legacy migration, corrupt-file preservation, offline/503 identity, uncertain-delivery deduplication, session recovery, remote completion and concurrent receipt merging"
    )
  }
}
