import Foundation
import SwiftData

enum RecordType: String, Codable, CaseIterable, Identifiable {
    case service = "service"
    case repair = "repair"
    case other = "other"
    case charging = "charging"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .service: return "保养"
        case .repair: return "维修"
        case .other: return "其他"
        case .charging: return "充电"
        }
    }
}

@Model
final class Record {
    var id: UUID
    var vehicle: Vehicle?
    var type: RecordType
    var title: String
    var date: Date
    var odometerKm: Double?
    var amountCents: Int?
    var notes: String?
    var receiptImagePath: String?
    var ocrRawText: String?
    
    var kWh: Double?
    var locationKind: String?
    
    init(
        id: UUID = UUID(),
        vehicle: Vehicle? = nil,
        type: RecordType = .service,
        title: String,
        date: Date = Date(),
        odometerKm: Double? = nil,
        amountCents: Int? = nil,
        notes: String? = nil,
        receiptImagePath: String? = nil,
        ocrRawText: String? = nil,
        kWh: Double? = nil,
        locationKind: String? = nil
    ) {
        self.id = id
        self.vehicle = vehicle
        self.type = type
        self.title = title
        self.date = date
        self.odometerKm = odometerKm
        self.amountCents = amountCents
        self.notes = notes
        self.receiptImagePath = receiptImagePath
        self.ocrRawText = ocrRawText
        self.kWh = kWh
        self.locationKind = locationKind
    }
    
    var formattedAmount: String? {
        guard let cents = amountCents else { return nil }
        let yuan = Double(cents) / 100.0
        return String(format: "¥%.2f", yuan)
    }
}
