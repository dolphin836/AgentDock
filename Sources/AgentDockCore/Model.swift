import Foundation

public enum AgentKind: String, Codable, Sendable {
    case claudeCode = "claude-code"
    case codex
}

public enum SessionState: String, Codable, Sendable {
    case idle, thinking, runningTool, waitingInput, waitingApproval, done, disconnected
}

public struct AgentEvent: Sendable, Equatable {
    public let sessionId: String
    public let kind: AgentKind
    public let cwd: String?
    public let name: String
    public let detail: String?
    public let timestamp: Date

    public init(sessionId: String, kind: AgentKind, cwd: String? = nil,
                name: String, detail: String? = nil, timestamp: Date = Date()) {
        self.sessionId = sessionId
        self.kind = kind
        self.cwd = cwd
        self.name = name
        self.detail = detail
        self.timestamp = timestamp
    }
}

public struct Metrics: Sendable, Equatable {
    public var model: String?
    public var contextPct: Int?
    public var costUSD: Double?
    public var totalTokens: Int?

    public init(model: String? = nil, contextPct: Int? = nil,
                costUSD: Double? = nil, totalTokens: Int? = nil) {
        self.model = model
        self.contextPct = contextPct
        self.costUSD = costUSD
        self.totalTokens = totalTokens
    }
}

public struct AgentSession: Identifiable, Sendable {
    public let id: String
    public let kind: AgentKind
    public var projectName: String
    public var cwd: String
    public var state: SessionState
    public var metrics: Metrics?
    public var recentEvents: [AgentEvent]
    public var lastActivity: Date

    public init(id: String, kind: AgentKind, projectName: String, cwd: String,
                state: SessionState, metrics: Metrics? = nil,
                recentEvents: [AgentEvent] = [], lastActivity: Date = Date()) {
        self.id = id
        self.kind = kind
        self.projectName = projectName
        self.cwd = cwd
        self.state = state
        self.metrics = metrics
        self.recentEvents = recentEvents
        self.lastActivity = lastActivity
    }
}
