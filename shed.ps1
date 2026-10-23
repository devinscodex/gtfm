# shed: free disk space the Windows way. Plan, restore point, ask, clean, check.
# Windows PowerShell 5.1 and 7. Anyone can read the plan. Removal needs an elevated shell.
#   shed                   print the plan, then ask: remove? (y/N)
#   shed -Smoke C:\a,C:\b  paths that must still exist after the run
# Removes: old files in the temp folders, the Windows Update download cache,
# the Delivery Optimization cache, error reports, crash dumps, the Recycle Bin,
# and unused component store files (DISM). It never touches user documents.
# Windows.old is reported but never removed. DISM and Windows.old cannot be undone.

function shed {
    param([string[]]$Smoke = @())

    $adm = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $win = $env:windir
    $sys = $env:SystemDrive

    function Fmt($b) {
        if ($b -ge 1GB) { '{0:N1} GB' -f ($b / 1GB) } elseif ($b -ge 1MB) { '{0:N0} MB' -f ($b / 1MB) } else { '{0:N0} KB' -f ($b / 1KB) }
    }
    # Size of the items older than $age days. Links are skipped, never followed.
    function Du($p, $age = 0) {
        try { if (-not (Test-Path -LiteralPath $p -ErrorAction SilentlyContinue)) { return 0 } } catch { return 0 }
        $cut = (Get-Date).AddDays(-$age); $s = 0
        try {
            foreach ($i in [IO.DirectoryInfo]::new($p).EnumerateFileSystemInfos()) {
                if ($i.LastWriteTime -gt $cut) { continue }
                if (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                if ($i -is [IO.DirectoryInfo]) { $s += Du $i.FullName 0 } else { $s += $i.Length }
            }
        } catch {}
        $s
    }
    # Returns how many items it could not remove (files in use).
    function Clear-Dir($p, $age = 0) {
        try { if (-not (Test-Path -LiteralPath $p -ErrorAction SilentlyContinue)) { return 0 } } catch { return 0 }
        $cut = (Get-Date).AddDays(-$age); $skip = 0
        foreach ($i in [IO.DirectoryInfo]::new($p).EnumerateFileSystemInfos()) {
            if ($i.LastWriteTime -gt $cut) { continue }
            if (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            try { if ($i -is [IO.DirectoryInfo]) { [IO.Directory]::Delete($i.FullName, $true) } else { $i.Delete() } } catch { $skip++ }
        }
        $skip
    }
    function Free { (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sys'").FreeSpace }
    function Healthy { (dism /online /cleanup-image /checkhealth 2>&1 | Out-String) -match 'No component store corruption detected' }
    function Pending {
        (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
        (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    }
    function Busy { try { (New-Object -ComObject Microsoft.Update.Installer).IsBusy } catch { $false } }
    function Last-Rp { (Get-ComputerRestorePoint | Measure-Object SequenceNumber -Maximum).Maximum -as [int] }

    # The restore point. Windows allows one per 24 hours, so lift that limit for this call only.
    function New-Rp {
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        $v = 'SystemRestorePointCreationFrequency'
        $old = (Get-ItemProperty $k -Name $v -ErrorAction SilentlyContinue).$v
        $before = Last-Rp
        $name = 'shed ' + (Get-Date -Format 'yyyy-MM-dd_HHmm')
        try {
            Set-ItemProperty $k $v 0 -Type DWord
            try { Checkpoint-Computer -Description $name -RestorePointType MODIFY_SETTINGS -ErrorAction Stop }
            catch {
                Enable-ComputerRestore -Drive "$sys\"
                Checkpoint-Computer -Description $name -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
            }
        } finally {
            if ($null -eq $old) { Remove-ItemProperty $k $v -ErrorAction SilentlyContinue } else { Set-ItemProperty $k $v $old -Type DWord }
        }
        (Last-Rp) -gt $before
    }

    $items = @(
        @{ N = 'User temp (over 1 day old)';        P = @($env:TEMP);                                  Age = 1 }
        @{ N = 'Windows temp (over 1 day old)';     P = @("$win\Temp");                                Age = 1 }
        @{ N = 'Windows Update download cache';     P = @("$win\SoftwareDistribution\Download");       Svc = $true }
        @{ N = 'Delivery Optimization cache';       P = @("$win\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"); DO = $true }
        @{ N = 'Error reports and crash dumps';     P = @("$env:ProgramData\Microsoft\Windows\WER\ReportQueue", "$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$win\Minidump") }
        @{ N = 'Recycle Bin';                       Bin = $true }
        @{ N = 'Component store (DISM, 5-30 min, cannot be undone)'; Dism = $true }
    )
    foreach ($i in $items) {
        if ($i.Bin) { $i.S = [long](((New-Object -ComObject Shell.Application).NameSpace(10).Items() | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum) }
        elseif ($i.Dism) { $i.S = $null }
        else { $i.S = 0; foreach ($p in $i.P) { $i.S += Du $p $(if ($i.Age) { $i.Age } else { 0 }) } }
    }
    $old = Du "$sys\Windows.old"

    ''
    '{0,-52}{1,12}' -f 'Item', 'Frees'
    '{0,-52}{1,12}' -f ('-' * 50), ('-' * 10)
    foreach ($i in $items) { '{0,-52}{1,12}' -f $i.N, $(if ($null -eq $i.S) { 'unknown' } else { Fmt $i.S }) }
    $total = 0; foreach ($i in $items) { if ($null -ne $i.S) { $total += $i.S } }
    '{0,-52}{1,12}' -f ('-' * 50), ('-' * 10)
    '{0,-52}{1,12}' -f 'Total (without DISM)', (Fmt $total)
    if ($old) { "Windows.old: $(Fmt $old). Not removed. Use Settings > System > Storage > Temporary files." }
    "Free now: $(Fmt (Free))"
    ''
    if (-not $adm) { 'Not elevated: sizes may read low, and removal needs an administrator shell.'; return }
    if (Pending) { 'A restart is pending. Restart first, then run shed again.'; return }
    if (Busy)    { 'Windows Update is installing. Try again later.'; return }
    if ((Read-Host 'Take a restore point, then remove these items? (y/N)') -notmatch '^[yY]') { 'Nothing changed.'; return }

    # Runner, before.
    $h = dism /online /cleanup-image /checkhealth 2>&1 | Out-String
    if ($h -notmatch 'No component store corruption detected') {
        'CHECK FAILED: the component store check did not pass. Nothing was changed.'
        'DISM said:'; $h.Trim(); return
    }
    $log = "$env:ProgramData\gtfm"; $null = New-Item $log -ItemType Directory -Force
    Start-Transcript "$log\shed-$(Get-Date -Format 'yyyyMMdd-HHmm').log" | Out-Null
    $free0 = Free
    $svc = 'wuauserv', 'bits'
    $was = $svc | Where-Object { (Get-Service $_).Status -eq 'Running' }
    try {
        'Restore point: creating (can take a minute)...'
        if (-not (New-Rp)) { 'CHECK FAILED: no new restore point. Nothing was removed.'; return }
        'Restore point: done'
        'Stopping services: ' + ($was -join ', ')
        $was | ForEach-Object { Stop-Service $_ -Force }
        foreach ($i in $items) {
            if ($i.Dism) { continue }
            "clearing: $($i.N) ..."
            $f = Free; $skip = 0
            if ($i.Bin)    { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
            elseif ($i.DO) { Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue }
            else { foreach ($p in $i.P) { $skip += Clear-Dir $p $(if ($i.Age) { $i.Age } else { 0 }) } }
            '  freed {0}{1}' -f (Fmt ((Free) - $f)), $(if ($skip) { ", $skip in use, left alone" } else { '' })
        }
    } finally {
        'Starting services: ' + ($was -join ', ')
        $was | ForEach-Object { Start-Service $_ -ErrorAction SilentlyContinue }
    }
    'DISM: component store cleanup. This takes 5 to 30 minutes. Do not restart.'
    dism /online /cleanup-image /startcomponentcleanup

    # Runner, after.
    $freed = (Free) - $free0
    ''
    'Freed: {0}  (plan said {1}, DISM extra)' -f (Fmt $freed), (Fmt $total)
    $checks = [ordered]@{
        'restore point exists'   = (Last-Rp) -gt 0
        'component store healthy' = (Healthy)
        'services as before'     = -not ($was | Where-Object { (Get-Service $_).Status -ne 'Running' })
        'space was freed'        = $freed -gt 0
    }
    foreach ($s in $Smoke) { $checks["exists: $s"] = Test-Path -LiteralPath $s }
    foreach ($c in $checks.Keys) { '{0,-30}{1}' -f $c, $(if ($checks[$c]) { 'PASS' } else { 'FAIL' }) }
    "Log: $log"
    Stop-Transcript | Out-Null
}

try { shed @args } catch {
    $user = [regex]::Escape($env:USERNAME); $pc = [regex]::Escape($env:COMPUTERNAME)
    $msg = ($_.Exception.Message -replace $user, '<user>' -replace $pc, '<pc>')
    $body = "tool: shed 0.9.0`nPowerShell: $($PSVersionTable.PSVersion)`nWindows: $([Environment]::OSVersion.Version)`nline: $($_.InvocationInfo.ScriptLineNumber)`nerror: $msg"
    "shed failed: $msg"
    'To report it, open this link and press Submit. Nothing is sent before that:'
    'https://github.com/devinscodex/gtfm/issues/new?title=shed%20failed&body=' + [uri]::EscapeDataString($body)
}
