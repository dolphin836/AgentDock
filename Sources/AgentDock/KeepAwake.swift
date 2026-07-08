import Foundation
import IOKit.pwr_mgt

/// Agent 任务进行中阻止 Mac 闲置休眠(参考 adrafinil 的核心机制,去掉其 root helper/合盖部分):
/// 标准的 IOPMAssertion(PreventUserIdleSystemSleep),幂等获取/释放,
/// 进程退出内核自动回收,不会留下永久改动;`pmset -g assertions` 可见,用户可自查。
/// 注意:不阻止合盖休眠(那需要 root 权限的 pmset disablesleep,超出本 App 的定位)。
@MainActor
final class KeepAwake {
    private var assertionID: IOPMAssertionID = 0

    var isHeld: Bool { assertionID != 0 }

    /// 幂等:目标状态一致时是 no-op
    func setActive(_ active: Bool) {
        active ? acquire() : release()
    }

    private func acquire() {
        guard assertionID == 0 else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "AgentDock: agent task in progress" as CFString,
            &assertionID)
        if result != kIOReturnSuccess {
            assertionID = 0
        }
    }

    private func release() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }
}
