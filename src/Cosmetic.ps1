#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Install','Undo','Status','Preflight')][string]$Action='Status', [switch]$AcceptDebuggingRisk)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Configuration.ps1')
$root=Join-Path $env:LOCALAPPDATA 'OutlookCosmeticFilter'
$configFile=Join-Path $env:LOCALAPPDATA 'Microsoft\Olk\config.json'
$stateFile=Join-Path $root 'install-state.json'
$runPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName='OutlookCosmeticFilter'
function Save-Json($file,$value) {
    $temporary=$file+'.tmp'
    [IO.File]::WriteAllText($temporary,($value|ConvertTo-Json -Depth 50),(New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporary -Destination $file -Force
}
function Find-Node {
    $candidate=Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue
    if(-not $candidate){throw 'Install Node.js 24 LTS from https://nodejs.org/ and reopen this installer.'}
    $version=& $candidate.Source -p 'process.versions.node'
    if($LASTEXITCODE -ne 0 -or [int]($version.Split('.')[0]) -lt 24){throw 'Node.js 24 or newer is required.'}
    return $candidate.Source
}
function Get-Helper {
    $file=Join-Path $root 'helper.pid'
    if(-not(Test-Path -LiteralPath $file)){return $null}
    $helperId=0
    if(-not [int]::TryParse((Get-Content -LiteralPath $file -Raw),[ref]$helperId)){return $null}
    $p=Get-CimInstance Win32_Process -Filter "ProcessId = $helperId" -ErrorAction SilentlyContinue
    if($p -and $p.Name -eq 'node.exe' -and $p.CommandLine -like ('*'+(Join-Path $root 'helper.cjs')+'*')){return $p}
    return $null
}
function Stop-Helper {
    $p=Get-Helper
    if($p){Stop-Process -Id $p.ProcessId -ErrorAction Stop}
    $file=Join-Path $root 'helper.pid'
    if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file}
}
try {
    $startup=(Get-ItemProperty -LiteralPath $runPath -Name $runName -ErrorAction SilentlyContinue).$runName
    if($Action -eq 'Status') {
        Write-Output ('Cosmetic installation recorded: '+(Test-Path -LiteralPath $stateFile))
        Write-Output ('Helper running: '+[bool](Get-Helper))
        Write-Output ('Starts at sign-in: '+[bool]($startup -like ('*'+(Join-Path $root 'Start-Filter.ps1')+'*')))
        $statusFile=Join-Path $root 'status.json'
        if(Test-Path -LiteralPath $statusFile){Write-Output 'Last observation (may be stale if the helper is stopped):';Get-Content -LiteralPath $statusFile}
        exit 0
    }
    if(Get-Process olk -ErrorAction SilentlyContinue){throw 'Save drafts and fully quit new Outlook before installing or uninstalling.'}
    if($Action -in @('Install','Preflight')) {
        if(-not $AcceptDebuggingRisk){throw 'Full filtering requires explicit acceptance of the local debugging risk. Use Install.cmd.'}
        $nodePath=Find-Node
        if(-not(Test-Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Olk\EBWebView'))){throw 'Open new Outlook once and sign in, then fully quit it and retry.'}
        $exists=Test-Path -LiteralPath $configFile
        $config=if($exists){Get-Content -LiteralPath $configFile -Raw|ConvertFrom-Json}else{[pscustomobject]@{}}
        $prior=if(Test-Path -LiteralPath $stateFile){Get-Content -LiteralPath $stateFile -Raw|ConvertFrom-Json}else{$null}
        if(-not $prior -and $config.Browser.AdditionalCommandLine -match '--remote-debugging-'){throw 'Existing debug configuration is not owned by this tool. Review it before installing.'}
        if($startup -and $startup -notlike ('*'+(Join-Path $root 'Start-Filter.ps1')+'*')){throw 'The startup entry is owned by another program.'}
        $originalArguments=$config.Browser.AdditionalCommandLine
        $browserExisted=$null -ne $config.Browser
        $config=Add-FilterConfiguration $config
        if($Action -eq 'Preflight'){Write-Output 'Cosmetic prerequisites passed.';exit 0}
        New-Item -ItemType Directory -Path $root -Force|Out-Null
        if(-not $prior){Save-Json $stateFile ([ordered]@{version=2;configExisted=$exists;browserExisted=$browserExisted;originalArguments=$originalArguments;created=(Get-Date).ToString('o')})}
        Stop-Helper
        foreach($name in @('filter.js','helper.cjs','connection.cjs','Start-Filter.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('cosmetic\'+$name)) -Destination (Join-Path $root $name) -Force}
        Save-Json (Join-Path $root 'runtime.json') ([ordered]@{nodePath=$nodePath})
        Save-Json $configFile $config
        $launcher='"'+$env:SystemRoot+'\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $root 'Start-Filter.ps1')+'"'
        if(-not(Test-Path -LiteralPath $runPath)){New-Item -Path $runPath -Force|Out-Null}
        New-ItemProperty -Path $runPath -Name $runName -Value $launcher -PropertyType String -Force|Out-Null
        & (Join-Path $root 'Start-Filter.ps1')
        Write-Output 'Cosmetic filter installed. Open Outlook normally.'
    }else{
        if(-not(Test-Path -LiteralPath $stateFile)){Write-Output 'No cosmetic installation recorded; nothing to undo.';exit 0}
        Stop-Helper
        if($startup -like ('*'+(Join-Path $root 'Start-Filter.ps1')+'*')){Remove-ItemProperty -Path $runPath -Name $runName}
        $prior=Get-Content -LiteralPath $stateFile -Raw|ConvertFrom-Json
        if(Test-Path -LiteralPath $configFile){
            $config=Get-Content -LiteralPath $configFile -Raw|ConvertFrom-Json
            $config=Remove-FilterConfiguration $config $prior
            if($null -eq $config){Remove-Item -LiteralPath $configFile}else{Save-Json $configFile $config}
        }
        Move-Item -LiteralPath $stateFile -Destination ($stateFile+'.removed-'+[guid]::NewGuid().ToString('N'))
        Write-Output 'Startup helper and owned debugging arguments removed. Inert local files are retained for recovery.'
    }
    exit 0
}catch{Write-Output ('Cosmetic operation failed: '+$_.Exception.Message);Write-Output 'If installation was interrupted, run Uninstall.cmd before retrying.';exit 1}
