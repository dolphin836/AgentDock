import Foundation
import Observation
import AgentDockCore

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "AgentDockLanguage") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "AgentDockLanguage")
        language = AppLanguage(rawValue: saved ?? "") ?? .english  // 默认英文
    }

    /// 双语文案:t(英文, 中文)
    func t(_ en: String, _ zh: String) -> String {
        language == .english ? en : zh
    }

    func label(for state: SessionState) -> String {
        switch state {
        case .idle: t("Idle", "空闲")
        case .thinking: t("Thinking", "思考中")
        case .runningTool: t("Running tool", "执行工具")
        case .waitingApproval: t("Awaiting approval", "等待审批")
        case .done: t("Done", "已完成")
        case .disconnected: t("Disconnected", "已断开")
        }
    }
}
