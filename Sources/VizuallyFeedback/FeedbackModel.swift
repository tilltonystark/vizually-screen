import Foundation

/// Give every host a stable project ID and its own storage directory.
public struct FeedbackConfiguration: Sendable {
  public var projectID: String
  public var appName: String
  public var build: String
  public var storageDirectory: URL
  public var sessionURL: URL
  public var endpoint: URL?
  public var legacySessionKey: String?
  public var importLegacyRecords: Bool
  public init(
    projectID: String, appName: String, build: String = "development", storageDirectory: URL? = nil,
    sessionURL: URL? = nil, endpoint: URL? = URL(string: "http://127.0.0.1:4747"),
    legacySessionKey: String? = nil, importLegacyRecords: Bool = false
  ) {
    self.projectID = projectID
    self.appName = appName
    self.build = build
    self.storageDirectory =
      storageDirectory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(projectID).appendingPathComponent("Feedback")
    var components = URLComponents()
    components.scheme = "vizually-feedback"
    components.host = "native"
    components.path = "/\(projectID)/workspace"
    self.sessionURL = sessionURL ?? components.url!
    self.endpoint = endpoint
    self.legacySessionKey = legacySessionKey
    self.importLegacyRecords = importLegacyRecords
  }
}

/// Host context is captured when the pin is created, not when Send is pressed.
public struct FeedbackContext: Sendable {
  public var route: String
  public var playbackTime: Double?
  public var metadata: [String: String]
  public init(route: String, playbackTime: Double? = nil, metadata: [String: String] = [:]) {
    self.route = route
    self.playbackTime = playbackTime
    self.metadata = metadata
  }
}

public struct FeedbackRecord: Codable, Identifiable, Equatable, Sendable {
  public var id: UUID = UUID()
  public var created: Date = Date()
  public var targetID: String
  public var targetLabel: String
  public var sourceFile: String
  public var sourceLine: Int
  public var route: String
  public var playbackTime: Double?
  public var bounds: [Double]
  public var point: [Double]
  public var viewport: [Double]
  public var build: String
  public var comment: String
  public var metadata: [String: String]? = nil
  public var resolved: Bool = false
  public var agentID: String? = nil
  public var agentStatus: String? = nil
  public var agentQuestion: String? = nil
  public init(
    targetID: String, targetLabel: String, sourceFile: String, sourceLine: Int,
    context: FeedbackContext, bounds: [Double], point: [Double], viewport: [Double], build: String,
    comment: String
  ) {
    self.targetID = targetID
    self.targetLabel = targetLabel
    self.sourceFile = sourceFile
    self.sourceLine = sourceLine
    self.route = context.route
    self.playbackTime = context.playbackTime
    self.metadata = context.metadata
    self.bounds = bounds
    self.point = point
    self.viewport = viewport
    self.build = build
    self.comment = comment
  }
  public var isValid: Bool {
    !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bounds.count == 4
      && point.count == 2 && viewport.count == 2
      && (bounds + point + viewport).allSatisfy(\.isFinite) && bounds[2] >= 0 && bounds[3] >= 0
      && viewport.allSatisfy { $0 > 0 } && point.allSatisfy { (0...1).contains($0) }
      && (playbackTime == nil || playbackTime!.isFinite)
  }
}

package enum FeedbackStatus: String {
  case saved = "Saved locally"
  case unsent = "Waiting to send"
  case queued = "Queued"
  case inProgress = "In progress"
  case waitingForInput = "Waiting for input"
  case resolved = "Resolved"
  case dismissed = "Dismissed"

  package init(_ record: FeedbackRecord, connectionEnabled: Bool) {
    switch record.agentStatus {
    case "dismissed": self = .dismissed
    case "resolved": self = .resolved
    default:
      if record.resolved { self = .resolved }
      else if record.agentStatus == "waiting_for_input" || record.agentQuestion != nil {
        self = .waitingForInput
      }
      else if record.agentStatus == "acknowledged" { self = .inProgress }
      else if record.agentID != nil { self = .queued }
      else { self = connectionEnabled ? .unsent : .saved }
    }
  }
}

public struct FeedbackReceipt: Sendable {
  public var recordID: UUID
  public var agentID: String
  public var status: String
  public var agentQuestion: String?
  public init(recordID: UUID, agentID: String, status: String, agentQuestion: String? = nil) {
    self.recordID = recordID
    self.agentID = agentID
    self.status = status
    self.agentQuestion = agentQuestion
  }
}
public struct FeedbackSyncResult: Sendable {
  public var sessionID: String?
  public var receipts: [FeedbackReceipt]
  public var error: String?
  public var replacedSession: Bool
  public init(
    sessionID: String?, receipts: [FeedbackReceipt] = [], error: String? = nil,
    replacedSession: Bool = false
  ) {
    self.sessionID = sessionID
    self.receipts = receipts
    self.error = error
    self.replacedSession = replacedSession
  }
}
public protocol FeedbackTransport: Sendable {
  func synchronize(
    configuration: FeedbackConfiguration, sessionID: String?, records: [FeedbackRecord]
  ) async -> FeedbackSyncResult
}
