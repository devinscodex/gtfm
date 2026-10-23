# etch: print a stable machine name, e.g. DSKASR6B-9SGCGT. Read-only. Windows PowerShell 5.1 and 7.
# Format: TYPE MAKER RAM DISK - ID

# KEY  TYPE MAKER RAM C: - ID        e.g. DSKASR6B-9SGCGT
#  TYPE   DSK desktop | LAP laptop | TAB tablet | AIO all-in-one | MIN mini/small PC | SRV server | VIR virtual machine
#  MAKER  3 letters of the board maker (DEL Dell, HPI HP, LEN Lenovo, ASU ASUS, ASR ASRock, ACE Acer, MSI, GIG Gigabyte,
#         MIC Microsoft, FRM Framework, APL Apple, SAM Samsung, TOS Toshiba; others = first 3 letters)
#  RAM    installed RAM, nearest power of two: size = 2^n GB  (4=16  5=32  6=64  7=128 ...)
#  C:     size of the C: drive, rounded up to a power of two: size = 2^n GB  (8=256  9=512  A=1 TB  B=2 TB ...)
#  ID     6 chars, SHA-256 of all usable IDs among BIOS serial, UUID, board serial (MAC only if none). Identity = the ID only;
#         RAM and C: are hints and go stale after an upgrade.

$junk = 'TOBEFILLED|OEM|DEFAULT|SERIALNUMBER|NOTSPEC|NOTAPPL|NONE|INVALID|UNKNOWN|EMPTY|^SN$|^NA$|0123456789|^123456'
$cs   = Get-CimInstance Win32_ComputerSystem
$bb   = Get-CimInstance Win32_BaseBoard
$ch   = @( (Get-CimInstance Win32_SystemEnclosure).ChassisTypes )
$a    = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'

$type = if ("$($cs.Manufacturer) $($cs.Model)" -match 'Virtual|VMware|QEMU|Xen|KVM') { 'VIR' }
        else { switch ($ch) {
            { 8,9,10,14,31,32 -contains $_ } { 'LAP'; break }
            { 30 -contains $_ }               { 'TAB'; break }
            { 13 -contains $_ }               { 'AIO'; break }
            { 15,16,35,36 -contains $_ }      { 'MIN'; break }
            { 17..24 -contains $_ }           { 'SRV'; break }
            default { 'DSK' }
        } }
if (-not $type) { $type = 'DSK' }

$cands = [ordered]@{
    BIOS  = (Get-CimInstance Win32_BIOS).SerialNumber
    UUID  = (Get-CimInstance Win32_ComputerSystemProduct).UUID
    Board = $bb.SerialNumber
    MAC   = (Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Sort-Object ifIndex | Select-Object -First 1).MacAddress
}
function Clean($x) { ($x -replace '[^A-Za-z0-9]','').ToUpper() }
function Good($c) {
    $c.Length -ge 6 -and
    ($c.ToCharArray() | Sort-Object -Unique).Count -ge 3 -and
    ($c.ToCharArray() | Group-Object | Measure-Object Count -Maximum).Maximum -le $c.Length/2 -and
    $c -notmatch $junk
}
$ids = @(); $srcs = @()
foreach ($k in 'BIOS','UUID','Board') {
    $c = Clean $cands[$k]
    if (Good $c) { $ids += $c; $srcs += $k }
}
if (-not $ids) {
    $c = Clean $cands['MAC']
    if (Good $c) { $ids += $c; $srcs += 'MAC' }
}
if (-not $ids) { throw 'No usable hardware ID' }
$id  = $ids -join '|'
$src = $srcs -join '+'

$v = [uint64]0
[Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::ASCII.GetBytes($id))[0..4] |
    ForEach-Object { $v = $v * 256 + $_ }
$sig = -join (0..5 | ForEach-Object { $a[$v -band 31]; $v = $v -shr 5 })

$mf = $bb.Manufacturer -replace '[^A-Za-z]',''
$map = @{
    DELL='DEL'; HP='HPI'; HEWLETTPACKARD='HPI'; LENOVO='LEN'
    ASUS='ASU'; ASUSTEK='ASU'; ASROCK='ASR'; ACER='ACE'
    MSI='MSI'; MICROSTARINTERNATIONAL='MSI'; GIGABYTE='GIG'
    MICROSOFT='MIC'; FRAMEWORK='FRM'; APPLE='APL'; SAMSUNG='SAM'
    TOSHIBA='TOS'
}
$m2 = $map[$mf.ToUpper()]
if (-not $m2) { $m2 = ($mf + 'XXX').Substring(0,3).ToUpper() }

function L2($gb) {
    if ($gb -lt 1) { '0' }
    else { $a[[int][math]::Ceiling([math]::Log($gb, 2))] }
}
$gb  = $cs.TotalPhysicalMemory / 1GB
$ram = if ($gb -lt 1) { '0' } else { $a[[int][math]::Round([math]::Log($gb, 2))] }
$dsk = L2( (Get-Volume -DriveLetter C).Size / 1GB )

"$type$m2$ram$dsk-$sig"
"(source: $src; mfr=$mf)"

function Sz($n) { $g = [math]::Pow(2, $n); if ($g -ge 1024) { '{0} TB' -f ($g / 1024) } else { '{0} GB' -f $g } }
$names = @{ DSK='desktop'; LAP='laptop'; TAB='tablet'; AIO='all-in-one'; MIN='mini PC'; SRV='server'; VIR='virtual machine' }
"$($names[$type]) | $mf | $(Sz $a.IndexOf($ram)) RAM | $(Sz $a.IndexOf($dsk)) C: | id $sig"

$name = "$type$m2$ram$dsk-$sig"
$taken = $false
if ($env:COMPUTERNAME -ne $name) {
    try { if (Resolve-DnsName $name -ErrorAction Stop) { $taken = $true } } catch {}
    if (-not $taken) { try { if (Test-Connection $name -Count 1 -Quiet -ErrorAction Stop) { $taken = $true } } catch {} }
}
if ($taken) { "WARNING: $name already answers on this network - possible duplicate or cloned machine." }
else { "dup check: $name not seen on the network" }
