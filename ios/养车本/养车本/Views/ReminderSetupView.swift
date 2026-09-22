import SwiftUI
import SwiftData

struct ReminderSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]
    
    let record: Record
    let vehicle: Vehicle
    let onComplete: () -> Void
    
    @State private var setupReminder = true
    @State private var title: String
    @State private var intervalKm = ""
    @State private var intervalMonths = ""
    @State private var selectedMode: ReminderMode = .earlier
    
    init(record: Record, vehicle: Vehicle, onComplete: @escaping () -> Void) {
        self.record = record
        self.vehicle = vehicle
        self.onComplete = onComplete
        _title = State(initialValue: record.title)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("设置下次提醒", isOn: $setupReminder)
                } header: {
                    Text("提醒设置")
                }
                
                if setupReminder {
                    Section {
                        TextField("提醒项目", text: $title)
                    } header: {
                        Text("项目名称")
                    }
                    
                    Section {
                        Picker("提醒方式", selection: $selectedMode) {
                            ForEach([ReminderMode.mileage, .date, .earlier], id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("提醒方式")
                    }
                    
                    if selectedMode == .mileage || selectedMode == .earlier {
                        Section {
                            HStack {
                                TextField("间隔里程", text: $intervalKm)
                                    .keyboardType(.numberPad)
                                Text("公里")
                                    .foregroundColor(.secondary)
                            }
                        } header: {
                            Text("里程间隔")
                        } footer: {
                            Text("例如：机油保养每 5000 公里一次")
                        }
                    }
                    
                    if selectedMode == .date || selectedMode == .earlier {
                        Section {
                            HStack {
                                TextField("间隔月份", text: $intervalMonths)
                                    .keyboardType(.numberPad)
                                Text("个月")
                                    .foregroundColor(.secondary)
                            }
                        } header: {
                            Text("时间间隔")
                        } footer: {
                            Text("例如：车险每 12 个月一次")
                        }
                    }
                }
            }
            .navigationTitle("设置提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        completeSetup()
                    }
                }
            }
        }
    }
    
    private func completeSetup() {
        if setupReminder {
            createReminder()
            requestNotificationPermissionIfNeeded()
        }
        
        onComplete()
    }
    
    private func createReminder() {
        guard !title.isEmpty else { return }
        
        let kmInterval = Double(intervalKm)
        let monthsInterval = Int(intervalMonths)
        
        var nextDueKm: Double?
        var nextDueDate: Date?
        
        if let km = kmInterval, let recordOdometer = record.odometerKm {
            nextDueKm = recordOdometer + km
        }
        
        if let months = monthsInterval {
            nextDueDate = Calendar.current.date(byAdding: .month, value: months, to: record.date)
        }
        
        let reminder = ReminderRule(
            vehicle: vehicle,
            title: title,
            intervalKm: kmInterval,
            intervalMonths: monthsInterval,
            mode: selectedMode,
            nextDueKm: nextDueKm,
            nextDueDate: nextDueDate,
            lastCompletedAt: record.date,
            lastCompletedOdometerKm: record.odometerKm
        )
        
        modelContext.insert(reminder)
        try? modelContext.save()
        
        let reminderService = ReminderService()
        reminderService.scheduleNotifications(for: vehicle, modelContext: modelContext)
    }
    
    private func requestNotificationPermissionIfNeeded() {
        guard let appSettings = settings.first else { return }
        
        if !appSettings.hasRequestedNotificationPermission {
            let reminderService = ReminderService()
            Task {
                await reminderService.requestNotificationPermission()
            }
            appSettings.hasRequestedNotificationPermission = true
            try? modelContext.save()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle.self, Record.self, AppSettings.self, configurations: config)
    
    let vehicle = Vehicle(makeModel: "特斯拉 Model 3", powertrain: .bev, odometerKm: 15000)
    let record = Record(
        vehicle: vehicle,
        type: .service,
        title: "机油保养",
        date: Date(),
        odometerKm: 15000,
        amountCents: 58000
    )
    
    container.mainContext.insert(vehicle)
    container.mainContext.insert(record)
    
    return ReminderSetupView(record: record, vehicle: vehicle) {}
        .modelContainer(container)
}
