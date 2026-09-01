#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
foreach($folder in @('Logs','Output','Templates','Config','Documents')){$p=Join-Path $root $folder;if(-not(Test-Path $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}}
try {
 Import-Module (Join-Path $root 'Modules\AuditOnsite.Core.psm1') -Force
 Import-Module (Join-Path $root 'Modules\AuditOnsite.Theme.psm1') -Force
 Import-Module (Join-Path $root 'Modules\AuditOnsite.Excel.psm1') -Force
 Import-Module (Join-Path $root 'Modules\AuditOnsite.Word.psm1') -Force
 Import-Module (Join-Path $root 'Modules\AuditOnsite.UI.psm1') -Force
 $config=Read-AuditJson (Join-Path $root 'Config\Onsite_Mapping_Config.json')
 Start-AuditOnsiteUI -AppRoot $root -Config $config -FixedPath (Join-Path $root 'Config\Fixed_Values.json')
} catch {Add-Type -AssemblyName System.Windows.Forms;[Windows.Forms.MessageBox]::Show("ไม่สามารถเริ่มโปรแกรมได้`r`n$($_.Exception.Message)`r`n$($_.InvocationInfo.PositionMessage)",'Audit Onsite Report')|Out-Null;exit 1}
