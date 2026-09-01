Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$script:ThaiMonths = @('มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม')

function Get-AuditThaiDate {
    param([datetime]$Date = (Get-Date))
    return ('{0} {1} {2}' -f $Date.Day,$script:ThaiMonths[$Date.Month - 1],($Date.Year + 543))
}

function Get-AuditUiSettingsPath { param([string]$AppRoot) return (Join-Path $AppRoot 'Config\UI_Settings.json') }

function Read-AuditUiScale {
    # อ่านระดับซูมที่ผู้ใช้เลือกไว้ครั้งก่อน ถ้าไฟล์ไม่มีหรือเสีย ให้กลับไป 100 เปอร์เซ็นต์
    param([string]$AppRoot)
    $path = Get-AuditUiSettingsPath -AppRoot $AppRoot
    if (-not (Test-Path -LiteralPath $path)) { return 1.0 }
    try { $settings = Read-AuditJson $path; return [double]$settings.ui_scale } catch { return 1.0 }
}

function Write-AuditUiScale {
    param([string]$AppRoot,[double]$Scale)
    Write-AuditJson ([pscustomobject]@{ ui_scale = $Scale; saved_at = (Get-Date).ToString('s') }) (Get-AuditUiSettingsPath -AppRoot $AppRoot)
}

function Show-AuditExportConfirm {
    <# หน้าต่างยืนยันก่อน Export แทน MessageBox เดิม แสดงแหล่งข้อมูลรายข้อเป็นตาราง #>
    param([Parameter(Mandatory)]$Owner,[Parameter(Mandatory)]$Rows,[string]$OutputName = '')
    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = 'ยืนยันก่อน Export'
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MinimizeBox = $false; $dialog.MaximizeBox = $false
    $dialog.Size = New-Object Drawing.Size((Get-AuditScaled 860),(Get-AuditScaled 660))
    $dialog.BackColor = Get-AuditColor 'Canvas'
    $dialog.Font = New-AuditFont -Size 12

    $head = New-Object Windows.Forms.Panel
    $head.Dock = 'Top'; $head.Height = Get-AuditScaled 84; $head.BackColor = Get-AuditColor 'Navy'
    $headText = New-AuditLabel -Text 'ตรวจแหล่งข้อมูลผลตรวจก่อนสร้างไฟล์ Word' -Size 15 -Style 'Bold' -ForeColor ([Drawing.Color]::White) -AutoSize
    $headText.Location = New-Object Drawing.Point((Get-AuditScaled 22),(Get-AuditScaled 16))
    $headSub = New-AuditLabel -Text $OutputName -Size 11 -ForeColor ([Drawing.Color]::FromArgb(178,198,218)) -AutoSize
    $headSub.Location = New-Object Drawing.Point((Get-AuditScaled 22),(Get-AuditScaled 50))
    $head.Controls.AddRange(@($headText,$headSub))

    $grid = New-Object Windows.Forms.DataGridView
    $grid.Dock = 'Fill'
    [void](Set-AuditGridStyle -Grid $grid)
    foreach ($column in @('ข้อ','หัวข้อ','แหล่งข้อมูล')) { [void]$grid.Columns.Add($column,$column) }
    $grid.Columns[0].Width = Get-AuditScaled 60
    $grid.Columns[1].AutoSizeMode = 'Fill'
    $grid.Columns[2].Width = Get-AuditScaled 170
    foreach ($row in $Rows) {
        $index = $grid.Rows.Add()
        $grid.Rows[$index].Cells[0].Value = $row.ItemId
        $grid.Rows[$index].Cells[1].Value = $row.Title
        $grid.Rows[$index].Cells[2].Value = $row.Source
        switch (Get-AuditStatusKind -Status $row.Source) {
            'Warning' { $grid.Rows[$index].Cells[2].Style.ForeColor = Get-AuditColor 'Warning' }
            'Success' { $grid.Rows[$index].Cells[2].Style.ForeColor = Get-AuditColor 'Success' }
            default   { $grid.Rows[$index].Cells[2].Style.ForeColor = Get-AuditColor 'Accent' }
        }
    }

    $gridHost = New-Object Windows.Forms.Panel
    $gridHost.Dock = 'Fill'; $gridHost.Padding = New-Object Windows.Forms.Padding((Get-AuditScaled 20),(Get-AuditScaled 16),(Get-AuditScaled 20),(Get-AuditScaled 8))
    $gridHost.BackColor = Get-AuditColor 'Canvas'
    $gridHost.Controls.Add($grid)

    $foot = New-Object Windows.Forms.Panel
    $foot.Dock = 'Bottom'; $foot.Height = Get-AuditScaled 96; $foot.BackColor = Get-AuditColor 'Canvas'
    $note = New-AuditLabel -Text 'AUTO_DRAFT คือค่าที่อ่านจาก Excel แต่ Mapping ยังไม่ยืนยัน กรุณาตรวจข้อความก่อนยืนยัน' -Size 11 -ForeColor (Get-AuditColor 'Warning') -AutoSize
    $note.Location = New-Object Drawing.Point((Get-AuditScaled 24),(Get-AuditScaled 12))
    $cancel = New-AuditButton -Text 'ยกเลิก' -Width 150 -Kind 'Secondary'
    $cancel.DialogResult = 'No'
    $confirm = New-AuditButton -Text 'ยืนยันและ Export' -Width 210 -Kind 'Primary'
    $confirm.DialogResult = 'Yes'
    $foot.Controls.AddRange(@($note,$cancel,$confirm))
    $placeButtons = {
        $confirm.Location = New-Object Drawing.Point(($foot.Width - $confirm.Width - (Get-AuditScaled 24)),(Get-AuditScaled 46))
        $cancel.Location = New-Object Drawing.Point(($confirm.Left - $cancel.Width - (Get-AuditScaled 12)),(Get-AuditScaled 46))
    }
    $foot.Add_Resize({ & $placeButtons }.GetNewClosure())
    & $placeButtons

    $dialog.Controls.AddRange(@($gridHost,$foot,$head))
    $dialog.AcceptButton = $confirm
    $dialog.CancelButton = $cancel
    $result = $dialog.ShowDialog($Owner)
    $dialog.Dispose()
    return ($result -eq [Windows.Forms.DialogResult]::Yes)
}

function Start-AuditOnsiteUI {
    <#
      ตัวห่อหุ้ม เปิดหน้าต่างใหม่ทุกครั้งที่ผู้ใช้เปลี่ยนขนาดตัวอักษร
      การสร้างหน้าต่างใหม่ทั้งบานคือวิธีที่พลาดยากที่สุดใน WinForms
      เพราะไม่ต้องไล่เปลี่ยนฟอนต์และขนาดของคอนโทรลทีละตัว
    #>
    param([string]$AppRoot,$Config,[string]$FixedPath)
    [void](Set-AuditUiScale (Read-AuditUiScale -AppRoot $AppRoot))
    $carry = $null
    while ($true) {
        $outcome = New-AuditOnsiteWindow -AppRoot $AppRoot -Config $Config -FixedPath $FixedPath -Carry $carry
        if (-not $outcome.Restart) { break }
        [void](Set-AuditUiScale $outcome.Carry.Scale)
        $carry = $outcome.Carry
    }
}

function New-AuditOnsiteWindow {
    param([string]$AppRoot,$Config,[string]$FixedPath,$Carry = $null)

    $state = @{
        Files         = New-Object Collections.Generic.List[string]
        Fields        = @{}
        FixChecks     = @{}
        Results       = @{}
        ResultSources = @{}
        ResultBadges  = @{}
        ResultCards   = @{}
        Fix           = @{}
        TemplateReady = $false
        TemplateNote  = 'ยังไม่ได้ตรวจ Template'
        SummarySignature = ''
        ActivePage       = 0
    }
    # ผลลัพธ์ที่ส่งกลับให้ตัวห่อหุ้ม บอกว่าต้องเปิดหน้าต่างใหม่ด้วยขนาดใหม่หรือไม่
    $outcome = @{ Restart = $false; Carry = $null }
    if (Test-Path $FixedPath) {
        try { $fixed = Read-AuditJson $FixedPath; foreach ($property in $fixed.PSObject.Properties) { $state.Fix[$property.Name] = [string]$property.Value } } catch { }
    }

    $requiredKeys = @('AUDIT_UNIT','PHONE','DOCUMENT_NO','REPORT_DATE','BRANCH_NAME','RECIPIENT','APPROVAL_NO','APPROVAL_DATE','AUDITORS','LEAD_NAME','LEAD_POSITION','AUDITEE_NAME','AUDITEE_POSITION')
    $dateKeys = @('REPORT_DATE','APPROVAL_DATE','AUDIT_PERIOD','DATA_AS_OF')
    $mappings = @($Config.mappings)
    $template = Join-Path $AppRoot 'Templates\Word_Template_Onsite_Latest.docx'

    # ---------- โครงหน้าต่างหลัก ----------
    $form = New-Object Windows.Forms.Form
    $form.Text = 'Audit Onsite Report - Phase 4.2 V0.9'
    $form.StartPosition = 'CenterScreen'
    $working = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    # ขนาดหน้าต่างต้องไม่เกินพื้นที่จอจริง ไม่งั้นที่ 175 เปอร์เซ็นต์จะเปิดมาแล้วล้นจอ
    $form.Size = New-Object Drawing.Size([Math]::Min((Get-AuditScaled 1400),$working.Width),[Math]::Min((Get-AuditScaled 900),$working.Height))
    $form.MinimumSize = New-Object Drawing.Size([Math]::Min((Get-AuditScaled 1180),$working.Width),[Math]::Min((Get-AuditScaled 780),$working.Height))
    $form.BackColor = Get-AuditColor 'Canvas'
    $form.Font = New-AuditFont -Size 12
    $form.AutoScaleMode = 'Dpi'
    $form.KeyPreview = $true

    $tips = New-Object Windows.Forms.ToolTip
    $tips.AutoPopDelay = 12000; $tips.InitialDelay = 400; $tips.ReshowDelay = 120

    $root = New-Object Windows.Forms.TableLayoutPanel
    $root.Dock = 'Fill'; $root.ColumnCount = 1; $root.RowCount = 3
    [void]$root.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
    [void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,(Get-AuditScaled 92))))
    [void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))
    [void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,(Get-AuditScaled 44))))
    $form.Controls.Add($root)

    # ---------- แถบหัว ----------
    $header = New-Object Windows.Forms.Panel
    $header.Dock = 'Fill'; $header.BackColor = Get-AuditColor 'Navy'
    $headerTitle = New-AuditLabel -Text 'Audit Onsite Report' -Size 21 -Style 'Bold' -ForeColor ([Drawing.Color]::White) -AutoSize
    $headerTitle.Location = New-Object Drawing.Point((Get-AuditScaled 28),(Get-AuditScaled 14))
    $headerSub = New-AuditLabel -Text 'สรุปรายงานผลการตรวจสอบสาขา - ทำงานออฟไลน์ ไม่แก้ไขไฟล์ Excel ต้นฉบับ' -Size 11.5 -ForeColor ([Drawing.Color]::FromArgb(170,192,214)) -AutoSize
    $headerSub.Location = New-Object Drawing.Point((Get-AuditScaled 30),(Get-AuditScaled 56))
    $header.Controls.AddRange(@($headerTitle,$headerSub))

    # ปุ่มขยายตัวอักษร วางบนแถบหัวเพื่อให้เห็นได้จากทุกหน้า
    $zoomLabel = New-AuditLabel -Text '' -Size 12 -Style 'Bold' -ForeColor ([Drawing.Color]::White)
    $zoomLabel.TextAlign = 'MiddleRight'
    $zoomLabel.Size = New-Object Drawing.Size((Get-AuditScaled 80),(Get-AuditScaled 44))
    $zoomOut = New-AuditButton -Text 'ก-' -Width 54 -Height 44 -Kind 'Ghost' -FontSize 13
    $zoomReset = New-AuditButton -Text 'ก' -Width 54 -Height 44 -Kind 'Ghost' -FontSize 13
    $zoomIn = New-AuditButton -Text 'ก+' -Width 54 -Height 44 -Kind 'Ghost' -FontSize 13
    $tips.SetToolTip($zoomOut,'ย่อขนาดตัวอักษรทั้งโปรแกรม  (Ctrl และ เครื่องหมายลบ)')
    $tips.SetToolTip($zoomReset,'กลับไปขนาดปกติ 100 เปอร์เซ็นต์  (Ctrl และ 0)')
    $tips.SetToolTip($zoomIn,'ขยายขนาดตัวอักษรทั้งโปรแกรม  (Ctrl และ เครื่องหมายบวก)')
    $headerBadge = New-AuditBadge -Text 'PHASE 4.2 - TEST' -Kind 'Warning'
    $header.Controls.AddRange(@($zoomLabel,$zoomOut,$zoomReset,$zoomIn,$headerBadge))

    $layoutHeader = {
        $edge = Get-AuditScaled 28
        $top = Get-AuditScaled 12
        $zoomIn.Location = New-Object Drawing.Point(($header.Width - $edge - $zoomIn.Width),$top)
        $zoomReset.Location = New-Object Drawing.Point(($zoomIn.Left - $zoomReset.Width - (Get-AuditScaled 6)),$top)
        $zoomOut.Location = New-Object Drawing.Point(($zoomReset.Left - $zoomOut.Width - (Get-AuditScaled 6)),$top)
        $zoomLabel.Location = New-Object Drawing.Point(($zoomOut.Left - $zoomLabel.Width - (Get-AuditScaled 8)),$top)
        $headerBadge.Location = New-Object Drawing.Point(($header.Width - $edge - $headerBadge.Width),($top + $zoomIn.Height + (Get-AuditScaled 8)))
    }
    $header.Add_Resize({ & $layoutHeader }.GetNewClosure())
    $root.Controls.Add($header,0,0)

    # ---------- พื้นที่กลาง เมนูซ้ายและเนื้อหา ----------
    $body = New-Object Windows.Forms.TableLayoutPanel
    $body.Dock = 'Fill'; $body.ColumnCount = 2; $body.RowCount = 1
    [void]$body.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,(Get-AuditScaled 300))))
    [void]$body.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
    $root.Controls.Add($body,0,1)

    $sidebar = New-Object Windows.Forms.Panel
    $sidebar.Dock = 'Fill'; $sidebar.BackColor = Get-AuditColor 'NavyDark'
    $sidebar.Padding = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 18),(Get-AuditScaled 0),(Get-AuditScaled 12))
    $body.Controls.Add($sidebar,0,0)

    $content = New-Object Windows.Forms.Panel
    $content.Dock = 'Fill'; $content.BackColor = Get-AuditColor 'Canvas'
    $body.Controls.Add($content,1,0)

    $pages = @()
    $stepTitles = @('1  ข้อมูลรายงาน','2  ไฟล์ Excel และ Scan','3  ผลตรวจ 11 ข้อ','4  ตรวจสอบและ Export')
    $stepHints  = @('15 ช่องข้อมูลหัวรายงาน','เลือกไฟล์และอ่านค่าอัตโนมัติ','กรอกหรือแก้ผลตรวจรายข้อ','ตรวจ Template แล้วสร้าง Word')
    for ($i = 0; $i -lt 4; $i++) {
        $page = New-Object Windows.Forms.Panel
        $page.Dock = 'Fill'; $page.BackColor = Get-AuditColor 'Canvas'; $page.Visible = ($i -eq 0)
        $content.Controls.Add($page)
        $pages += $page
    }

    $navButtons = @()
    $navFlow = New-Object Windows.Forms.FlowLayoutPanel
    $navFlow.Dock = 'Top'; $navFlow.FlowDirection = 'TopDown'; $navFlow.WrapContents = $false
    $navFlow.AutoSize = $true; $navFlow.AutoSizeMode = 'GrowAndShrink'
    $sidebar.Controls.Add($navFlow)

    $selectPage = {
        param([int]$Index)
        for ($n = 0; $n -lt $pages.Count; $n++) {
            $pages[$n].Visible = ($n -eq $Index)
            if ($n -eq $Index) {
                $navButtons[$n].BackColor = Get-AuditColor 'Accent'
                $navButtons[$n].ForeColor = [Drawing.Color]::White
                $navButtons[$n].FlatAppearance.MouseOverBackColor = Get-AuditColor 'Accent'
            } else {
                $navButtons[$n].BackColor = Get-AuditColor 'NavyDark'
                $navButtons[$n].ForeColor = [Drawing.Color]::FromArgb(196,212,228)
                $navButtons[$n].FlatAppearance.MouseOverBackColor = Get-AuditColor 'Navy'
            }
        }
        $state.ActivePage = $Index
    }

    for ($i = 0; $i -lt 4; $i++) {
        $navButton = New-Object Windows.Forms.Button
        $navButton.Text = '   ' + $stepTitles[$i] + "`r`n   " + $stepHints[$i]
        $navButton.TextAlign = 'MiddleLeft'
        $navButton.Size = New-Object Drawing.Size((Get-AuditScaled 300),(Get-AuditScaled 74))
        $navButton.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 0),(Get-AuditScaled 0),(Get-AuditScaled 2))
        $navButton.FlatStyle = 'Flat'
        $navButton.FlatAppearance.BorderSize = 0
        $navButton.Font = New-AuditFont -Size 12
        $navButton.Cursor = [Windows.Forms.Cursors]::Hand
        $navButton.UseVisualStyleBackColor = $false
        $navButton.Tag = $i
        $navButton.Add_Click({ & $selectPage ([int]$this.Tag) }.GetNewClosure())
        [void]$navFlow.Controls.Add($navButton)
        $navButtons += $navButton
    }

    $sideFoot = New-Object Windows.Forms.Panel
    $sideFoot.Dock = 'Bottom'; $sideFoot.Height = Get-AuditScaled 176; $sideFoot.BackColor = Get-AuditColor 'NavyDark'
    $progressTitle = New-AuditLabel -Text 'ความคืบหน้า' -Size 11 -Style 'Bold' -ForeColor ([Drawing.Color]::FromArgb(150,174,198)) -AutoSize
    $progressTitle.Location = New-Object Drawing.Point((Get-AuditScaled 20),(Get-AuditScaled 12))
    $progressFields = New-AuditLabel -Text '' -Size 11.5 -ForeColor ([Drawing.Color]::White)
    $progressFields.Location = New-Object Drawing.Point((Get-AuditScaled 20),(Get-AuditScaled 44)); $progressFields.Size = New-Object Drawing.Size((Get-AuditScaled 260),(Get-AuditScaled 26))
    $progressResults = New-AuditLabel -Text '' -Size 11.5 -ForeColor ([Drawing.Color]::White)
    $progressResults.Location = New-Object Drawing.Point((Get-AuditScaled 20),(Get-AuditScaled 70)); $progressResults.Size = New-Object Drawing.Size((Get-AuditScaled 260),(Get-AuditScaled 26))
    $progressTemplate = New-AuditLabel -Text '' -Size 11.5 -ForeColor ([Drawing.Color]::White)
    $progressTemplate.Location = New-Object Drawing.Point((Get-AuditScaled 20),(Get-AuditScaled 96)); $progressTemplate.Size = New-Object Drawing.Size((Get-AuditScaled 260),(Get-AuditScaled 26))
    $progressBar = New-Object Windows.Forms.ProgressBar
    $progressBar.Location = New-Object Drawing.Point((Get-AuditScaled 20),(Get-AuditScaled 132)); $progressBar.Size = New-Object Drawing.Size((Get-AuditScaled 260),(Get-AuditScaled 14))
    $progressBar.Minimum = 0; $progressBar.Maximum = 100; $progressBar.Style = 'Continuous'
    $sideFoot.Controls.AddRange(@($progressTitle,$progressFields,$progressResults,$progressTemplate,$progressBar))
    $sidebar.Controls.Add($sideFoot)

    # ---------- แถบสถานะล่าง ----------
    $statusBar = New-Object Windows.Forms.Panel
    $statusBar.Dock = 'Fill'; $statusBar.BackColor = [Drawing.Color]::FromArgb(233,237,242)
    $statusText = New-AuditLabel -Text 'พร้อมใช้งาน' -Size 11.5 -ForeColor (Get-AuditColor 'TextMuted')
    $statusText.Location = New-Object Drawing.Point((Get-AuditScaled 18),(Get-AuditScaled 10)); $statusText.Size = New-Object Drawing.Size((Get-AuditScaled 900),(Get-AuditScaled 26))
    $statusRight = New-AuditLabel -Text 'F5 = Scan   |   Ctrl+E = Export   |   Ctrl และ + หรือ - = ขนาดตัวอักษร' -Size 11 -ForeColor (Get-AuditColor 'TextMuted')
    $statusRight.TextAlign = 'MiddleRight'
    $statusRight.Size = New-Object Drawing.Size((Get-AuditScaled 470),(Get-AuditScaled 26))
    $statusRight.Location = New-Object Drawing.Point((Get-AuditScaled 900),(Get-AuditScaled 10))
    $statusBar.Controls.AddRange(@($statusText,$statusRight))
    $statusBar.Add_Resize({
        $statusRight.Location = New-Object Drawing.Point(($statusBar.Width - $statusRight.Width - (Get-AuditScaled 18)),(Get-AuditScaled 10))
        $statusText.Width = [Math]::Max((Get-AuditScaled 200),$statusRight.Left - (Get-AuditScaled 36))
    }.GetNewClosure())
    $root.Controls.Add($statusBar,0,2)

    # ================= หน้า 1 ข้อมูลรายงาน =================
    $fieldGroups = @(
        @{ Title = 'ข้อมูลหน่วยงานผู้ตรวจสอบ'; Note = 'ส่วนหัวหนังสือ ใช้ซ้ำได้ทุกสาขา ติ๊ก จำค่า เพื่อบันทึกถาวร'
           Fields = @(
             ,@('AUDIT_UNIT','1.1 หน่วยงาน','ส่วนตรวจสอบภายในสายสาขา 4')
             ,@('PHONE','1.2 โทรศัพท์','โทร. 999306')
             ,@('DOCUMENT_NO','1.3 เลขที่หนังสือ','ตข.(จผ.)       /2569')
             ,@('REPORT_DATE','1.4 วันที่รายงาน','')) }
        @{ Title = 'ข้อมูลสาขาที่รับตรวจ'; Note = 'เปลี่ยนทุกครั้งที่ขึ้นสาขาใหม่'
           Fields = @(
             ,@('BRANCH_NAME','2.1 ชื่อสาขา','')
             ,@('RECIPIENT','2.2 เรียน','ผจส. ')
             ,@('APPROVAL_NO','2.3 เลขที่อนุมัติแผนตรวจสอบ','')
             ,@('APPROVAL_DATE','2.4 วันที่อนุมัติ','')) }
        @{ Title = 'ขอบเขตการตรวจสอบ'; Note = 'ข้อ 3.2 และ 3.3 ไม่ได้ใช้ใน Template ปัจจุบัน แต่คงไว้ตามข้อกำหนด 15 ช่อง'
           Fields = @(
             ,@('AUDITORS','3.1 รายชื่อผู้ตรวจสอบ','')
             ,@('AUDIT_PERIOD','3.2 ขอบเขตเดือน','')
             ,@('DATA_AS_OF','3.3 ข้อมูลสิ้นเดือน','')) }
        @{ Title = 'ผู้ลงนาม'; Note = 'ใช้ในหน้าลงนามท้ายรายงาน'
           Fields = @(
             ,@('LEAD_NAME','4.1 ชื่อหัวหน้าตรวจสอบ','')
             ,@('LEAD_POSITION','4.2 ตำแหน่งหัวหน้าตรวจสอบ','')
             ,@('AUDITEE_NAME','4.3 ชื่อผู้รับตรวจ','')
             ,@('AUDITEE_POSITION','4.4 ตำแหน่งผู้รับตรวจ','')) }
    )

    $fieldsScroll = New-AuditScrollHost
    $pages[0].Controls.Add($fieldsScroll)

    $fieldToolbar = New-Object Windows.Forms.FlowLayoutPanel
    $fieldToolbar.Dock = 'Top'; $fieldToolbar.AutoSize = $true; $fieldToolbar.AutoSizeMode = 'GrowAndShrink'
    $fieldToolbar.WrapContents = $true
    $fieldToolbar.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 0),(Get-AuditScaled 0),(Get-AuditScaled 14))
    $buttonSaveFix = New-AuditButton -Text 'บันทึกค่าที่ติ๊กจำไว้' -Width 230 -Kind 'Primary'
    $buttonClearFix = New-AuditButton -Text 'ล้างค่าจำทั้งหมด' -Width 200 -Kind 'Secondary'
    $buttonNewBranch = New-AuditButton -Text 'เริ่มสาขาใหม่' -Width 180 -Kind 'Secondary'
    $buttonFillToday = New-AuditButton -Text 'ใส่วันที่วันนี้ทุกช่องวันที่' -Width 250 -Kind 'Secondary'
    $fieldToolbar.Controls.AddRange(@($buttonSaveFix,$buttonClearFix,$buttonNewBranch,$buttonFillToday))
    [void]$fieldsScroll.Stack.Controls.Add($fieldToolbar)
    $tips.SetToolTip($buttonSaveFix,'บันทึกค่าปัจจุบันของช่องที่ติ๊ก จำค่า ลงไฟล์ Config\Fixed_Values.json')
    $tips.SetToolTip($buttonClearFix,'ลบค่าที่จำไว้ทั้งหมด แต่ไม่ลบข้อความในช่องกรอก')
    $tips.SetToolTip($buttonNewBranch,'ล้างข้อมูลสาขาและผลตรวจทั้งหมด แต่คงค่าที่ติ๊กจำไว้')

    # ที่ระดับซูมสูง พื้นที่แนวนอนไม่พอวางป้ายชื่อไว้ข้างช่องกรอก จึงสลับเป็นวางบนล่าง
    $stackedFields = ((Get-AuditUiScale) -ge 1.5)

    $markField = {
        param($TextBox)
        $key = [string]$TextBox.Tag
        if (($requiredKeys -contains $key) -and [string]::IsNullOrWhiteSpace($TextBox.Text)) {
            $TextBox.BackColor = Get-AuditColor 'FieldEmpty'
        } else { $TextBox.BackColor = [Drawing.Color]::White }
    }

    foreach ($group in $fieldGroups) {
        $card = New-AuditCard -Title $group.Title -Subtitle $group.Note
        $grid = New-Object Windows.Forms.TableLayoutPanel
        $grid.Dock = 'Top'; $grid.AutoSize = $true; $grid.AutoSizeMode = 'GrowAndShrink'
        if ($stackedFields) {
            # โหมดตัวอักษรใหญ่: ป้ายชื่อช่องอยู่บรรทัดบน ช่องกรอกจึงได้ความกว้างเต็ม
            $grid.ColumnCount = 3
            [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
            [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,(Get-AuditScaled 100))))
            [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,(Get-AuditScaled 124))))
        } else {
            $grid.ColumnCount = 4
            [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,(Get-AuditScaled 306))))
            [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
            [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,(Get-AuditScaled 100))))
            [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,(Get-AuditScaled 124))))
        }

        foreach ($definition in $group.Fields) {
            $key = [string]$definition[0]
            $isRequired = $requiredKeys -contains $key
            $labelText = [string]$definition[1]
            if ($isRequired) { $labelText = $labelText + '  *' }
            $label = New-AuditLabel -Text $labelText -Size 12 -ForeColor $(if ($isRequired) { Get-AuditColor 'Text' } else { Get-AuditColor 'TextMuted' })
            $label.TextAlign = 'MiddleLeft'
            $label.AutoSize = $stackedFields
            if (-not $stackedFields) { $label.Size = New-Object Drawing.Size((Get-AuditScaled 298),(Get-AuditScaled 38)) }
            $label.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 5),(Get-AuditScaled 8),(Get-AuditScaled 5))

            $textBox = New-Object Windows.Forms.TextBox
            $textBox.Font = New-AuditFont -Size 13
            $textBox.Anchor = 'Left, Right'
            $textBox.Height = Get-AuditScaled 38
            $textBox.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 5),(Get-AuditScaled 8),(Get-AuditScaled 5))
            $textBox.BorderStyle = 'FixedSingle'
            $textBox.Tag = $key
            $textBox.Text = $(if ($state.Fix.ContainsKey($key)) { $state.Fix[$key] } else { [string]$definition[2] })
            $textBox.Add_TextChanged({ & $markField $this }.GetNewClosure())
            $state.Fields[$key] = $textBox
            & $markField $textBox

            if ($dateKeys -contains $key) {
                $dateCell = New-AuditButton -Text 'วันนี้' -Width 92 -Height 44 -Kind 'Ghost' -FontSize 11
                $dateCell.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 5),(Get-AuditScaled 8),(Get-AuditScaled 5))
                $dateCell.Tag = $key
                $dateCell.Add_Click({ $state.Fields[[string]$this.Tag].Text = Get-AuditThaiDate }.GetNewClosure())
                $tips.SetToolTip($dateCell,('เติมวันที่ปัจจุบันแบบไทย เช่น ' + (Get-AuditThaiDate)))
            } else {
                $dateCell = New-AuditLabel -Text '' -Size 11
                $dateCell.Size = New-Object Drawing.Size((Get-AuditScaled 92),(Get-AuditScaled 38))
            }

            $fixCheck = New-Object Windows.Forms.CheckBox
            $fixCheck.Text = 'จำค่า'
            $fixCheck.Font = New-AuditFont -Size 11.5
            $fixCheck.ForeColor = Get-AuditColor 'TextMuted'
            $fixCheck.Size = New-Object Drawing.Size((Get-AuditScaled 118),(Get-AuditScaled 38))
            $fixCheck.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 5),(Get-AuditScaled 0),(Get-AuditScaled 5))
            $fixCheck.Tag = $key
            $fixCheck.Checked = $state.Fix.ContainsKey($key)
            $fixCheck.Add_CheckedChanged({
                $fixKey = [string]$this.Tag
                if ($this.Checked) { $state.Fix[$fixKey] = $state.Fields[$fixKey].Text } else { [void]$state.Fix.Remove($fixKey) }
                Write-AuditJson ([pscustomobject]$state.Fix) $FixedPath
            }.GetNewClosure())
            $tips.SetToolTip($fixCheck,'จำค่าช่องนี้ไว้ใช้กับสาขาถัดไป')
            $state.FixChecks[$key] = $fixCheck

            [void]$grid.Controls.Add($label)
            if ($stackedFields) { $grid.SetColumnSpan($label,3) }
            [void]$grid.Controls.Add($textBox)
            [void]$grid.Controls.Add($dateCell)
            [void]$grid.Controls.Add($fixCheck)
        }
        [void]$card.Body.Controls.Add($grid)
        [void]$fieldsScroll.Stack.Controls.Add($card)
    }

    $buttonSaveFix.Add_Click({
        foreach ($key in @($state.FixChecks.Keys)) {
            if ($state.FixChecks[$key].Checked) { $state.Fix[$key] = $state.Fields[$key].Text }
        }
        Write-AuditJson ([pscustomobject]$state.Fix) $FixedPath
        [void][Windows.Forms.MessageBox]::Show(('บันทึกค่าที่จำไว้แล้ว ' + $state.Fix.Count + ' ช่อง'),'บันทึกค่าจำ',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)
    }.GetNewClosure())

    $buttonClearFix.Add_Click({
        $answer = [Windows.Forms.MessageBox]::Show('ล้างค่าที่จำไว้ทั้งหมดหรือไม่ ข้อความในช่องกรอกจะยังอยู่','ล้างค่าจำ',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
        $state.Fix.Clear()
        foreach ($key in @($state.FixChecks.Keys)) { $state.FixChecks[$key].Checked = $false }
        Write-AuditJson ([pscustomobject]$state.Fix) $FixedPath
    }.GetNewClosure())

    $buttonFillToday.Add_Click({
        foreach ($key in $dateKeys) { if ($state.Fields.ContainsKey($key)) { $state.Fields[$key].Text = Get-AuditThaiDate } }
    }.GetNewClosure())

    # ================= หน้า 2 ไฟล์ Excel และ Scan =================
    $excelLayout = New-Object Windows.Forms.TableLayoutPanel
    $excelLayout.Dock = 'Fill'; $excelLayout.ColumnCount = 2; $excelLayout.RowCount = 2
    $excelLayout.Padding = New-Object Windows.Forms.Padding((Get-AuditScaled 24),(Get-AuditScaled 20),(Get-AuditScaled 24),(Get-AuditScaled 20))
    $excelLayout.BackColor = Get-AuditColor 'Canvas'
    [void]$excelLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,42)))
    [void]$excelLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,58)))
    [void]$excelLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::AutoSize)))
    [void]$excelLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))
    $pages[1].Controls.Add($excelLayout)

    $excelToolbar = New-Object Windows.Forms.FlowLayoutPanel
    $excelToolbar.Dock = 'Top'; $excelToolbar.AutoSize = $true; $excelToolbar.AutoSizeMode = 'GrowAndShrink'
    $excelToolbar.WrapContents = $true
    $excelToolbar.Margin = New-Object Windows.Forms.Padding(0,0,0,(Get-AuditScaled 14))
    $buttonChoose = New-AuditButton -Text 'เลือกไฟล์ Excel' -Width 200 -Kind 'Primary'
    $buttonRemove = New-AuditButton -Text 'นำออกจากรายการ' -Width 200 -Kind 'Secondary'
    $buttonClearFiles = New-AuditButton -Text 'ล้างรายการ' -Width 160 -Kind 'Secondary'
    $buttonScan = New-AuditButton -Text 'ตรวจและ Scan Mapping  (F5)' -Width 300 -Kind 'Primary'
    $excelToolbar.Controls.AddRange(@($buttonChoose,$buttonRemove,$buttonClearFiles,$buttonScan))
    $excelLayout.Controls.Add($excelToolbar,0,0)
    $excelLayout.SetColumnSpan($excelToolbar,2)

    $fileCard = New-AuditFillCard -Title 'ไฟล์ที่เลือก' -Subtitle 'ลากไฟล์ .xlsx หรือ .xlsm มาวางในกรอบนี้ได้'
    $fileList = New-Object Windows.Forms.ListView
    $fileList.View = 'Details'; $fileList.FullRowSelect = $true; $fileList.HideSelection = $false
    $fileList.Dock = 'Fill'; $fileList.BorderStyle = 'None'
    $fileList.Font = New-AuditFont -Size 11.5
    $fileList.AllowDrop = $true
    $fileList.ShowItemToolTips = $true
    [void]$fileList.Columns.Add('ชื่อไฟล์',(Get-AuditScaled 250))
    [void]$fileList.Columns.Add('ขนาด',(Get-AuditScaled 86))
    [void]$fileList.Columns.Add('แก้ไขล่าสุด',(Get-AuditScaled 132))
    # คอลัมน์ชื่อไฟล์ต้องยืดตามความกว้างจริง ไม่งั้นคอลัมน์วันที่จะหลุดออกนอกกรอบ
    $fileList.Add_Resize({ $this.Columns[0].Width = [Math]::Max((Get-AuditScaled 160),$this.ClientSize.Width - (Get-AuditScaled 226)) })
    $fileCard.Surface.Controls.Add($fileList)
    $fileCardHost = New-Object Windows.Forms.Panel
    $fileCardHost.Dock = 'Fill'; $fileCardHost.Padding = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 0),(Get-AuditScaled 12),(Get-AuditScaled 0))
    $fileCardHost.Controls.Add($fileCard)
    $excelLayout.Controls.Add($fileCardHost,0,1)

    $scanCard = New-AuditFillCard -Title 'ผลการตรวจไฟล์และ Mapping' -Subtitle 'สถานะ Workbook แยกจากสถานะ Mapping ตามกฎเดิม'
    $scanGrid = New-Object Windows.Forms.DataGridView
    $scanGrid.Dock = 'Fill'
    [void](Set-AuditGridStyle -Grid $scanGrid)
    foreach ($column in @('ไฟล์','ข้อ','Workbook','Mapping','รายละเอียด')) { [void]$scanGrid.Columns.Add($column,$column) }
    $scanGrid.Columns[0].Width = Get-AuditScaled 200
    $scanGrid.Columns[1].Width = Get-AuditScaled 56
    $scanGrid.Columns[2].Width = Get-AuditScaled 104
    $scanGrid.Columns[3].Width = Get-AuditScaled 104
    $scanGrid.ShowCellToolTips = $true
    $scanGrid.Columns[4].AutoSizeMode = 'Fill'
    $scanCard.Surface.Controls.Add($scanGrid)
    $scanCardHost = New-Object Windows.Forms.Panel
    $scanCardHost.Dock = 'Fill'
    $scanCardHost.Controls.Add($scanCard)
    $excelLayout.Controls.Add($scanCardHost,1,1)

    $addFiles = {
        param($Paths)
        $added = 0
        foreach ($path in $Paths) {
            if ([string]$path -notmatch '\.xls[xm]$') { continue }
            if ($state.Files.Contains([string]$path)) { continue }
            if (-not (Test-Path -LiteralPath $path)) { continue }
            $state.Files.Add([string]$path)
            $info = Get-Item -LiteralPath $path
            $item = New-Object Windows.Forms.ListViewItem($info.Name)
            [void]$item.SubItems.Add(('{0:N0} KB' -f ($info.Length / 1KB)))
            [void]$item.SubItems.Add($info.LastWriteTime.ToString('dd/MM/yyyy HH:mm'))
            $item.Tag = [string]$path
            $item.ToolTipText = [string]$path
            [void]$fileList.Items.Add($item)
            $added++
        }
        $statusText.Text = ('เพิ่มไฟล์ ' + $added + ' รายการ รวมทั้งหมด ' + $state.Files.Count + ' ไฟล์')
    }

    $buttonChoose.Add_Click({
        $dialog = New-Object Windows.Forms.OpenFileDialog
        $dialog.Filter = 'Excel (*.xlsx;*.xlsm)|*.xlsx;*.xlsm'
        $dialog.Multiselect = $true
        if ($dialog.ShowDialog() -eq 'OK') { & $addFiles $dialog.FileNames }
    }.GetNewClosure())

    $buttonRemove.Add_Click({
        foreach ($item in @($fileList.SelectedItems)) {
            [void]$state.Files.Remove([string]$item.Tag)
            $fileList.Items.Remove($item)
        }
    }.GetNewClosure())

    $buttonClearFiles.Add_Click({ $state.Files.Clear(); $fileList.Items.Clear(); $scanGrid.Rows.Clear() }.GetNewClosure())

    $fileList.Add_DragEnter({ param($sender,$e); if ($e.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $e.Effect = 'Copy' } })
    $fileList.Add_DragDrop({ param($sender,$e); & $addFiles ($e.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) }.GetNewClosure())

    $runScan = {
        if ($state.Files.Count -eq 0) {
            [void][Windows.Forms.MessageBox]::Show('ยังไม่ได้เลือกไฟล์ Excel','Scan Mapping',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        $form.Cursor = [Windows.Forms.Cursors]::WaitCursor
        $scanGrid.Rows.Clear()
        try {
            foreach ($path in @($state.Files)) {
                $fileName = [IO.Path]::GetFileName($path)
                try {
                    $inspection = Get-AuditWorkbookInspection $path
                    $eligible = @($mappings | Where-Object { $_.status -in @('draft_observed','user_confirmed') -and $fileName -like [string]$_.source_file.expected_name_or_pattern })
                    $index = $scanGrid.Rows.Add()
                    $scanGrid.Rows[$index].Cells[0].Value = $fileName
                    $scanGrid.Rows[$index].Cells[2].Value = $inspection.InspectionStatus
                    if ($eligible.Count -eq 1) {
                        $mapping = $eligible[0]
                        $scanResult = Invoke-AuditMappingScan $path $mapping
                        $itemId = [string]$mapping.item_id
                        $scanGrid.Rows[$index].Cells[1].Value = $itemId
                        $scanGrid.Rows[$index].Cells[3].Value = $scanResult.Status
                        $scanGrid.Rows[$index].Cells[4].Value = $scanResult.Message
                        if ($scanResult.Value) {
                            $state.Results[$itemId].Text = $scanResult.Value
                            $state.ResultSources[$itemId] = $(if ($mapping.status -eq 'user_confirmed') { 'AUTO_CONFIRMED' } else { 'AUTO_DRAFT' })
                        }
                    } else {
                        $scanGrid.Rows[$index].Cells[3].Value = 'PENDING'
                        $scanGrid.Rows[$index].Cells[4].Value = 'ยังไม่มี Mapping ที่ยืนยันสำหรับไฟล์นี้ ให้กรอกผลตรวจด้วยมือ'
                    }
                } catch {
                    $index = $scanGrid.Rows.Add()
                    $scanGrid.Rows[$index].Cells[0].Value = $fileName
                    $scanGrid.Rows[$index].Cells[2].Value = 'BLOCKED'
                    $scanGrid.Rows[$index].Cells[4].Value = $_.Exception.Message
                }
                foreach ($cellIndex in @(2,3)) {
                    $cellValue = [string]$scanGrid.Rows[$index].Cells[$cellIndex].Value
                    switch (Get-AuditStatusKind -Status $cellValue) {
                        'Success' { $scanGrid.Rows[$index].Cells[$cellIndex].Style.ForeColor = Get-AuditColor 'Success' }
                        'Warning' { $scanGrid.Rows[$index].Cells[$cellIndex].Style.ForeColor = Get-AuditColor 'Warning' }
                        'Danger'  { $scanGrid.Rows[$index].Cells[$cellIndex].Style.ForeColor = Get-AuditColor 'Danger' }
                        default   { $scanGrid.Rows[$index].Cells[$cellIndex].Style.ForeColor = Get-AuditColor 'TextMuted' }
                    }
                }
            }
            $statusText.Text = ('Scan เสร็จ ' + $scanGrid.Rows.Count + ' รายการ')
        } finally { $form.Cursor = [Windows.Forms.Cursors]::Default }
    }
    $buttonScan.Add_Click({ & $runScan }.GetNewClosure())

    # ================= หน้า 3 ผลตรวจ =================
    $resultsLayout = New-Object Windows.Forms.TableLayoutPanel
    $resultsLayout.Dock = 'Fill'; $resultsLayout.ColumnCount = 1; $resultsLayout.RowCount = 2
    [void]$resultsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
    [void]$resultsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,(Get-AuditScaled 72))))
    [void]$resultsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))
    $pages[2].Controls.Add($resultsLayout)

    $resultsToolbar = New-Object Windows.Forms.Panel
    $resultsToolbar.Dock = 'Fill'
    $searchBox = New-Object Windows.Forms.TextBox
    $searchBox.Font = New-AuditFont -Size 12
    $searchBox.BorderStyle = 'FixedSingle'
    $searchBox.Location = New-Object Drawing.Point((Get-AuditScaled 130),(Get-AuditScaled 18))
    $searchBox.Size = New-Object Drawing.Size((Get-AuditScaled 360),(Get-AuditScaled 38))
    $tips.SetToolTip($searchBox,'พิมพ์เลขข้อหรือคำในหัวข้อเพื่อกรองรายการ')
    $searchHint = New-AuditLabel -Text 'ค้นหาหัวข้อ' -Size 11 -ForeColor (Get-AuditColor 'TextMuted') -AutoSize
    $searchHint.Location = New-Object Drawing.Point((Get-AuditScaled 26),(Get-AuditScaled 24))
    $resultsCounter = New-AuditLabel -Text '' -Size 12 -Style 'Bold' -ForeColor (Get-AuditColor 'Accent') -AutoSize
    $resultsCounter.Location = New-Object Drawing.Point((Get-AuditScaled 540),(Get-AuditScaled 24))
    $resultsToolbar.Controls.AddRange(@($searchBox,$searchHint,$resultsCounter))
    $resultsToolbar.Add_Resize({
        $searchBox.Left = $searchHint.Right + (Get-AuditScaled 12)
        $resultsCounter.Left = $searchBox.Right + (Get-AuditScaled 24)
    }.GetNewClosure())
    $resultsLayout.Controls.Add($resultsToolbar,0,0)

    $resultsScroll = New-AuditScrollHost -PadTop 6
    $resultsLayout.Controls.Add($resultsScroll,0,1)

    foreach ($mapping in $mappings) {
        $itemId = [string]$mapping.item_id
        $card = New-AuditCard
        $card.Tag = ($itemId + ' ' + [string]$mapping.title)

        $cardHeader = New-Object Windows.Forms.FlowLayoutPanel
        $cardHeader.Dock = 'Top'; $cardHeader.AutoSize = $true; $cardHeader.AutoSizeMode = 'GrowAndShrink'
        $cardHeader.WrapContents = $false
        $titleLabel = New-AuditLabel -Text ('ข้อ ' + $itemId + '   ' + [string]$mapping.title) -Size 13 -Style 'Bold' -AutoSize
        $titleLabel.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 3),(Get-AuditScaled 14),(Get-AuditScaled 6))
        $mappingBadge = New-AuditBadge -Text ([string]$mapping.status) -Kind (Get-AuditStatusKind -Status ([string]$mapping.status))
        $sourceBadge = New-AuditBadge -Text 'ยังไม่กรอก' -Kind 'Danger'
        $cardHeader.Controls.AddRange(@($titleLabel,$mappingBadge,$sourceBadge))
        [void]$card.Body.Controls.Add($cardHeader)

        $resultBox = New-Object Windows.Forms.TextBox
        $resultBox.Multiline = $true
        $resultBox.ScrollBars = 'Vertical'
        $resultBox.Font = New-AuditFont -Size 13
        $resultBox.BorderStyle = 'FixedSingle'
        $resultBox.Height = Get-AuditScaled 104
        $resultBox.Anchor = 'Left, Right'
        $resultBox.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 4),(Get-AuditScaled 0),(Get-AuditScaled 2))
        $resultBox.Tag = $itemId
        $resultBox.Add_TextChanged({
            $id = [string]$this.Tag
            if ($this.Focused) { $state.ResultSources[$id] = 'MANUAL' }
        }.GetNewClosure())
        [void]$card.Body.Controls.Add($resultBox)

        $state.Results[$itemId] = $resultBox
        $state.ResultSources[$itemId] = 'EMPTY'
        $state.ResultBadges[$itemId] = $sourceBadge
        $state.ResultCards[$itemId] = $card
        [void]$resultsScroll.Stack.Controls.Add($card)
    }

    $searchBox.Add_TextChanged({
        $keyword = $searchBox.Text.Trim()
        foreach ($id in @($state.ResultCards.Keys)) {
            $card = $state.ResultCards[$id]
            $card.Visible = ($keyword -eq '') -or ([string]$card.Tag -like ('*' + $keyword + '*'))
        }
    }.GetNewClosure())

    # ================= หน้า 4 ตรวจสอบและ Export =================
    $exportScroll = New-AuditScrollHost
    $pages[3].Controls.Add($exportScroll)

    $checklistCard = New-AuditCard -Title 'รายการตรวจก่อน Export' -Subtitle 'ต้องผ่านครบทุกข้อ ปุ่ม Export จึงจะทำงาน'
    $checkFields = New-AuditLabel -Text '' -Size 13 -AutoSize
    $checkFields.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 2),(Get-AuditScaled 0),(Get-AuditScaled 4))
    $checkResults = New-AuditLabel -Text '' -Size 13 -AutoSize
    $checkResults.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 2),(Get-AuditScaled 0),(Get-AuditScaled 4))
    $checkTemplate = New-AuditLabel -Text '' -Size 13 -AutoSize
    $checkTemplate.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 2),(Get-AuditScaled 0),(Get-AuditScaled 4))
    [void]$checklistCard.Body.Controls.Add($checkFields)
    [void]$checklistCard.Body.Controls.Add($checkResults)
    [void]$checklistCard.Body.Controls.Add($checkTemplate)

    $exportToolbar = New-Object Windows.Forms.FlowLayoutPanel
    $exportToolbar.Dock = 'Top'; $exportToolbar.AutoSize = $true; $exportToolbar.AutoSizeMode = 'GrowAndShrink'
    $exportToolbar.WrapContents = $true
    $exportToolbar.Margin = New-Object Windows.Forms.Padding((Get-AuditScaled 0),(Get-AuditScaled 12),(Get-AuditScaled 0),(Get-AuditScaled 0))
    $buttonCheckTemplate = New-AuditButton -Text 'ตรวจ Template และ Placeholder' -Width 320 -Kind 'Secondary'
    $buttonExport = New-AuditButton -Text 'Export Word  (Ctrl+E)' -Width 260 -Kind 'Primary'
    $buttonExport.Enabled = $false
    $buttonOpenOutput = New-AuditButton -Text 'เปิดโฟลเดอร์ Output' -Width 240 -Kind 'Secondary'
    $exportToolbar.Controls.AddRange(@($buttonCheckTemplate,$buttonExport,$buttonOpenOutput))
    [void]$checklistCard.Body.Controls.Add($exportToolbar)
    [void]$exportScroll.Stack.Controls.Add($checklistCard)

    $summaryCard = New-AuditCard -Title 'สรุปแหล่งข้อมูลผลตรวจ' -Subtitle 'MANUAL คือกรอกเอง  AUTO_DRAFT คืออ่านจาก Excel แต่ Mapping ยังไม่ยืนยัน  AUTO_CONFIRMED คือ Mapping ยืนยันแล้ว'
    $summaryGrid = New-Object Windows.Forms.DataGridView
    $summaryGrid.Dock = 'Fill'
    [void](Set-AuditGridStyle -Grid $summaryGrid)
    foreach ($column in @('ข้อ','หัวข้อ','แหล่งข้อมูล','สถานะ')) { [void]$summaryGrid.Columns.Add($column,$column) }
    $summaryGrid.Columns[0].Width = Get-AuditScaled 60
    $summaryGrid.Columns[1].AutoSizeMode = 'Fill'
    $summaryGrid.Columns[2].Width = Get-AuditScaled 168
    $summaryGrid.Columns[3].Width = Get-AuditScaled 128
    $summaryGridHost = New-Object Windows.Forms.Panel
    $summaryGridHost.Height = Get-AuditScaled 400
    $summaryGridHost.Dock = 'Top'
    $summaryGridHost.Controls.Add($summaryGrid)
    [void]$summaryCard.Body.Controls.Add($summaryGridHost)
    [void]$exportScroll.Stack.Controls.Add($summaryCard)

    $logCard = New-AuditCard -Title 'บันทึกการทำงาน' -Subtitle 'ผลการตรวจ Template และผลการ Export ล่าสุด'
    $logBox = New-Object Windows.Forms.TextBox
    $logBox.Multiline = $true; $logBox.ReadOnly = $true; $logBox.ScrollBars = 'Vertical'
    $logBox.BackColor = [Drawing.Color]::FromArgb(248,250,252)
    $logBox.BorderStyle = 'FixedSingle'
    $logBox.Font = New-Object Drawing.Font('Consolas',[single](11 * (Get-AuditUiScale)))
    $logBox.Height = Get-AuditScaled 230
    $logBox.Anchor = 'Left, Right'
    [void]$logCard.Body.Controls.Add($logBox)
    [void]$exportScroll.Stack.Controls.Add($logCard)

    $writeLog = {
        param([string]$Message)
        $stamp = (Get-Date).ToString('HH:mm:ss')
        $logBox.Text = ($stamp + '  ' + $Message + "`r`n" + $logBox.Text)
    }

    # ---------- รีเฟรชสถานะรวม ----------
    $refresh = {
        $filledFields = 0
        $missingRequired = New-Object Collections.Generic.List[string]
        foreach ($key in @($state.Fields.Keys)) {
            if (-not [string]::IsNullOrWhiteSpace($state.Fields[$key].Text)) { $filledFields++ }
        }
        foreach ($key in $requiredKeys) {
            if ([string]::IsNullOrWhiteSpace($state.Fields[$key].Text)) { [void]$missingRequired.Add($key) }
        }
        $filledResults = 0
        $signature = New-Object Text.StringBuilder
        $summaryRowData = New-Object Collections.Generic.List[object]
        foreach ($mapping in $mappings) {
            $itemId = [string]$mapping.item_id
            $text = [string]$state.Results[$itemId].Text
            $source = [string]$state.ResultSources[$itemId]
            if ([string]::IsNullOrWhiteSpace($text)) { $source = 'EMPTY' }
            elseif ($source -eq 'EMPTY' -or [string]::IsNullOrWhiteSpace($source)) { $source = 'MANUAL' }
            if (-not [string]::IsNullOrWhiteSpace($text)) { $filledResults++ }
            $badge = $state.ResultBadges[$itemId]
            if ($source -eq 'EMPTY') { Set-AuditBadgeState -Badge $badge -Text 'ยังไม่กรอก' -Kind 'Danger' }
            else { Set-AuditBadgeState -Badge $badge -Text $source -Kind (Get-AuditStatusKind -Status $source) }

            [void]$summaryRowData.Add([pscustomobject]@{ ItemId = $itemId; Title = [string]$mapping.title; Source = $source })
            [void]$signature.Append($itemId).Append('=').Append($source).Append(';')
        }

        if ([string]$state.SummarySignature -ne $signature.ToString()) {
            $state.SummarySignature = $signature.ToString()
            $summaryGrid.Rows.Clear()
            foreach ($row in $summaryRowData) {
                $index = $summaryGrid.Rows.Add()
                $summaryGrid.Rows[$index].Cells[0].Value = $row.ItemId
                $summaryGrid.Rows[$index].Cells[1].Value = $row.Title
                $summaryGrid.Rows[$index].Cells[2].Value = $(if ($row.Source -eq 'EMPTY') { '-' } else { $row.Source })
                $summaryGrid.Rows[$index].Cells[3].Value = $(if ($row.Source -eq 'EMPTY') { 'ยังไม่กรอก' } else { 'พร้อม' })
                $summaryGrid.Rows[$index].Cells[3].Style.ForeColor = $(if ($row.Source -eq 'EMPTY') { Get-AuditColor 'Danger' } else { Get-AuditColor 'Success' })
            }
        }

        $totalFields = $state.Fields.Count
        $totalResults = $mappings.Count
        $progressFields.Text = ('ข้อมูลรายงาน  {0}/{1}' -f $filledFields,$totalFields)
        $progressResults.Text = ('ผลตรวจ  {0}/{1}' -f $filledResults,$totalResults)
        $progressTemplate.Text = ('Template  ' + $(if ($state.TemplateReady) { 'พร้อม' } else { 'ยังไม่พร้อม' }))
        $done = ($totalFields - $missingRequired.Count) + $filledResults + $(if ($state.TemplateReady) { 3 } else { 0 })
        $total = $totalFields + $totalResults + 3
        $progressBar.Value = [Math]::Max(0,[Math]::Min(100,[int](100 * $done / $total)))
        $resultsCounter.Text = ('กรอกแล้ว {0} จาก {1} ข้อ' -f $filledResults,$totalResults)
        $zoomLabel.Text = ('{0}%' -f [int]((Get-AuditUiScale) * 100))

        $checkFields.Text = $(if ($missingRequired.Count -eq 0) { 'ผ่าน   ข้อมูลรายงานที่จำเป็นครบแล้ว' } else { ('ยังไม่ผ่าน   ขาด ' + $missingRequired.Count + ' ช่อง: ' + ($missingRequired -join ', ')) })
        $checkFields.ForeColor = $(if ($missingRequired.Count -eq 0) { Get-AuditColor 'Success' } else { Get-AuditColor 'Danger' })
        $checkResults.Text = $(if ($filledResults -eq $totalResults) { ('ผ่าน   ผลตรวจครบ ' + $totalResults + ' ข้อ') } else { ('ยังไม่ผ่าน   ผลตรวจกรอกแล้ว ' + $filledResults + ' จาก ' + $totalResults + ' ข้อ') })
        $checkResults.ForeColor = $(if ($filledResults -eq $totalResults) { Get-AuditColor 'Success' } else { Get-AuditColor 'Danger' })
        $checkTemplate.Text = $(if ($state.TemplateReady) { ('ผ่าน   ' + $state.TemplateNote) } else { ('ยังไม่ผ่าน   ' + $state.TemplateNote) })
        $checkTemplate.ForeColor = $(if ($state.TemplateReady) { Get-AuditColor 'Success' } else { Get-AuditColor 'Warning' })

        $ready = ($missingRequired.Count -eq 0) -and ($filledResults -eq $totalResults) -and $state.TemplateReady
        $buttonExport.Enabled = $ready
        if ($ready) {
            $statusText.Text = 'พร้อม Export  ตรวจครบทุกเงื่อนไขแล้ว'
            $statusText.ForeColor = Get-AuditColor 'Success'
        } else {
            $statusText.Text = ('ยังไม่พร้อม Export   |   ข้อมูลรายงานขาด ' + $missingRequired.Count + ' ช่อง   |   ผลตรวจ ' + $filledResults + '/' + $totalResults + '   |   Template: ' + $(if ($state.TemplateReady) { 'พร้อม' } else { 'ยังไม่ตรวจ' }))
            $statusText.ForeColor = Get-AuditColor 'TextMuted'
        }
    }

    $buttonNewBranch.Add_Click({
        $answer = [Windows.Forms.MessageBox]::Show('ล้างข้อมูลสาขาและผลตรวจทั้งหมดเพื่อเริ่มสาขาใหม่หรือไม่ ค่าที่ติ๊กจำไว้จะยังอยู่','เริ่มสาขาใหม่',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
        foreach ($key in @($state.Fields.Keys)) {
            if ($state.Fix.ContainsKey($key)) { $state.Fields[$key].Text = $state.Fix[$key] } else { $state.Fields[$key].Text = '' }
        }
        foreach ($id in @($state.Results.Keys)) { $state.Results[$id].Text = ''; $state.ResultSources[$id] = 'EMPTY' }
        $state.Files.Clear(); $fileList.Items.Clear(); $scanGrid.Rows.Clear()
        & $refresh
        & $writeLog 'เริ่มสาขาใหม่ ล้างข้อมูลสาขาและผลตรวจแล้ว'
    }.GetNewClosure())

    $buttonCheckTemplate.Add_Click({
        try {
            $check = Test-AuditWordTemplate -Path $template -Config $Config
            $state.TemplateReady = ($check.Status -eq 'READY')
            $state.TemplateNote = ('พบ Placeholder ' + $check.FoundCount + '/' + $check.RequiredCount + $(if ($check.MissingCount -gt 0) { ' ขาด: ' + ($check.Missing -join ', ') } else { '' }))
            Write-AuditJson $check (Get-ShortLogPath $AppRoot 'WordTemplate')
            & $writeLog ('ตรวจ Template: ' + $check.Status + ' | ' + $state.TemplateNote)
        } catch {
            $state.TemplateReady = $false
            $state.TemplateNote = $_.Exception.Message
            & $writeLog ('ตรวจ Template ล้มเหลว: ' + $_.Exception.Message)
        }
        & $refresh
    }.GetNewClosure())

    $buttonOpenOutput.Add_Click({ Start-Process explorer.exe (Join-Path $AppRoot 'Output') }.GetNewClosure())

    $runExport = {
        $missingFields = New-Object Collections.Generic.List[string]
        foreach ($key in $requiredKeys) { if ([string]::IsNullOrWhiteSpace($state.Fields[$key].Text)) { [void]$missingFields.Add($key) } }
        $summaryRows = New-Object Collections.Generic.List[object]
        foreach ($mapping in $mappings) {
            $itemId = [string]$mapping.item_id
            if ([string]::IsNullOrWhiteSpace($state.Results[$itemId].Text)) { [void]$missingFields.Add('ผลตรวจข้อ ' + $itemId); continue }
            $source = [string]$state.ResultSources[$itemId]
            if ([string]::IsNullOrWhiteSpace($source) -or $source -eq 'EMPTY') { $source = 'MANUAL' }
            [void]$summaryRows.Add([pscustomobject]@{ ItemId = $itemId; Title = [string]$mapping.title; Source = $source })
        }
        if ($missingFields.Count -gt 0) {
            [void][Windows.Forms.MessageBox]::Show(("ยัง Export ไม่ได้ กรุณากรอกข้อมูลต่อไปนี้`r`n`r`n" + ($missingFields -join "`r`n")),'Export Word',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        $safeBranch = ($state.Fields['BRANCH_NAME'].Text -replace '[\\/:*?"<>|]','_').Trim()
        if ([string]::IsNullOrWhiteSpace($safeBranch)) { $safeBranch = 'Branch' }
        $outputPath = Join-Path $AppRoot ('Output\สรุปรายงานผลการตรวจสอบ-{0}-{1}.docx' -f $safeBranch,(Get-Date -Format yyyyMMdd-HHmmss))
        if (-not (Show-AuditExportConfirm -Owner $form -Rows $summaryRows -OutputName ('ไฟล์ปลายทาง: ' + [IO.Path]::GetFileName($outputPath)))) {
            & $writeLog 'ผู้ใช้ยกเลิกที่หน้ายืนยัน ไม่มีการสร้างไฟล์'
            return
        }
        $form.Cursor = [Windows.Forms.Cursors]::WaitCursor
        try {
            $dateValue = $state.Fields['REPORT_DATE'].Text
            $replacements = @{
                '[[AUDIT_UNIT]]'       = $state.Fields['AUDIT_UNIT'].Text
                '[[PHONE]]'            = $state.Fields['PHONE'].Text
                '[[DOCUMENT_NO]]'      = $state.Fields['DOCUMENT_NO'].Text
                '[[REPORT_DATE]]'      = $dateValue
                '[[BRANCH_NAME]]'      = $state.Fields['BRANCH_NAME'].Text
                '[[RECIPIENT]]'        = $state.Fields['RECIPIENT'].Text
                '[[APPROVAL_NO]]'      = $state.Fields['APPROVAL_NO'].Text
                '[[APPROVAL_DATE]]'    = $state.Fields['APPROVAL_DATE'].Text
                '[[AUDITORS]]'         = $state.Fields['AUDITORS'].Text
                '[[ONSITE_DATE]]'      = $dateValue
                '[[MEETING_DATE]]'     = $dateValue
                '[[LEAD_NAME]]'        = $state.Fields['LEAD_NAME'].Text
                '[[LEAD_POSITION]]'    = $state.Fields['LEAD_POSITION'].Text
                '[[LEAD_DATE]]'        = $dateValue
                '[[AUDITEE_NAME]]'     = $state.Fields['AUDITEE_NAME'].Text
                '[[AUDITEE_POSITION]]' = $state.Fields['AUDITEE_POSITION'].Text
                '[[AUDITEE_DATE]]'     = $dateValue
            }
            foreach ($mapping in $mappings) { $replacements[[string]$mapping.word_placeholder] = $state.Results[[string]$mapping.item_id].Text }
            $result = Export-AuditWordDocument -TemplatePath $template -OutputPath $outputPath -Replacements $replacements -Config $Config
            Write-AuditJson $result (Get-ShortLogPath $AppRoot 'WordExport')
            Write-AuditLog $AppRoot ('Word Export SUCCESS: ' + $outputPath)
            & $writeLog ('Export สำเร็จ: ' + $outputPath)
            & $writeLog ('แทนค่า ' + $result.ReplacementCount + ' Placeholder | ตกค้าง ' + $result.LeftoverCount + ' | ลบย่อหน้าว่างท้ายเอกสาร ' + $result.TrailingEmptyParagraphsRemoved)
            [void][Windows.Forms.MessageBox]::Show(("สร้างไฟล์ Word สำเร็จ`r`n`r`n" + $outputPath),'Export Word',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)
            Start-Process explorer.exe -ArgumentList ('/select,"' + $outputPath + '"')
        } catch {
            Write-AuditLog $AppRoot $_.Exception.Message 'ERROR'
            & $writeLog ('Export BLOCKED: ' + $_.Exception.Message)
            [void][Windows.Forms.MessageBox]::Show(("Export ไม่สำเร็จ`r`n`r`n" + $_.Exception.Message),'Export Word',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)
        } finally { $form.Cursor = [Windows.Forms.Cursors]::Default }
    }
    $buttonExport.Add_Click({ & $runExport }.GetNewClosure())

    # ---------- ปุ่มขยายตัวอักษร ----------
    # เก็บทุกอย่างที่ผู้ใช้กรอกไว้ ปิดหน้าต่าง แล้วเปิดใหม่ด้วยขนาดใหม่
    # ข้อมูลต้องกลับมาครบทุกช่อง ห้ามให้ผู้ใช้กรอกใหม่
    $applyScale = {
        param([double]$NewScale)
        if ([Math]::Abs($NewScale - (Get-AuditUiScale)) -lt 0.001) { return }
        $carry = @{
            Scale         = $NewScale
            Fields        = @{}
            Results       = @{}
            Sources       = @{}
            Files         = @(@($state.Files))
            TemplateReady = $state.TemplateReady
            TemplateNote  = $state.TemplateNote
            ActivePage    = $state.ActivePage
            Log           = $logBox.Text
        }
        foreach ($key in @($state.Fields.Keys)) { $carry.Fields[$key] = $state.Fields[$key].Text }
        foreach ($id in @($state.Results.Keys)) { $carry.Results[$id] = $state.Results[$id].Text; $carry.Sources[$id] = $state.ResultSources[$id] }
        Write-AuditUiScale -AppRoot $AppRoot -Scale $NewScale
        Write-AuditLog $AppRoot ('เปลี่ยนขนาดตัวอักษรเป็น ' + [int]($NewScale * 100) + ' เปอร์เซ็นต์')
        $outcome.Restart = $true
        $outcome.Carry = $carry
        $form.Close()
    }
    $zoomIn.Add_Click({ & $applyScale (Get-AuditNextUiScale 1) }.GetNewClosure())
    $zoomOut.Add_Click({ & $applyScale (Get-AuditNextUiScale -1) }.GetNewClosure())
    $zoomReset.Add_Click({ & $applyScale 1.0 }.GetNewClosure())

    # ---------- คีย์ลัด ----------
    $form.Add_KeyDown({
        param($sender,$e)
        if ($e.KeyCode -eq [Windows.Forms.Keys]::F5) { & $runScan; $e.Handled = $true; return }
        if ($e.Control -and ($e.KeyCode -eq [Windows.Forms.Keys]::Oemplus -or $e.KeyCode -eq [Windows.Forms.Keys]::Add)) { & $applyScale (Get-AuditNextUiScale 1); $e.Handled = $true; return }
        if ($e.Control -and ($e.KeyCode -eq [Windows.Forms.Keys]::OemMinus -or $e.KeyCode -eq [Windows.Forms.Keys]::Subtract)) { & $applyScale (Get-AuditNextUiScale -1); $e.Handled = $true; return }
        if ($e.Control -and ($e.KeyCode -eq [Windows.Forms.Keys]::D0 -or $e.KeyCode -eq [Windows.Forms.Keys]::NumPad0)) { & $applyScale 1.0; $e.Handled = $true; return }
        if ($e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::E) { if ($buttonExport.Enabled) { & $runExport }; $e.Handled = $true; return }
        if ($e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::S) { $buttonSaveFix.PerformClick(); $e.Handled = $true; return }
        if ($e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::D1) { & $selectPage 0; $e.Handled = $true; return }
        if ($e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::D2) { & $selectPage 1; $e.Handled = $true; return }
        if ($e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::D3) { & $selectPage 2; $e.Handled = $true; return }
        if ($e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::D4) { & $selectPage 3; $e.Handled = $true; return }
    }.GetNewClosure())

    # ---------- เติมค่าที่ค้างไว้กลับ เมื่อเปิดหน้าต่างใหม่หลังเปลี่ยนขนาด ----------
    $startPage = 0
    if ($null -ne $Carry) {
        foreach ($key in @($Carry.Fields.Keys)) { if ($state.Fields.ContainsKey($key)) { $state.Fields[$key].Text = [string]$Carry.Fields[$key] } }
        foreach ($id in @($Carry.Results.Keys)) { if ($state.Results.ContainsKey($id)) { $state.Results[$id].Text = [string]$Carry.Results[$id] } }
        # ต้องคืนค่าแหล่งข้อมูลหลังใส่ข้อความเสมอ เพราะการใส่ข้อความไปกระตุ้น TextChanged
        foreach ($id in @($Carry.Sources.Keys)) { if ($state.ResultSources.ContainsKey($id)) { $state.ResultSources[$id] = [string]$Carry.Sources[$id] } }
        & $addFiles @($Carry.Files)
        $state.TemplateReady = [bool]$Carry.TemplateReady
        $state.TemplateNote = [string]$Carry.TemplateNote
        $logBox.Text = [string]$Carry.Log
        $startPage = [int]$Carry.ActivePage
    }

    # ---------- ตัวจับเวลารีเฟรชสถานะ ----------
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 700
    $timer.Add_Tick({ & $refresh }.GetNewClosure())
    $form.Add_Shown({ & $layoutHeader; & $selectPage $startPage; & $refresh; $timer.Start() }.GetNewClosure())
    $form.Add_FormClosed({ $timer.Stop(); $timer.Dispose() }.GetNewClosure())

    if ($null -eq $Carry) {
        & $writeLog ('เปิดโปรแกรม Phase 4.2 V0.9 ที่ขนาดตัวอักษร ' + [int]((Get-AuditUiScale) * 100) + ' เปอร์เซ็นต์')
        Write-AuditLog $AppRoot 'เปิด Phase 4.2 V0.9'
    } else {
        $statusText.Text = ('ปรับขนาดตัวอักษรเป็น ' + [int]((Get-AuditUiScale) * 100) + ' เปอร์เซ็นต์แล้ว ข้อมูลที่กรอกไว้ยังอยู่ครบ')
    }
    [void]$form.ShowDialog()
    $form.Dispose()
    return $outcome
}

Export-ModuleMember -Function Start-AuditOnsiteUI,Get-AuditThaiDate,Read-AuditUiScale,Write-AuditUiScale
