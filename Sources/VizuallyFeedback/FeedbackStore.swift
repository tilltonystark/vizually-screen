import Combine
import Foundation

/// Local-first storage. Receipts are merged by UUID so an in-flight sync cannot
/// overwrite a newer comment. No host types, global singleton or app paths.
@MainActor public final class FeedbackStore: ObservableObject {
  @Published public var enabled = false
  @Published public private(set) var items: [FeedbackRecord] = []
  @Published public private(set) var error: String?
  @Published public private(set) var syncing = false
  @Published var requestedTargetID: String?
  public func requestComment(on targetID: String) {
    enabled = true
    requestedTargetID = targetID
  }
  func consumeTargetRequest() { requestedTargetID = nil }
  public private(set) var sessionID: String?
  public let configuration: FeedbackConfiguration
  public var url: URL { configuration.storageDirectory.appendingPathComponent("feedback.json") }
  public var connectionEnabled: Bool { transport != nil }
  private let transport: (any FeedbackTransport)?
  private var loadFailed = false
  private struct Archive: Codable {
    var version: Int = 1
    var projectID: String
    var endpoint: String?
    var sessionURL: String
    var sessionID: String?
    var items: [FeedbackRecord]
  }
  public init(configuration: FeedbackConfiguration, transport: (any FeedbackTransport)? = nil) {
    self.configuration = configuration
    self.transport = transport ?? configuration.endpoint.map { AgentationTransport(endpoint: $0) }
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    do {
      let data = try Data(contentsOf: url)
      if let archive = try? JSONDecoder().decode(Archive.self, from: data) {
        guard archive.version == 1, archive.projectID == configuration.projectID else {
          throw CocoaError(.fileReadCorruptFile)
        }
        items = archive.items
        if archive.endpoint == configuration.endpoint?.absoluteString
          && archive.sessionURL == configuration.sessionURL.absoluteString
        {
          sessionID = archive.sessionID
        } else {
          for index in items.indices where !items[index].resolved {
            items[index].agentID = nil
            items[index].agentStatus = nil
            items[index].agentQuestion = nil
          }
        }
      } else if configuration.importLegacyRecords {
        items = try JSONDecoder().decode([FeedbackRecord].self, from: data)
        if let key = configuration.legacySessionKey {
          sessionID = UserDefaults.standard.string(forKey: key)
        }
      } else {
        throw CocoaError(.fileReadCorruptFile)
      }
      guard items.allSatisfy(\.isValid) else { throw CocoaError(.fileReadCorruptFile) }
    } catch {
      items = []
      loadFailed = true
      self.error =
        "Could not read saved feedback. The original file has been preserved: \(error.localizedDescription)"
    }
  }
  @discardableResult public func add(_ item: FeedbackRecord) -> Bool {
    guard item.isValid else {
      error = "This comment has invalid selection coordinates."
      return false
    }
    var updated = items
    updated.insert(item, at: 0)
    return persist(updated, sessionID: sessionID)
  }
  private func persist(_ updated: [FeedbackRecord], sessionID: String?) -> Bool {
    guard !loadFailed else { return false }
    do {
      let archive = Archive(
        projectID: configuration.projectID, endpoint: configuration.endpoint?.absoluteString,
        sessionURL: configuration.sessionURL.absoluteString, sessionID: sessionID, items: updated)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try FileManager.default.createDirectory(
        at: configuration.storageDirectory, withIntermediateDirectories: true)
      try encoder.encode(archive).write(to: url, options: .atomic)
      items = updated
      self.sessionID = sessionID
      error = nil
      return true
    } catch {
      self.error = "Could not save feedback: \(error.localizedDescription)"
      return false
    }
  }
  public func sendPending() async {
    guard !syncing, !loadFailed, !items.isEmpty, let transport else { return }
    syncing = true
    defer { syncing = false }
    let result = await transport.synchronize(
      configuration: configuration, sessionID: sessionID, records: items)
    var merged = items
    if result.replacedSession {
      for index in merged.indices where !merged[index].resolved {
        merged[index].agentID = nil
        merged[index].agentStatus = nil
        merged[index].agentQuestion = nil
      }
    }
    for receipt in result.receipts {
      if let index = merged.firstIndex(where: { $0.id == receipt.recordID }) {
        merged[index].agentID = receipt.agentID
        merged[index].agentStatus = receipt.status
        merged[index].agentQuestion = receipt.agentQuestion
        merged[index].resolved = ["resolved", "dismissed"].contains(receipt.status)
      }
    }
    let nextSession = result.sessionID ?? sessionID
    if merged != items || nextSession != sessionID {
      guard persist(merged, sessionID: nextSession) else { return }
    }
    error = result.error
  }
}
