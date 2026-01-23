import Foundation
import ServiceManagement

/// Manages the "Launch at Login" functionality using SMAppService
class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private init() {}

    /// Whether the app is currently registered to launch at login
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    /// Enable or disable launch at login
    /// - Parameter enabled: Whether to enable launch at login
    /// - Returns: True if the operation succeeded
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status == .enabled {
                        print("Launch at login already enabled")
                        return true
                    }
                    try SMAppService.mainApp.register()
                    print("Launch at login enabled")
                } else {
                    if SMAppService.mainApp.status != .enabled {
                        print("Launch at login already disabled")
                        return true
                    }
                    try SMAppService.mainApp.unregister()
                    print("Launch at login disabled")
                }
                return true
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
                return false
            }
        } else {
            print("Launch at login requires macOS 13.0 or later")
            return false
        }
    }

    /// Get the current status as a human-readable string
    var statusDescription: String {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                return "Enabled"
            case .notRegistered:
                return "Not registered"
            case .notFound:
                return "Not found"
            case .requiresApproval:
                return "Requires approval in System Settings"
            @unknown default:
                return "Unknown"
            }
        } else {
            return "Not available (requires macOS 13.0+)"
        }
    }
}
