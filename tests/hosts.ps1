$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\src\Hosts.ps1'
$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
. $scriptPath
$samples = @('', '# comment', "# hosts`r`n127.0.0.1 localhost`r`n", "# hosts`n127.0.0.1 localhost`n", "# caf$([char]233)`r`n")
foreach ($sample in $samples) {
    $installed = Get-ManagedText $sample Install
    if ($installed -notmatch '0\.0\.0\.0 outlookads\.live\.com') { throw 'IPv4 rule missing' }
    if ($installed -notmatch ':: outlookads\.live\.com') { throw 'IPv6 rule missing' }
    if ($installed -notmatch '0\.0\.0\.0 m\.adnxs\.com') { throw 'Current ad server IPv4 rule missing' }
    if ($installed -notmatch ':: m\.adnxs\.com') { throw 'Current ad server IPv6 rule missing' }
    if ($installed -notmatch '0\.0\.0\.0 msft-ssp\.adnxs\.com') { throw 'Installed Outlook ad endpoint IPv4 rule missing' }
    if ($installed -notmatch ':: msft-ssp\.adnxs\.com') { throw 'Installed Outlook ad endpoint IPv6 rule missing' }
    if ((Get-ManagedText $installed Install) -cne $installed) { throw 'Install not idempotent' }
    if ((Get-ManagedText $installed Undo) -cne $sample) { throw 'Undo did not restore exact original text' }
    $later = "10.1.2.3 later.example`r`n"
    if ((Get-ManagedText ($installed + $later) Undo) -cne ($sample + $later)) { throw 'Undo removed later edits' }
}
$legacy = "# original`r`n`r`n$begin`r`n0.0.0.0 outlookads.live.com`r`n:: outlookads.live.com`r`n$end`r`n"
$upgraded = Get-ManagedText $legacy Install
if ($upgraded -notmatch '0\.0\.0\.0 m\.adnxs\.com') { throw 'Legacy block was not upgraded' }
if ((Get-ManagedText $upgraded Undo) -cne "# original`r`n") { throw 'Upgraded block undo failed' }
$refusals = @("1.2.3.4 outlookads.live.com`r`n", "1.2.3.4 alias OUTLOOKADS.LIVE.COM # other tool`n", "1.2.3.4 m.adnxs.com`r`n", ($legacy + "1.2.3.4 m.adnxs.com`r`n"), "`r`n$begin`r`n")
foreach ($sample in $refusals) {
    $refused = $false
    try { [void](Get-ManagedText $sample Install) } catch { $refused = $true }
    if (-not $refused) { throw 'Conflicting or damaged block was accepted' }
}
Write-Output 'PASS: PowerShell syntax, exact undo, repeat install, IPv4/IPv6, later edits, encoding, conflict refusal, malformed block refusal.'
