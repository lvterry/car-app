import Foundation
import SwiftData

enum Powertrain: String, Codable, CaseIterable, Identifiable {
    case fuel = "fuel"
    case bev = "bev"
    case hev = "hev"
    case phev = "phev"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fuel: return "燃油"
        case .bev: return "纯电"
        case .hev: return "混动"
        case .phev: return "插混"
        }
    }
}

@Model
final class Vehicle {
    var id: UUID
    var name: String?
    var makeModel: String
    var powertrain: Powertrain
    var odometerKm: Double
    var odometerUpdatedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Record.vehicle)
    var records: [Record]?
    
    @Relationship(deleteRule: .cascade, inverse: \ReminderRule.vehicle)
    var reminders: [ReminderRule]?
    
    init(
        id: UUID = UUID(),
        name: String? = nil,
        makeModel: String,
        powertrain: Powertrain,
        odometerKm: Double,
        odometerUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.makeModel = makeModel
        self.powertrain = powertrain
        self.odometerKm = odometerKm
        self.odometerUpdatedAt = odometerUpdatedAt
    }
    
    var displayName: String {
        name ?? makeModel
    }
}
