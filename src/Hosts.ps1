#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Install','Undo','Status')]
    [string]$Action = 'Status',
    [switch]$Elevated
)

$ErrorActionPreference = 'Stop'
$domains = @('outlookads.live.com', 'm.adnxs.com', 'msft-ssp.adnxs.com')
$hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$begin = '# BEGIN Outlook Inbox Ad Block (local)'
$end = '# END Outlook Inbox Ad Block (local)'
$operationLog = Join-Path $env:LOCALAPPDATA 'OutlookInboxAdblock\last-operation.json'

function Get-ManagedText {
    param([string]$Text, [string]$Operation)
    $pattern = '(?s)\r?\n' + [regex]::Escape($begin) + '\r?\n.*?' + [regex]::Escape($end) + '(?:\r?\n|$)'
    $matches = [regex]::Matches($Text, $pattern)
    $starts = [regex]::Matches($Text, [regex]::Escape($begin)).Count
    $ends = [regex]::Matches($Text, [regex]::Escape($end)).Count
    if ($starts -ne $ends -or $starts -gt 1 -or $matches.Count -ne $starts) {
        throw 'The managed block is damaged or duplicated. No changes were made.'
    }
    if ($Operation -eq 'Undo') { return [regex]::Replace($Text, $pattern, '') }
    $rules = foreach ($hostName in $domains) { "0.0.0.0 $hostName`r`n:: $hostName" }
    $block = "`r`n$begin`r`n" + ($rules -join "`r`n") + "`r`n$end`r`n"
    # Respect another tool's configuration for this exact host; do not silently override it.
    $outsideBlock = [regex]::Replace($Text, $pattern, '')
    foreach ($line in ($outsideBlock -split '\r?\n')) {
        $fields = (($line -split '#', 2)[0].Trim() -split '\s+')
        foreach ($hostName in $domains) {
            if ($fields.Count -gt 1 -and $fields[1..($fields.Count - 1)] -contains $hostName) {
                throw "An existing hosts entry already controls $hostName. No changes were made."
            }
        }
    }
    if ($matches.Count -eq 1) { return $Text.Replace($matches[0].Value, $block) }
    return $Text + $block
}

# Dot-sourcing exposes the transformation for offline verification without changing Windows.
if ($MyInvocation.InvocationName -eq '.') { return }

try {
    if ($Action -ne 'Status') { New-Item -ItemType Directory -Path (Split-Path $operationLog) -Force | Out-Null }
    if ($Action -eq 'Status') {
        Write-Output "Hosts file: $hostsPath"
        $text = [IO.File]::ReadAllText($hostsPath)
        $managed = $text.Contains($begin) -and $text.Contains($end)
        Write-Output "Managed block present: $managed"
        foreach ($hostName in $domains) {
            $escapedHost = [regex]::Escape($hostName)
            $hasIPv4Block = $text -match "(?im)^0\.0\.0\.0\s+$escapedHost\s*$"
            $hasIPv6Block = $text -match "(?im)^::\s+$escapedHost\s*$"
            if (-not ($managed -and $hasIPv4Block -and $hasIPv6Block)) {
                Write-Output "$hostName : entries missing; run Install.cmd."
                continue
            }
            try {
                $addresses = @([Net.Dns]::GetHostAddresses($hostName) | ForEach-Object { $_.IPAddressToString })
                $unexpected = @($addresses | Where-Object { $_ -notin @('0.0.0.0','::','127.0.0.1','::1') })
                if ($unexpected.Count -eq 0 -and $addresses.Count -gt 0) {
                    Write-Output "$hostName : HOSTNAME BLOCK VERIFIED."
                } else { Write-Output "$hostName : resolver block not verified." }
            } catch {
                $rootError = $_.Exception.GetBaseException()
                if ($rootError -is [Net.Sockets.SocketException] -and
                    $rootError.SocketErrorCode -in @([Net.Sockets.SocketError]::NoData, [Net.Sockets.SocketError]::HostNotFound)) {
                    Write-Output "$hostName : HOSTNAME BLOCK VERIFIED (no usable address)."
                } else { Write-Output ($hostName + ' : resolver check unavailable: ' + $_.Exception.Message) }
            }
        }
        Write-Output 'This checks Windows hostname blocking, not whether all inbox ads are gone.'
        Write-Output 'Fully quit and reopen Outlook after installation to discard cached ads.'
        exit 0
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if ($Elevated) { throw 'Administrator rights were not granted.' }
        Write-Output 'Windows administrator approval is required to edit the hosts file.'
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Action {1} -Elevated' -f $PSCommandPath, $Action
        $child = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
        if (Test-Path -LiteralPath $operationLog) { Get-Content -LiteralPath $operationLog }
        exit $child.ExitCode
    }

    # Use a reversible single-byte encoding so all existing hosts bytes are preserved.
    $encoding = [Text.Encoding]::GetEncoding(28591)
    $stream = [IO.File]::Open($hostsPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
    $backup = $null
    $changed = $false
    try {
        $bytes = New-Object byte[] $stream.Length
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $count = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($count -eq 0) { throw 'Could not read the entire hosts file.' }
            $offset += $count
        }
        if ($bytes -contains 0) { throw 'Unsupported hosts encoding (contains NUL bytes). No changes were made.' }
        $oldText = $encoding.GetString($bytes)
        $newText = Get-ManagedText -Text $oldText -Operation $Action
        if ($newText -cne $oldText) {
            $backup = $hostsPath + '.outlook-adblock.' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.bak'
            [IO.File]::WriteAllBytes($backup, $bytes)
            $newBytes = $encoding.GetBytes($newText)
            try {
                $stream.Position = 0
                $stream.Write($newBytes, 0, $newBytes.Length)
                $stream.SetLength($newBytes.Length)
                $stream.Flush($true)
            } catch {
                $writeError = $_
                $stream.Position = 0
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.SetLength($bytes.Length)
                $stream.Flush($true)
                throw $writeError
            }
            $changed = $true
        }
    } finally { $stream.Dispose() }

    $flush = & "$env:SystemRoot\System32\ipconfig.exe" /flushdns 2>&1 | Out-String
    $result = [ordered]@{
        Action = $Action
        Success = $true
        Changed = $changed
        Domains = $domains
        Backup = $backup
        Time = (Get-Date).ToString('o')
        Note = 'Fully quit and reopen Outlook. Existing cached ads may remain until then.'
    }
    $result | ConvertTo-Json | Set-Content -LiteralPath $operationLog -Encoding UTF8
    $result | ConvertTo-Json | Write-Output
    exit 0
} catch {
    $result = [ordered]@{ Action = $Action; Success = $false; Error = $_.Exception.Message; Time = (Get-Date).ToString('o') }
    try { $result | ConvertTo-Json | Set-Content -LiteralPath $operationLog -Encoding UTF8 } catch {}
    Write-Output ($result | ConvertTo-Json)
    exit 1
}
