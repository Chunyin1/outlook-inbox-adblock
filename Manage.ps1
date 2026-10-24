#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Install','Undo','Status')][string]$Action='Status', [ValidateSet('Full','HostsOnly','CosmeticOnly')][string]$Mode='Full', [switch]$AcceptDebuggingRisk)
$ErrorActionPreference='Stop'
$ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Invoke-Step($name,$stepAction) {
    $params=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot ('src\'+$name+'.ps1')),'-Action',$stepAction)
    if($name -eq 'Cosmetic' -and $stepAction -in @('Install','Preflight')){$params+='-AcceptDebuggingRisk'}
    & $ps @params
    if($LASTEXITCODE -ne 0){throw "$name $stepAction failed. Earlier successful steps may remain; use Uninstall.cmd to undo them."}
}
try {
    $cosmetic=$Mode -ne 'HostsOnly'
    $hosts=$Mode -ne 'CosmeticOnly'
    if($Action -ne 'Status' -and (Get-Process olk -ErrorAction SilentlyContinue)){throw 'Save drafts and fully quit new Outlook first.'}
    if($Action -eq 'Install' -and $cosmetic){
        if(-not $AcceptDebuggingRisk){
            Write-Output 'Full filtering installs a helper that starts at Windows sign-in.'
            Write-Output 'It enables a loopback-only debugging connection while Outlook is open.'
            Write-Output 'Other local programs can use that connection to access your signed-in Outlook session.'
            Write-Output 'Use Install-Hosts-Only.cmd to avoid this access (the Upgrade card may remain).'
            $answer=Read-Host 'Type ENABLE to accept and install the full filter, or anything else to cancel'
            if($answer -cne 'ENABLE'){Write-Output 'Cancelled. No changes made.';exit 1}
        }
        Invoke-Step 'Cosmetic' 'Preflight'
    }
    if($Action -eq 'Undo'){
        if($cosmetic){Invoke-Step 'Cosmetic' 'Undo'}
        if($hosts){Invoke-Step 'Hosts' 'Undo'}
    }else{
        if($hosts){Invoke-Step 'Hosts' $Action}
        if($cosmetic){Invoke-Step 'Cosmetic' $Action}
    }
    if($Action -eq 'Install'){Write-Output 'Installation complete. Open Outlook normally.'}
    exit 0
}catch{Write-Output $_.Exception.Message;exit 1}
