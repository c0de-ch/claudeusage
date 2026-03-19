import Foundation
import ServiceManagement

enum LaunchAtLogin {
    @available(macOS 13.0, *)
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @available(macOS 13.0, *)
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
