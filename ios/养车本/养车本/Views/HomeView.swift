import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var vehicle: Vehicle
    @Query(sort: \Record.date, order: .reverse) private var records: [Record]
    @Query private var reminders: [ReminderRule]
    @Query private var settings: [AppSettings]
    
    @State private var showingAddRecord = false
    @State private var showingMenu = false
    @State private var showingOdometerEdit = false
    @State private var newOdometer = ""
    
    var nextReminder: ReminderRule? {
        reminders
            .filter { $0.vehicle?.id == vehicle.id }
            .sorted { r1, r2 in
                let status1 = r1.calculateStatus(currentOdometerKm: vehicle.odometerKm)
                let status2 = r2.calculateStatus(currentOdometerKm: vehicle.odometerKm)
                
                if status1 == .overdue && status2 != .overdue { return true }
                if status1 != .overdue && status2 == .overdue { return false }
                if status1 == .approaching && status2 == .normal { return true }
                if status1 == .normal && status2 == .approaching { return false }
                
                return true
            }
            .first
    }
    
    var shouldShowOdometerPrompt: Bool {
        guard let appSettings = settings.first, !appSettings.hasDismissedOdometerPrompt else {
            return false
        }
        
        guard let reminder = nextReminder,
              reminder.mode == .mileage || reminder.mode == .earlier else {
            return false
        }
        
        let daysSinceUpdate = Calendar.current.dateComponents(
            [.day],
            from: vehicle.odometerUpdatedAt,
            to: Date()
        ).day ?? 0
        
        return daysSinceUpdate >= 7
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if shouldShowOdometerPrompt {
                        odometerPromptBanner
                    }
                    
                    nextTodoCard
                    
                    if !vehicleRecords.isEmpty {
                        recentRecordsSection
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle(vehicle.displayName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingOdometerEdit = true
                        } label: {
                            Label("更新里程", systemImage: "speedometer")
                        }
                        
                        NavigationLink {
                            VehicleView(vehicle: vehicle)
                        } label: {
                            Label("车辆信息", systemImage: "car")
                        }
                        
                        NavigationLink {
                            ExportView(vehicle: vehicle)
                        } label: {
                            Label("导出", systemImage: "square.and.arrow.up")
                        }
                        
                        if let appSettings = settings.first {
                            NavigationLink {
                                ProView(settings: appSettings)
                            } label: {
                                Label("Pro 版本", systemImage: "star")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecord) {
                AddRecordView(vehicle: vehicle)
            }
            .alert("更新里程", isPresented: $showingOdometerEdit) {
                TextField("当前里程（公里）", text: $newOdometer)
                    .keyboardType(.numberPad)
                Button("取消", role: .cancel) {
                    newOdometer = ""
                }
                Button("更新") {
                    updateOdometer()
                }
            } message: {
                Text("当前里程：\(Int(vehicle.odometerKm)) km")
            }
            .overlay(alignment: .bottom) {
                Button {
                    showingAddRecord = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("记一笔")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
    }
    
    private var vehicleRecords: [Record] {
        records.filter { $0.vehicle?.id == vehicle.id }
    }
    
    private var odometerPromptBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("该更新一下当前里程了吗？")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("上次更新：\(vehicle.odometerUpdatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                showingOdometerEdit = true
            } label: {
                Text("更新")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Button {
                dismissOdometerPrompt()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .cornerRadius(12)
    }
    
    private var nextTodoCard: some View {
        Group {
            if let reminder = nextReminder {
                ReminderCard(reminder: reminder, vehicle: vehicle) {
                    showingAddRecord = true
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无提醒")
                        .font(.headline)
                    Text("记一笔保养后可以设置提醒")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近记录")
                .font(.headline)
            
            ForEach(vehicleRecords.prefix(10)) { record in
                NavigationLink {
                    RecordDetailView(record: record)
                } label: {
                    RecordRow(record: record)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("记下最近一次保养")
                .font(.headline)
            Text("之后我会提醒你")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }
    
    private func updateOdometer() {
        guard let newValue = Double(newOdometer), newValue > 0 else { return }
        vehicle.odometerKm = newValue
        vehicle.odometerUpdatedAt = Date()
        
        let reminderService = ReminderService()
        reminderService.recalculateReminders(for: vehicle, modelContext: modelContext)
        
        try? modelContext.save()
        newOdometer = ""
    }
    
    private func dismissOdometerPrompt() {
        guard let appSettings = settings.first else { return }
        appSettings.hasDismissedOdometerPrompt = true
        try? modelContext.save()
    }
}

struct ReminderCard: View {
    let reminder: ReminderRule
    let vehicle: Vehicle
    let onComplete: () -> Void
    
    var status: ReminderStatus {
        reminder.calculateStatus(currentOdometerKm: vehicle.odometerKm)
    }
    
    var backgroundColor: Color {
        switch status {
        case .normal: return Color(.systemGray6)
        case .approaching: return Color.orange.opacity(0.2)
        case .overdue: return Color.red.opacity(0.2)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("下一件待办")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                statusBadge
            }
            
            Text(reminder.title)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(reminder.formattedRemaining(currentOdometerKm: vehicle.odometerKm))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                onComplete()
            } label: {
                Text("已完成")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
    }
    
    private var statusBadge: some View {
        Group {
            switch status {
            case .normal:
                EmptyView()
            case .approaching:
                Text("临近")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            case .overdue:
                Text("已过期")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
    }
}

struct RecordRow: View {
    let record: Record
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.headline)
                HStack(spacing: 12) {
                    Text(record.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let odometer = record.odometerKm {
                        Text("\(Int(odometer)) km")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let amount = record.formattedAmount {
                Text(amount)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ProView: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Pro 版本")
                    Spacer()
                    if settings.proUnlocked {
                        Text("已解锁")
                            .foregroundColor(.green)
                    } else {
                        Text("未解锁")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Text("• 去水印 PDF 导出")
                Text("• 更好的 PDF 排版")
                Text("• 无限 OCR 识别")
            } header: {
                Text("Pro 功能")
            }
            
            Section {
                if !settings.proUnlocked {
                    Button("购买 Pro - ¥48") {
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Button("恢复购买") {
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Pro 版本")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle.self, Record.self, ReminderRule.self, AppSettings.self, configurations: config)
    
    let vehicle = Vehicle(makeModel: "特斯拉 Model 3", powertrain: .bev, odometerKm: 15000)
    container.mainContext.insert(vehicle)
    
    return HomeView(vehicle: vehicle)
        .modelContainer(container)
}
