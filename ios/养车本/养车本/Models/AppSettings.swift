import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var proUnlocked: Bool
    var hasRequestedNotificationPermission: Bool
    var hasDismissedOdometerPrompt: Bool
    
    init(
        id: UUID = UUID(),
        proUnlocked: Bool = false,
        hasRequestedNotificationPermission: Bool = false,
        hasDismissedOdometerPrompt: Bool = false
    ) {
        self.id = id
        self.proUnlocked = proUnlocked
        self.hasRequestedNotificationPermission = hasRequestedNotificationPermission
        self.hasDismissedOdometerPrompt = hasDismissedOdometerPrompt
    }
}
