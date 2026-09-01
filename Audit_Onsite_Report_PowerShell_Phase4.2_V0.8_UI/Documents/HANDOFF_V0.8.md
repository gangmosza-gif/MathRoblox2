# HANDOFF: Audit Onsite Report PowerShell (ปรับปรุงแทนฉบับ V0.5)

**สถานะล่าสุด:** Phase 4.2 V0.8 UI Test - ยังไม่ใช่ Final

## 1. สิ่งที่เปลี่ยนจาก Handoff ฉบับ V0.5

ฉบับ V0.5 เขียนตอนที่ Export Word ยังทำไม่ได้ ปัจจุบันข้อมูลต่อไปนี้ **ล้าสมัยแล้ว**

- ข้อ 6 เดิมระบุว่า ปุ่ม Export Word ยัง Block และยังไม่สร้าง Word จริง
  ปัจจุบัน Phase 4.1 และ 4.2 ทำ Export DOCX ได้จริงแล้ว รูปแบบคงตาม Template
- ข้อ 7 Phase 4.1 และ Phase 4.2 ในรายการงานถัดไป ทำเสร็จแล้วทั้งหมด
- Template ที่ใช้จริงคือ `Templates/Word_Template_Onsite_Latest.docx` มี Placeholder 28 รายการ
  โดยตัด `[[AUDIT_PERIOD]]` และ `[[DATA_AS_OF]]` ออก และเพิ่ม
  `[[ONSITE_DATE]]` `[[MEETING_DATE]]` `[[LEAD_DATE]]` `[[AUDITEE_DATE]]`
  ซึ่งทั้ง 4 ตัวใช้ค่าเดียวกับ REPORT_DATE
- ช่องข้อมูลรายงานยังคงต้องมี 15 ช่องเหมือนเดิม แม้ 3.2 และ 3.3 จะไม่ถูกใช้ใน Template แล้ว

## 2. สิ่งที่ยังไม่เปลี่ยนและยังต้องรักษา

- Mapping: ยืนยันแล้วเฉพาะข้อ 3.2 ที่สถานะ `draft_observed` อีก 10 ข้อยังเป็น `pending_file`
- ห้ามเดา Mapping ต้องได้ไฟล์จริงและคำชี้เป้าจากผู้ใช้ก่อน
- ห้ามแก้หรือลบไฟล์ Excel ต้นฉบับ เปิดแบบ Read-only เท่านั้น
- Output ต้องเป็นไฟล์ใหม่เสมอ
- ข้อกำหนดรูปแบบ Word ทั้งหมดในฉบับ V0.5 ยังใช้อยู่ (TH SarabunPSK, เนื้อหาสีดำ, คำว่า ลับ สีแดง, ห้ามแก้ Alignment / Tab / Indent / Layout)
- ห้ามลดข้อมูลรายงานจาก 15 ช่อง และห้ามลบปุ่ม Fix, ล้างค่าจำ, เริ่มสาขาใหม่
  (ปุ่มล้างค่าจำและเริ่มสาขาใหม่หายไปใน V0.7 และถูกนำกลับมาแล้วใน V0.8)

## 3. โครงสร้างโค้ดปัจจุบัน

| ไฟล์ | หน้าที่ | แก้ล่าสุด |
|---|---|---|
| `Start-AuditOnsiteReport.ps1` | จุดเริ่ม โหลด Module และ Config | V0.8 เพิ่มการโหลด Theme |
| `Modules/AuditOnsite.Core.psm1` | JSON, Log, Path | ไม่แก้ตั้งแต่ V0.5 |
| `Modules/AuditOnsite.Excel.psm1` | Excel COM Read-only, Workbook Inspector, Mapping Scan | ไม่แก้ตั้งแต่ V0.5 |
| `Modules/AuditOnsite.Word.psm1` | ตรวจ Template, Export Engine, ลบย่อหน้าว่างท้ายเอกสาร | ไม่แก้ตั้งแต่ V0.7 |
| `Modules/AuditOnsite.Theme.psm1` | สี ฟอนต์ ปุ่ม ป้ายสถานะ การ์ด ตาราง | ใหม่ใน V0.8 |
| `Modules/AuditOnsite.UI.psm1` | หน้าจอทั้งหมด | เขียนใหม่ใน V0.8 |

## 4. งานถัดไปตามลำดับความสำคัญ

1. ทดสอบ V0.8 ตาม `Documents/TEST_PLAN.md` โดยเฉพาะข้อ Regression 1 ถึง 10
2. ตรวจไฟล์ Word ที่ Export จริงว่าหน้าเปล่าท้ายเอกสารหายหรือยัง หากยังอยู่ให้ส่งไฟล์จริงมาวิเคราะห์ Section และ Page Break
3. ยืนยัน Mapping ข้อ 3.2 จาก `draft_observed` เป็น `user_confirmed` หลังผู้ใช้เทียบข้อความกับ Excel จริง
4. เก็บ Mapping อีก 10 ข้อจากไฟล์จริงและคำชี้เป้าของผู้ใช้ ทีละข้อ ห้ามเดา
5. งานปรับ UI เพิ่มเติม ดู `Documents/UI_REVIEW.md` หัวข้อ 3

## 5. คำเตือนสำหรับ Session ถัดไป

- ห้ามถือ `draft_observed` เป็นการยืนยัน
- ห้ามเปลี่ยนสถานะเป็น Final จนกว่าผู้ใช้จะยืนยัน
- ถ้าจะแก้ UI ให้แก้ที่ `AuditOnsite.Theme.psm1` และ `AuditOnsite.UI.psm1` เท่านั้น อย่าแตะ Word และ Excel Module
