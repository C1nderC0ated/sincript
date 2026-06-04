# Sincript

A single, menu-driven batch script (`PerfTweaks.cmd`) that applies a **curated, reversible** set of performance, privacy, and maintenance tweaks for **Windows 10 and Windows 11**.

Everything is opt-in from a menu, every registry change is backed up before it is made, and the script can create a System Restore Point and a full registry export on request. There is no silent "apply everything" — you choose what runs.

---

## Requirements

- Windows 10 or Windows 11 (tested on recent builds, including 24H2 / build 26100).
- Administrator rights. The script **auto-elevates**: when launched, it requests elevation through UAC and relaunches itself elevated. You only need to approve the UAC prompt.
- No installation, no dependencies. It is a single self-contained `.cmd` file.

## How to run

1. Place `PerfTweaks.cmd` anywhere (Desktop, a USB stick, etc.).
2. Double-click it (or right-click → *Run as administrator*).
3. Approve the UAC prompt.
4. Use the number keys to navigate the menu, then press `Enter`.

> **Recommended first step:** open **`8. Backups & status`** and create a **System Restore Point** and/or a **full registry backup** before applying anything.

---

## Menu overview

### Main menu
| # | Item | What it covers |
|---|------|----------------|
| 1 | Cleanup & repair | Temp/log cleanup, SFC/DISM, Windows Update reset, Store repair, WinSxS compaction |
| 2 | Performance tweaks | GameDVR off, game-task priorities, snappier UI timings |
| 3 | Privacy & telemetry | Telemetry, ad ID, Cortana/web search, location, feedback off |
| 4 | Power plan | High-performance / Ultimate plan, disable sleep & disk timeouts |
| 5 | Network & DNS | TCP tuning, DNS provider switch, full network stack reset |
| 6 | Apps & files | OpenAsar for Discord, Unity `boot.config`, custom `hosts` file, lightweight Steam launcher |
| 7 | Advanced | At-your-own-risk items: CPU mitigations, boot timers, NVMe flags, IPv6, memory compression, GPU telemetry |
| 8 | Backups & status | Restore point, full registry export, current-status report |
| 9 | Apply recommended safe set | One-click core tweaks from categories 1–5 (no prompts) |
| 10 | What was excluded | Explains what the script deliberately leaves out, and why |
| 0 | Exit | |

### Sub-menus
- **Cleanup & repair** — Disk cleanup · SFC + DISM repair · Windows Update reset · re-register Microsoft Store · compact WinSxS.
- **Network & DNS** — Apply TCP tweaks · DNS menu (Cloudflare, Google, Quad9, or back to automatic/DHCP) · reset network stack.
- **Apps & files** — Install OpenAsar · apply a Unity `boot.config` · apply a custom `hosts` blocklist · restore the original `hosts` · install **SteamLight** (a lightweight Steam launcher + Desktop shortcut).
- **Advanced** — Disable/enable CPU mitigations · set/revert boot (BCD) timers · NVMe feature flags · disable IPv6 · disable memory compression · disable GPU telemetry (NVIDIA / AMD aware).
- **Backups & status** — Create a System Restore Point · export HKLM + HKCU · show the current state of key tweaks, the active power plan, DNS, TCP settings, the `hosts` line count, and whether OpenAsar is installed.

---

## Safety & backups

The script is built around being undoable.

- **Per-value registry backups.** Before changing any registry value, the script saves a small `.reg` file containing **only that one value's previous state** to `Documents\PerfTweaks_Backups`. Double-click that `.reg` to put the value back. (It backs up just the value, not the whole key, so backups stay tiny — typically about 1 KB each.)
- **Full registry export** (optional) — exports all of `HKLM` and `HKCU` to `Documents\PerfTweaks_Backups`.
- **System Restore Point** (optional) — created on demand; `Apply recommended safe set` also offers to make one first.
- **Log file** — every action is logged to `Documents\PerfTweaks_Backups\PerfTweaks_<random>.log`.

All backups and logs live in **`Documents\PerfTweaks_Backups`** — a `PerfTweaks_Backups` folder inside your user **Documents** folder. The script auto-detects the real Documents path (including OneDrive-redirected Documents) and falls back to `%USERPROFILE%\Documents` if needed.

## Reverting changes

| Change | How to undo |
|--------|-------------|
| Any single registry tweak | Double-click its `.reg` backup in `Documents\PerfTweaks_Backups` |
| CPU mitigations | Advanced → **Enable mitigations** |
| Boot (BCD) timers | Advanced → **Revert BCD timers** |
| DNS | Network → DNS → **Automatic (DHCP)** |
| Custom `hosts` | Apps & files → **Restore hosts** |
| Memory compression | PowerShell: `Enable-MMAgent -MemoryCompression` |
| Everything at once | Roll back to the **System Restore Point**, or import the **full registry backup** |

---

## Optional bundled files

Some actions can use files placed **next to `PerfTweaks.cmd`**. They are optional:

- **`app.asar`** — an OpenAsar build for the Discord action. If it isn't present, the script offers to download the latest nightly from the official OpenAsar GitHub releases.
- **`boot.config`** — a Unity engine boot configuration applied to a game's `*_Data` folder.
- **`hosts`** — an ad/telemetry blocklist that the "apply hosts" action installs (the original is backed up first).

**SteamLight** does not require a bundled file. The *Apps & files → Install SteamLight* action finds your Steam folder via the registry, writes a `SteamLight.bat` launcher **into that folder**, and adds a `SteamLight` shortcut to your Desktop. The launcher starts Steam with resource-saving flags (single process / single core, no shaders, no shared textures, no Big Picture, high-DPI off, etc.) for lower RAM/CPU use. It references `steam.exe` relative to its own folder, so it keeps working even if Steam is installed on another drive. To change the flags, edit the single `_SLFLAGS=` line in the script.

---

## Recent changes

### Backup location moved to Documents

Backups and logs are now created in **`Documents\PerfTweaks_Backups`** (inside your user Documents folder) instead of the drive root (`C:\PerfTweaks_Backups`). The script resolves the real Documents path from the registry, so it also works when Documents is redirected to OneDrive, and falls back to `%USERPROFILE%\Documents` if that lookup fails.

### Console compatibility (Windows 10 / Server 2022)

Users on Windows 10 and Windows Server 2022 reported a cluttered menu where every `echo` and `set` command was printed before its output. That happened when `@echo off` did not take effect — most often because the script was saved with a **UTF-8 BOM**, which legacy `cmd.exe` mishandles.

Fixes in the current `PerfTweaks.cmd`:

- File is **ASCII-only, no BOM** (safe encoding for `.cmd` on all supported Windows versions).
- Redundant `echo off` guard at startup.
- UAC relaunch sets **`-WorkingDirectory`** to the script folder and runs **`cd /d "%~dp0"`** so the console prompt is not stuck in `System32`.
- **`mode`** / **`color`** errors are suppressed on narrow or restricted consoles (e.g. Server Core).
- The header logo uses **ASCII art** instead of Unicode box-drawing characters (which break on CP437 consoles).

### Unity `boot.config` — CPU-aware apply

The *Apps & files → Place Unity boot.config* action no longer copies the template verbatim. It now:

1. Detects physical core count (PowerShell CIM, then WMIC, then `%NUMBER_OF_PROCESSORS%`, then a manual prompt if detection fails).
2. Sets **`job-worker-count`** and **`job-worker-maximum-count`** to **cores − 1** (min 1, max 32) before copying into the game's `*_Data` folder.
3. Shows the detected CPU info and chosen worker count before asking for the game path.

The bundled `boot.config` values for those keys are placeholders; they are always overwritten at apply time.

### Bundled-file error handling

If **`boot.config`** or **`hosts`** is missing or empty next to `PerfTweaks.cmd`, the script stops with a clear message: expected path, what the file is for, and how to fix it (copy from the Sincript package). Copy failures for Unity paths or the system `hosts` file also report actionable causes (permissions, AV tamper protection, game still running).

---

## Notes & caveats

- **Run as administrator.** HKLM changes, services, scheduled tasks, BCD edits, and restore points all need elevation. The script elevates itself; just approve UAC.
- **Backups go to your Documents.** They are written under the account that is elevated. On a normal single-admin PC (UAC consent prompt) that is your own Documents folder; if you elevate with a *different* administrator account, the backups land in that account's Documents instead.
- **A reboot is recommended** after several tweaks (memory compression, mitigations, NVMe flags, boot timers) for them to fully take effect.
- **Brief minimized windows.** Some actions (DNS, Store re-register, OpenAsar download, restore point, the status screen) run PowerShell in a short-lived minimized window so the main window's font/colors are not disturbed. The flicker is normal.
- **The "Advanced" menu is genuinely advanced.** A few highlights:
  - *Disable CPU mitigations* trades security hardening (Spectre/Meltdown-class) for speed. Only do this on a machine where you understand the trade-off.
  - *NVMe feature flags* may be blocked by Microsoft on fully-patched systems; the script tells you so.
  - *Disable memory compression* frees a little CPU but increases RAM pressure on low-memory PCs.
- **Opt-in only.** Riskier items such as disabling mitigations and enabling `LargeSystemCache` are never part of the "recommended safe set" — you must select them yourself.
- **Console appearance.** The script uses a magenta theme and shows a small "SIN" logo. It runs in your default console font (Consolas on most systems) and does not change any system-wide console, scaling, or registry settings beyond the tweaks you choose.

## "What was excluded" — the philosophy

The in-app **`10. What was excluded`** screen lists, by category, the popular "tweaks" this script intentionally omits — for example security-weakening changes (disabling Defender, the firewall, UAC, or SmartScreen), placebo or obsolete registry values, firewall rules that block Google/YouTube IP ranges, hard-coded MTU values, and bulk undocumented GPU dumps. Read it to understand the safety rationale.

---

## Disclaimer

Use at your own risk. These tweaks modify system settings; while the script backs up each change and can create a restore point, you are responsible for your system. **Make a restore point and/or a full registry backup first** (the script provides both). Sincript is an independent utility and is not affiliated with or endorsed by Microsoft, NVIDIA, AMD, Discord, or any other vendor mentioned.
