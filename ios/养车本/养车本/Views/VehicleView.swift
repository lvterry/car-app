import SwiftUI
import SwiftData

struct VehicleView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var vehicle: Vehicle
    
    @State private var name: String
    @State private var makeModel: String
    @State private var odometerKm: String
    @State private var selectedPowertrain: Powertrain
    
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _name = State(initialValue: vehicle.name ?? "")
        _makeModel = State(initialValue: vehicle.makeModel)
        _odometerKm = State(initialValue: String(Int(vehicle.odometerKm)))
        _selectedPowertrain = State(initialValue: vehicle.powertrain)
    }
    
    var body: some View {
        Form {
            Section {
                TextField("车辆名称（可选）", text: $name)
                    .onChange(of: name) { _, newValue in
                        vehicle.name = newValue.isEmpty ? nil : newValue
                    }
                
                TextField("车型", text: $makeModel)
                    .onChange(of: makeModel) { _, newValue in
                        vehicle.makeModel = newValue
                    }
            } header: {
                Text("基本信息")
            } footer: {
                Text("车辆名称可用于区分多辆车，留空则显示车型")
            }
            
            Section {
                Picker("动力类型", selection: $selectedPowertrain) {
                    ForEach(Powertrain.allCases) { powertrain in
                        Text(powertrain.displayName).tag(powertrain)
                    }
                }
                .onChange(of: selectedPowertrain) { _, newValue in
                    vehicle.powertrain = newValue
                }
            } header: {
                Text("动力类型")
            }
            
            Section {
                HStack {
                    TextField("当前里程", text: $odometerKm)
                        .keyboardType(.numberPad)
                    Text("公里")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("上次更新")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(vehicle.odometerUpdatedAt, style: .relative)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("里程")
            } footer: {
                Text("更新里程后，会自动重新计算提醒")
            }
            
            Section {
                Button("保存") {
                    saveVehicle()
                }
            }
        }
        .navigationTitle("车辆信息")
    }
    
    private func saveVehicle() {
        if let newOdometer = Double(odometerKm), newOdometer != vehicle.odometerKm {
            vehicle.odometerKm = newOdometer
            vehicle.odometerUpdatedAt = Date()
            
            let reminderService = ReminderService()
            reminderService.recalculateReminders(for: vehicle, modelContext: modelContext)
        }
        
        try? modelContext.save()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle.self, configurations: config)
    
    let vehicle = Vehicle(makeModel: "特斯拉 Model 3", powertrain: .bev, odometerKm: 15000)
    container.mainContext.insert(vehicle)
    
    return NavigationStack {
        VehicleView(vehicle: vehicle)
    }
    .modelContainer(container)
}
