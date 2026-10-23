# gtfm: Green Team Field Manual

Small PowerShell tools for Windows PCs. Each tool does one job. Each tool
runs with one line.

| Tool | Does | Changes the PC | Runs |
|---|---|---|---|
| [etch](#etch) | Prints a stable name for the PC | No | ![](https://img.shields.io/github/downloads/devinscodex/gtfm/etch-v1.0.0/etch.ps1?label=runs&color=lightgrey) |

## Rules

- A tool reads the PC and prints. It never changes anything unless its name
  says so.
- A tool sends no data off the PC.
- A tool runs on Windows PowerShell 5.1 and on PowerShell 7.
- Every run line points to a fixed release, so the file cannot change under
  you. Each release lists the SHA-256 of the file.
- Read a tool before you run it. Replace `iex` with `more` in the run line.

## etch

Etch prints a stable name for a Windows PC.

    DSKASR6B-9SGCGT

The name comes from the hardware, not from a sticker. The same PC gets the
same name after a Windows reinstall.

### Run

    irm https://github.com/devinscodex/gtfm/releases/download/etch-v1.0.0/etch.ps1 | iex

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

## Run counts

The badge counts downloads of the release file. It counts every download,
including scans and the author's own tests. It does not count unique users.

## License

MIT.
