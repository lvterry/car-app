import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var vehicles: [Vehicle]
    @Query private var settings: [AppSettings]
    
    @State private var showingVehicleSetup = false
    
    var body: some View {
        Group {
            if let vehicle = vehicles.first {
                HomeView(vehicle: vehicle)
            } else {
                VehicleSetupView()
            }
        }
        .onAppear {
            setupInitialData()
        }
    }
    
    private func setupInitialData() {
        if settings.isEmpty {
            let appSettings = AppSettings()
            modelContext.insert(appSettings)
            try? modelContext.save()
        }
    }
}

struct VehicleSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var makeModel = ""
    @State private var odometerKm = ""
    @State private var selectedPowertrain: Powertrain = .fuel
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("车型（如：特斯拉 Model 3）", text: $makeModel)
                } header: {
                    Text("车辆信息")
                }
                
                Section {
                    Picker("动力类型", selection: $selectedPowertrain) {
                        ForEach(Powertrain.allCases) { powertrain in
                            Text(powertrain.displayName).tag(powertrain)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("动力类型")
                }
                
                Section {
                    TextField("当前里程", text: $odometerKm)
                        .keyboardType(.numberPad)
                } header: {
                    Text("当前里程（公里）")
                }
                
                Section {
                    Button("创建车辆") {
                        createVehicle()
                    }
                    .disabled(makeModel.isEmpty || odometerKm.isEmpty)
                }
            }
            .navigationTitle("添加车辆")
        }
    }
    
    private func createVehicle() {
        guard let odometer = Double(odometerKm) else { return }
        
        let vehicle = Vehicle(
            makeModel: makeModel,
            powertrain: selectedPowertrain,
            odometerKm: odometer
        )
        
        modelContext.insert(vehicle)
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Vehicle.self, Record.self, ReminderRule.self, AppSettings.self], inMemory: true)
}
