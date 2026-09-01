Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ชุดสี ฟอนต์ และตัวช่วยสร้างคอนโทรลกลาง ใช้ร่วมกันทุกหน้าจอ
# ออกแบบให้ทำงานบน Windows PowerShell 5.1 + WinForms เท่านั้น ไม่พึ่ง .NET รุ่นใหม่

$script:Palette = @{
    Navy       = [Drawing.Color]::FromArgb(23,50,77)
    NavyDark   = [Drawing.Color]::FromArgb(16,36,56)
    Accent     = [Drawing.Color]::FromArgb(0,102,178)
    AccentHot  = [Drawing.Color]::FromArgb(0,86,150)
    AccentSoft = [Drawing.Color]::FromArgb(228,240,250)
    Success    = [Drawing.Color]::FromArgb(21,128,84)
    SuccessSoft= [Drawing.Color]::FromArgb(226,244,235)
    Warning    = [Drawing.Color]::FromArgb(168,110,0)
    WarningSoft= [Drawing.Color]::FromArgb(253,242,219)
    Danger     = [Drawing.Color]::FromArgb(180,40,40)
    DangerSoft = [Drawing.Color]::FromArgb(253,232,232)
    Canvas     = [Drawing.Color]::FromArgb(243,246,249)
    Surface    = [Drawing.Color]::White
    Border     = [Drawing.Color]::FromArgb(214,220,228)
    Text       = [Drawing.Color]::FromArgb(30,37,45)
    TextMuted  = [Drawing.Color]::FromArgb(108,117,127)
    FieldEmpty = [Drawing.Color]::FromArgb(255,251,242)
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
    param([double]$Size = 10,[string]$Style = 'Regular')
    $fontStyle = [Drawing.FontStyle]::Regular
    if ($Style -eq 'Bold') { $fontStyle = [Drawing.FontStyle]::Bold }
    return (New-Object Drawing.Font($script:FontFamily,[single]$Size,$fontStyle))
}

function New-AuditLabel {
    param([string]$Text = '',[double]$Size = 10,[string]$Style = 'Regular',$ForeColor = $null,[switch]$AutoSize)
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
        'Ghost'     { $back = $script:Palette.Canvas;  $fore = $script:Palette.Text;   $hover = $script:Palette.AccentSoft; $border = $script:Palette.Canvas }
        default     { $back = $script:Palette.Surface; $fore = $script:Palette.Text;   $hover = $script:Palette.AccentSoft; $border = $script:Palette.Border }
    }
    $Button.FlatStyle = 'Flat'
    $Button.FlatAppearance.BorderSize = 1
    $Button.FlatAppearance.BorderColor = $border
    $Button.FlatAppearance.MouseOverBackColor = $hover
    $Button.BackColor = $back
    $Button.ForeColor = $fore
    $Button.Font = New-AuditFont -Size 10
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.UseVisualStyleBackColor = $false
    $Button.AutoSize = $false
    if ($Button.Height -lt 34) { $Button.Height = 36 }
    return $Button
}

function New-AuditButton {
    param([string]$Text,[int]$Width = 170,[int]$Height = 38,[string]$Kind = 'Secondary',[string]$Tooltip = '')
    $button = New-Object Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object Drawing.Size($Width,$Height)
    $button.Margin = New-Object Windows.Forms.Padding(0,0,10,0)
    [void](Set-AuditButtonStyle -Button $button -Kind $Kind)
    if ($Tooltip) { $button.Tag = $Tooltip }
    return $button
}

function New-AuditBadge {
    param([string]$Text = '',[string]$Kind = 'Neutral')
    $badge = New-Object Windows.Forms.Label
    $badge.AutoSize = $true
    $badge.Font = New-AuditFont -Size 8.5 -Style 'Bold'
    $badge.Padding = New-Object Windows.Forms.Padding(8,3,8,3)
    $badge.Margin = New-Object Windows.Forms.Padding(0,2,8,0)
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
        default   { $Badge.BackColor = [Drawing.Color]::FromArgb(238,241,245); $Badge.ForeColor = $script:Palette.TextMuted }
    }
    $Badge.Text = $Text
}

function New-AuditCard {
    <#
      การ์ดพื้นขาว ขอบบาง มีแถบสีด้านซ้าย
      คืนค่า Panel ที่มี property Body สำหรับใส่คอนโทรลภายใน
    #>
    param([string]$Title = '',[string]$Subtitle = '',[int]$BottomMargin = 14)
    $card = New-Object Windows.Forms.Panel
    $card.BackColor = $script:Palette.Surface
    $card.Dock = 'Fill'
    $card.AutoSize = $true
    $card.AutoSizeMode = 'GrowAndShrink'
    $card.Padding = New-Object Windows.Forms.Padding(20,14,20,16)
    $card.Margin = New-Object Windows.Forms.Padding(0,0,0,$BottomMargin)
    $card.Add_Paint({
        param($sender,$e)
        $borderPen = New-Object Drawing.Pen((Get-AuditColor 'Border'))
        try { $e.Graphics.DrawRectangle($borderPen,0,0,$sender.Width - 1,$sender.Height - 1) } finally { $borderPen.Dispose() }
        $accentBrush = New-Object Drawing.SolidBrush((Get-AuditColor 'Accent'))
        try { $e.Graphics.FillRectangle($accentBrush,0,0,4,$sender.Height) } finally { $accentBrush.Dispose() }
    })

    $stack = New-Object Windows.Forms.TableLayoutPanel
    $stack.Dock = 'Top'
    $stack.AutoSize = $true
    $stack.AutoSizeMode = 'GrowAndShrink'
    $stack.ColumnCount = 1
    [void]$stack.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))

    if ($Title) {
        $titleLabel = New-AuditLabel -Text $Title -Size 12 -Style 'Bold' -AutoSize
        $titleLabel.Margin = New-Object Windows.Forms.Padding(0,0,0,4)
        [void]$stack.Controls.Add($titleLabel)
    }
    if ($Subtitle) {
        $subtitleLabel = New-AuditLabel -Text $Subtitle -Size 9.5 -ForeColor $script:Palette.TextMuted -AutoSize
        $subtitleLabel.Margin = New-Object Windows.Forms.Padding(0,0,0,10)
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

function New-AuditScrollHost {
    # พื้นที่เลื่อนแนวตั้งที่ความกว้างของลูกยืดตามหน้าต่างเสมอ
    param([int]$PadLeft = 24,[int]$PadTop = 20,[int]$PadRight = 24,[int]$PadBottom = 20)
    $scroll = New-Object Windows.Forms.Panel
    $scroll.Dock = 'Fill'
    $scroll.AutoScroll = $true
    $scroll.BackColor = $script:Palette.Canvas
    $scroll.Padding = New-Object Windows.Forms.Padding($PadLeft,$PadTop,$PadRight,$PadBottom)

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

function Set-AuditGridStyle {
    param([Parameter(Mandatory)]$Grid)
    $Grid.BackgroundColor = $script:Palette.Surface
    $Grid.BorderStyle = 'None'
    $Grid.EnableHeadersVisualStyles = $false
    $Grid.ColumnHeadersDefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(238,242,246)
    $Grid.ColumnHeadersDefaultCellStyle.ForeColor = $script:Palette.Text
    $Grid.ColumnHeadersDefaultCellStyle.Font = New-AuditFont -Size 9.5 -Style 'Bold'
    $Grid.ColumnHeadersHeight = 34
    $Grid.ColumnHeadersHeightSizeMode = 'DisableResizing'
    $Grid.DefaultCellStyle.Font = New-AuditFont -Size 9.5
    $Grid.DefaultCellStyle.SelectionBackColor = $script:Palette.AccentSoft
    $Grid.DefaultCellStyle.SelectionForeColor = $script:Palette.Text
    $Grid.AlternatingRowsDefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(249,251,253)
    $Grid.RowHeadersVisible = $false
    $Grid.AllowUserToAddRows = $false
    $Grid.AllowUserToDeleteRows = $false
    $Grid.AllowUserToResizeRows = $false
    $Grid.ReadOnly = $true
    $Grid.MultiSelect = $false
    $Grid.SelectionMode = 'FullRowSelect'
    $Grid.CellBorderStyle = 'SingleHorizontal'
    $Grid.GridColor = $script:Palette.Border
    $Grid.RowTemplate.Height = 30
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
    New-AuditBadge,Set-AuditBadgeState,New-AuditCard,New-AuditScrollHost,Set-AuditGridStyle,Get-AuditStatusKind,
    Resolve-AuditFontFamily
