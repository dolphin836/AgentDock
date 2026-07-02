import Foundation

public enum CoreResources {
    /// bundle 内附带的 agentdock-emit 脚本路径
    public static var emitScriptPath: String? {
        Bundle.module.path(forResource: "agentdock-emit", ofType: nil)
    }
}
