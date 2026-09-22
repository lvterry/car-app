import UIKit
import PDFKit
import SwiftData

class PDFService {
    func generateServiceHistoryPDF(
        vehicle: Vehicle,
        records: [Record],
        isPro: Bool
    ) async -> URL? {
        let pdfMetadata = [
            kCGPDFContextCreator: "养车本",
            kCGPDFContextAuthor: "养车本 App",
            kCGPDFContextTitle: "\(vehicle.displayName) 保养履历"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]
        
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("service_history_\(UUID().uuidString).pdf")
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        do {
            try renderer.writePDF(to: tempURL) { context in
                context.beginPage()
                
                var yOffset: CGFloat = 60
                
                drawTitle(at: &yOffset, in: pageRect, isPro: isPro)
                
                yOffset += 20
                drawVehicleInfo(vehicle: vehicle, at: &yOffset, in: pageRect)
                
                yOffset += 30
                drawRecordsTable(records: records, at: &yOffset, in: pageRect, context: context)
                
                drawFooter(at: pageHeight - 60, in: pageRect, isPro: isPro)
            }
            
            return tempURL
        } catch {
            print("PDF generation error: \(error)")
            return nil
        }
    }
    
    private func drawTitle(at yOffset: inout CGFloat, in rect: CGRect, isPro: Bool) {
        let titleText = "车辆保养履历"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        
        let titleSize = titleText.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (rect.width - titleSize.width) / 2,
            y: yOffset,
            width: titleSize.width,
            height: titleSize.height
        )
        
        titleText.draw(in: titleRect, withAttributes: titleAttributes)
        yOffset += titleSize.height + 10
        
        if !isPro {
            let watermarkText = "由 养车本 生成"
            let watermarkAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            
            let watermarkSize = watermarkText.size(withAttributes: watermarkAttributes)
            let watermarkRect = CGRect(
                x: (rect.width - watermarkSize.width) / 2,
                y: yOffset,
                width: watermarkSize.width,
                height: watermarkSize.height
            )
            
            watermarkText.draw(in: watermarkRect, withAttributes: watermarkAttributes)
            yOffset += watermarkSize.height
        }
    }
    
    private func drawVehicleInfo(vehicle: Vehicle, at yOffset: inout CGFloat, in rect: CGRect) {
        let margin: CGFloat = 60
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let lines = [
            "车型：\(vehicle.makeModel)",
            "动力类型：\(vehicle.powertrain.displayName)",
            "当前里程：\(Int(vehicle.odometerKm)) 公里"
        ]
        
        for line in lines {
            line.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: attributes)
            yOffset += 20
        }
    }
    
    private func drawRecordsTable(
        records: [Record],
        at yOffset: inout CGFloat,
        in rect: CGRect,
        context: UIGraphicsPDFRendererContext
    ) {
        let margin: CGFloat = 60
        let tableWidth = rect.width - 2 * margin
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        let columns = ["日期", "里程", "项目", "费用", "备注"]
        let columnWidths: [CGFloat] = [80, 70, 120, 70, 135]
        
        var xOffset = margin
        for (index, column) in columns.enumerated() {
            column.draw(
                at: CGPoint(x: xOffset + 5, y: yOffset + 5),
                withAttributes: headerAttributes
            )
            xOffset += columnWidths[index]
        }
        
        yOffset += 25
        
        drawLine(from: CGPoint(x: margin, y: yOffset), to: CGPoint(x: margin + tableWidth, y: yOffset))
        yOffset += 5
        
        var totalAmount = 0
        
        for record in records {
            if yOffset > rect.height - 120 {
                context.beginPage()
                yOffset = 60
            }
            
            let rowHeight: CGFloat = 30
            
            xOffset = margin
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateText = dateFormatter.string(from: record.date)
            dateText.draw(
                at: CGPoint(x: xOffset + 5, y: yOffset + 8),
                withAttributes: cellAttributes
            )
            xOffset += columnWidths[0]
            
            let odometerText = record.odometerKm.map { "\(Int($0))" } ?? "-"
            odometerText.draw(
                at: CGPoint(x: xOffset + 5, y: yOffset + 8),
                withAttributes: cellAttributes
            )
            xOffset += columnWidths[1]
            
            let titleRect = CGRect(x: xOffset + 5, y: yOffset + 8, width: columnWidths[2] - 10, height: rowHeight - 10)
            record.title.draw(in: titleRect, withAttributes: cellAttributes)
            xOffset += columnWidths[2]
            
            if let cents = record.amountCents {
                let amountText = String(format: "¥%.2f", Double(cents) / 100.0)
                amountText.draw(
                    at: CGPoint(x: xOffset + 5, y: yOffset + 8),
                    withAttributes: cellAttributes
                )
                totalAmount += cents
            } else {
                "-".draw(at: CGPoint(x: xOffset + 5, y: yOffset + 8), withAttributes: cellAttributes)
            }
            xOffset += columnWidths[3]
            
            let notesText = record.notes ?? "-"
            let notesRect = CGRect(x: xOffset + 5, y: yOffset + 8, width: columnWidths[4] - 10, height: rowHeight - 10)
            notesText.draw(in: notesRect, withAttributes: cellAttributes)
            
            yOffset += rowHeight
            
            drawLine(from: CGPoint(x: margin, y: yOffset), to: CGPoint(x: margin + tableWidth, y: yOffset))
        }
        
        yOffset += 20
        
        let totalText = "总计费用：¥\(String(format: "%.2f", Double(totalAmount) / 100.0))"
        let totalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        totalText.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: totalAttributes)
    }
    
    private func drawLine(from start: CGPoint, to end: CGPoint) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
    
    private func drawFooter(at yOffset: CGFloat, in rect: CGRect, isPro: Bool) {
        let footerText = "本履历由车主个人记录，仅供参考，不构成官方认证。"
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]
        
        let footerSize = footerText.size(withAttributes: footerAttributes)
        let footerRect = CGRect(
            x: (rect.width - footerSize.width) / 2,
            y: yOffset,
            width: footerSize.width,
            height: footerSize.height
        )
        
        footerText.draw(in: footerRect, withAttributes: footerAttributes)
    }
}
