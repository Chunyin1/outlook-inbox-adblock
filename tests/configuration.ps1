$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../src/Configuration.ps1')
function Assert($condition,$message){if(-not $condition){throw $message}}
function Json($value){return ($value|ConvertTo-Json -Depth 50 -Compress)}
foreach($original in @('{}','{"Browser":{}}','{"theme":"dark","Browser":{"AdditionalCommandLine":"--existing-option","Other":true}}')){
    $config=$original|ConvertFrom-Json
    $state=[pscustomobject]@{configExisted=$true;browserExisted=$null -ne $config.Browser;originalArguments=$config.Browser.AdditionalCommandLine}
    $result=Add-FilterConfiguration $config
    $once=Json $result
    Assert ((Json (Add-FilterConfiguration $result)) -eq $once) 'Repeated install changed config'
    Assert ((Json (Remove-FilterConfiguration $result $state)) -eq $original) ("Undo failed: expected " + $original + "; got " + (Json $result))
}
$state=[pscustomobject]@{configExisted=$false;browserExisted=$false;originalArguments=$null}
$config=Add-FilterConfiguration ([pscustomobject]@{})
Assert ($null -eq (Remove-FilterConfiguration $config $state)) 'Undo should remove newly created empty config'
$config=Add-FilterConfiguration ([pscustomobject]@{})
$config|Add-Member -NotePropertyName Later -NotePropertyValue 'keep'
$config.Browser.AdditionalCommandLine+=' --later-option'
$result=Remove-FilterConfiguration $config $state
Assert ($result.Later -eq 'keep' -and $result.Browser.AdditionalCommandLine -eq '--later-option') 'Undo discarded later edits'
Assert ($null -eq (Remove-FilterConfiguration ([pscustomobject]@{}) $state)) 'Undo failed if another tool already removed Browser'
foreach($bad in @('{"Browser":{"AdditionalCommandLine":"--remote-debugging-port=1234"}}','{"Browser":42}','{"Browser":{"AdditionalCommandLine":[]}}')){
    $refused=$false;try{Add-FilterConfiguration ($bad|ConvertFrom-Json)|Out-Null}catch{$refused=$true}
    Assert $refused 'Invalid or conflicting configuration accepted'
}
Write-Output 'PASS: config install/undo, idempotence, later edits, missing keys, and conflict refusal.'

$config=Add-FilterConfiguration ([pscustomobject]@{})
$config.Browser.AdditionalCommandLine+=' --remote-debugging-address=0.0.0.0'
$refused=$false;try{Add-FilterConfiguration $config|Out-Null}catch{$refused=$true}
Assert $refused 'Additional conflicting debugging arguments accepted'
