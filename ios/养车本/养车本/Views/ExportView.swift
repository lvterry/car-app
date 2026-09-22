import SwiftUI
import SwiftData
import PDFKit

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    
    let vehicle: Vehicle
    
    @State private var showingPDFPreview = false
    @State private var showingShareSheet = false
    @State private var showingBackupShare = false
    @State private var showingRestorePicker = false
    @State private var showingRestoreConfirm = false
    @State private var generatedPDF: URL?
    @State private var generatedBackup: URL?
    @State private var selectedRestoreURL: URL?
    @State private var isGenerating = false
    @State private var isRestoring = false
    
    var body: some View {
        List {
            Section {
                Button {
                    generatePDF()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("导出履历 PDF")
                                .font(.headline)
                            Text("可分享给买家的保养履历")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "doc.text")
                            .foregroundColor(.accentColor)
                    }
                }
                .disabled(isGenerating)
            } header: {
                Text("履历 PDF")
            } footer: {
                if let appSettings = settings.first, !appSettings.proUnlocked {
                    Text("免费版 PDF 会带有水印，升级 Pro 可去除水印")
                        .font(.caption)
                }
            }
            
            Section {
                Button {
                    generateBackup()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("导出备份包")
                                .font(.headline)
                            Text("包含所有数据和照片，用于换机恢复")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "archivebox")
                            .foregroundColor(.accentColor)
                    }
                }
                .disabled(isGenerating)
                
                Button {
                    showingRestorePicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("从备份恢复")
                                .font(.headline)
                            Text("选择之前导出的备份包")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.down.doc")
                            .foregroundColor(.accentColor)
                    }
                }
                .disabled(isGenerating || isRestoring)
            } header: {
                Text("备份包")
            } footer: {
                Text("备份包功能对所有用户免费")
            }
        }
        .navigationTitle("导出")
        .sheet(isPresented: $showingPDFPreview) {
            if let pdfURL = generatedPDF {
                PDFPreviewView(pdfURL: pdfURL) {
                    showingShareSheet = true
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let pdfURL = generatedPDF {
                ShareSheet(items: [pdfURL])
            }
        }
        .sheet(isPresented: $showingBackupShare) {
            if let backupURL = generatedBackup {
                ShareSheet(items: [backupURL])
            }
        }
        .fileImporter(
            isPresented: $showingRestorePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                selectedRestoreURL = url
                showingRestoreConfirm = true
            }
        }
        .alert("确认恢复备份", isPresented: $showingRestoreConfirm) {
            Button("取消", role: .cancel) {
                selectedRestoreURL = nil
            }
            Button("确认恢复", role: .destructive) {
                if let url = selectedRestoreURL {
                    restoreBackup(from: url)
                }
            }
        } message: {
            Text("恢复备份将会替换所有当前数据（车辆、记录、提醒）。此操作不可撤销。确定要继续吗？")
        }
        .overlay {
            if isGenerating || isRestoring {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(isRestoring ? "正在恢复…" : "正在生成…")
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
    
    private func generatePDF() {
        isGenerating = true
        
        Task {
            let pdfService = PDFService()
            let isPro = settings.first?.proUnlocked ?? false
            let records = fetchRecords()
            
            if let pdfURL = await pdfService.generateServiceHistoryPDF(
                vehicle: vehicle,
                records: records,
                isPro: isPro
            ) {
                await MainActor.run {
                    generatedPDF = pdfURL
                    isGenerating = false
                    showingPDFPreview = true
                }
            } else {
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
    
    private func generateBackup() {
        isGenerating = true
        
        Task {
            let backupService = BackupService()
            let records = fetchRecords()
            
            if let backupURL = await backupService.createBackup(
                vehicle: vehicle,
                records: records,
                modelContext: modelContext
            ) {
                await MainActor.run {
                    generatedBackup = backupURL
                    isGenerating = false
                    showingBackupShare = true
                }
            } else {
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
    
    private func fetchRecords() -> [Record] {
        let descriptor = FetchDescriptor<Record>(
            predicate: #Predicate { $0.vehicle?.id == vehicle.id },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func restoreBackup(from url: URL) {
        isRestoring = true
        selectedRestoreURL = nil
        
        Task {
            let backupService = BackupService()
            let success = await backupService.restoreBackup(from: url, modelContext: modelContext)
            
            await MainActor.run {
                isRestoring = false
                if success {
                }
            }
        }
    }
}

struct PDFPreviewView: View {
    let pdfURL: URL
    let onShare: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            PDFKitView(url: pdfURL)
                .navigationTitle("PDF 预览")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            onShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle.self, Record.self, AppSettings.self, configurations: config)
    
    let vehicle = Vehicle(makeModel: "特斯拉 Model 3", powertrain: .bev, odometerKm: 15000)
    container.mainContext.insert(vehicle)
    
    return NavigationStack {
        ExportView(vehicle: vehicle)
    }
    .modelContainer(container)
}
