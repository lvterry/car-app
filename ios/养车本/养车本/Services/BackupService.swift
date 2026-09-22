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
    
    func restoreBackup(from backupURL: URL, modelContext: ModelContext) async -> Bool {
        do {
            let jsonURL = backupURL.appendingPathComponent("backup.json")
            let jsonData = try Data(contentsOf: jsonURL)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let backupData = try decoder.decode(BackupData.self, from: jsonData)
            
            let allVehicles = try modelContext.fetch(FetchDescriptor<Vehicle>())
            for vehicle in allVehicles {
                modelContext.delete(vehicle)
            }
            
            let allRecords = try modelContext.fetch(FetchDescriptor<Record>())
            for record in allRecords {
                modelContext.delete(record)
            }
            
            let allReminders = try modelContext.fetch(FetchDescriptor<ReminderRule>())
            for reminder in allReminders {
                modelContext.delete(reminder)
            }
            
            let vehicle = Vehicle(
                id: backupData.vehicle.id,
                name: backupData.vehicle.name,
                makeModel: backupData.vehicle.makeModel,
                powertrain: Powertrain(rawValue: backupData.vehicle.powertrain) ?? .fuel,
                odometerKm: backupData.vehicle.odometerKm,
                odometerUpdatedAt: backupData.vehicle.odometerUpdatedAt
            )
            modelContext.insert(vehicle)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let receiptsPath = documentsPath.appendingPathComponent("Receipts", isDirectory: true)
            try? FileManager.default.createDirectory(at: receiptsPath, withIntermediateDirectories: true)
            
            let existingReceipts = try? FileManager.default.contentsOfDirectory(atPath: receiptsPath.path)
            existingReceipts?.forEach { filename in
                try? FileManager.default.removeItem(at: receiptsPath.appendingPathComponent(filename))
            }
            
            let backupReceiptsPath = backupURL.appendingPathComponent("receipts")
            if FileManager.default.fileExists(atPath: backupReceiptsPath.path) {
                let receiptFiles = try? FileManager.default.contentsOfDirectory(atPath: backupReceiptsPath.path)
                receiptFiles?.forEach { filename in
                    let sourceURL = backupReceiptsPath.appendingPathComponent(filename)
                    let destURL = receiptsPath.appendingPathComponent(filename)
                    try? FileManager.default.copyItem(at: sourceURL, to: destURL)
                }
            }
            
            for recordBackup in backupData.records {
                let record = Record(
                    id: recordBackup.id,
                    vehicle: vehicle,
                    type: RecordType(rawValue: recordBackup.type) ?? .other,
                    title: recordBackup.title,
                    date: recordBackup.date,
                    odometerKm: recordBackup.odometerKm,
                    amountCents: recordBackup.amountCents,
                    notes: recordBackup.notes,
                    receiptImagePath: recordBackup.receiptImagePath,
                    ocrRawText: recordBackup.ocrRawText,
                    kWh: recordBackup.kWh,
                    locationKind: recordBackup.locationKind
                )
                modelContext.insert(record)
            }
            
            for reminderBackup in backupData.reminders {
                let reminder = ReminderRule(
                    id: reminderBackup.id,
                    vehicle: vehicle,
                    title: reminderBackup.title,
                    intervalKm: reminderBackup.intervalKm,
                    intervalMonths: reminderBackup.intervalMonths,
                    mode: ReminderMode(rawValue: reminderBackup.mode) ?? .earlier,
                    nextDueKm: reminderBackup.nextDueKm,
                    nextDueDate: reminderBackup.nextDueDate,
                    notifyEnabled: reminderBackup.notifyEnabled,
                    createdAt: reminderBackup.createdAt,
                    lastCompletedAt: reminderBackup.lastCompletedAt,
                    lastCompletedOdometerKm: reminderBackup.lastCompletedOdometerKm
                )
                modelContext.insert(reminder)
            }
            
            try modelContext.save()
            
            let reminderService = ReminderService()
            reminderService.scheduleNotifications(for: vehicle, modelContext: modelContext)
            
            return true
        } catch {
            print("Restore error: \(error)")
            return false
        }
    }
}
