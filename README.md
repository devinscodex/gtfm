# gtfm: Green Team Field Manual

Small PowerShell tools for Windows PCs. Each tool does one job. Each tool
runs with one line.

| Tool | Does | Changes the PC | Runs |
|---|---|---|---|
| [etch](#etch) | **E**tch **T**ags **C**omputers' **H**ostnames. A safe way to get a readable, unique hostname | No | ![](https://img.shields.io/github/downloads/devinscodex/gtfm/etch-v1.0.0/etch.ps1?label=runs&color=lightgrey) |
| [shed](#shed) (pre-release) | **S**hed **H**elps **E**mpty **D**isks. Frees disk space after a restore point and a health check | Yes, after you answer `y` | ![](https://img.shields.io/github/downloads/devinscodex/gtfm/shed-v0.9.0/shed.ps1?label=runs&color=lightgrey) |

## Rules

- A tool reads the PC and prints. It changes nothing unless its row above
  says so. A tool that changes the PC shows a plan first and asks.
- A tool sends no data off the PC. If a tool fails, it prints a report link.
  Nothing is sent unless you open the link and submit it.
- A tool runs on Windows PowerShell 5.1 and on PowerShell 7.
- Every run line points to a fixed release, so the file cannot change under
  you. Each release lists the SHA-256 of the file.
- Read a tool before you run it. Each tool has a read line. It shows the same
  file from the repository, and it does not add to the run count.

## etch

Etch **T**ags **C**omputers' **H**ostnames. Etch is a safe way to get a readable, unique hostname for a Windows PC.
It reads the PC and prints the name. It never renames anything.

    DSKASR6B-9SGCGT

The name comes from the hardware, not from a sticker. The same PC gets the
same name after a Windows reinstall.

### Run

    irm https://github.com/devinscodex/gtfm/releases/download/etch-v1.0.0/etch.ps1 | iex

### Read

    irm https://raw.githubusercontent.com/devinscodex/gtfm/etch-v1.0.0/etch.ps1 | more

### Read a name

    DSK  ASR  6  B  -  9SGCGT
    |    |    |  |     |
    |    |    |  |     ID: unique part
    |    |    |  C: drive size
    |    |    installed RAM
    |    maker of the board
    type of PC

| Part | Meaning |
|---|---|
| Type | `DSK` desktop, `LAP` laptop, `TAB` tablet, `AIO` all-in-one, `MIN` mini PC, `SRV` server, `VIR` virtual machine |
| Maker | `DEL` Dell, `HPI` HP, `LEN` Lenovo, `ASU` ASUS, `ASR` ASRock, `ACE` Acer, `MSI`, `GIG` Gigabyte, `MIC` Microsoft, `FRM` Framework, `APL` Apple, `SAM` Samsung, `TOS` Toshiba. Other makers use the first 3 letters. |
| RAM, C: | One character each. The size is 2^n GB. `4` is 16 GB, `6` is 64 GB, `9` is 512 GB, `A` is 1 TB, `B` is 2 TB. |
| ID | 6 characters. The SHA-256 of the BIOS serial, the UUID and the board serial. |

Only the ID makes the name unique. The type, maker and sizes are hints. They
go stale when you change the hardware. The ID does not.

### How it works

1. Etch reads the BIOS serial, the UUID and the board serial.
2. It drops junk values such as `Default string` or `To Be Filled By O.E.M.`
3. It hashes the good values together. If none are good, it uses the MAC
   address of the first network card.
4. It writes the first 30 bits of the hash as 6 characters. The alphabet has
   no `I`, `L`, `O` or `U`.
5. It asks the network if the name is in use. A warning means a clone or a
   duplicate.

The second line of output names the sources. `BIOS+UUID+Board` is the best
case. `MAC` means the PC has no good serial. Check it twice.

### Duplicates

A random duplicate is rare. With 1,000 PCs the chance is 0.047%. With 5,000
PCs it is 1.2%.

Cloned images are the real risk. A clone has the same serial as its source and
gets the same name. The duplicate check finds it only while both PCs are
online.

### Apply a name

Etch does not rename the PC. To do it yourself, run this in an elevated
shell, then restart:

    Rename-Computer -NewName "DSKASR6B-9SGCGT" -Force

### Limits

- The RAM and C: characters round to the next power of two.
- Soldered RAM and virtual disks can report odd sizes.
- Tested on one desktop and one laptop.

## shed

Shed **H**elps **E**mpty **D**isks. Shed frees disk space the Windows way. Shed is a **pre-release**. The file
clearing code has run on test files. The restore point and DISM steps have
not yet run end to end on a full PC. Read the plan before you answer `y`.

### Run

Open an elevated PowerShell. Any user can read the plan, but only an
administrator can remove.

    irm https://github.com/devinscodex/gtfm/releases/download/shed-v0.9.0/shed.ps1 | iex

### Read

    irm https://raw.githubusercontent.com/devinscodex/gtfm/shed-v0.9.0/shed.ps1 | more

### What it does

1. It prints a plan: each item and the space it frees.
2. It stops if a restart is pending or Windows Update is installing.
3. It asks `(y/N)`. The default is no.
4. It checks the component store with `DISM /CheckHealth`. If the store is
   damaged, it stops and changes nothing.
5. It takes a restore point and checks that a new one exists. If not, it
   stops and removes nothing.
6. It clears the items. It says what it clears and what it frees.
7. It runs `DISM /StartComponentCleanup`. This takes 5 to 30 minutes.
8. It prints PASS or FAIL for the restore point, the component store, the
   services, and the freed space.

### What it removes

Files over a day old in the user and Windows temp folders, the Windows Update
download cache, the Delivery Optimization cache, error reports, crash dumps,
the Recycle Bin, and unused component store files.

It never touches user documents, browser data or `Windows.old`. It reports the
size of `Windows.old` and points to Settings. Links are skipped and never
followed.

### Limits

- The DISM cleanup and the Recycle Bin cannot be undone. A restore point does
  not bring back deleted caches.
- The health check matches an English DISM message. On other languages it
  stops safely.
- Run it again after a restart if it reports a pending restart.

## Run counts

The badge counts downloads of the release file. A run adds one. A read does
not, because the read line uses the repository file. The count includes scans
and the author's own tests. It does not count unique users.

`stats/snapshot.sh` saves the counts with the date, so you can see the trend.

## License

MIT.
