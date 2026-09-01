# Changelog

## Phase 4.2 V0.9 Accessible Test
- ขยายฟอนต์ทั้งโปรแกรม ขั้นต่ำ 11 pt บังคับไว้ใน New-AuditFont
- เพิ่มปุ่มขยายตัวอักษร 4 ระดับ 100/125/150/175 บนแถบหัว พร้อมคีย์ลัด Ctrl + - 0
- จำระดับซูมไว้ใน Config/UI_Settings.json
- เก็บและคืนค่าที่ผู้ใช้กรอกทั้งหมดเมื่อเปลี่ยนขนาด ไม่ต้องกรอกใหม่
- เพิ่ม Get-AuditScaled ให้ขนาดพิกเซลทุกจุดขยายตามระดับซูม
- แยก Start-AuditOnsiteUI เป็นตัวห่อหุ้ม และ New-AuditOnsiteWindow เป็นตัวสร้างหน้าต่าง
- เพิ่ม New-AuditFillCard และ New-AuditTextBox ใน Theme
- เพิ่ม Contrast ของสีข้อความรองและสีเส้นขอบ
- จำกัดขนาดหน้าต่างไม่ให้เกินพื้นที่จอจริง
- ไม่แก้ Word Export Engine, Excel Module, Core Module, Config Mapping และ Template

## Phase 4.2 V0.8 UI Test
- เพิ่ม AuditOnsite.Theme.psm1 เป็นชั้น Design System กลาง
- เขียน AuditOnsite.UI.psm1 ใหม่เป็นแบบ Layout ยืดหยุ่น ไม่ใช้พิกัดตายตัว
- เปลี่ยน TabControl เป็นเมนูขั้นตอนด้านซ้าย
- เพิ่มแถบความคืบหน้าและแถบสถานะที่บอกเหตุผลที่ยัง Export ไม่ได้แบบทันที
- คืนปุ่มล้างค่าจำทั้งหมดและปุ่มเริ่มสาขาใหม่
- เพิ่มปุ่มเติมวันที่แบบไทย ลากวางไฟล์ Excel ค้นหาหัวข้อผลตรวจ และคีย์ลัด
- เปลี่ยน Export Gate เป็นหน้าต่างยืนยันแบบตาราง
- แก้คำสั่งเปิด Explorer หลัง Export ที่ต่อสตริงผิด และเลิกใช้ตัวแปรชื่อ host

## Phase 4.2 V0.7 Test
- Add Manual Entry and result-source tracking
- Add pre-export source summary and confirmation gate
- Permit manual results for pending mappings
- Add conservative trailing-empty-paragraph cleanup
- Preserve Template layout and Phase 4.1 Export Engine
