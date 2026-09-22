import Foundation
import SwiftData

enum OCRMode: String, Codable {
    case onDevice = "on_device"
    case cloud = "cloud"
    case disabled = "disabled"
}

@Model
final class AppSettings {
    var id: UUID
    var ocrMode: OCRMode
    var proUnlocked: Bool
    var hasRequestedNotificationPermission: Bool
    
    init(
        id: UUID = UUID(),
        ocrMode: OCRMode = .onDevice,
        proUnlocked: Bool = false,
        hasRequestedNotificationPermission: Bool = false
    ) {
        self.id = id
        self.ocrMode = ocrMode
        self.proUnlocked = proUnlocked
        self.hasRequestedNotificationPermission = hasRequestedNotificationPermission
    }
}
