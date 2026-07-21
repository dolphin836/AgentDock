import Foundation

public enum AgentKind: String, Codable, Sendable, CaseIterable {
    case claudeCode = "claude-code"
    case codex
    case cursor
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
    /// 工具调用事件的工具名(detail 可能被文件名/命令覆盖,这里始终是工具本名)
    public let tool: String?
    /// 宿主 App 的 .app 路径(由发射脚本沿父进程链探测)
    public let appPath: String?
    /// 事件自带的模型名(Cursor hook 每个事件都带;其他 agent 走 statusline/SQLite)
    public let model: String?
    /// 同一工具调用在 hook/transcript 间共享的 id(tool_use_id/tool_call_id)。
    public let correlationId: String?
    /// Cursor 子 agent hook 显式或从 transcript 路径解析出的父会话 id。
    public let parentSessionId: String?
    /// Cursor 子 agent hook 的 child id(首选别名)。
    public let subagentId: String?
    /// 子 agent 的全部跨通道身份别名(subagent_id/tool_call_id + transcript path stem 等),
    /// 供 Aggregator 关联同一 canonical child;subagentId 为其首选项。
    public let subagentAliases: [String]
    public let timestamp: Date

    public init(sessionId: String, kind: AgentKind, cwd: String? = nil,
                name: String, detail: String? = nil, tool: String? = nil,
                appPath: String? = nil, model: String? = nil,
                correlationId: String? = nil, parentSessionId: String? = nil,
                subagentId: String? = nil, subagentAliases: [String] = [],
                timestamp: Date = Date()) {
        self.sessionId = sessionId
        self.kind = kind
        self.cwd = cwd
        self.name = name
        self.detail = detail
        self.tool = tool
        self.appPath = appPath
        self.model = model
        self.correlationId = correlationId
        self.parentSessionId = parentSessionId
        self.subagentId = subagentId
        self.subagentAliases = subagentAliases
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

/// 账号级限额(5 小时 / 7 天窗口用量百分比,可带窗口重置时间)
public struct RateLimits: Sendable, Equatable {
    public var fiveHourPct: Int?
    public var sevenDayPct: Int?
    public var fiveHourResetAt: Date?
    public var sevenDayResetAt: Date?
    public var updatedAt: Date

    public init(fiveHourPct: Int? = nil, sevenDayPct: Int? = nil,
                fiveHourResetAt: Date? = nil, sevenDayResetAt: Date? = nil,
                updatedAt: Date = Date()) {
        self.fiveHourPct = fiveHourPct
        self.sevenDayPct = sevenDayPct
        self.fiveHourResetAt = fiveHourResetAt
        self.sevenDayResetAt = sevenDayResetAt
        self.updatedAt = updatedAt
    }

    /// 合并新读数:百分比取新值,重置时间在新值缺失时保留旧值
    /// (statusline 等旁路来源只带百分比,不应抹掉 OAuth 拿到的重置时间)
    public func merging(_ incoming: RateLimits) -> RateLimits {
        RateLimits(fiveHourPct: incoming.fiveHourPct ?? fiveHourPct,
                   sevenDayPct: incoming.sevenDayPct ?? sevenDayPct,
                   fiveHourResetAt: incoming.fiveHourResetAt ?? fiveHourResetAt,
                   sevenDayResetAt: incoming.sevenDayResetAt ?? sevenDayResetAt,
                   updatedAt: incoming.updatedAt)
    }
}

/// Cursor 账号用量(usage-summary):套餐/团队池用量百分比 + 花费(美元)。
/// 个人版在 individualUsage.plan;企业旧形状在 teamUsage.pooled + overall;
/// 企业新形状可能只有 overall + onDemand。
public struct CursorUsage: Sendable, Equatable {
    public var planPct: Int?
    public var planUsedUSD: Double?
    public var planLimitUSD: Double?
    public var onDemandUsedUSD: Double?
    public var onDemandLimitUSD: Double?
    /// 企业/团队版:本人在共享池里的花费
    public var personalUsedUSD: Double?
    public var membershipType: String?
    public var billingCycleEnd: Date?
    public var updatedAt: Date

    public init(planPct: Int? = nil,
                planUsedUSD: Double? = nil, planLimitUSD: Double? = nil,
                onDemandUsedUSD: Double? = nil, onDemandLimitUSD: Double? = nil,
                personalUsedUSD: Double? = nil,
                membershipType: String? = nil,
                billingCycleEnd: Date? = nil, updatedAt: Date = Date()) {
        self.planPct = planPct
        self.planUsedUSD = planUsedUSD
        self.planLimitUSD = planLimitUSD
        self.onDemandUsedUSD = onDemandUsedUSD
        self.onDemandLimitUSD = onDemandLimitUSD
        self.personalUsedUSD = personalUsedUSD
        self.membershipType = membershipType
        self.billingCycleEnd = billingCycleEnd
        self.updatedAt = updatedAt
    }
}

public struct AgentSession: Identifiable, Sendable {
    public let id: String
    public let kind: AgentKind
    public var projectName: String
    public var cwd: String
    public var state: SessionState
    public var metrics: Metrics?
    /// 会话宿主 App 的 .app 路径
    public var appPath: String?
    public var recentEvents: [AgentEvent]
    public var lastActivity: Date

    public init(id: String, kind: AgentKind, projectName: String, cwd: String,
                state: SessionState, metrics: Metrics? = nil, appPath: String? = nil,
                recentEvents: [AgentEvent] = [], lastActivity: Date = Date()) {
        self.id = id
        self.kind = kind
        self.projectName = projectName
        self.cwd = cwd
        self.state = state
        self.metrics = metrics
        self.appPath = appPath
        self.recentEvents = recentEvents
        self.lastActivity = lastActivity
    }
}
