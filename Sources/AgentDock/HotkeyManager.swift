import AppKit
import Carbon.HIToolbox

enum AppInfo {
    static let version = "0.2.1"
}

/// 全局快捷键(Carbon RegisterEventHotKey,无需辅助功能授权)。
/// ⌘G 常驻;⌘Y/⌘N 只在有待审批请求时注册,避免长期霸占系统级按键。
@MainActor
final class HotkeyManager {
    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextId: UInt32 = 1
    private var handler: EventHandlerRef?
    private static let signature: OSType = 0x4147444B  // 'AGDK'

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                let id = hotKeyID.id
                Task { @MainActor in manager.actions[id]?() }
                return noErr
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func register(keyCode: Int, modifiers: Int = cmdKey, action: @escaping () -> Void) -> UInt32 {
        let id = nextId
        nextId += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                  GetApplicationEventTarget(), 0, &ref) == noErr,
              let ref else { return 0 }
        actions[id] = action
        refs[id] = ref
        return id
    }

    func unregister(_ id: UInt32) {
        guard let ref = refs.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(ref)
        actions[id] = nil
    }
}
