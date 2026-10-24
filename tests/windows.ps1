$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
foreach($file in Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse|Where-Object {$_.FullName -notlike '*node_modules*'}){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw ($errors|Out-String)}
}
foreach($file in Get-ChildItem -LiteralPath $root -Filter '*.cmd'){
    $lines=Get-Content -LiteralPath $file.FullName
    if(@($lines|Where-Object {$_ -match 'powershell.exe.*-File.*Manage.ps1.*-Action'}).Count -ne 1){throw "Broken launcher: $($file.Name)"}
}
& (Join-Path $PSScriptRoot 'hosts.ps1')
& (Join-Path $PSScriptRoot 'configuration.ps1')
Write-Output 'PASS: all PowerShell files parse and CMD launchers include their action on the command line.'
