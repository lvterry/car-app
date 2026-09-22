# 养车本 · 技术意见摘要（Architect）

完整讨论结论摘要，供实现对照。产品约束以 `PRODUCT.md` 为准。

## 选型

- SwiftUI + NavigationStack  
- 存储：SwiftData（默认）或 GRDB/SQLite（要强 SQL 时）  
- 图片：FileManager；DB 只存相对路径  
- OCR / PDF / IAP 分端口，便于替换  

## OCR

- 默认 **Vision 端侧** → raw text → 规则/关键词填草稿 → 确认页  
- 云端可选增强，默认关；同一确认页接口  
- 验收见 PRODUCT §4A，勿承诺字段全对  

## 提醒

- `dueMileage` / `dueDate` / `mode: mileage|date|earlier`  
- 时间：`UNUserNotificationCenter`  
- 里程：用户更新里程时重算并重排通知  
- 首页待办为真相源  

## PDF & IAP

- PDFKit 自绘；中文系统字体  
- StoreKit 2；水印在生成时绘制；恢复购买必有  
- 未购可预览带水印 PDF  

## 模型最小实体

- **Vehicle：** id, name?, makeModel, powertrain, odometerKm, odometerUpdatedAt, …  
- **Record：** id, vehicleId, type(service|repair|other|charging), title, date, odometerKm?, amountCents?, notes?, receiptImagePath?, ocrRawText?, …  
- **ReminderRule：** intervalKm?, intervalMonths?, nextDueKm?, nextDueDate?, notifyEnabled  
- **AppSettings：** ocrMode, proUnlocked  

金额用整数分。

## 工期粗估

约 **6–10 人周**（一人约 1.5–2.5 个月）。云端 OCR 再加 1–2 周。

## Top 风险

1. 中文小票 OCR 预期  
2. 里程提醒「不可靠感」  
3. IAP + 导出体验边界  
