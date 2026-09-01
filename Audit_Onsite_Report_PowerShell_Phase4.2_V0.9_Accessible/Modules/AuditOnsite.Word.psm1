Set-StrictMode -Version Latest

function Get-AuditWordRequiredTokens {
    param($Config)
    $tokens = @(
        '[[AUDIT_UNIT]]','[[PHONE]]','[[DOCUMENT_NO]]','[[REPORT_DATE]]',
        '[[BRANCH_NAME]]','[[RECIPIENT]]','[[APPROVAL_NO]]','[[APPROVAL_DATE]]',
        '[[AUDITORS]]','[[ONSITE_DATE]]','[[MEETING_DATE]]','[[LEAD_NAME]]',
        '[[LEAD_POSITION]]','[[LEAD_DATE]]','[[AUDITEE_NAME]]',
        '[[AUDITEE_POSITION]]','[[AUDITEE_DATE]]'
    )
    $tokens += @($Config.mappings | ForEach-Object { [string]$_.word_placeholder })
    return @($tokens)
}

function Test-AuditWordTemplate {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)]$Config)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "ไม่พบ Template: $Path" }
    $zip = $null
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($Path)
        $parts = @($zip.Entries | Where-Object { $_.FullName -match '^word/(document|header[0-9]+|footer[0-9]+)\.xml$' })
        if ($parts.Count -eq 0) { throw 'ไม่พบ Word XML Parts' }
        $all = ''
        foreach ($entry in $parts) {
            $reader = $null
            try { $reader = New-Object IO.StreamReader($entry.Open(),[Text.Encoding]::UTF8); $all += $reader.ReadToEnd() }
            finally { if ($reader) { $reader.Dispose() } }
        }
        $required = Get-AuditWordRequiredTokens -Config $Config
        $found = @(); $missing = @()
        foreach ($token in $required) { if ($all.Contains($token)) { $found += $token } else { $missing += $token } }
        return [pscustomobject]@{
            TemplatePath=$Path; RequiredCount=$required.Count; FoundCount=$found.Count
            MissingCount=$missing.Count; Missing=$missing
            Status=$(if ($missing.Count -eq 0) {'READY'} else {'BLOCKED'})
            Schema='2026-09-01-latest'
        }
    } finally { if ($zip) { $zip.Dispose() } }
}

function ConvertTo-AuditWordXmlValue {
    param([AllowEmptyString()][string]$Value)
    $escaped = [Security.SecurityElement]::Escape([string]$Value)
    $escaped = $escaped -replace "`r`n", "`n"
    $escaped = $escaped -replace "`r", "`n"
    return ($escaped -replace "`n", '</w:t><w:br/><w:t xml:space="preserve">')
}


function Remove-AuditTrailingEmptyParagraphs {
    param([Parameter(Mandatory)][string]$DocumentXmlPath)
    [xml]$doc = Get-Content -LiteralPath $DocumentXmlPath -Raw -Encoding UTF8
    $ns = New-Object Xml.XmlNamespaceManager($doc.NameTable)
    $ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $body = $doc.SelectSingleNode('//w:body',$ns)
    if (-not $body) { return 0 }
    $removed = 0
    while ($body.ChildNodes.Count -gt 1) {
        $lastIndex = $body.ChildNodes.Count - 1
        $last = $body.ChildNodes[$lastIndex]
        if ($last.LocalName -eq 'sectPr') { $candidate = $body.ChildNodes[$lastIndex - 1] } else { $candidate = $last }
        if ($candidate.LocalName -ne 'p') { break }
        $textNodes = $candidate.SelectNodes('.//w:t',$ns)
        $visible = ''
        foreach ($node in $textNodes) { $visible += [string]$node.InnerText }
        $hasBreak = $null -ne $candidate.SelectSingleNode('.//w:br',$ns)
        $hasDrawing = $null -ne $candidate.SelectSingleNode('.//w:drawing',$ns)
        $hasBookmark = ($null -ne $candidate.SelectSingleNode('.//w:bookmarkStart',$ns)) -or ($null -ne $candidate.SelectSingleNode('.//w:bookmarkEnd',$ns))
        $hasSection = $null -ne $candidate.SelectSingleNode('.//w:sectPr',$ns)
        if (-not [string]::IsNullOrWhiteSpace($visible) -or $hasBreak -or $hasDrawing -or $hasBookmark -or $hasSection) { break }
        [void]$body.RemoveChild($candidate)
        $removed++
    }
    if ($removed -gt 0) {
        $settings = New-Object Xml.XmlWriterSettings
        $settings.Encoding = New-Object Text.UTF8Encoding($false)
        $settings.Indent = $false
        $writer = [Xml.XmlWriter]::Create($DocumentXmlPath,$settings)
        try { $doc.Save($writer) } finally { $writer.Dispose() }
    }
    return $removed
}

function Export-AuditWordDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TemplatePath,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][hashtable]$Replacements,
        [Parameter(Mandatory)]$Config
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) { throw "ไม่พบ Template: $TemplatePath" }
    $templateCheck = Test-AuditWordTemplate -Path $TemplatePath -Config $Config
    if ($templateCheck.Status -ne 'READY') { throw "Template ไม่ผ่าน: ขาด $($templateCheck.Missing -join ', ')" }
    $parent = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $OutputPath) { throw "มีไฟล์ปลายทางอยู่แล้ว: $OutputPath" }

    $temp = Join-Path ([IO.Path]::GetTempPath()) ('AuditOnsiteWord-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    try {
        [IO.Compression.ZipFile]::ExtractToDirectory($TemplatePath,$temp)
        $xmlFiles = @(Get-ChildItem -LiteralPath (Join-Path $temp 'word') -File | Where-Object { $_.Name -match '^(document|header[0-9]+|footer[0-9]+)\.xml$' })
        foreach ($xmlFile in $xmlFiles) {
            $xml = Get-Content -LiteralPath $xmlFile.FullName -Raw -Encoding UTF8
            foreach ($token in @($Replacements.Keys)) {
                $xmlValue = ConvertTo-AuditWordXmlValue -Value ([string]$Replacements[$token])
                $xml = $xml.Replace([string]$token,$xmlValue)
            }
            [IO.File]::WriteAllText($xmlFile.FullName,$xml,(New-Object Text.UTF8Encoding($false)))
        }
        $trimmedTrailingParagraphs = Remove-AuditTrailingEmptyParagraphs -DocumentXmlPath (Join-Path $temp 'word\document.xml')
        $leftover = @()
        foreach ($xmlFile in $xmlFiles) {
            $xml = Get-Content -LiteralPath $xmlFile.FullName -Raw -Encoding UTF8
            $leftover += @([regex]::Matches($xml,'\[\[[A-Z0-9_]+\]\]') | ForEach-Object { $_.Value })
        }
        $leftover = @($leftover | Sort-Object -Unique)
        if ($leftover.Count -gt 0) { throw "ยังมี Placeholder ตกค้าง: $($leftover -join ', ')" }
        [IO.Compression.ZipFile]::CreateFromDirectory($temp,$OutputPath,[IO.Compression.CompressionLevel]::Optimal,$false)
        if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw 'ไม่พบไฟล์ผลลัพธ์หลังสร้าง' }
        return [pscustomobject]@{
            Status='SUCCESS'; OutputPath=$OutputPath; TemplatePath=$TemplatePath
            ReplacementCount=$Replacements.Count; LeftoverCount=0; TrailingEmptyParagraphsRemoved=$trimmedTrailingParagraphs; CreatedAt=(Get-Date).ToString('s')
        }
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue } }
}

Export-ModuleMember -Function Test-AuditWordTemplate,Export-AuditWordDocument
