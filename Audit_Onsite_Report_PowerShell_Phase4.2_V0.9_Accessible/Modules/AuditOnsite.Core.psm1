Set-StrictMode -Version Latest
function Ensure-AuditDirectory{param([string]$Path);if(-not(Test-Path $Path)){New-Item -ItemType Directory -Path $Path -Force|Out-Null}}
function Read-AuditJson{param([string]$Path);Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json}
function Write-AuditJson{param($Data,[string]$Path);Ensure-AuditDirectory (Split-Path -Parent $Path);$Data|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $Path -Encoding UTF8}
function Write-AuditLog{param([string]$AppRoot,[string]$Message,[string]$Level='INFO');$d=Join-Path $AppRoot 'Logs';Ensure-AuditDirectory $d;('{0:u}`t{1}`t{2}'-f(Get-Date),$Level,$Message)|Add-Content (Join-Path $d ('AuditOnsite-{0}.log'-f(Get-Date -Format yyyyMMdd))) -Encoding UTF8}
function Get-ShortLogPath{param([string]$AppRoot,[string]$Prefix,[string]$ItemId='NA');$d=Join-Path $AppRoot 'Logs';Ensure-AuditDirectory $d;$id=$ItemId-replace'[^0-9A-Za-z._-]','_';Join-Path $d ('{0}-Item{1}-{2}.json'-f$Prefix,$id,(Get-Date -Format yyyyMMdd-HHmmssfff))}
Export-ModuleMember -Function *
