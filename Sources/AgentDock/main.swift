import AppKit

// 安装脚本的无头配置模式:执行完直接退出,不起 GUI
if SetupCLI.runIfRequested() {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
