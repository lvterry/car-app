import SwiftUI
import SwiftData

struct OCRConfirmView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let ocrResult: OCRResult
    let receiptImage: UIImage?
    let vehicle: Vehicle
    let onComplete: (Bool) -> Void
    
    @State private var title: String
    @State private var selectedType: RecordType = .service
    @State private var date: Date
    @State private var odometerKm: String
    @State private var amountYuan: String
    @State private var shopName: String
    @State private var notes: String
    
    @State private var showingReminderSetup = false
    @State private var savedRecord: Record?
    @State private var showingImage = false
    
    init(ocrResult: OCRResult, receiptImage: UIImage?, vehicle: Vehicle, onComplete: @escaping (Bool) -> Void) {
        self.ocrResult = ocrResult
        self.receiptImage = receiptImage
        self.vehicle = vehicle
        self.onComplete = onComplete
        
        _title = State(initialValue: ocrResult.title ?? "")
        _date = State(initialValue: ocrResult.date ?? Date())
        _odometerKm = State(initialValue: ocrResult.odometerKm.map { String(Int($0)) } ?? "")
        _amountYuan = State(initialValue: ocrResult.amountYuan.map { String(format: "%.2f", $0) } ?? "")
        _shopName = State(initialValue: ocrResult.shopName ?? "")
        _notes = State(initialValue: "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("识别成草稿，你确认后才保存")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("OCR 结果")
                }
                
                Section {
                    Picker("类型", selection: $selectedType) {
                        ForEach(RecordType.allCases.filter { $0 != .charging }) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("项目名称", text: $title)
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    
                    TextField("里程（公里）", text: $odometerKm)
                        .keyboardType(.numberPad)
                    
                    TextField("费用（元）", text: $amountYuan)
                        .keyboardType(.decimalPad)
                    
                    TextField("店名", text: $shopName)
                } header: {
                    Text("详情")
                }
                
                Section {
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("备注")
                }
                
                if receiptImage != nil {
                    Section {
                        Button {
                            showingImage = true
                        } label: {
                            Label("查看原图", systemImage: "photo")
                        }
                    } header: {
                        Text("收据照片")
                    }
                }
            }
            .navigationTitle("确认信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                        onComplete(false)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingImage) {
                if let image = receiptImage {
                    ImageViewer(image: image)
                }
            }
            .sheet(isPresented: $showingReminderSetup) {
                if let record = savedRecord {
                    ReminderSetupView(record: record, vehicle: vehicle) {
                        dismiss()
                        onComplete(true)
                    }
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
        
        var finalNotes = notes
        if !shopName.isEmpty {
            finalNotes = shopName + (notes.isEmpty ? "" : "\n\(notes)")
        }
        
        let record = Record(
            vehicle: vehicle,
            type: selectedType,
            title: title,
            date: date,
            odometerKm: odometerValue,
            amountCents: amountValue,
            notes: finalNotes.isEmpty ? nil : finalNotes,
            receiptImagePath: imagePath,
            ocrRawText: ocrResult.rawText
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

struct ImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZoomableScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .navigationTitle("收据照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.bouncesZoom = true
        
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostedView)
        
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hostedView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableScrollView
        let hostingController: UIHostingController<Content>
        
        init(_ parent: ZoomableScrollView) {
            self.parent = parent
            self.hostingController = UIHostingController(rootView: parent.content)
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle.self, Record.self, configurations: config)
    
    let vehicle = Vehicle(makeModel: "特斯拉 Model 3", powertrain: .bev, odometerKm: 15000)
    container.mainContext.insert(vehicle)
    
    let ocrResult = OCRResult(
        title: "机油保养",
        date: Date(),
        odometerKm: 15500,
        amountYuan: 580,
        shopName: "4S店",
        rawText: "Sample OCR text"
    )
    
    return OCRConfirmView(ocrResult: ocrResult, receiptImage: nil, vehicle: vehicle) { _ in }
        .modelContainer(container)
}
