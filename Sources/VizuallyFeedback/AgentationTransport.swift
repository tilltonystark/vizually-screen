import Foundation

/// Injectable HTTP boundary; tests never need a real agent or another project's sessions.
public protocol FeedbackHTTPClient: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
public struct URLSessionFeedbackClient: FeedbackHTTPClient {
  public init() {}
  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
    return (data, response)
  }
}
public struct AgentationTransport: FeedbackTransport {
  public let endpoint: URL
  private let client: any FeedbackHTTPClient
  public init(
    endpoint: URL = URL(string: "http://127.0.0.1:4747")!,
    client: any FeedbackHTTPClient = URLSessionFeedbackClient()
  ) {
    self.endpoint = endpoint
    self.client = client
  }
  private struct HTTPFailure: Error { var status: Int }
  private func question(in annotation: [String: Any]) -> String? {
    let thread = annotation["thread"] as? [[String: Any]] ?? []
    for message in thread.reversed() where message["role"] as? String == "agent" {
      guard let content = message["content"] as? String else { continue }
      if content.hasPrefix("In progress:") { return nil }
      let prefix = "Waiting for input:"
      if content.hasPrefix(prefix) {
        let question = content.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return question.isEmpty ? nil : question
      }
    }
    return nil
  }
  private func request(_ path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
    var request = URLRequest(url: endpoint.appendingPathComponent(path))
    request.timeoutInterval = 3
    if let body {
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }
    let (data, response) = try await client.data(for: request)
    guard (200...299).contains(response.statusCode) else {
      throw HTTPFailure(status: response.statusCode)
    }
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw URLError(.cannotParseResponse)
    }
    return object
  }
  public func synchronize(
    configuration: FeedbackConfiguration, sessionID: String?, records: [FeedbackRecord]
  ) async -> FeedbackSyncResult {
    var result = FeedbackSyncResult(sessionID: sessionID)
    do {
      var session: [String: Any]?
      if let id = sessionID {
        do { session = try await request("sessions/\(id)") } catch let failure as HTTPFailure
          where failure.status == 404
        { result.sessionID = nil }
        // Network failures must not create a new session or lose existing history.
      }
      if session == nil {
        session = try await request(
          "sessions",
          body: [
            "url": configuration.sessionURL.absoluteString, "projectId": configuration.projectID,
          ])
        guard let id = session?["id"] as? String else { throw URLError(.cannotParseResponse) }
        result.sessionID = id
        result.replacedSession = true
      }
      guard let id = result.sessionID else { throw URLError(.cannotParseResponse) }
      let remote = session?["annotations"] as? [[String: Any]] ?? []
      for record in records {
        guard record.isValid else { continue }
        if let known = remote.first(where: {
          ($0["attributes"] as? [String: Any])?["localFeedbackID"] as? String
            == record.id.uuidString
            || (!result.replacedSession && record.agentID != nil && $0["id"] as? String == record.agentID)
        }), let remoteID = known["id"] as? String {
          result.receipts.append(
            FeedbackReceipt(
              recordID: record.id, agentID: remoteID,
              status: known["status"] as? String ?? "pending", agentQuestion: question(in: known)))
          continue
        }
        guard !record.resolved, record.agentID == nil || result.replacedSession else { continue }
        var attributes = record.metadata ?? [:]
        attributes.merge(
          [
            "localFeedbackID": record.id.uuidString, "app": configuration.appName,
            "projectID": configuration.projectID, "build": record.build, "route": record.route,
            "playbackTime": record.playbackTime.map(String.init(describing:)) ?? "none",
          ], uniquingKeysWith: { _, required in required })
        let annotation = try await request(
          "sessions/\(id)/annotations",
          body: [
            "x": record.bounds[0] + record.bounds[2] * record.point[0],
            "y": record.bounds[1] + record.bounds[3] * record.point[1],
            "comment": record.comment, "element": record.targetLabel,
            "elementPath": "SwiftUI/\(record.route)/\(record.targetID)",
            "timestamp": record.created.timeIntervalSince1970 * 1000,
            "sourceFile": "\(record.sourceFile):\(record.sourceLine)",
            "boundingBox": [
              "x": record.bounds[0], "y": record.bounds[1], "width": record.bounds[2],
              "height": record.bounds[3],
            ], "attributes": attributes, "kind": "feedback",
          ])
        guard let remoteID = annotation["id"] as? String else {
          throw URLError(.cannotParseResponse)
        }
        result.receipts.append(
          FeedbackReceipt(recordID: record.id, agentID: remoteID, status: "pending"))
      }
    } catch { result.error = "Saved locally. Agent connection unavailable; delivery will retry." }
    return result
  }
}
