#requires -Version 5.1
# Pure configuration transforms. No filesystem or registry access.
$script:DebugArguments = '--remote-debugging-port=0 --remote-debugging-address=127.0.0.1'
function Get-DebugArguments { return $script:DebugArguments }
function Add-FilterConfiguration {
    param([object]$Config)
    if ($null -eq $Config) { $Config = [pscustomobject]@{} }
    if ($Config -isnot [pscustomobject]) { throw 'Outlook config must be a JSON object.' }
    if ($null -eq $Config.Browser) { $Config | Add-Member -NotePropertyName Browser -NotePropertyValue ([pscustomobject]@{}) -Force }
    if ($Config.Browser -isnot [pscustomobject]) { throw 'Browser config must be a JSON object.' }
    $current = $Config.Browser.AdditionalCommandLine
    if ($null -ne $current -and $current -isnot [string]) { throw 'AdditionalCommandLine must be a string.' }
    if ($current -and $current.Contains($script:DebugArguments)) {
        $otherArguments = $current.Replace($script:DebugArguments, '')
        if ($otherArguments -match '--remote-debugging-') { throw 'Additional debugging arguments conflict with this tool.' }
        return $Config
    }
    if ($current -match '--remote-debugging-') { throw 'An existing debugging configuration needs manual review.' }
    $value = (@($current, $script:DebugArguments) | Where-Object { $_ }) -join ' '
    if ($Config.Browser.PSObject.Properties['AdditionalCommandLine']) { $Config.Browser.AdditionalCommandLine = $value }
    else { $Config.Browser | Add-Member -NotePropertyName AdditionalCommandLine -NotePropertyValue $value }
    return $Config
}
function Remove-FilterConfiguration {
    param([object]$Config, [object]$State)
    if ($null -eq $Config) { return $null }
    $current = $Config.Browser.AdditionalCommandLine
    $expected = (@($State.originalArguments, $script:DebugArguments) | Where-Object { $_ }) -join ' '
    if ($current -eq $expected) { $remaining = $State.originalArguments }
    elseif ($current -is [string]) { $remaining = $current.Replace($script:DebugArguments, '').Trim() }
    elseif ($null -eq $current) { $remaining = $null }
    else { throw 'AdditionalCommandLine changed type; review it manually.' }
    if ($remaining) { $Config.Browser.AdditionalCommandLine = $remaining }
    elseif ($Config.Browser) { $Config.Browser.PSObject.Properties.Remove('AdditionalCommandLine') }
    if ($Config.Browser -and @($Config.Browser.PSObject.Properties).Count -eq 0 -and -not $State.browserExisted) { $Config.PSObject.Properties.Remove('Browser') }
    if (-not $State.configExisted -and @($Config.PSObject.Properties).Count -eq 0) { return $null }
    return $Config
}
