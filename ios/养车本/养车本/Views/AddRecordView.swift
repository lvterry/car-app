import SwiftUI
import SwiftData
import PhotosUI

struct AddRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]
    
    let vehicle: Vehicle
    
    @State private var title = ""
    @State private var selectedType: RecordType = .service
    @State private var date = Date()
    @State private var odometerKm = ""
    @State private var amountYuan = ""
    @State private var notes = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var receiptImage: UIImage?
    @State private var showingCamera = false
    @State private var showingOCRConfirm = false
    @State private var ocrResult: OCRResult?
    @State private var isProcessingOCR = false
    
    @State private var showingReminderSetup = false
    @State private var savedRecord: Record?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $selectedType) {
                        ForEach(RecordType.allCases.filter { $0 != .charging }) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("项目名称（如：机油保养）", text: $title)
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    
                    TextField("里程（公里）", text: $odometerKm)
                        .keyboardType(.numberPad)
                    
                    TextField("费用（元）", text: $amountYuan)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("详情")
                }
                
                Section {
                    TextField("备注（可选）", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("备注")
                }
                
                Section {
                    if let image = receiptImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                        
                        Button("移除照片", role: .destructive) {
                            receiptImage = nil
                            selectedImage = nil
                        }
                    } else {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("拍照", systemImage: "camera")
                        }
                        
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            Label("从相册选择", systemImage: "photo")
                        }
                    }
                } header: {
                    Text("收据照片（可选）")
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    receiptImage = image
                    processImageWithOCR(image)
                }
            }
            .sheet(isPresented: $showingOCRConfirm) {
                if let result = ocrResult {
                    OCRConfirmView(
                        ocrResult: result,
                        receiptImage: receiptImage,
                        vehicle: vehicle
                    ) { confirmed in
                        if confirmed {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingReminderSetup) {
                if let record = savedRecord {
                    ReminderSetupView(record: record, vehicle: vehicle) {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        receiptImage = image
                        processImageWithOCR(image)
                    }
                }
            }
            .overlay {
                if isProcessingOCR {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("正在读票据…")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private func processImageWithOCR(_ image: UIImage) {
        isProcessingOCR = true
        
        Task {
            let ocrService = OCRService()
            let result = await ocrService.recognizeReceipt(image: image)
            
            await MainActor.run {
                isProcessingOCR = false
                
                if result.isSuccessful {
                    ocrResult = result
                    showingOCRConfirm = true
                } else {
                }
            }
        }
    }
    
    private func saveRecord() {
        let odometerValue = Double(odometerKm)
        let amountValue = Double(amountYuan).map { Int($0 * 100) }
        
        var imagePath: String?
        if let image = receiptImage {
            imagePath = saveReceiptImage(image)
        }
        
        let record = Record(
            vehicle: vehicle,
            type: selectedType,
            title: title,
            date: date,
            odometerKm: odometerValue,
            amountCents: amountValue,
            notes: notes.isEmpty ? nil : notes,
            receiptImagePath: imagePath
        )
        
        modelContext.insert(record)
        
        if let odometer = odometerValue, odometer > vehicle.odometerKm {
            vehicle.odometerKm = odometer
            vehicle.odometerUpdatedAt = Date()
            
            let reminderService = ReminderService()
            reminderService.recalculateReminders(for: vehicle, modelContext: modelContext)
        }
        
        try? modelContext.save()
        
        savedRecord = record
        showingReminderSetup = true
    }
    
    private func saveReceiptImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let receiptsPath = documentsPath.appendingPathComponent("Receipts", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: receiptsPath, withIntermediateDirectories: true)
        
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = receiptsPath.appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
        
        return filename
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle.self, Record.self, AppSettings.self, configurations: config)
    
    let vehicle = Vehicle(makeModel: "特斯拉 Model 3", powertrain: .bev, odometerKm: 15000)
    container.mainContext.insert(vehicle)
    
    return AddRecordView(vehicle: vehicle)
        .modelContainer(container)
}
