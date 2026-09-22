import Foundation
import SwiftData

enum ReminderMode: String, Codable {
    case mileage = "mileage"
    case date = "date"
    case earlier = "earlier"
    
    var displayName: String {
        switch self {
        case .mileage: return "按里程"
        case .date: return "按时间"
        case .earlier: return "先到者"
        }
    }
}

enum ReminderStatus: String, Codable {
    case normal = "normal"
    case approaching = "approaching"
    case overdue = "overdue"
}

@Model
final class ReminderRule {
    var id: UUID
    var vehicle: Vehicle?
    var title: String
    var intervalKm: Double?
    var intervalMonths: Int?
    var mode: ReminderMode
    var nextDueKm: Double?
    var nextDueDate: Date?
    var notifyEnabled: Bool
    var createdAt: Date
    var lastCompletedAt: Date?
    var lastCompletedOdometerKm: Double?
    
    init(
        id: UUID = UUID(),
        vehicle: Vehicle? = nil,
        title: String,
        intervalKm: Double? = nil,
        intervalMonths: Int? = nil,
        mode: ReminderMode = .earlier,
        nextDueKm: Double? = nil,
        nextDueDate: Date? = nil,
        notifyEnabled: Bool = true,
        createdAt: Date = Date(),
        lastCompletedAt: Date? = nil,
        lastCompletedOdometerKm: Double? = nil
    ) {
        self.id = id
        self.vehicle = vehicle
        self.title = title
        self.intervalKm = intervalKm
        self.intervalMonths = intervalMonths
        self.mode = mode
        self.nextDueKm = nextDueKm
        self.nextDueDate = nextDueDate
        self.notifyEnabled = notifyEnabled
        self.createdAt = createdAt
        self.lastCompletedAt = lastCompletedAt
        self.lastCompletedOdometerKm = lastCompletedOdometerKm
    }
    
    func calculateStatus(currentOdometerKm: Double) -> ReminderStatus {
        var isOverdue = false
        var isApproaching = false
        
        if mode == .mileage || mode == .earlier {
            if let dueKm = nextDueKm {
                let remainingKm = dueKm - currentOdometerKm
                if remainingKm < 0 {
                    isOverdue = true
                } else if remainingKm < 1000 {
                    isApproaching = true
                }
            }
        }
        
        if mode == .date || mode == .earlier {
            if let dueDate = nextDueDate {
                let remainingDays = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                if remainingDays < 0 {
                    isOverdue = true
                } else if remainingDays < 3 {
                    isApproaching = true
                }
            }
        }
        
        if isOverdue {
            return .overdue
        } else if isApproaching {
            return .approaching
        } else {
            return .normal
        }
    }
    
    func formattedRemaining(currentOdometerKm: Double) -> String {
        switch mode {
        case .mileage:
            if let dueKm = nextDueKm {
                let remaining = dueKm - currentOdometerKm
                return remaining > 0 ? "还有约 \(Int(remaining)) km" : "已过期 \(Int(-remaining)) km"
            }
        case .date:
            if let dueDate = nextDueDate {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                return days > 0 ? "还有约 \(days) 天" : "已过期 \(abs(days)) 天"
            }
        case .earlier:
            var messages: [String] = []
            if let dueKm = nextDueKm {
                let remaining = dueKm - currentOdometerKm
                messages.append(remaining > 0 ? "\(Int(remaining)) km" : "已过期")
            }
            if let dueDate = nextDueDate {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                messages.append(days > 0 ? "\(days) 天" : "已过期")
            }
            return messages.joined(separator: " / ")
        }
        return ""
    }
}
