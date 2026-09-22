import SwiftUI
import SwiftData

struct RecordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var record: Record
    
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @State private var showingImage = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(record.type.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                DetailRow(label: "日期", value: record.date.formatted(date: .long, time: .omitted))
                
                if let odometer = record.odometerKm {
                    DetailRow(label: "里程", value: "\(Int(odometer)) km")
                }
                
                if let amount = record.formattedAmount {
                    DetailRow(label: "费用", value: amount)
                }
                
                if let notes = record.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.body)
                    }
                }
                
                if let imagePath = record.receiptImagePath,
                   let image = loadReceiptImage(imagePath) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("收据照片")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button {
                            showingImage = true
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("记录详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isEditing = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingImage) {
            if let imagePath = record.receiptImagePath,
               let image = loadReceiptImage(imagePath) {
                ImageViewer(image: image)
            }
        }
        .alert("删除记录", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("确定要删除这条记录吗？")
        }
    }
    
    private func loadReceiptImage(_ filename: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let receiptsPath = documentsPath.appendingPathComponent("Receipts", isDirectory: true)
        let fileURL = receiptsPath.appendingPathComponent(filename)
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    private func deleteRecord() {
        if let imagePath = record.receiptImagePath {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let receiptsPath = documentsPath.appendingPathComponent("Receipts", isDirectory: true)
            let fileURL = receiptsPath.appendingPathComponent(imagePath)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        modelContext.delete(record)
        try? modelContext.save()
        dismiss()
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle.self, Record.self, configurations: config)
    
    let vehicle = Vehicle(makeModel: "特斯拉 Model 3", powertrain: .bev, odometerKm: 15000)
    let record = Record(
        vehicle: vehicle,
        type: .service,
        title: "机油保养",
        date: Date(),
        odometerKm: 15000,
        amountCents: 58000,
        notes: "更换机油和机滤"
    )
    
    container.mainContext.insert(vehicle)
    container.mainContext.insert(record)
    
    return NavigationStack {
        RecordDetailView(record: record)
    }
    .modelContainer(container)
}
