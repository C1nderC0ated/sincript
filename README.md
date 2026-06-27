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
| 8 | Backups & status | Restore point, full registry export, current-status report, single-value `.reg` restore, backup-folder manager |
| 9 | Apply recommended safe set | One-click core tweaks from categories 1–5 (no prompts) |
| 10 | Presets | Auto-apply **light / moderate / heavy** preset, build your own **custom** preset, or restore a preset's JSON backup |
| 11 | What was excluded | Explains what the script deliberately leaves out, and why |
| 0 | Exit | |

### Sub-menus
- **Cleanup & repair** — Disk cleanup · SFC + DISM repair · Windows Update reset · re-register Microsoft Store · compact WinSxS.
- **Network & DNS** — Apply TCP tweaks · DNS menu (Cloudflare, Google, Quad9, or back to automatic/DHCP) · reset network stack.
- **Apps & files** — Install OpenAsar · apply a Unity `boot.config` · apply a custom `hosts` blocklist · restore the original `hosts` · install **SteamLight** (a lightweight Steam launcher + Desktop shortcut) · apply or remove a higher **timer resolution** (SetTimerResolution autostart) · remove built-in Store apps (**debloat**).
- **Advanced** — Disable/enable CPU mitigations · set/revert boot (BCD) timers · NVMe feature flags · disable IPv6 · disable memory compression · disable GPU telemetry (NVIDIA telemetry tasks + registry, or the AMD User Experience Program opt-out) · GPU hardware scheduling (HAGS) on/off · set a permanent per-program CPU priority (per `.exe`, via Image File Execution Options).
- **Presets** — Apply a built-in **light**, **moderate**, or **heavy** preset (no per-item prompts) · apply a **custom** preset from a `.preset` file · **restore** the registry values a preset changed from one of its JSON backups.
- **Backups & status** — Create a System Restore Point · export HKLM + HKCU · restore from a preset JSON backup · restore a single value backup (`.reg`) · manage / open the backup folder · show the current state of key tweaks, the active power plan, hibernation, minimum processor state, DNS, TCP autotuning, GPU hardware scheduling (HAGS), memory compression, the `hosts` line count, and whether OpenAsar is installed.

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
| `win32priority` | `42`, `26` or `2` | `Win32PrioritySeparation` — `42` = short fixed quantum (strong foreground), `26` = short variable quantum (strong foreground), `2` = Windows default |
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
| Any single registry tweak | Double-click its `.reg` backup in `Documents\PerfTweaks_Backups`, or use Backups & status → **Restore a single value backup (.reg)** |
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

Newest first. Feature details live in the sections above — this is just what changed.

- **Backup-folder manager (Backups & status).** New *Manage / open backup folder* item shows a per-category summary of `Documents\PerfTweaks_Backups` (how many per-value `.reg` undo files, full `HKLM`/`HKCU` exports and roughly how many MB they occupy, preset JSONs, hosts backups and logs), opens the folder in Explorer on request, and offers a safe one-shot prune of the **older full-registry exports** while always keeping the newest pair. The small per-value `.reg` backups and preset JSONs - the precise undo data - are never deleted. This reclaims the disk space those large exports accumulate without weakening reversibility.
- **In-app single-value restore (Backups & status).** New *Restore a single value backup (.reg)* item lists the small per-value `.reg` backups the script writes before each registry tweak (newest first) and re-imports the one you pick — logged, and reversing a single manual change no longer means leaving the tool to double-click in Explorer. It reads the same backups as before; full-registry exports (`FullReg_*.reg`) are filtered out of the list and stay a manual import. The companion *Restore from a preset backup (JSON)* item (for preset changes) is unchanged.
- **Per-app CPU priority (Advanced).** New *Set permanent process priority* item pins a per-`.exe` priority (High / Above normal / Normal / Below normal / Low) via Image File Execution Options (`CpuPriorityClass`), which Windows re-applies on every launch — backed up and reversible, with a *Remove override* option. Target the .exe that actually runs (Task Manager → Details), since High / Above-normal don't pass to child processes; Realtime is intentionally not offered.
- **Reversibility + WinUtil tweaks.** Nagle (Network menu) and the per-user sync-services disable (Privacy) are now backed up like everything else, and the status helper is hardened against a `>` in registry data. Added three opt-in items: disable mouse acceleration / Enhance pointer precision, show file extensions, and full **Activity History** off (`PublishUserActivities` / `UploadUserActivities`).
- **GPU hardware scheduling (HAGS).** New Advanced two-way toggle for `HwSchMode` (on/off, reversible). Needs a reboot and Windows 10 2004+ with a supporting GPU; turning it off disables features that need it on (e.g. NVIDIA DLSS 3 Frame Generation), so it is kept out of the presets.
- **AMD telemetry opt-out.** The GPU-telemetry action and `gpu_telemetry_off` key now also opt out of the **AMD User Experience Program** (registry, backed up), and the screen points to AMD Software → Preferences to confirm. Previously these did nothing on AMD.
- **Status screen + localization.** The status screen adds hibernation, minimum processor state, HAGS and memory compression (all read-only). It — and the DNS apply/reset actions — no longer depend on English text in command output, so they work on localized (incl. Cyrillic) Windows: registry and cmdlet properties are read instead, TCP via `netsh` filtered on the `:` separator (which also dodges `Get-NetTCPSetting` failing where `MSFT_NetTCPSetting` is missing), and DNS is applied to all physical adapters.
- **Presets, custom presets & JSON backups.** New **`10. Presets`** menu (light / moderate / heavy + custom `.preset` files), each writing one restorable JSON backup; *What was excluded* moved to item 11.
- **Console-font fix.** The last two inline-PowerShell spots (Unity core detection and the `boot.config` rewrite) now use the minimized-window pattern; boot.config paths pass via environment variables.
- **Community-guide tweaks.** BCD timers also set `useplatformtick yes`; optional minimum processor state 5%; optional Game Mode off; a *debloat* action (removed apps are reinstallable from the Store).
- **Timer resolution.** SetTimerResolution installs as a hidden logon task plus a system-wide registry switch (needs a reboot); fully removable.
- **Backups moved to Documents** (`Documents\PerfTweaks_Backups`, OneDrive-aware) instead of the drive root.
- **Console compatibility (Windows 10 / Server 2022).** ASCII-only / no BOM, an echo-off guard, a working-directory fix, suppressed `mode`/`color` errors, and an ASCII logo — so `@echo off` and the menu render correctly on legacy `cmd.exe`.
- **Unity `boot.config` is CPU-aware.** It sets `job-worker-count` / `-maximum-count` to logical processors − 1 before copying into the game's `*_Data` folder.
- **Bundled-file error handling.** Missing/empty `boot.config` or `hosts`, and copy failures, now stop with a clear, actionable message.

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
