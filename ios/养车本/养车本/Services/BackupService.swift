import Foundation
import SwiftData

struct BackupData: Codable {
    let version: String
    let createdAt: Date
    let vehicle: VehicleBackup
    let records: [RecordBackup]
    let reminders: [ReminderBackup]
    
    struct VehicleBackup: Codable {
        let id: UUID
        let name: String?
        let makeModel: String
        let powertrain: String
        let odometerKm: Double
        let odometerUpdatedAt: Date
    }
    
    struct RecordBackup: Codable {
        let id: UUID
        let type: String
        let title: String
        let date: Date
        let odometerKm: Double?
        let amountCents: Int?
        let notes: String?
        let receiptImagePath: String?
        let ocrRawText: String?
        let kWh: Double?
        let locationKind: String?
    }
    
    struct ReminderBackup: Codable {
        let id: UUID
        let title: String
        let intervalKm: Double?
        let intervalMonths: Int?
        let mode: String
        let nextDueKm: Double?
        let nextDueDate: Date?
        let notifyEnabled: Bool
        let createdAt: Date
        let lastCompletedAt: Date?
        let lastCompletedOdometerKm: Double?
    }
}

class BackupService {
    func createBackup(
        vehicle: Vehicle,
        records: [Record],
        modelContext: ModelContext
    ) async -> URL? {
        let descriptor = FetchDescriptor<ReminderRule>(
            predicate: #Predicate { $0.vehicle?.id == vehicle.id }
        )
        let reminders = (try? modelContext.fetch(descriptor)) ?? []
        
        let vehicleBackup = BackupData.VehicleBackup(
            id: vehicle.id,
            name: vehicle.name,
            makeModel: vehicle.makeModel,
            powertrain: vehicle.powertrain.rawValue,
            odometerKm: vehicle.odometerKm,
            odometerUpdatedAt: vehicle.odometerUpdatedAt
        )
        
        let recordsBackup = records.map { record in
            BackupData.RecordBackup(
                id: record.id,
                type: record.type.rawValue,
                title: record.title,
                date: record.date,
                odometerKm: record.odometerKm,
                amountCents: record.amountCents,
                notes: record.notes,
                receiptImagePath: record.receiptImagePath,
                ocrRawText: record.ocrRawText,
                kWh: record.kWh,
                locationKind: record.locationKind
            )
        }
        
        let remindersBackup = reminders.map { reminder in
            BackupData.ReminderBackup(
                id: reminder.id,
                title: reminder.title,
                intervalKm: reminder.intervalKm,
                intervalMonths: reminder.intervalMonths,
                mode: reminder.mode.rawValue,
                nextDueKm: reminder.nextDueKm,
                nextDueDate: reminder.nextDueDate,
                notifyEnabled: reminder.notifyEnabled,
                createdAt: reminder.createdAt,
                lastCompletedAt: reminder.lastCompletedAt,
                lastCompletedOdometerKm: reminder.lastCompletedOdometerKm
            )
        }
        
        let backupData = BackupData(
            version: "1.0",
            createdAt: Date(),
            vehicle: vehicleBackup,
            records: recordsBackup,
            reminders: remindersBackup
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let jsonData = try encoder.encode(backupData)
            
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("backup_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let jsonURL = tempDir.appendingPathComponent("backup.json")
            try jsonData.write(to: jsonURL)
            
            let receiptsDir = tempDir.appendingPathComponent("receipts", isDirectory: true)
            try FileManager.default.createDirectory(at: receiptsDir, withIntermediateDirectories: true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let receiptsSourcePath = documentsPath.appendingPathComponent("Receipts", isDirectory: true)
            
            for record in records {
                if let imagePath = record.receiptImagePath {
                    let sourceURL = receiptsSourcePath.appendingPathComponent(imagePath)
                    let destURL = receiptsDir.appendingPathComponent(imagePath)
                    try? FileManager.default.copyItem(at: sourceURL, to: destURL)
                }
            }
            
            // Note: ZIP creation stubbed for prototype
            // In production, use Apple's Archive framework or add ZIPFoundation via SPM
            // For now, return the uncompressed directory
            return tempDir
        } catch {
            print("Backup error: \(error)")
            return nil
        }
    }
    
    func restoreBackup(from zipURL: URL, modelContext: ModelContext) async -> Bool {
        return false
    }
}
