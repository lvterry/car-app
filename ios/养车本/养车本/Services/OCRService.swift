import UIKit
import Vision

struct OCRResult {
    let title: String?
    let date: Date?
    let odometerKm: Double?
    let amountYuan: Double?
    let shopName: String?
    let rawText: String
    
    var isSuccessful: Bool {
        title != nil || date != nil || odometerKm != nil || amountYuan != nil
    }
}

class OCRService {
    func recognizeReceipt(image: UIImage) async -> OCRResult {
        guard let cgImage = image.cgImage else {
            return OCRResult(title: nil, date: nil, odometerKm: nil, amountYuan: nil, shopName: nil, rawText: "")
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(
                        title: nil, date: nil, odometerKm: nil, amountYuan: nil, shopName: nil, rawText: ""
                    ))
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let rawText = recognizedStrings.joined(separator: "\n")
                let result = self.parseReceipt(from: recognizedStrings, rawText: rawText)
                
                continuation.resume(returning: result)
            }
            
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func parseReceipt(from lines: [String], rawText: String) -> OCRResult {
        var title: String?
        var date: Date?
        var odometerKm: Double?
        var amountYuan: Double?
        var shopName: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if title == nil {
                if let extracted = extractServiceTitle(from: trimmed) {
                    title = extracted
                }
            }
            
            if date == nil {
                if let extracted = extractDate(from: trimmed) {
                    date = extracted
                }
            }
            
            if odometerKm == nil {
                if let extracted = extractOdometer(from: trimmed) {
                    odometerKm = extracted
                }
            }
            
            if amountYuan == nil {
                if let extracted = extractAmount(from: trimmed) {
                    amountYuan = extracted
                }
            }
            
            if shopName == nil {
                if let extracted = extractShopName(from: trimmed) {
                    shopName = extracted
                }
            }
        }
        
        return OCRResult(
            title: title,
            date: date,
            odometerKm: odometerKm,
            amountYuan: amountYuan,
            shopName: shopName,
            rawText: rawText
        )
    }
    
    private func extractServiceTitle(from text: String) -> String? {
        let serviceKeywords = [
            "机油", "保养", "维修", "更换", "检查", "清洗",
            "轮胎", "刹车", "空调", "滤", "电池"
        ]
        
        for keyword in serviceKeywords {
            if text.contains(keyword) && text.count < 20 {
                return text
            }
        }
        
        return nil
    }
    
    private func extractDate(from text: String) -> Date? {
        let patterns = [
            "\\d{4}[-/年]\\d{1,2}[-/月]\\d{1,2}[日]?",
            "\\d{4}\\.\\d{1,2}\\.\\d{1,2}",
            "\\d{1,2}[-/]\\d{1,2}[-/]\\d{4}"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let dateString = String(text[range])
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "zh_CN")
                
                let formats = [
                    "yyyy-MM-dd",
                    "yyyy/MM/dd",
                    "yyyy.MM.dd",
                    "yyyy年MM月dd日",
                    "yyyy年M月d日",
                    "dd/MM/yyyy",
                    "MM/dd/yyyy"
                ]
                
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractOdometer(from text: String) -> Double? {
        let patterns = [
            "里程[：:]*\\s*(\\d+)",
            "公里[：:]*\\s*(\\d+)",
            "(\\d+)\\s*[kK][mM]",
            "ODO[：:]*\\s*(\\d+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                let nsString = text as NSString
                if match.numberOfRanges > 1 {
                    let numberString = nsString.substring(with: match.range(at: 1))
                    if let number = Double(numberString) {
                        return number
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractAmount(from text: String) -> Double? {
        let patterns = [
            "[¥￥]\\s*(\\d+\\.?\\d*)",
            "金额[：:]*\\s*(\\d+\\.?\\d*)",
            "合计[：:]*\\s*(\\d+\\.?\\d*)",
            "总计[：:]*\\s*(\\d+\\.?\\d*)",
            "(\\d+\\.\\d{2})\\s*元"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                let nsString = text as NSString
                if match.numberOfRanges > 1 {
                    let numberString = nsString.substring(with: match.range(at: 1))
                    if let number = Double(numberString) {
                        return number
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractShopName(from text: String) -> String? {
        let shopKeywords = ["店", "4S", "服务", "中心", "汽修", "修理"]
        
        for keyword in shopKeywords {
            if text.contains(keyword) && text.count < 30 && text.count > 2 {
                return text
            }
        }
        
        return nil
    }
}
