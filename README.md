# Sincript

<img width="178" height="97" alt="{4166AFF4-89CF-41C6-84E0-CC0A51EE1796}" src="https://github.com/user-attachments/assets/92274647-6952-4a5b-a115-0fe5c40d10f2" />

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
| 2 | Performance tweaks | GameDVR off, game-task priorities, snappier UI timings, optional Game Mode / mouse-acceleration / file-extensions toggles |
| 3 | Privacy & telemetry | Telemetry, ad ID, Cortana/web search, location, activity history, feedback off |
| 4 | Power plan | High-performance / Ultimate plan, disable sleep & disk timeouts, optional 5% min processor state |
| 5 | Network & DNS | TCP tuning, DNS provider switch, full network stack reset |
| 6 | Apps & files | OpenAsar for Discord, Unity `boot.config`, custom `hosts` file, lightweight Steam launcher, Windows timer resolution |
| 7 | Advanced | At-your-own-risk items: CPU mitigations, boot timers, NVMe flags, IPv6, memory compression, GPU telemetry |
| 8 | Backups & status | Restore point, full registry export, current-status report |
| 9 | Apply recommended safe set | One-click core tweaks from categories 1–5 (no prompts) |
| 10 | Presets | Auto-apply **light / moderate / heavy** preset, build your own **custom** preset, or restore a preset's JSON backup |
| 11 | What was excluded | Explains what the script deliberately leaves out, and why |
| 0 | Exit | |

### Sub-menus
- **Cleanup & repair** — Disk cleanup · SFC + DISM repair · Windows Update reset · re-register Microsoft Store · compact WinSxS.
- **Network & DNS** — Apply TCP tweaks · DNS menu (Cloudflare, Google, Quad9, or back to automatic/DHCP) · reset network stack.
- **Apps & files** — Install OpenAsar · apply a Unity `boot.config` · apply a custom `hosts` blocklist · restore the original `hosts` · install **SteamLight** (a lightweight Steam launcher + Desktop shortcut) · apply or remove a higher **timer resolution** (SetTimerResolution autostart) · remove built-in Store apps (**debloat**).
- **Advanced** — Disable/enable CPU mitigations · set/revert boot (BCD) timers · NVMe feature flags · disable IPv6 · disable memory compression · disable GPU telemetry (NVIDIA telemetry tasks + registry, or the AMD User Experience Program opt-out) · GPU hardware scheduling (HAGS) on/off.
- **Presets** — Apply a built-in **light**, **moderate**, or **heavy** preset (no per-item prompts) · apply a **custom** preset from a `.preset` file · **restore** the registry values a preset changed from one of its JSON backups.
- **Backups & status** — Create a System Restore Point · export HKLM + HKCU · restore from a preset JSON backup · show the current state of key tweaks, the active power plan, hibernation, minimum processor state, DNS, TCP autotuning, GPU hardware scheduling (HAGS), memory compression, the `hosts` line count, and whether OpenAsar is installed.

---

## Presets

**`10. Presets`** applies a whole bundle of tweaks in one go, with **no per-item prompts** (a couple of yes/no questions only — restore point, and DNS choice where relevant). There are three built-in presets plus your own custom presets.

| Preset | What it applies | DNS |
|--------|-----------------|-----|
| **Light** | Cleanup core (temp/log cleanup, DNS flush), privacy/telemetry core, network core (TCP autotuning, RSS/RSC). Nothing risky. | Asks (Cloudflare / Google / Quad9 / skip) |
| **Moderate** | The full **recommended safe set** (cleanup + privacy + performance + power + network cores) — same as menu item 9. Optionally installs OpenAsar (uses a bundled `app.asar` if present, otherwise downloads the latest nightly). | — (uses the safe set; DNS unchanged) |
| **Heavy** | Everything in the safe set **plus** foreground/latency tuning: `SystemResponsiveness = 0`, network throttling off, `Win32PrioritySeparation = 42`, Game Mode off, Nagle off, IPv6 off, NVMe flags, GPU telemetry off, BCD timers, memory compression off. | Asks (Cloudflare / Google / Quad9 / skip) |

**Heavy deliberately does *not* include** CPU-mitigation changes, network-stack reset, system repair (SFC/DISM), debloat, `LargeSystemCache`, or the timer-resolution autostart — those stay manual under their own menus. Heavy shows a warning and offers a restore point first.

### Preset backups (JSON)

Manual menu actions each write their own tiny `.reg` backup. **Presets are different:** every registry value a preset changes is recorded into **one JSON file** in `Documents\PerfTweaks_Backups`, named `Preset_<name>_<random>.json`. The script prints the exact path when the preset finishes.

To put those registry values back, use **`8. Backups & status → 4. Restore from a preset backup (JSON)`** (also reachable from the Presets menu). It reads the JSON and, for each value, either restores the previous data or deletes the value if it didn't exist before.

> The JSON backup covers **registry values only**. The non-registry parts of a preset — power plan, DNS, BCD timers, services/scheduled tasks — are reverted from their own menus (see the *Reverting changes* table). A System Restore Point (offered before moderate/heavy) rolls back everything at once.

## Custom presets

You can define your own preset as a small text file and have the script apply it.

1. Create a folder named **`sincript_presets`** next to `PerfTweaks.cmd`.
2. Put a text file in it ending in **`.preset`** (e.g. `mypreset.preset`). A ready-to-edit **`example.preset`** ships with Sincript.
3. Run **`10. Presets → 4. Custom preset`**, pick your file from the list, review the summary, and confirm.

### File format

- One directive per line, written as **`key=value`**.
- **No spaces around the `=`** (`cleanup=1`, not `cleanup = 1`).
- Start each directive in **column 1** (no leading spaces).
- A line beginning with **`#`** or **`;`** is a comment and is ignored.
- **Inline comments are not supported** — don't put `# note` after a value; put comments on their own lines.

### Keys

| Key | Value | Effect |
|-----|-------|--------|
| `cleanup` | `1` | Cleanup core (temp/log cleanup, DNS flush) |
| `privacy` | `1` | Privacy/telemetry core |
| `performance` | `1` | Performance core (GameDVR off, game-task priorities, UI timings) |
| `power` | `1` | Power core (Ultimate/High plan, no sleep/disk timeouts) |
| `network` | `1` | Network core (TCP autotuning, RSS/RSC) |
| `openasar` | `1` | Install OpenAsar silently (bundled `app.asar` if present, otherwise downloads the latest nightly) |
| `gamemode_off` | `1` | Disable Windows Game Mode |
| `systemresponsiveness` | `0` | `SystemResponsiveness = 0` (favor foreground) |
| `networkthrottling_off` | `1` | Network throttling off (`0xFFFFFFFF`) |
| `largesystemcache` | `1` | Enable `LargeSystemCache` *(situational; can hurt on desktops)* |
| `minprocstate5` | `1` | Minimum processor state 5% |
| `bcdtimers` | `1` | BCD timer set (`useplatformclock` off, `useplatformtick`/`disabledynamictick` on, TSC enhanced) |
| `ipv6_off` | `1` | Disable IPv6 (`DisabledComponents = 0xFF`) |
| `memcompress_off` | `1` | Disable memory compression *(raises RAM pressure on low-memory PCs)* |
| `nvme_flags` | `1` | NVMe feature flags *(may be blocked on fully-patched Windows)* |
| `gpu_telemetry_off` | `1` | Disable GPU telemetry (NVIDIA tasks + opt-out; opt-out on AMD) |
| `nagle_off` | `1` | Disable Nagle on all interfaces (`TcpAckFrequency` / `TCPNoDelay`) |
| `win32priority` | `42`, `26` or `2` | `Win32PrioritySeparation` — `42` = short fixed quantum (strong foreground), `26` = short variable quantum (strong foreground) `2` = Windows default |
| `dns` | `cloudflare`, `google`, or `quad9` | Set DNS on all active adapters |

Keys not listed here (and `1`-keys given any value other than the one shown) are **rejected**.

### What happens with a bad file

The script validates the whole file first and shows a summary: how many directives it recognized and how many problems it found. Each problem is listed (`unknown key`, or `bad value … (expected …)`). Then:

- **Some valid, some bad** → it reports the problems and asks whether to apply the valid ones anyway.
- **Nothing valid** → it aborts without changing anything and points you back to this key list.

Like the built-in presets, a custom preset writes a single JSON registry backup you can restore from the Backups menu.

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
| Timer resolution | Apps & files → **Remove timer resolution** |
| Windows Game Mode | Settings → Gaming → Game Mode (or merge the value backup) |
| Minimum processor state | Control Panel → power plan → set back to 100% |
| Removed built-in apps (debloat) | Reinstall from the Microsoft Store |
| Memory compression | PowerShell: `Enable-MMAgent -MemoryCompression` |
| Registry values changed by a preset | Backups & status → **Restore from a preset backup (JSON)** (or run the relevant menu item to reverse it) |
| Everything at once | Roll back to the **System Restore Point**, or import the **full registry backup** |

---

## Optional bundled files

Some actions can use files placed **next to `PerfTweaks.cmd`**. They are optional:

- **`app.asar`** — an OpenAsar build for the Discord action. If it isn't present, the script offers to download the latest nightly from the official OpenAsar GitHub releases (https://github.com/GooseMod/OpenAsar).
- **`boot.config`** — a Unity engine boot configuration applied to a game's `*_Data` folder.
- **`hosts`** — an ad/telemetry blocklist that the "apply hosts" action installs (the original is backed up first).
- **`SetTimerResolution.exe`** — the timer-resolution helper from [valleyofdoom/TimerResolution](https://github.com/valleyofdoom/TimerResolution). *Apps & files → Apply timer resolution* copies it to `C:\ProgramData\Sincript`, registers a hidden logon task that holds your chosen resolution, and (on Windows 10 2004+/11) sets the registry switch that makes the change system-wide.

**SteamLight** does not require a bundled file. The *Apps & files → Install SteamLight* action finds your Steam folder via the registry, writes a `SteamLight.bat` launcher **into that folder**, and adds a `SteamLight` shortcut to your Desktop. The launcher starts Steam with resource-saving flags (single process / single core, no shaders, no shared textures, no Big Picture, high-DPI off, etc.) for lower RAM/CPU use. It references `steam.exe` relative to its own folder, so it keeps working even if Steam is installed on another drive. To change the flags, edit the single `_SLFLAGS=` line in the script.

---

## Recent changes

### Reversibility fixes + a few WinUtil-style tweaks

Two registry tweaks that were previously applied without a backup are now routed through the same backup path as everything else: **Nagle / delayed-ACK** disabling from the **Network** menu (it was already backed up when applied via a preset — now the menu path matches), and the optional **per-user sync services** disable in **Privacy**. Both are now captured in the `.reg` / preset-JSON backups and restore cleanly. The internal status-display helper was also hardened so a registry value containing `>` can never be misread as a redirection.

Inspired by Chris Titus Tech's WinUtil, three safe, reversible items were added: **Performance** gained optional *disable mouse acceleration / Enhance pointer precision* (raw 1:1 mouse — popular for gaming; applies after sign out/in) and *show file extensions in Explorer*; and the privacy set now fully disables **Activity History** (`PublishUserActivities` / `UploadUserActivities` in addition to the activity feed). As always, these are opt-in and backed up.

### GPU hardware scheduling (HAGS) toggle

**Advanced → GPU hardware scheduling (HAGS)** is a new two-way toggle that sets `HwSchMode` in `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` to **1 (off)** or **2 (on, the Windows default)**, with the previous value backed up so the change stays reversible. It takes effect after a reboot, needs Windows 10 2004+ and a GPU/driver that supports HAGS (older GPUs simply ignore it), and the on/off difference is usually small and system-specific — turning it off can help some capture/overlay stutter, but disables features that require it on, notably NVIDIA Frame Generation (DLSS 3). It is deliberately kept out of the auto-apply presets because it is a measure-it-yourself tradeoff rather than a guaranteed win. The status screen reflects the current value and points to this toggle.

### AMD telemetry opt-out

The **Advanced → GPU telemetry** option (and the `gpu_telemetry_off` preset key) previously did nothing on AMD systems — it only handled NVIDIA. It now also opts you out of the **AMD User Experience Program** (AMD's usage-data / telemetry collection) by writing the opt-out to the registry under `HKLM\SOFTWARE\AMD\CN`, with the previous value saved to a backup so the change stays reversible. Because AMD does not expose a single guaranteed registry switch across driver versions, the screen also points you to **AMD Software → Settings → Preferences**, where you can confirm that **AMD User Experience Program**, **AMD Image Inspector** and **Game Adjustment Tracking and Notifications** are off.

### Status report expanded, and made language-independent

The **Backups & status → Show current status** screen now also reports **hibernation**, **minimum processor state**, **GPU hardware scheduling (HAGS)** and **memory compression**, alongside the existing power plan, DNS, key registry tweaks, TCP autotuning, `hosts` line count and OpenAsar detection. All of these are **read-only** — the screen never changes anything.

These status lines (and the DNS apply/reset actions) no longer rely on English text in Windows' command output, so they work correctly on **localized Windows, including Cyrillic (Russian)** systems. Power plan, hibernation and HAGS are read from the registry; minimum processor state reads the active power scheme's stored value; TCP global settings are read with `netsh` and filtered on the universal `:` separator (not English labels), which also avoids `Get-NetTCPSetting` failing on systems whose `MSFT_NetTCPSetting` WMI class is missing; and DNS is now applied to all physical adapters (active ones take effect, the rest are skipped) instead of filtering on a localized “Up” status string.

### Presets, custom presets, and JSON backups

A new **`10. Presets`** menu applies tweaks in bundles instead of one screen at a time. Three built-in presets — **light**, **moderate**, and **heavy** — run with no per-item prompts (just a restore-point and DNS yes/no where relevant); see the *Presets* section above for exactly what each one changes and what heavy deliberately leaves out. You can also write your own **custom preset** as a `key=value` text file in a `sincript_presets\` folder (a sample `example.preset` is included) and apply it from the same menu; the script validates the file, reports any unknown keys or bad values, and asks before applying. Unlike the per-action `.reg` backups, **every registry value a preset changes is saved into a single JSON file** in `Documents\PerfTweaks_Backups`, and a new **Backups → Restore from a preset backup (JSON)** action puts those values back. (The main menu's *What was excluded* screen moved from item 10 to **item 11** to make room.)

### Console-font fix for two more PowerShell calls

All PowerShell in Sincript now runs in a short-lived **minimized window** so it can't disturb the main console's font or colors. Two spots that still called PowerShell inline were switched to that pattern: the **CPU core detection** used by the Unity `boot.config` action, and the **`boot.config` rewrite** step itself (its input/output paths are now passed via environment variables so spaces or quotes can't break the command, and its exit code is read back reliably).

### Tweaks adopted from a community optimization guide

After reviewing a widely-shared Windows 11 gaming optimization guide, a few safe, scriptable items were folded in — all opt-in and reversible. The **BCD timer** action now also sets `useplatformtick yes` to match the guide’s recommended timer combo. **Power plan** gained an optional *minimum processor state = 5%* (lets the CPU idle down to save power with no FPS loss). **Performance** gained an optional *disable Windows Game Mode* toggle (contested — some titles run smoother without it, but Microsoft says it can help, so try both). And **Apps & files** gained a *debloat* action that removes built-in Store apps in opt-in groups (standard bloat; optional apps like Camera / Snipping Tool; OneDrive) — anything removed is reinstallable from the Microsoft Store. Manual or external-tool steps from that guide (driver installs, NVIDIA control-panel values, RTSS frame caps, ISLC, third-party antivirus, activation scripts) were intentionally left out, and the *What was excluded* screen now explains why.

### Timer resolution (SetTimerResolution)

*Apps & files → Apply timer resolution* installs the bundled `SetTimerResolution.exe` as a hidden logon task (Task Scheduler) that raises the Windows timer resolution and holds it. You pick the resolution in 100ns units (default `5000` = 0.5 ms). On Windows 10 2004+ / 11 it also sets `GlobalTimerResolutionRequests = 1` under `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel`, so the change applies system-wide rather than only to the helper process — that part needs a **reboot**. *Remove timer resolution* deletes the task, stops the helper, removes the copied file, and can revert the registry switch.

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

1. Detects the **logical processor** (thread) count (PowerShell CIM, then WMIC, then `%NUMBER_OF_PROCESSORS%`, then a manual prompt if detection fails).
2. Sets **`job-worker-count`** and **`job-worker-maximum-count`** to **logical processors − 1** (min 1, max 32) before copying into the game's `*_Data` folder.
3. Shows the detected CPU info and chosen worker count before asking for the game path.

The bundled `boot.config` values for those keys are placeholders; they are always overwritten at apply time.

### Bundled-file error handling

If **`boot.config`** or **`hosts`** is missing or empty next to `PerfTweaks.cmd`, the script stops with a clear message: expected path, what the file is for, and how to fix it (copy from the Sincript package). Copy failures for Unity paths or the system `hosts` file also report actionable causes (permissions, AV tamper protection, game still running).

---

## Notes & caveats

- **Run as administrator.** HKLM changes, services, scheduled tasks, BCD edits, and restore points all need elevation. The script elevates itself; just approve UAC.
- **Backups go to your Documents.** They are written under the account that is elevated. On a normal single-admin PC (UAC consent prompt) that is your own Documents folder; if you elevate with a *different* administrator account, the backups land in that account's Documents instead.
- **A reboot is recommended** after several tweaks (memory compression, mitigations, NVMe flags, boot timers, timer resolution) for them to fully take effect.
- **Brief minimized windows.** Some actions (DNS, Store re-register, OpenAsar download, restore point, the status screen) run PowerShell in a short-lived minimized window so the main window's font/colors are not disturbed. The flicker is normal.
- **The "Advanced" menu is genuinely advanced.** A few highlights:
  - *Disable CPU mitigations* trades security hardening (Spectre/Meltdown-class) for speed. Only do this on a machine where you understand the trade-off.
  - *NVMe feature flags* may be blocked by Microsoft on fully-patched systems; the script tells you so.
  - *Disable memory compression* frees a little CPU but increases RAM pressure on low-memory PCs.
- **Opt-in only.** Riskier items such as disabling mitigations and enabling `LargeSystemCache` are never part of the "recommended safe set" — you must select them yourself.
- **Console appearance.** The script uses a magenta theme and shows a small "SIN" logo. It runs in your default console font (Consolas on most systems) and does not change any system-wide console, scaling, or registry settings beyond the tweaks you choose.

## "What was excluded" — the philosophy

The in-app **`11. What was excluded`** screen lists, by category, the popular "tweaks" this script intentionally omits — for example security-weakening changes (disabling Defender, the firewall, UAC, or SmartScreen), placebo or obsolete registry values, firewall rules that block Google/YouTube IP ranges, hard-coded MTU values, and bulk undocumented GPU dumps. It also covers items from popular gaming guides that are deliberately skipped — Windows activation scripts, replacing Defender with a third-party antivirus, aggressive RAM / standby “cleaners”, and forcing MSI mode or NIC parameter edits (which the experienced guides themselves advise against). Read it to understand the safety rationale.

---

## Disclaimer

Use at your own risk. These tweaks modify system settings; while the script backs up each change and can create a restore point, you are responsible for your system. **Make a restore point and/or a full registry backup first** (the script provides both). Sincript is an independent utility and is not affiliated with or endorsed by Microsoft, NVIDIA, AMD, Discord, or any other vendor mentioned.
