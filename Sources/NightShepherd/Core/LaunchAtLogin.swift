import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` so SettingsView can flip Launch-at-Login
/// with a single Boolean. Only works once the .app lives in /Applications.
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var canRegister: Bool {
        // SMAppService refuses to register when the app is running from a sandbox
        // or from a non-/Applications location. We still surface the toggle but the
        // setter will throw; the UI then nudges the user to install to /Applications.
        Bundle.main.bundlePath.contains("/Applications/")
    }

    /// Enables or disables Launch-at-Login. Throws `LaunchAtLoginError.notInApplications`
    /// when the app is not in /Applications yet (so the UI can guide the user).
    static func set(_ enabled: Bool) throws {
        guard canRegister else { throw LaunchAtLoginError.notInApplications }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case notInApplications

    var errorDescription: String? {
        switch self {
        case .notInApplications:
            return "Move Night Shepherd to /Applications first, then enable Launch at Login."
        }
    }
}
