# gtfm: Green Team Field Manual

Small PowerShell tools for Windows PCs. One job each. One line to run.

| Tool | Meaning | Changes PC | Runs |
|---|---|---|---|
| [etch](#etch) | **E**tch **T**ags **C**omputers' **H**ostnames | No | ![](https://img.shields.io/github/downloads/devinscodex/gtfm/etch-v1.0.0/etch.ps1?label=runs&color=lightgrey) |
| [shed](#shed) (pre-release) | **S**hed **H**elps **E**mpty **D**isks | Yes, after `y` | ![](https://img.shields.io/github/downloads/devinscodex/gtfm/shed-v0.9.0/shed.ps1?label=runs&color=lightgrey) |

## Rules

- Tool reads and prints. Tool that changes the PC shows a plan first and asks.
- Tool sends no data off the PC. On failure, it prints a report link. Nothing
  leaves unless you open the link and submit.
- Windows PowerShell 5.1 and PowerShell 7.
- Run line points to a fixed release. File cannot change under you. Release
  notes list the SHA-256.
- Read before you run. Each tool links its file below. A read does not add to
  the run count.

## etch

Prints a stable, readable name for this PC. Never renames. Same PC, same name,
also after a Windows reinstall. [Read etch.ps1](https://raw.githubusercontent.com/devinscodex/gtfm/etch-v1.0.0/etch.ps1)

    irm https://github.com/devinscodex/gtfm/releases/download/etch-v1.0.0/etch.ps1 | iex

Name = TYPE MAKER RAM DISK - SIGNATURE. Example: `DSKASR6B-9SGCGT`.

| Part | Meaning |
|---|---|
| TYPE | `DSK` desktop, `LAP` laptop, `TAB` tablet, `AIO` all-in-one, `MIN` mini PC, `SRV` server, `VIR` virtual machine |
| MAKER | `DEL` Dell, `HPI` HP, `LEN` Lenovo, `ASU` ASUS, `ASR` ASRock, `ACE` Acer, `MSI`, `GIG` Gigabyte, `MIC` Microsoft, `FRM` Framework, `APL` Apple, `SAM` Samsung, `TOS` Toshiba. Others: first 3 letters. |
| RAM | Installed RAM as 2^n GB. `4` = 16 GB, `6` = 64 GB, `7` = 128 GB. |
| DISK | Size of C: as 2^n GB, rounded up. `9` = 512 GB, `A` = 1 TB, `B` = 2 TB. |
| SIGNATURE | 6 characters of the SHA-256 of the BIOS serial, UUID and board serial. No `I`, `L`, `O`, `U`. |

Only the SIGNATURE is unique. Other parts are hints. They go stale after a
hardware change. The SIGNATURE does not.

How it works:

1. Read BIOS serial, UUID, board serial.
2. Drop junk such as `Default string` or `To Be Filled By O.E.M.`
3. Hash the good values. If none are good, use the MAC of the first network card.
4. Write the first 30 bits as 6 characters.
5. Ask the network if the name is in use. A hit means a clone or duplicate.

Output line 2 names the sources. `BIOS+UUID+Board` is best. `MAC` means no good
serial. Check twice.

Limits:

- Chance of a random duplicate: 0.047% at 1,000 PCs, 1.2% at 5,000.
- Cloned images are the real risk. A clone has the same serial and the same
  name. The duplicate check sees it only while both PCs are online.
- RAM and DISK round to a power of two. Soldered RAM and virtual disks can
  report odd sizes.
- To apply a name, run `Rename-Computer -NewName "<name>" -Force` in an
  elevated shell. Then restart.
- Tested on one desktop and one laptop.

## shed

Frees disk space the Windows way. **Pre-release.** The file-clearing code ran
on test files. The restore point and DISM steps have not yet run end to end on
a full PC. Read the plan before you answer `y`.
[Read shed.ps1](https://raw.githubusercontent.com/devinscodex/gtfm/shed-v0.9.0/shed.ps1)

Open an elevated PowerShell. Any user can see the plan. Only an administrator
can remove.

    irm https://github.com/devinscodex/gtfm/releases/download/shed-v0.9.0/shed.ps1 | iex

Steps:

1. Print the plan: each item and the space it frees.
2. Stop if a restart is pending or Windows Update is installing.
3. Ask `(y/N)`. Default is no.
4. Run `DISM /CheckHealth`. If the component store is damaged, stop. Nothing
   changed.
5. Take a restore point. Check that a new one exists. If not, stop. Nothing
   removed.
6. Clear the items. Print what it clears and what it frees.
7. Run `DISM /StartComponentCleanup`. Takes 5 to 30 minutes.
8. Print PASS or FAIL: restore point, component store, services, freed space.

Removes: files over a day old in the user and Windows temp folders, Windows
Update download cache, Delivery Optimization cache, error reports, crash dumps,
Recycle Bin, unused component store files.

Never touches: user documents, browser data, `Windows.old`. It reports the size
of `Windows.old` and points to Settings. It skips links.

Limits:

- DISM cleanup and Recycle Bin cannot be undone. A restore point does not
  bring back deleted caches.
- The health check matches an English DISM message. On other languages it
  stops, safely.
- Pending restart: restart, then run again.

## Run counts

Badge = downloads of the release file. A run adds one. A read does not.
Includes scans and the author's tests. Not unique users.
`stats/snapshot.sh` saves the counts with the date, for trends.

## License

MIT.
