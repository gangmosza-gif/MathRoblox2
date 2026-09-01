Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ชุดสี ฟอนต์ ตัวคูณขนาด และตัวช่วยสร้างคอนโทรลกลาง ใช้ร่วมกันทุกหน้าจอ
# ออกแบบให้ทำงานบน Windows PowerShell 5.1 + WinForms เท่านั้น ไม่พึ่ง .NET รุ่นใหม่
#
# หลักการสำคัญของไฟล์นี้
#   ขนาดทุกอย่างในโปรแกรม ทั้งฟอนต์และพิกเซล ต้องผ่าน New-AuditFont หรือ Get-AuditScaled
#   เพื่อให้ปุ่มขยายตัวอักษรทำงานได้ทั้งหน้าจอ ไม่ใช่ขยายแค่ตัวหนังสือจนโดนตัด

$script:Palette = @{
    Navy       = [Drawing.Color]::FromArgb(23,50,77)
    NavyDark   = [Drawing.Color]::FromArgb(16,36,56)
    Accent     = [Drawing.Color]::FromArgb(0,102,178)
    AccentHot  = [Drawing.Color]::FromArgb(0,86,150)
    AccentSoft = [Drawing.Color]::FromArgb(228,240,250)
    Success    = [Drawing.Color]::FromArgb(21,128,84)
    SuccessSoft= [Drawing.Color]::FromArgb(226,244,235)
    Warning    = [Drawing.Color]::FromArgb(150,98,0)
    WarningSoft= [Drawing.Color]::FromArgb(253,242,219)
    Danger     = [Drawing.Color]::FromArgb(172,32,32)
    DangerSoft = [Drawing.Color]::FromArgb(253,232,232)
    Canvas     = [Drawing.Color]::FromArgb(243,246,249)
    Surface    = [Drawing.Color]::White
    Border     = [Drawing.Color]::FromArgb(196,205,215)
    Text       = [Drawing.Color]::FromArgb(26,32,40)
    TextMuted  = [Drawing.Color]::FromArgb(90,99,110)
    FieldEmpty = [Drawing.Color]::FromArgb(255,249,235)
}

# ---------- ตัวคูณขนาดสำหรับปุ่มขยายตัวอักษร ----------
$script:UiScaleSteps = @(1.0,1.25,1.5,1.75)
$script:UiScale = 1.0

function Get-AuditUiScaleSteps { return @($script:UiScaleSteps) }
function Get-AuditUiScale { return $script:UiScale }

function Set-AuditUiScale {
    param([double]$Scale)
    $nearest = $script:UiScaleSteps[0]
    foreach ($step in $script:UiScaleSteps) { if ([Math]::Abs($step - $Scale) -lt [Math]::Abs($nearest - $Scale)) { $nearest = $step } }
    $script:UiScale = $nearest
    return $script:UiScale
}

function Get-AuditNextUiScale {
    # ทิศทาง 1 คือขยาย -1 คือย่อ คืนค่าระดับถัดไปที่มีจริง
    param([int]$Direction)
    $index = [Array]::IndexOf($script:UiScaleSteps,$script:UiScale)
    if ($index -lt 0) { $index = 0 }
    $next = [Math]::Max(0,[Math]::Min($script:UiScaleSteps.Count - 1,$index + $Direction))
    return $script:UiScaleSteps[$next]
}

function Get-AuditScaled {
    # แปลงขนาดพิกเซลฐานเป็นขนาดจริงตามระดับซูมปัจจุบัน
    param([Parameter(Mandatory)][int]$Value)
    return [int][Math]::Round($Value * $script:UiScale)
}

function Get-AuditColor { param([Parameter(Mandatory)][string]$Name) return $script:Palette[$Name] }

function Resolve-AuditFontFamily {
    # เลือกฟอนต์ที่รองรับภาษาไทยตัวแรกที่ติดตั้งอยู่จริงในเครื่อง
    $installed = @([Drawing.FontFamily]::Families | ForEach-Object { $_.Name })
    foreach ($candidate in @('Leelawadee UI','Leelawadee','Segoe UI','Tahoma')) {
        if ($installed -contains $candidate) { return $candidate }
    }
    return 'Microsoft Sans Serif'
}

$script:FontFamily = Resolve-AuditFontFamily

function New-AuditFont {
    # ขนาดฐานต่ำสุดของโปรแกรมนี้คือ 11 pt ตามข้อกำหนดเรื่องการมองเห็น
    param([double]$Size = 12,[string]$Style = 'Regular')
    if ($Size -lt 11) { $Size = 11 }
    $fontStyle = [Drawing.FontStyle]::Regular
    if ($Style -eq 'Bold') { $fontStyle = [Drawing.FontStyle]::Bold }
    return (New-Object Drawing.Font($script:FontFamily,[single]($Size * $script:UiScale),$fontStyle))
}

function New-AuditLabel {
    param([string]$Text = '',[double]$Size = 12,[string]$Style = 'Regular',$ForeColor = $null,[switch]$AutoSize)
    $label = New-Object Windows.Forms.Label
    $label.Text = $Text
    $label.Font = New-AuditFont -Size $Size -Style $Style
    $label.ForeColor = $(if ($null -ne $ForeColor) { $ForeColor } else { $script:Palette.Text })
    $label.BackColor = [Drawing.Color]::Transparent
    $label.AutoSize = [bool]$AutoSize
    $label.Margin = New-Object Windows.Forms.Padding(0,0,0,0)
    return $label
}

function Set-AuditButtonStyle {
    param(
        [Parameter(Mandatory)]$Button,
        [ValidateSet('Primary','Secondary','Ghost','Danger')][string]$Kind = 'Secondary'
    )
    switch ($Kind) {
        'Primary'   { $back = $script:Palette.Accent;  $fore = [Drawing.Color]::White; $hover = $script:Palette.AccentHot;  $border = $script:Palette.Accent }
        'Danger'    { $back = $script:Palette.Surface; $fore = $script:Palette.Danger; $hover = $script:Palette.DangerSoft; $border = $script:Palette.Border }
        'Ghost'     { $back = $script:Palette.Canvas;  $fore = $script:Palette.Text;   $hover = $script:Palette.AccentSoft; $border = $script:Palette.Border }
        default     { $back = $script:Palette.Surface; $fore = $script:Palette.Text;   $hover = $script:Palette.AccentSoft; $border = $script:Palette.Border }
    }
    $Button.FlatStyle = 'Flat'
    $Button.FlatAppearance.BorderSize = 1
    $Button.FlatAppearance.BorderColor = $border
    $Button.FlatAppearance.MouseOverBackColor = $hover
    $Button.BackColor = $back
    $Button.ForeColor = $fore
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.UseVisualStyleBackColor = $false
    $Button.AutoSize = $false
    return $Button
}

function New-AuditButton {
    # Width และ Height ที่ส่งเข้ามาเป็นขนาดฐานที่ระดับซูม 100 เปอร์เซ็นต์
    # ความสูงขั้นต่ำ 44 พิกเซล เพื่อให้กดง่ายสำหรับผู้สูงอายุ
    param([string]$Text,[int]$Width = 190,[int]$Height = 44,[string]$Kind = 'Secondary',[double]$FontSize = 12)
    if ($Height -lt 44) { $Height = 44 }
    $button = New-Object Windows.Forms.Button
    $button.Text = $Text
    $button.Font = New-AuditFont -Size $FontSize
    $button.Size = New-Object Drawing.Size((Get-AuditScaled $Width),(Get-AuditScaled $Height))
    $button.Margin = New-Object Windows.Forms.Padding(0,0,(Get-AuditScaled 10),0)
    [void](Set-AuditButtonStyle -Button $button -Kind $Kind)
    return $button
}

function New-AuditBadge {
    param([string]$Text = '',[string]$Kind = 'Neutral')
    $badge = New-Object Windows.Forms.Label
    $badge.AutoSize = $true
    $badge.Font = New-AuditFont -Size 11 -Style 'Bold'
    $badge.Padding = New-Object Windows.Forms.Padding((Get-AuditScaled 9),(Get-AuditScaled 4),(Get-AuditScaled 9),(Get-AuditScaled 4))
    $badge.Margin = New-Object Windows.Forms.Padding(0,(Get-AuditScaled 2),(Get-AuditScaled 8),0)
    $badge.TextAlign = 'MiddleCenter'
    Set-AuditBadgeState -Badge $badge -Text $Text -Kind $Kind
    return $badge
}

function Set-AuditBadgeState {
    param([Parameter(Mandatory)]$Badge,[string]$Text = '',[string]$Kind = 'Neutral')
    switch ($Kind) {
        'Success' { $Badge.BackColor = $script:Palette.SuccessSoft; $Badge.ForeColor = $script:Palette.Success }
        'Warning' { $Badge.BackColor = $script:Palette.WarningSoft; $Badge.ForeColor = $script:Palette.Warning }
        'Danger'  { $Badge.BackColor = $script:Palette.DangerSoft;  $Badge.ForeColor = $script:Palette.Danger }
        'Info'    { $Badge.BackColor = $script:Palette.AccentSoft;  $Badge.ForeColor = $script:Palette.Accent }
        default   { $Badge.BackColor = [Drawing.Color]::FromArgb(234,238,243); $Badge.ForeColor = $script:Palette.TextMuted }
    }
    $Badge.Text = $Text
}

function New-AuditCard {
    <#
      การ์ดพื้นขาว ขอบบาง มีแถบสีด้านซ้าย
      คืนค่า Panel ที่มี property Body สำหรับใส่คอนโทรลภายใน
    #>
    param([string]$Title = '',[string]$Subtitle = '',[int]$BottomMargin = 16)
    $card = New-Object Windows.Forms.Panel
    $card.BackColor = $script:Palette.Surface
    $card.Dock = 'Fill'
    $card.AutoSize = $true
    $card.AutoSizeMode = 'GrowAndShrink'
    $card.Padding = New-Object Windows.Forms.Padding((Get-AuditScaled 22),(Get-AuditScaled 16),(Get-AuditScaled 22),(Get-AuditScaled 18))
    $card.Margin = New-Object Windows.Forms.Padding(0,0,0,(Get-AuditScaled $BottomMargin))
    $card.Add_Paint({
        param($sender,$e)
        $borderPen = New-Object Drawing.Pen((Get-AuditColor 'Border'))
        try { $e.Graphics.DrawRectangle($borderPen,0,0,$sender.Width - 1,$sender.Height - 1) } finally { $borderPen.Dispose() }
        $accentBrush = New-Object Drawing.SolidBrush((Get-AuditColor 'Accent'))
        try { $e.Graphics.FillRectangle($accentBrush,0,0,(Get-AuditScaled 5),$sender.Height) } finally { $accentBrush.Dispose() }
    })

    $stack = New-Object Windows.Forms.TableLayoutPanel
    $stack.Dock = 'Top'
    $stack.AutoSize = $true
    $stack.AutoSizeMode = 'GrowAndShrink'
    $stack.ColumnCount = 1
    [void]$stack.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))

    if ($Title) {
        $titleLabel = New-AuditLabel -Text $Title -Size 14 -Style 'Bold' -AutoSize
        $titleLabel.Margin = New-Object Windows.Forms.Padding(0,0,0,(Get-AuditScaled 4))
        [void]$stack.Controls.Add($titleLabel)
    }
    if ($Subtitle) {
        $subtitleLabel = New-AuditLabel -Text $Subtitle -Size 11 -ForeColor $script:Palette.TextMuted -AutoSize
        $subtitleLabel.Margin = New-Object Windows.Forms.Padding(0,0,0,(Get-AuditScaled 12))
        [void]$stack.Controls.Add($subtitleLabel)
    }

    $body = New-Object Windows.Forms.TableLayoutPanel
    $body.Dock = 'Top'
    $body.AutoSize = $true
    $body.AutoSizeMode = 'GrowAndShrink'
    $body.ColumnCount = 1
    $body.Margin = New-Object Windows.Forms.Padding(0)
    [void]$body.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
    [void]$stack.Controls.Add($body)

    $card.Controls.Add($stack)
    Add-Member -InputObject $card -MemberType NoteProperty -Name Body -Value $body
    return $card
}

function New-AuditFillCard {
    <#
      การ์ดที่ยืดเต็มพื้นที่ ใช้กับตารางที่ต้องขยายตามหน้าต่าง
      คืนค่า Panel ที่มี property Surface สำหรับใส่ตาราง
    #>
    param([string]$Title = '',[string]$Subtitle = '')
    $card = New-Object Windows.Forms.Panel
    $card.Dock = 'Fill'
    $card.BackColor = $script:Palette.Surface
    $card.Add_Paint({
        param($sender,$e)
        $borderPen = New-Object Drawing.Pen((Get-AuditColor 'Border'))
        try { $e.Graphics.DrawRectangle($borderPen,0,0,$sender.Width - 1,$sender.Height - 1) } finally { $borderPen.Dispose() }
        $accentBrush = New-Object Drawing.SolidBrush((Get-AuditColor 'Accent'))
        try { $e.Graphics.FillRectangle($accentBrush,0,0,(Get-AuditScaled 5),$sender.Height) } finally { $accentBrush.Dispose() }
    })
    $surface = New-Object Windows.Forms.Panel
    $surface.Dock = 'Fill'
    $surface.BackColor = $script:Palette.Surface
    $surface.Padding = New-Object Windows.Forms.Padding((Get-AuditScaled 20),(Get-AuditScaled 4),(Get-AuditScaled 20),(Get-AuditScaled 18))
    $head = New-Object Windows.Forms.Panel
    $head.Dock = 'Top'
    $head.Height = Get-AuditScaled 70
    $head.BackColor = $script:Palette.Surface
    $titleLabel = New-AuditLabel -Text $Title -Size 14 -Style 'Bold' -AutoSize
    $titleLabel.Location = New-Object Drawing.Point((Get-AuditScaled 22),(Get-AuditScaled 14))
    $subtitleLabel = New-AuditLabel -Text $Subtitle -Size 11 -ForeColor $script:Palette.TextMuted -AutoSize
    $subtitleLabel.Location = New-Object Drawing.Point((Get-AuditScaled 22),(Get-AuditScaled 42))
    $head.Controls.AddRange(@($titleLabel,$subtitleLabel))
    # เพิ่ม Surface ก่อน Head เพื่อให้ Head อยู่บนสุดตามลำดับการ Dock ของ WinForms
    $card.Controls.Add($surface)
    $card.Controls.Add($head)
    Add-Member -InputObject $card -MemberType NoteProperty -Name Surface -Value $surface
    return $card
}

function New-AuditScrollHost {
    # พื้นที่เลื่อนแนวตั้งที่ความกว้างของลูกยืดตามหน้าต่างเสมอ
    param([int]$PadLeft = 26,[int]$PadTop = 22,[int]$PadRight = 26,[int]$PadBottom = 22)
    $scroll = New-Object Windows.Forms.Panel
    $scroll.Dock = 'Fill'
    $scroll.AutoScroll = $true
    $scroll.BackColor = $script:Palette.Canvas
    $scroll.Padding = New-Object Windows.Forms.Padding((Get-AuditScaled $PadLeft),(Get-AuditScaled $PadTop),(Get-AuditScaled $PadRight),(Get-AuditScaled $PadBottom))

    $stack = New-Object Windows.Forms.TableLayoutPanel
    $stack.Dock = 'Top'
    $stack.AutoSize = $true
    $stack.AutoSizeMode = 'GrowAndShrink'
    $stack.ColumnCount = 1
    [void]$stack.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
    $scroll.Controls.Add($stack)

    Add-Member -InputObject $scroll -MemberType NoteProperty -Name Stack -Value $stack
    return $scroll
}

function New-AuditTextBox {
    # ช่องกรอกมาตรฐาน ความสูงและฟอนต์ขยายตามระดับซูม
    param([int]$BaseHeight = 34,[double]$FontSize = 13,[switch]$Multiline)
    $textBox = New-Object Windows.Forms.TextBox
    $textBox.Font = New-AuditFont -Size $FontSize
    $textBox.BorderStyle = 'FixedSingle'
    $textBox.Multiline = [bool]$Multiline
    if ($Multiline) { $textBox.ScrollBars = 'Vertical' }
    $textBox.Height = Get-AuditScaled $BaseHeight
    return $textBox
}

function Set-AuditGridStyle {
    param([Parameter(Mandatory)]$Grid)
    $Grid.BackgroundColor = $script:Palette.Surface
    $Grid.BorderStyle = 'None'
    $Grid.EnableHeadersVisualStyles = $false
    $Grid.ColumnHeadersDefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(235,240,245)
    $Grid.ColumnHeadersDefaultCellStyle.ForeColor = $script:Palette.Text
    $Grid.ColumnHeadersDefaultCellStyle.Font = New-AuditFont -Size 11 -Style 'Bold'
    $Grid.ColumnHeadersHeight = Get-AuditScaled 40
    $Grid.ColumnHeadersHeightSizeMode = 'DisableResizing'
    $Grid.DefaultCellStyle.Font = New-AuditFont -Size 11
    $Grid.DefaultCellStyle.Padding = New-Object Windows.Forms.Padding((Get-AuditScaled 4),0,(Get-AuditScaled 4),0)
    $Grid.DefaultCellStyle.SelectionBackColor = $script:Palette.AccentSoft
    $Grid.DefaultCellStyle.SelectionForeColor = $script:Palette.Text
    $Grid.AlternatingRowsDefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(248,250,252)
    $Grid.RowHeadersVisible = $false
    $Grid.AllowUserToAddRows = $false
    $Grid.AllowUserToDeleteRows = $false
    $Grid.AllowUserToResizeRows = $false
    $Grid.ReadOnly = $true
    $Grid.MultiSelect = $false
    $Grid.SelectionMode = 'FullRowSelect'
    $Grid.CellBorderStyle = 'SingleHorizontal'
    $Grid.GridColor = $script:Palette.Border
    $Grid.RowTemplate.Height = Get-AuditScaled 38
    $Grid.ShowCellToolTips = $true
    return $Grid
}

function Get-AuditStatusKind {
    # แปลงสถานะข้อความเป็นชนิดสีของ Badge
    param([string]$Status)
    switch -Regex ([string]$Status) {
        '^(READY|SUCCESS|AUTO_CONFIRMED|user_confirmed)$' { return 'Success' }
        '^(WARNING|DRAFT|AUTO_DRAFT|draft_observed)$'     { return 'Warning' }
        '^(BLOCKED|ERROR)$'                               { return 'Danger' }
        '^(MANUAL)$'                                      { return 'Info' }
        default                                           { return 'Neutral' }
    }
}

Export-ModuleMember -Function Get-AuditColor,New-AuditFont,New-AuditLabel,New-AuditButton,Set-AuditButtonStyle,
    New-AuditBadge,Set-AuditBadgeState,New-AuditCard,New-AuditFillCard,New-AuditScrollHost,New-AuditTextBox,
    Set-AuditGridStyle,Get-AuditStatusKind,Resolve-AuditFontFamily,
    Get-AuditUiScale,Set-AuditUiScale,Get-AuditNextUiScale,Get-AuditUiScaleSteps,Get-AuditScaled
