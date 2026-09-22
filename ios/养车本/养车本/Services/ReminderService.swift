import Foundation
import UserNotifications
import SwiftData

class ReminderService {
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    func scheduleNotifications(for vehicle: Vehicle, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ReminderRule>(
            predicate: #Predicate { $0.vehicle?.id == vehicle.id && $0.notifyEnabled }
        )
        
        guard let reminders = try? modelContext.fetch(descriptor) else { return }
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        for reminder in reminders {
            scheduleNotification(for: reminder, vehicle: vehicle)
        }
    }
    
    func recalculateReminders(for vehicle: Vehicle, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ReminderRule>(
            predicate: #Predicate { $0.vehicle?.id == vehicle.id }
        )
        
        guard let reminders = try? modelContext.fetch(descriptor) else { return }
        
        for reminder in reminders {
            if reminder.mode == .mileage || reminder.mode == .earlier {
                if let lastOdometer = reminder.lastCompletedOdometerKm,
                   let intervalKm = reminder.intervalKm {
                    reminder.nextDueKm = lastOdometer + intervalKm
                }
            }
        }
        
        try? modelContext.save()
        
        scheduleNotifications(for: vehicle, modelContext: modelContext)
    }
    
    private func scheduleNotification(for reminder: ReminderRule, vehicle: Vehicle) {
        guard reminder.notifyEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "养车提醒"
        content.sound = .default
        
        var triggerDate: Date?
        
        switch reminder.mode {
        case .date:
            if let dueDate = reminder.nextDueDate {
                let daysBeforeNotify = 3
                triggerDate = Calendar.current.date(byAdding: .day, value: -daysBeforeNotify, to: dueDate)
                content.body = "\(reminder.title) 即将到期（\(dueDate.formatted(date: .abbreviated, time: .omitted))）"
            }
            
        case .mileage:
            if let dueKm = reminder.nextDueKm {
                let remainingKm = dueKm - vehicle.odometerKm
                if remainingKm < 1000 && remainingKm > 0 {
                    triggerDate = Date().addingTimeInterval(86400)
                    content.body = "\(reminder.title) 临近（还有约 \(Int(remainingKm)) 公里）"
                }
            }
            
        case .earlier:
            var shouldNotify = false
            var message = "\(reminder.title) 临近"
            
            if let dueDate = reminder.nextDueDate {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                if days < 7 && days > 0 {
                    shouldNotify = true
                    message += "（还有 \(days) 天）"
                    triggerDate = Date().addingTimeInterval(86400)
                }
            }
            
            if let dueKm = reminder.nextDueKm {
                let remainingKm = dueKm - vehicle.odometerKm
                if remainingKm < 1000 && remainingKm > 0 {
                    shouldNotify = true
                    message += "（还有约 \(Int(remainingKm)) 公里）"
                    triggerDate = Date().addingTimeInterval(86400)
                }
            }
            
            if shouldNotify {
                content.body = message
            } else {
                return
            }
        }
        
        guard let date = triggerDate, date > Date() else { return }
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification scheduling error: \(error)")
            }
        }
    }
}
