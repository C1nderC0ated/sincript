@echo off
echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0" 2>nul
mode con: cols=100 lines=36 >nul 2>&1
color 0D 
title Sincript - Windows 10/11 Optimizer
rem =====================================================================================
rem  PerfTweaks - a curated, reversible Windows 10/11 optimizer with a category menu.
rem  Every registry change is backed up first (.reg in %BACKUP_DIR%). "Backups & status"
rem  makes a System Restore Point and a full registry export - do that first.
rem  Read "What was excluded" in the main menu for the safety rationale.
rem =====================================================================================
rem ---------- Self-elevate to Administrator (robust, cannot loop) ----------
rem  net session needs the 'Server' service (often disabled by debloat scripts), so fall
rem  back to fltmc, then to reg-querying the LocalService hive (needs no service at all).
rem  The one-shot /elevated marker guarantees we relaunch at most once - no infinite loop.
net session >nul 2>&1 || fltmc >nul 2>&1 || reg query "HKU\S-1-5-19" >nul 2>&1
if not errorlevel 1 goto AdminOK
if /i "%~1"=="/elevated" goto AdminWarn
echo Requesting Administrator privileges...
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '/elevated' -Verb RunAs -WorkingDirectory (Split-Path -Parent '%~f0')" >nul 2>&1
exit /b

:AdminWarn
echo [WARN] Could not auto-confirm administrator rights. Continuing anyway - some HKLM
echo        changes may fail if this window is not actually elevated.
timeout /t 3 >nul

:AdminOK
cd /d "%~dp0" 2>nul
rem ---------- Globals ----------
set "SCRIPT_DIR=%~dp0"
rem  Put backups under the user's Documents folder (resolves OneDrive-redirected Documents);
rem  falls back to the profile default if the registry lookup fails.
set "DOCS=%USERPROFILE%\Documents"
for /f "tokens=2,*" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v Personal 2^>nul ^| findstr /I "Personal"') do set "DOCS=%%b"
call set "DOCS=%DOCS%"
set "BACKUP_DIR=%DOCS%\PerfTweaks_Backups"
set "LOGFILE=%BACKUP_DIR%\PerfTweaks_%RANDOM%.log"
if not exist "%BACKUP_DIR%" md "%BACKUP_DIR%" >nul 2>&1
rem ---------- OS build / Win11 / GPU detection ----------
set "WIN_BUILD="
for /f "tokens=3" %%B in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| findstr /I "CurrentBuildNumber"') do set "WIN_BUILD=%%B"
set "IS_WIN11=0"
if defined WIN_BUILD if !WIN_BUILD! GEQ 22000 set "IS_WIN11=1"
set "GPU=unknown"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s /v DriverDesc 2>nul | findstr /I "nvidia" >nul && set "GPU=nvidia"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s /v DriverDesc 2>nul | findstr /I "radeon" >nul && set "GPU=amd"
call :Log "PerfTweaks start - build %WIN_BUILD% win11=%IS_WIN11% gpu=%GPU%"
rem =====================================================================================
rem  MAIN MENU
rem =====================================================================================
:MainMenu
cls
call :Logo
echo ================================  MAIN MENU  ======================================
echo   Build %WIN_BUILD%   Win11=%IS_WIN11%   GPU=%GPU%
echo -----------------------------------------------------------------------------------
echo     1.  Cleanup ^& repair        (temp/logs, DISM/SFC, Windows Update, Store, WinSxS)
echo     2.  Performance tweaks       (GameDVR off, priorities, snappier UI)
echo     3.  Privacy ^& telemetry      (telemetry, ads, Cortana, location off)
echo     4.  Power plan               (high-performance, no sleep)
echo     5.  Network ^& DNS            (TCP tweaks, DNS, reset stack)
echo     6.  Apps ^& files            (OpenAsar, Unity boot.config, hosts, SteamLight)
echo     7.  Advanced                 (at your own risk - mitigations, timers, IPv6, GPU)
echo     8.  Backups ^& status        (restore point, registry backup, current status)
echo -----------------------------------------------------------------------------------
echo     9.  Apply recommended safe set  (one click: 1-5 core tweaks, no prompts)
echo    10.  Presets (light / moderate / heavy / custom)  + restore preset backup
echo    11.  What was excluded (info)
echo     0.  Exit
echo =====================================================================================

:MainMenu_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto MainMenu_ask
if "%sel%"=="1" goto MenuCleanup
if "%sel%"=="2" goto Performance
if "%sel%"=="3" goto Privacy
if "%sel%"=="4" goto Power
if "%sel%"=="5" goto MenuNetwork
if "%sel%"=="6" goto MenuApps
if "%sel%"=="7" goto MenuAdvanced
if "%sel%"=="8" goto MenuBackups
if "%sel%"=="9" goto ApplyRecommended
if "%sel%"=="10" goto MenuPresets
if "%sel%"=="11" goto Excluded
if "%sel%"=="0" goto ExitScript
goto MainMenu

:ExitScript
cls
call :Logo
echo   Log saved to: %LOGFILE%
echo   Backups in:   %BACKUP_DIR%
echo.
echo   Bye.
timeout /t 2 >nul
exit /b
rem =====================================================================================
rem  SUBMENU: Cleanup & repair
rem =====================================================================================
:MenuCleanup
cls
call :Logo
echo ============================  CLEANUP ^& REPAIR  ===================================
echo     1.  Clean temp / logs / caches      (+ optional: clear all Event Viewer logs)
echo     2.  DISM + SFC system integrity
echo     3.  Reset Windows Update components
echo     4.  Re-register Microsoft Store / apps
echo     5.  Compact WinSxS (free disk space)
echo     0.  Back
echo =====================================================================================

:MenuCleanup_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto MenuCleanup_ask
if "%sel%"=="1" goto Cleanup
if "%sel%"=="2" goto SfcDism
if "%sel%"=="3" goto WUReset
if "%sel%"=="4" goto StoreRepair
if "%sel%"=="5" goto CompactWinSxS
if "%sel%"=="0" goto MainMenu
goto MenuCleanup
rem =====================================================================================
rem  SUBMENU: Network & DNS
rem =====================================================================================
:MenuNetwork
cls
call :Logo
echo =============================  NETWORK ^& DNS  =====================================
echo     1.  Apply TCP tweaks        (autotuning/heuristics/RSS/RSC, optional low-latency)
echo     2.  Set DNS                 (Cloudflare / Google / Quad9 / automatic)
echo     3.  Reset network stack     (winsock / ip / dns)
echo     0.  Back
echo =====================================================================================

:MenuNetwork_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto MenuNetwork_ask
if "%sel%"=="1" goto NetworkApply
if "%sel%"=="2" goto MenuDns
if "%sel%"=="3" goto NetReset
if "%sel%"=="0" goto MainMenu
goto MenuNetwork

:MenuDns
cls
call :Logo
echo ===============================  SET DNS  =========================================
echo  IPv4 + IPv6, applied to all active adapters, DNS cache flushed. Fully reversible.
echo     1.  Cloudflare   1.1.1.1 / 1.0.0.1
echo     2.  Google       8.8.8.8 / 8.8.4.4
echo     3.  Quad9        9.9.9.9 / 149.112.112.112   (blocks known-malicious domains)
echo     4.  Revert to automatic (DHCP)
echo     0.  Back
echo =====================================================================================

:MenuDns_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto MenuDns_ask
if "%sel%"=="1" goto DnsCloudflare
if "%sel%"=="2" goto DnsGoogle
if "%sel%"=="3" goto DnsQuad9
if "%sel%"=="4" goto DnsAuto
if "%sel%"=="0" goto MenuNetwork
goto MenuDns
rem =====================================================================================
rem  SUBMENU: Apps & files
rem =====================================================================================
:MenuApps
cls
call :Logo
echo =============================  APPS ^& FILES  ======================================
echo     1.  Install OpenAsar into Discord
echo     2.  Place Unity boot.config into a game folder
echo     3.  Apply custom hosts file (ad/telemetry blocklist)
echo     4.  Restore / reset hosts
echo     5.  Install SteamLight (lightweight Steam launcher + desktop shortcut)
echo     6.  Apply timer resolution (SetTimerResolution autostart)
echo     7.  Remove timer resolution
echo     8.  Remove built-in apps (debloat)
echo     0.  Back
echo =====================================================================================

:MenuApps_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto MenuApps_ask
if "%sel%"=="1" goto OpenAsar
if "%sel%"=="2" goto UnityBoot
if "%sel%"=="3" goto ApplyHosts
if "%sel%"=="4" goto RestoreHosts
if "%sel%"=="5" goto SteamLight
if "%sel%"=="6" goto TimerResApply
if "%sel%"=="7" goto TimerResRemove
if "%sel%"=="8" goto Debloat
if "%sel%"=="0" goto MainMenu
goto MenuApps
rem =====================================================================================
rem  SUBMENU: Advanced
rem =====================================================================================
:MenuAdvanced
cls
call :Logo
echo ====================  ADVANCED  -  AT YOUR OWN RISK  ===============================
echo  Reversible, never part of "Apply recommended". Most need a reboot.
echo     1.  Disable CPU mitigations        (faster, LESS secure)
echo     2.  Re-enable CPU mitigations      (secure default)
echo     3.  BCDEdit timer tweaks
echo     4.  Revert BCDEdit timer tweaks
echo     5.  Experimental NVMe driver flags
echo     6.  Disable IPv6 (all adapters)
echo     7.  Disable memory compression / page combining
echo     8.  %GPU% telemetry / background tasks off
echo     9.  GPU hardware scheduling (HAGS) on/off
echo    10.  Set permanent process priority  (per .exe, e.g. a game)
echo     0.  Back
echo =====================================================================================

:MenuAdvanced_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto MenuAdvanced_ask
if "%sel%"=="1" goto DisableMitigations
if "%sel%"=="2" goto EnableMitigations
if "%sel%"=="3" goto BcdTimers
if "%sel%"=="4" goto BcdRevert
if "%sel%"=="5" goto NvmeFlags
if "%sel%"=="6" goto DisableIPv6
if "%sel%"=="7" goto MemCompress
if "%sel%"=="8" goto GpuTelemetry
if "%sel%"=="9" goto HagsToggle
if "%sel%"=="10" goto ProcPriority
if "%sel%"=="0" goto MainMenu
goto MenuAdvanced
rem =====================================================================================
rem  SUBMENU: Backups & status
rem =====================================================================================
:MenuBackups
cls
call :Logo
echo ===========================  BACKUPS ^& STATUS  ====================================
echo     1.  Create System Restore Point
echo     2.  Full registry backup (HKLM + HKCU export)
echo     3.  Show current status / what's applied
echo     4.  Restore from a preset backup (JSON)
echo     5.  Restore a single value backup (.reg)
echo     0.  Back
echo =====================================================================================

:MenuBackups_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto MenuBackups_ask
if "%sel%"=="1" goto DoRestorePoint
if "%sel%"=="2" goto DoRegBackup
if "%sel%"=="3" goto Status
if "%sel%"=="4" goto RestorePresetJson
if "%sel%"=="5" goto RestoreRegBackup
if "%sel%"=="0" goto MainMenu
goto MenuBackups
rem =====================================================================================
rem  ACTION: Cleanup
rem =====================================================================================
:Cleanup
cls
call :Logo
echo ================================  CLEANUP  ========================================
echo  Deletes temp files, Windows logs, the thumbnail cache and telemetry caches, then
echo  flushes the DNS cache. Only files are removed; nothing is changed in the registry.
echo =====================================================================================
set /p "_c=Proceed? (Y/N): "
if /i not "%_c%"=="Y" goto MenuCleanup
call :DoCleanupCore
set /p "_ev=Also clear ALL Event Viewer logs? (Y/N): "
if /i not "%_ev%"=="Y" goto _clEvDone
for /f "tokens=*" %%G in ('wevtutil el') do call :Run "wevtutil cl ""%%G"""

:_clEvDone
echo [OK] Cleanup done.
pause
goto MenuCleanup

:DoCleanupCore
call :Run "del /f /s /q ""%TEMP%\*.*"""
call :Run "del /f /s /q ""%SystemRoot%\Temp\*.*"""
call :Run "del /f /s /q ""%LocalAppData%\Temp\*.*"""
call :Run "del /f /s /q ""%SystemRoot%\Prefetch\*.*"""
call :Run "del /f /s /q /a ""%LocalAppData%\Microsoft\Windows\Explorer\*.db"""
call :Run "del /f /q ""%SystemRoot%\Logs\CBS\*"""
call :Run "del /f /q ""%SystemRoot%\Logs\DISM\*"""
call :Run "del /f /q ""%SystemRoot%\Temp\CBS\*"""
call :Run "del /f /q ""%SystemRoot%\setupact.log"""
call :Run "del /f /q ""%SystemRoot%\setuperr.log"""
call :Run "del /f /q ""%SystemRoot%\Panther\*"""
call :Run "del /f /q ""%LocalAppData%\Microsoft\Windows\WebCache\*.*"""
call :Run "ipconfig /flushdns"
goto :eof
rem =====================================================================================
rem  ACTION: DISM + SFC
rem =====================================================================================
:SfcDism
cls
call :Logo
echo =============================  DISM + SFC integrity  ==============================
echo  Repairs the component store (DISM RestoreHealth) then verifies system files (SFC).
echo  Takes several minutes; let it finish.
echo =====================================================================================
set /p "_c=Run DISM + SFC now? (Y/N): "
if /i not "%_c%"=="Y" goto MenuCleanup
call :Run "dism /online /cleanup-image /restorehealth"
call :Run "sfc /scannow"
echo [OK] Integrity check complete.
pause
goto MenuCleanup
rem =====================================================================================
rem  ACTION: Reset Windows Update
rem =====================================================================================
:WUReset
cls
call :Logo
echo =======================  Reset Windows Update components  =========================
echo  Stops update services, renames SoftwareDistribution and catroot2, restarts them.
echo  Fixes most stuck-update problems. Safe.
echo =====================================================================================
set /p "_c=Reset Windows Update now? (Y/N): "
if /i not "%_c%"=="Y" goto MenuCleanup
for %%S in (wuauserv bits cryptSvc msiserver appidsvc) do call :Run "net stop %%S"
call :Run "ren ""%SystemRoot%\SoftwareDistribution"" SoftwareDistribution.bak_%RANDOM%"
call :Run "ren ""%SystemRoot%\System32\catroot2"" catroot2.bak_%RANDOM%"
for %%S in (wuauserv bits cryptSvc msiserver appidsvc) do call :Run "net start %%S"
echo [OK] Windows Update components reset.
pause
goto MenuCleanup
rem =====================================================================================
rem  ACTION: Re-register Store / apps
rem =====================================================================================
:StoreRepair
cls
call :Logo
echo =====================  Re-register Microsoft Store / apps  ========================
echo  Re-registers the Store package for the current user. Fixes a broken Store.
echo =====================================================================================
set /p "_c=Re-register the Store now? (Y/N): "
if /i not "%_c%"=="Y" goto MenuCleanup
echo   ^> Re-registering Microsoft Store (separate window)...
call :Log "EXEC-PS (isolated): Store re-register"
start "" /min /wait powershell -NoProfile -Command "Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object {Add-AppxPackage -DisableDevelopmentMode -Register ($_.InstallLocation + '\AppXManifest.xml')}"
echo [OK] Store re-registered.
pause
goto MenuCleanup
rem =====================================================================================
rem  ACTION: Compact WinSxS
rem =====================================================================================
:CompactWinSxS
cls
call :Logo
echo ===============================  Compact WinSxS  ==================================
echo  Removes superseded component-store versions via the supported DISM method, then
echo  optionally compresses system binaries (CompactOS). Frees disk space; reversible.
echo =====================================================================================
set /p "_c=Run component cleanup now? (Y/N): "
if /i not "%_c%"=="Y" goto MenuCleanup
call :Run "dism /online /cleanup-image /startcomponentcleanup"
set /p "_co=Also compress OS binaries with CompactOS (slower, more space saved)? (Y/N): "
if /i "%_co%"=="Y" call :Run "compact.exe /compactos:always"
echo [OK] Done.
pause
goto MenuCleanup
rem =====================================================================================
rem  ACTION: Performance
rem =====================================================================================
:Performance
cls
call :Logo
echo ==============================  PERFORMANCE TWEAKS  ===============================
echo  GameDVR off, gaming MMCSS priorities, faster startup/menus/shutdown, best-performance
echo  visuals, long-path support, Explorer opens "This PC", unhide core-parking options.
echo  Legacy "memory optimization" values and CPU-mitigation changes are NOT here (Advanced).
echo =====================================================================================
set /p "_c=Apply performance tweaks? (Y/N): "
if /i not "%_c%"=="Y" goto MainMenu
call :DoPerformanceCore
set "_q1=" & set "_q2=" & set "_q3=" & set "_q3b=" & set "_q4=" & set "_q5=" & set "_q6=" & set "_q7="
echo.
echo Optional knobs (small / unproven gains - your call):
set /p "_q1=  SystemResponsiveness=0 (reserve less for background)? (Y/N): "
if /i "%_q1%"=="Y" call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" REG_DWORD 0 "SystemResponsiveness 0"
set /p "_q2=  Disable network throttling (may affect media playback)? (Y/N): "
if /i "%_q2%"=="Y" call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" REG_DWORD 4294967295 "Network throttling off"
set /p "_q3=  Win32PrioritySeparation = 42 (0x2A: short/fixed quantum, strong foreground boost)? (Y/N): "
if /i "%_q3%"=="Y" call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" REG_DWORD 42 "Win32PrioritySeparation = 42 (0x2A)"
set /p "_q3b=  Reset Win32PrioritySeparation to Windows default (2)? (Y/N): "
if /i "%_q3b%"=="Y" call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" REG_DWORD 2 "Win32PrioritySeparation default (2)"
set /p "_q4=  LargeSystemCache=1 (can help some laptops, can hurt desktops)? (Y/N): "
if /i "%_q4%"=="Y" call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" REG_DWORD 1 "LargeSystemCache on"
set /p "_q5=  Disable Windows Game Mode (contested; some titles run smoother without it)? (Y/N): "
if /i "%_q5%"=="Y" call :SafeRegAdd "HKCU\Software\Microsoft\GameBar" "AutoGameModeEnabled" REG_DWORD 0 "Game Mode off"
if /i "%_q5%"=="Y" call :SafeRegAdd "HKCU\Software\Microsoft\GameBar" "AllowAutoGameMode" REG_DWORD 0 "Auto Game Mode off"
set /p "_q6=  Disable mouse acceleration / Enhance pointer precision - raw 1:1 mouse, after sign out/in? (Y/N): "
if /i "%_q6%"=="Y" call :SafeRegAdd "HKCU\Control Panel\Mouse" "MouseSpeed" REG_SZ 0 "Mouse acceleration off"
if /i "%_q6%"=="Y" call :SafeRegAdd "HKCU\Control Panel\Mouse" "MouseThreshold1" REG_SZ 0 "Mouse accel threshold1 off"
if /i "%_q6%"=="Y" call :SafeRegAdd "HKCU\Control Panel\Mouse" "MouseThreshold2" REG_SZ 0 "Mouse accel threshold2 off"
set /p "_q7=  Show file extensions in Explorer (safer, see real file types)? (Y/N): "
if /i "%_q7%"=="Y" call :SafeRegAdd "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" REG_DWORD 0 "Show file extensions"
echo [OK] Performance tweaks applied.
pause
goto MainMenu

:DoPerformanceCore
call :SafeRegAdd "HKCU\System\GameConfigStore" "GameDVR_Enabled" REG_DWORD 0 "GameDVR off"
call :SafeRegAdd "HKCU\System\GameConfigStore" "GameDVR_FSEBehaviorMode" REG_DWORD 2 "FSE behavior"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" REG_DWORD 0 "GameDVR off (policy)"
call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" REG_DWORD 8 "Games GPU priority"
call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" REG_DWORD 6 "Games CPU priority"
call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" REG_SZ High "Games scheduling High"
call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" REG_SZ High "Games SFIO High"
call :SafeRegAdd "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" REG_DWORD 0 "No startup delay"
call :SafeRegAdd "HKCU\Control Panel\Desktop" "MenuShowDelay" REG_SZ 50 "Menu show delay 50ms"
call :SafeRegAdd "HKCU\Control Panel\Desktop" "AutoEndTasks" REG_SZ 1 "Auto-end hung tasks"
call :SafeRegAdd "HKCU\Control Panel\Desktop" "WaitToKillAppTimeout" REG_SZ 5000 "WaitToKill app 5s"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control" "WaitToKillServiceTimeout" REG_SZ 5000 "WaitToKill service 5s"
call :SafeRegAdd "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" REG_DWORD 2 "Visuals: best performance"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" REG_DWORD 1 "Enable long paths"
call :SafeRegAdd "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" REG_DWORD 1 "Explorer opens This PC"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" "Attributes" REG_DWORD 0 "Unhide core-parking option"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb" "Attributes" REG_DWORD 0 "Unhide core-parking max cores"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\ea062031-0e34-4ff1-9b6d-eb1059334028" "Attributes" REG_DWORD 0 "Unhide processor perf option"
goto :eof
rem =====================================================================================
rem  ACTION: Privacy
rem =====================================================================================
:Privacy
cls
call :Logo
echo =============================  PRIVACY ^& TELEMETRY  ===============================
echo  Disables diagnostic telemetry, advertising ID, suggested apps, Cortana/web search,
echo  feedback prompts, activity feed and location; stops DiagTrack and CEIP tasks.
echo =====================================================================================
set /p "_c=Apply privacy / telemetry hardening? (Y/N): "
if /i not "%_c%"=="Y" goto MainMenu
call :DoPrivacyCore
set /p "_svc=Also disable per-user sync services (breaks Mail/Calendar/People sync)? (Y/N): "
if /i not "%_svc%"=="Y" goto _privSvcDone
for %%S in (CDPUserSvc OneSyncSvc PimIndexMaintenanceSvc UnistoreSvc UserDataSvc MessagingService) do call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Services\%%S" "Start" REG_DWORD 4 "Disable per-user svc %%S"

:_privSvcDone
echo [OK] Privacy tweaks applied.
pause
goto MainMenu

:DoPrivacyCore
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" REG_DWORD 0 "Diagnostic telemetry (policy)"
call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" REG_DWORD 0 "Diagnostic telemetry (HKLM)"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" REG_DWORD 0 "App inventory off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" REG_DWORD 1 "Inventory collection off"
call :SafeRegAdd "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" REG_DWORD 0 "Advertising ID off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" REG_DWORD 1 "Advertising ID off (policy)"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" REG_DWORD 1 "Suggested apps off"
call :SafeRegAdd "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" REG_DWORD 0 "Start suggestions off"
call :SafeRegAdd "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" REG_DWORD 0 "Tips/tricks off"
call :SafeRegAdd "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" REG_DWORD 0 "Silent app install off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" REG_DWORD 0 "Cortana off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" REG_DWORD 1 "Web search in Start off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" REG_DWORD 0 "Connected web search off"
call :SafeRegAdd "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" REG_DWORD 0 "Bing in search off"
call :SafeRegAdd "HKCU\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" REG_DWORD 0 "Feedback prompts off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" REG_DWORD 1 "Feedback notifications off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" REG_DWORD 0 "Activity feed off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" REG_DWORD 0 "Activity history publish off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" REG_DWORD 0 "Activity history upload off"
call :SafeRegAdd "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" REG_DWORD 0 "App-launch tracking off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" REG_DWORD 1 "Location off"
call :SafeRegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" REG_DWORD 1 "OneDrive auto-sync off (policy)"
call :Run "sc config DiagTrack start= disabled"
call :Run "sc stop DiagTrack"
call :Run "sc config dmwappushservice start= disabled"
call :Run "sc stop dmwappushservice"
call :Run "schtasks /Change /TN ""\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"" /Disable"
call :Run "schtasks /Change /TN ""\Microsoft\Windows\Application Experience\ProgramDataUpdater"" /Disable"
call :Run "schtasks /Change /TN ""\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"" /Disable"
call :Run "schtasks /Change /TN ""\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"" /Disable"
call :Run "schtasks /Change /TN ""\Microsoft\Windows\Windows Error Reporting\QueueReporting"" /Disable"
goto :eof
rem =====================================================================================
rem  ACTION: Power plan
rem =====================================================================================
:Power
cls
call :Logo
echo ================================  POWER PLAN  =====================================
echo  Activates the Ultimate Performance plan (falls back to High Performance) and sets
echo  monitor/standby/disk sleep timeouts to never. Best for a plugged-in desktop.
echo =====================================================================================
set /p "_c=Apply high-performance power plan? (Y/N): "
if /i not "%_c%"=="Y" goto MainMenu
call :DoPowerCore
set /p "_hb=Also disable hibernation (frees disk space, removes Fast Startup)? (Y/N): "
if /i "%_hb%"=="Y" call :Run "powercfg /hibernate off"
set "_mp="
set /p "_mp=Set minimum processor state to 5%% (CPU idles down to save power, no FPS loss)? (Y/N): "
if /i "%_mp%"=="Y" call :SetMinProcState
echo [OK] Power settings applied.
pause
goto MainMenu

:DoPowerCore
call :Log "Power plan -> Ultimate (fallback High), no sleep"
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1 || powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
call :Run "powercfg -change -monitor-timeout-ac 0"
call :Run "powercfg -change -monitor-timeout-dc 0"
call :Run "powercfg -change -standby-timeout-ac 0"
call :Run "powercfg -change -standby-timeout-dc 0"
call :Run "powercfg -change -disk-timeout-ac 0"
call :Run "powercfg -change -disk-timeout-dc 0"
goto :eof

:SetMinProcState
call :Log "Min processor state -> 5%%"
call :Run "powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 5"
call :Run "powercfg /setdcvalueindex scheme_current sub_processor PROCTHROTTLEMIN 5"
call :Run "powercfg /setactive scheme_current"
goto :eof
rem =====================================================================================
rem  ACTION: Network TCP tweaks
rem =====================================================================================
:NetworkApply
cls
call :Logo
echo ==============================  APPLY TCP TWEAKS  =================================
echo  Receive-side autotuning = normal, heuristics off, RSS on, RSC on (sane defaults).
echo  Optionally disable Nagle / delayed-ACK on current adapters (lower latency).
echo =====================================================================================
set /p "_c=Apply TCP tweaks? (Y/N): "
if /i not "%_c%"=="Y" goto MenuNetwork
call :DoNetworkCore
set /p "_nag=Also disable Nagle/delayed-ACK on current adapters? (Y/N): "
if /i not "%_nag%"=="Y" goto _netNagDone
call :DoNagleOff

:_netNagDone
echo [OK] TCP tweaks applied.
pause
goto MenuNetwork

:DoNetworkCore
call :Run "netsh int tcp set global autotuninglevel=normal"
call :Run "netsh int tcp set heuristics disabled"
call :Run "netsh int tcp set global rss=enabled"
call :Run "netsh int tcp set global rsc=enabled"
goto :eof
rem =====================================================================================
rem  ACTION: Reset network stack
rem =====================================================================================
:NetReset
cls
call :Logo
echo ============================  Reset network stack  ================================
echo  Resets TCP/IP and Winsock, flushes DNS, releases/renews IP. Brief connectivity loss.
echo =====================================================================================
set /p "_c=Proceed? (Y/N): "
if /i not "%_c%"=="Y" goto MenuNetwork
call :Run "ipconfig /flushdns"
call :Run "netsh winsock reset"
call :Run "netsh int ip reset"
call :Run "ipconfig /release"
call :Run "ipconfig /renew"
echo [OK] Network stack reset. Reboot recommended.
pause
goto MenuNetwork
rem =====================================================================================
rem  ACTION: DNS options
rem =====================================================================================
:DnsCloudflare
set "DNSSRV='1.1.1.1','1.0.0.1','2606:4700:4700::1111','2606:4700:4700::1001'"
cls
call :Logo
call :ApplyDns "Cloudflare"
pause
goto MenuDns

:DnsGoogle
set "DNSSRV='8.8.8.8','8.8.4.4','2001:4860:4860::8888','2001:4860:4860::8844'"
cls
call :Logo
call :ApplyDns "Google"
pause
goto MenuDns

:DnsQuad9
set "DNSSRV='9.9.9.9','149.112.112.112','2620:fe::fe','2620:fe::9'"
cls
call :Logo
call :ApplyDns "Quad9"
pause
goto MenuDns

:DnsAuto
cls
call :Logo
echo Reverting DNS to automatic (DHCP) on all active adapters...
call :Log "DNS -> automatic (DHCP)"
start "" /min /wait powershell -NoProfile -Command "Get-NetAdapter -Physical | ForEach-Object { try { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction Stop } catch {} }"
ipconfig /flushdns >nul 2>&1
echo [OK] DNS reset to automatic.
pause
goto MenuDns
rem =====================================================================================
rem  ACTION: OpenAsar
rem =====================================================================================
:OpenAsar
cls
call :Logo
echo ==============================  Install OpenAsar  =================================
echo  Replaces Discord's app.asar in app-VERSION\resources\. Uses the bundled app.asar
echo  next to this script, or downloads the latest nightly. If a mod renamed the original
echo  to _app.asar / app.orig.asar / app.asar.orig, THAT is replaced (OpenAsar loads under
echo  the mod). Handles Discord / PTB / Canary. A Discord update can revert it - re-run.
echo =====================================================================================
set "_SRC="
if exist "%SCRIPT_DIR%app.asar" set "_SRC=%SCRIPT_DIR%app.asar"
if defined _SRC goto OA_HaveSrc
echo Local app.asar not found next to this script.
set /p "_dl=Download the latest OpenAsar (nightly) from GitHub instead? (Y/N): "
if /i not "%_dl%"=="Y" goto MenuApps
echo Downloading OpenAsar nightly...
start "" /min /wait powershell -NoProfile -Command "try{Invoke-WebRequest -Uri 'https://github.com/GooseMod/OpenAsar/releases/download/nightly/app.asar' -OutFile (Join-Path $env:TEMP 'openasar_nightly.asar') -UseBasicParsing}catch{exit 1}"
if not exist "%TEMP%\openasar_nightly.asar" goto OA_DlFail
set "_SRC=%TEMP%\openasar_nightly.asar"

:OA_HaveSrc
set /p "_c=Close Discord and continue? (Y/N): "
if /i not "%_c%"=="Y" goto MenuApps
taskkill /f /im Discord.exe       >nul 2>&1
taskkill /f /im DiscordPTB.exe    >nul 2>&1
taskkill /f /im DiscordCanary.exe >nul 2>&1
timeout /t 3 >nul
set "_DONE=0"
for %%F in (Discord DiscordPTB DiscordCanary) do if exist "%LocalAppData%\%%F\" call :InstallAsarInto "%LocalAppData%\%%F" "%%F" "%_SRC%"
if "%_DONE%"=="0" (
    echo [ERROR] No Discord install with a resources\app.asar found. ^(Store version unsupported.^)
    pause
    goto MenuApps
)
echo.
echo Reopening Discord...
if exist "%LocalAppData%\Discord\Update.exe" start "" "%LocalAppData%\Discord\Update.exe" --processStart Discord.exe
echo Check Settings at the bottom of the left sidebar for an "OpenAsar" entry.
echo To revert: restore the .bak file over the replaced .asar, or reinstall Discord.
pause
goto MenuApps

:OA_DlFail
echo [ERROR] Download failed (no internet, or GitHub is blocked here).
echo         Put OpenAsar's app.asar next to this script and re-run (openasar.dev).
pause
goto MenuApps
rem =====================================================================================
rem  ACTION: Unity boot.config
rem =====================================================================================
:UnityBoot
cls
call :Logo
echo ============================  Unity boot.config  =================================
echo  Copies the bundled boot.config into a Unity game's *_Data folder, tuned for your
echo  CPU (job-worker-count). Per-game; restore boot.config.bak from that folder if needed.
echo =====================================================================================
call :RequireBundledFile boot.config "Unity engine boot configuration"
call :DetectUnityJobWorkers
echo.
echo   Detected: !_CORESRC!
echo   Setting job-worker-count / job-worker-maximum-count to !_JWCOUNT! (logical CPUs minus one).
echo.
echo Paste the game's *_Data folder path (or drag the folder here), then Enter:
set "_gd="
set /p "_gd=Path: "
set "_gd=%_gd:"=%"
if not defined _gd (
    echo.
    echo [ERROR] No folder path entered.
    echo         Paste the full path to the game's *_Data folder and try again.
    call :Log "ABORT: Unity boot.config - empty path"
    pause
    goto MenuApps
)
if "!_gd:~-1!"=="\" set "_gd=!_gd:~0,-1!"
set "_boottmp=%TEMP%\PerfTweaks_boot_%RANDOM%.config"
call :PrepareBootConfig "%SCRIPT_DIR%boot.config" "!_boottmp!" "!_JWCOUNT!"
if errorlevel 1 (
    echo.
    echo [ERROR] Could not prepare boot.config with job-worker-count=!_JWCOUNT!.
    echo   Check that the bundled boot.config is readable and try again.
    call :Log "FAIL: PrepareBootConfig workers=!_JWCOUNT!"
    if exist "!_boottmp!" del /f /q "!_boottmp!" >nul 2>&1
    pause
    goto MenuApps
)
rem  Step INTO the game folder first, then copy to the bare name "boot.config". This way no
rem  command ever receives a full path containing spaces (e.g. C:\Program Files\..), so the
rem  space cannot be split into a stray "C:\Program" file at the drive root.
pushd "!_gd!" 2>nul
if errorlevel 1 (
    echo.
    echo [ERROR] Folder not found or not accessible:
    echo         "!_gd!"
    echo   Check the path and make sure you selected the game's *_Data folder.
    call :Log "ABORT: Unity boot.config - cannot enter path"
    if exist "!_boottmp!" del /f /q "!_boottmp!" >nul 2>&1
    pause
    goto MenuApps
)
if exist "boot.config" copy /y "boot.config" "boot.config.bak" >nul 2>&1
copy /y "!_boottmp!" "boot.config" >nul
set "_copyerr=!errorlevel!"
popd
del /f /q "!_boottmp!" >nul 2>&1
if !_copyerr! geq 1 goto _ubCopyFail
echo [OK] boot.config placed with job-worker-count=!_JWCOUNT! ^(!_CORESRC!^).
echo      Old file ^(if any^) saved as boot.config.bak
call :Log "OK: Unity boot.config -> !_gd! workers=!_JWCOUNT!"
pause
goto MenuApps

:_ubCopyFail
echo.
echo [ERROR] Could not write boot.config into:
echo         "!_gd!"
echo   The folder may be read-only, or boot.config is locked by the running game.
echo   Close the game, run PerfTweaks as administrator, then try again.
call :Log "FAIL: Unity boot.config copy to !_gd!"
pause
goto MenuApps
rem =====================================================================================
:SteamLight
cls
call :Logo
echo ==============================  SteamLight  =======================================
echo  Finds your Steam folder, writes a "SteamLight.bat" launcher there, and adds a
echo  Desktop shortcut. SteamLight starts Steam with flags that cut RAM/CPU use
echo  (single process/core, no shaders, no Big Picture, etc.) for a lighter, faster Steam.
echo =====================================================================================
rem  --- locate the Steam install folder (machine-wide first, then per-user) ---
set "_STEAMDIR="
for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Valve\Steam" /v InstallPath 2^>nul ^| findstr /I "InstallPath"') do set "_STEAMDIR=%%b"
if not defined _STEAMDIR for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\Valve\Steam" /v InstallPath 2^>nul ^| findstr /I "InstallPath"') do set "_STEAMDIR=%%b"
if not defined _STEAMDIR for /f "tokens=2,*" %%a in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul ^| findstr /I "SteamPath"') do set "_STEAMDIR=%%b"
if defined _STEAMDIR set "_STEAMDIR=!_STEAMDIR:/=\!"
if not defined _STEAMDIR (
    echo [ERROR] Could not find Steam in the registry. Is Steam installed?
    pause
    goto MenuApps
)
if not exist "!_STEAMDIR!\steam.exe" (
    echo [ERROR] Found a Steam path but no steam.exe there:
    echo         "!_STEAMDIR!"
    pause
    goto MenuApps
)
echo Steam folder: "!_STEAMDIR!"
echo.
set "_c="
set /p "_c=Install SteamLight here and add a Desktop shortcut? [Y/N]: "
if /i not "%_c%"=="Y" goto MenuApps
rem  Steam launch flags (edit this one line to change them). These cut RAM/CPU usage.
set "_SLFLAGS=-dev -console -nofriendsui -no-dwrite -nointro -nobigpicture -nofasthtml -nocrashmonitor -noshaders -no-shared-textures -disablehighdpi -cef-single-process -cef-in-process-gpu -single_core -cef-disable-d3d11 -cef-disable-sandbox -disable-winh264 -no-cef-sandbox -vrdisable -cef-disable-breakpad"
rem  Write the launcher INTO the Steam folder. It uses %~dp0steam.exe, i.e. the steam.exe
rem  sitting next to it, so it keeps working no matter where Steam is installed.
> "!_STEAMDIR!\SteamLight.bat" echo @echo off
>>"!_STEAMDIR!\SteamLight.bat" echo taskkill /f /im steam.exe ^>nul 2^>^&1
>>"!_STEAMDIR!\SteamLight.bat" echo start "" "%%~dp0steam.exe" !_SLFLAGS!
call :Log "SteamLight written to !_STEAMDIR!\SteamLight.bat"
echo   ^> Creating Desktop shortcut...
start "" /min /wait powershell -NoProfile -Command "$d=[Environment]::GetFolderPath('Desktop'); $w=New-Object -ComObject WScript.Shell; $s=$w.CreateShortcut((Join-Path $d 'SteamLight.lnk')); $s.TargetPath=(Join-Path '!_STEAMDIR!' 'SteamLight.bat'); $s.WorkingDirectory='!_STEAMDIR!'; $s.WindowStyle=7; $s.IconLocation=((Join-Path '!_STEAMDIR!' 'steam.exe')+',0'); $s.Description='Launch Steam in lightweight mode'; $s.Save()"
call :Log "SteamLight desktop shortcut created"
echo [OK] SteamLight installed in the Steam folder, and a shortcut was placed on your Desktop.
echo      First launch restarts Steam, so it may take a moment.
pause
goto MenuApps
rem =====================================================================================
rem  ACTION: Apply hosts
rem =====================================================================================
:ApplyHosts
cls
call :Logo
echo ============================  Apply custom hosts file  ============================
echo  Replaces the system hosts file with the bundled blocklist (entries point to 0.0.0.0).
echo  The current hosts is backed up next to it AND into the backup folder. DNS is flushed.
echo =====================================================================================
set "_HOSTS=%SystemRoot%\System32\drivers\etc\hosts"
call :RequireBundledFile hosts "ad/telemetry blocklist for the system hosts file"
set /p "_c=Proceed? (Y/N): "
if /i not "%_c%"=="Y" goto MenuApps
if exist "%_HOSTS%" (
    copy /y "%_HOSTS%" "%_HOSTS%.bak" >nul 2>&1
    copy /y "%_HOSTS%" "%BACKUP_DIR%\hosts_%RANDOM%.bak" >nul 2>&1
    call :Log "hosts backup made"
)
copy /y "%SCRIPT_DIR%hosts" "%_HOSTS%" >nul
if errorlevel 1 (
    echo.
    echo [ERROR] Could not replace the system hosts file:
    echo         "%_HOSTS%"
    echo   Common causes: Defender tamper protection, a third-party AV web-shield, or the
    echo   file is read-only. Temporarily allow edits to hosts, then re-run this action.
    call :Log "FAIL: apply hosts -> %_HOSTS%"
) else (
    echo [OK] hosts replaced. Backup at "%_HOSTS%.bak".
    call :Log "OK: hosts applied from %SCRIPT_DIR%hosts"
    call :Run "ipconfig /flushdns"
)
pause
goto MenuApps
rem =====================================================================================
rem  ACTION: Restore / reset hosts
rem =====================================================================================
:RestoreHosts
cls
call :Logo
echo ===========================  Restore / reset hosts  ==============================
echo     1.  Restore from PerfTweaks backup (hosts.bak)
echo     2.  Reset to a clean Windows default (un-blocks everything)
echo     0.  Back
echo =====================================================================================
set "_HOSTS=%SystemRoot%\System32\drivers\etc\hosts"

:RestoreHosts_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto RestoreHosts_ask
if "%sel%"=="1" goto RestoreHostsBak
if "%sel%"=="2" goto ResetHostsDefault
if "%sel%"=="0" goto MenuApps
goto RestoreHosts

:RestoreHostsBak
if not exist "%_HOSTS%.bak" (
    echo [ERROR] No backup found at "%_HOSTS%.bak". Use option 2 to reset to default.
    pause
    goto RestoreHosts
)
copy /y "%_HOSTS%.bak" "%_HOSTS%" >nul
if errorlevel 1 ( echo [WARN] Restore failed (AV tamper protection?). ) else ( echo [OK] hosts restored from backup. & call :Run "ipconfig /flushdns" )
pause
goto MenuApps

:ResetHostsDefault
if exist "%_HOSTS%" copy /y "%_HOSTS%" "%_HOSTS%.bak" >nul 2>&1
(
echo # Copyright ^(c^) 1993-2009 Microsoft Corp.
echo #
echo # This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
echo #
echo # This file contains the mappings of IP addresses to host names. Each
echo # entry should be kept on an individual line. The IP address should
echo # be placed in the first column followed by the corresponding host name.
echo #
echo # localhost name resolution is handled within DNS itself.
echo #	127.0.0.1       localhost
echo #	::1             localhost
) > "%_HOSTS%"
if errorlevel 1 ( echo [WARN] Reset failed (AV tamper protection?). ) else ( echo [OK] hosts reset to Windows default ^(old one saved as hosts.bak^). & call :Run "ipconfig /flushdns" )
pause
goto MenuApps
rem =====================================================================================
rem  ACTION: Disable / enable CPU mitigations
rem =====================================================================================
:DisableMitigations
cls
call :Logo
echo =====================  Disable CPU mitigations (RISKY)  ===========================
echo  Disables Spectre/Meltdown/MDS/SSBD/L1TF mitigations (FeatureSettingsOverride=3).
echo  Can improve CPU performance but REDUCES security. Reversible (option 2).
echo  Downfall/GDS has no separate switch (microcode-driven); this is the broadest
echo  documented override. Verify after reboot: PowerShell ^> Get-SpeculationControlSettings
echo =====================================================================================
set /p "_rp=Create a restore point first? (Y/N): "
if /i "%_rp%"=="Y" call :CreateRestorePoint
set /p "_c=Disable mitigations now? (Y/N): "
if /i not "%_c%"=="Y" goto MenuAdvanced
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" REG_DWORD 3 "Disable CPU mitigations"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" REG_DWORD 3 "Mitigations override mask"
echo [OK] Mitigations disabled. REBOOT required.
pause
goto MenuAdvanced

:EnableMitigations
cls
call :Logo
echo =====================  Re-enable CPU mitigations (secure)  ========================
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" REG_DWORD 0 "Re-enable CPU mitigations"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" REG_DWORD 3 "Mitigations override mask"
echo [OK] Mitigations restored to secure default. REBOOT required.
pause
goto MenuAdvanced
rem =====================================================================================
rem  ACTION: BCDEdit timer tweaks
rem =====================================================================================
:BcdTimers
cls
call :Logo
echo ============================  BCDEdit timer tweaks  ===============================
echo  Removes the forced platform clock, forces the platform tick, disables dynamic tick
echo  and sets TSC sync = enhanced (the BCD timer combo from the optimization guide).
echo  Can help timer-sensitive workloads. Reversible (option 4). REBOOT required.
echo =====================================================================================
set /p "_c=Apply timer tweaks? (Y/N): "
if /i not "%_c%"=="Y" goto MenuAdvanced
call :Run "bcdedit /deletevalue useplatformclock"
call :Run "bcdedit /set useplatformtick yes"
call :Run "bcdedit /set disabledynamictick yes"
call :Run "bcdedit /set tscsyncpolicy enhanced"
echo [OK] Timer tweaks applied. REBOOT required.
pause
goto MenuAdvanced

:BcdRevert
cls
call :Logo
echo ============================  Revert BCDEdit timers  ==============================
call :Run "bcdedit /deletevalue useplatformclock"
call :Run "bcdedit /deletevalue useplatformtick"
call :Run "bcdedit /deletevalue disabledynamictick"
call :Run "bcdedit /deletevalue tscsyncpolicy"
echo [OK] Timer settings reverted to defaults. REBOOT required.
pause
goto MenuAdvanced
rem =====================================================================================
rem  ACTION: NVMe flags
rem =====================================================================================
:NvmeFlags
cls
call :Logo
echo ======================  Experimental NVMe driver flags  ==========================
echo  Toggles feature flags for Microsoft's in-box NVMe driver (StorNVMe). NOTE: Microsoft
echo  blocked these on fully-patched systems in 2026, so on an updated PC this likely does
echo  nothing now. Only relevant if your SSD uses the in-box driver. Harmless + reversible.
echo =====================================================================================
set /p "_rp=Create a restore point first? (Y/N): "
if /i "%_rp%"=="Y" call :CreateRestorePoint
set /p "_c=Apply NVMe flags? (Y/N): "
if /i not "%_c%"=="Y" goto MenuAdvanced
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" "1176759950" REG_DWORD 1 "NVMe flag 1"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" "1853569164" REG_DWORD 1 "NVMe flag 2"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" "156965516" REG_DWORD 1 "NVMe flag 3"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" "735209102" REG_DWORD 1 "NVMe flag 4"
echo [OK] NVMe flags written. REBOOT required.
pause
goto MenuAdvanced
rem =====================================================================================
rem  ACTION: Disable IPv6
rem =====================================================================================
:DisableIPv6
cls
call :Logo
echo ===============================  Disable IPv6  ====================================
echo  Sets DisabledComponents=0xFF (disables IPv6 on all interfaces). Do this only if you
echo  know you don't need IPv6. To revert, delete that value or set it to 0. REBOOT needed.
echo =====================================================================================
set /p "_c=Disable IPv6? (Y/N): "
if /i not "%_c%"=="Y" goto MenuAdvanced
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" REG_DWORD 255 "Disable IPv6 (0xFF)"
echo [OK] IPv6 disabled. REBOOT required.
pause
goto MenuAdvanced
rem =====================================================================================
rem  ACTION: Memory compression
rem =====================================================================================
:MemCompress
cls
call :Logo
echo =====================  Disable memory compression / combining  ====================
echo  Turns off RAM compression and page combining. Frees a little CPU at the cost of more
echo  RAM pressure on low-memory PCs. Re-enable: PowerShell ^> Enable-MMAgent -MemoryCompression
echo =====================================================================================
set /p "_c=Disable memory compression and page combining? (Y/N): "
if /i not "%_c%"=="Y" goto MenuAdvanced
rem  Launch PowerShell in a SEPARATE minimized window. Running powershell inside THIS
rem  window makes it apply its own console font/size (shows up as bold + small) until the
rem  window is closed; a separate window keeps this window's Consolas font intact.
echo   ^> Disabling memory compression and page combining...
call :Log "EXEC-PS (isolated): Disable-MMAgent -MemoryCompression / -PageCombining"
start "" /min /wait powershell -NoProfile -Command "try{Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue}catch{}; try{Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue}catch{}"
call :Log "Done: Disable-MMAgent"
echo [OK] Done. REBOOT recommended.
pause
goto MenuAdvanced
rem =====================================================================================
rem  ACTION: GPU telemetry off
rem =====================================================================================
:GpuTelemetry
cls
call :Logo
echo =========================  GPU telemetry / tasks off  =============================
if "%GPU%"=="nvidia" goto GpuNvidia
if "%GPU%"=="amd" goto GpuAmd
echo  No NVIDIA/AMD GPU detected (or detection failed). Nothing to do here.
pause
goto MenuAdvanced

:GpuNvidia
echo  Detected NVIDIA. Disables NVIDIA telemetry tasks and background reporting only. The
echo  large undocumented GPU registry tweaks are NOT applied (they can cause crashes).
set /p "_c=Apply NVIDIA telemetry-off? (Y/N): "
if /i not "%_c%"=="Y" goto MenuAdvanced
call :Run "schtasks /Change /Disable /TN ""NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup" "SendTelemetryData" REG_DWORD 0 "NVIDIA telemetry off"
call :SafeRegAdd "HKLM\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" "OptInOrOutPreference" REG_DWORD 0 "NVIDIA opt-out"
echo [OK] NVIDIA telemetry / tasks disabled.
pause
goto MenuAdvanced

:GpuAmd
echo  Detected AMD. This opts you out of the AMD User Experience Program - AMD's usage-data /
echo  telemetry collection - by writing the opt-out to the registry, with a backup (reversible).
echo  No bulk undocumented AMD register tweaks are applied; those can cause instability.
set /p "_c=Apply AMD telemetry opt-out? (Y/N): "
if /i not "%_c%"=="Y" goto MenuAdvanced
call :SafeRegAdd "HKLM\SOFTWARE\AMD\CN" "UserExperienceProgram" REG_DWORD 0 "AMD User Experience Program opt-out"
echo.
echo [OK] AMD User Experience Program opt-out written.
echo      AMD has no single guaranteed switch across driver versions, so to be sure also open
echo      AMD Software ^> Settings ^> Preferences and turn OFF: AMD User Experience Program,
echo      AMD Image Inspector, and Game Adjustment Tracking and Notifications.
pause
goto MenuAdvanced
rem =====================================================================================
rem  ACTION: GPU hardware scheduling (HAGS)
rem =====================================================================================
:HagsToggle
cls
call :Logo
echo =====================  GPU hardware scheduling (HAGS)  =============================
echo  HwSchMode in GraphicsDrivers: 2 = on (Windows default), 1 = off. Takes effect after a
echo  REBOOT. Needs Windows 10 2004+ and a GPU/driver that supports it - on older GPUs the
echo  setting is simply ignored. The on/off difference is usually small and system-specific;
echo  turning it OFF can help some capture/overlay stutter, but DISABLES features that need
echo  it ON - notably NVIDIA Frame Generation (DLSS 3). Backed up, so it stays reversible.
echo.
echo     1.  Turn HAGS OFF  (HwSchMode = 1)
echo     2.  Turn HAGS ON   (HwSchMode = 2, default)
echo     0.  Back
echo =====================================================================================

:HagsToggle_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto HagsToggle_ask
if "%sel%"=="1" goto HagsOff
if "%sel%"=="2" goto HagsOn
if "%sel%"=="0" goto MenuAdvanced
goto HagsToggle_ask

:HagsOff
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" REG_DWORD 1 "HAGS off"
echo [OK] HAGS set OFF. Reboot for the change to take effect.
pause
goto MenuAdvanced

:HagsOn
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" REG_DWORD 2 "HAGS on (default)"
echo [OK] HAGS set ON (default). Reboot for the change to take effect.
pause
goto MenuAdvanced

:ProcPriority
cls
call :Logo
echo =====================  PERMANENT PROCESS PRIORITY (per .exe)  ======================
echo  Pins a CPU priority that Windows re-applies every time that program starts, via
echo  Image File Execution Options (CpuPriorityClass). Backed up, so it stays reversible.
echo  Use the .exe that ACTUALLY runs (Task Manager -^> Details tab), not a launcher -
echo  High / Above-normal do NOT pass down to child processes. Realtime is not offered
echo  (it can starve Windows and freeze the machine).
echo =====================================================================================
set "_exe="
set /p "_exe=.exe name (e.g. game.exe), blank = cancel: "
if not defined _exe goto MenuAdvanced
set "_exe=!_exe:"=!"
if not defined _exe goto MenuAdvanced
for %%I in ("!_exe!") do set "_exe=%%~nxI"
if not defined _exe goto MenuAdvanced
if /i not "!_exe:~-4!"==".exe" set "_exe=!_exe!.exe"
if /i "!_exe!"==".exe" (echo   Please enter a real .exe name. & pause & goto MenuAdvanced)
echo.
echo  Priority for !_exe!:
echo     1.  High            (demanding games; use sparingly)
echo     2.  Above normal    (a gentler boost than High)
echo     3.  Normal          (Windows default)
echo     4.  Below normal
echo     5.  Low / Idle      (background apps you want out of the way)
echo     6.  Remove override (delete the setting -^> back to default)
echo     0.  Cancel
set "_plv="
set "_pln="
set "_pl="
set /p "_pl=Choose: "
if "!_pl!"=="0" goto MenuAdvanced
if "!_pl!"=="6" goto _ppRemove
if "!_pl!"=="1" (set "_plv=3" & set "_pln=High")
if "!_pl!"=="2" (set "_plv=6" & set "_pln=Above normal")
if "!_pl!"=="3" (set "_plv=2" & set "_pln=Normal")
if "!_pl!"=="4" (set "_plv=5" & set "_pln=Below normal")
if "!_pl!"=="5" (set "_plv=1" & set "_pln=Low/Idle")
if not defined _plv goto MenuAdvanced
call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\!_exe!\PerfOptions" "CpuPriorityClass" REG_DWORD !_plv! "Priority !_pln! for !_exe!"
echo.
echo [OK] !_exe! priority set to !_pln!. Close and reopen the program for it to take effect.
pause
goto MenuAdvanced

:_ppRemove
call :SafeRegDelete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\!_exe!\PerfOptions" "CpuPriorityClass" "Remove priority override for !_exe!"
echo.
echo [OK] Priority override for !_exe! removed (back to Windows default).
pause
goto MenuAdvanced
rem =====================================================================================
rem  ACTION: Backups & status
rem =====================================================================================
:DoRestorePoint
cls
call :Logo
echo ===========================  Create restore point  ================================
call :CreateRestorePoint
pause
goto MenuBackups

:DoRegBackup
cls
call :Logo
echo ===========================  Full registry backup  ================================
call :CreateRegBackup
pause
goto MenuBackups

:Status
cls
call :Logo
echo ===============================  CURRENT STATUS  ==================================
echo   OS build %WIN_BUILD%   Win11=%IS_WIN11%   GPU=%GPU%
echo -----------------------------------------------------------------------------------
echo [Power plan]
for /f "tokens=*" %%i in ('powercfg /getactivescheme') do echo   %%i
echo [Hibernation]  (0x0 = off, 0x1 = on)
call :ShowReg "HKLM\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled"
echo [Min processor state]  (this script can set 5%%)
start "" /min /wait powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; $g=[regex]::Match(((powercfg /getactivescheme) -join ' '),'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}').Value; $p='HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\'+$g+'\54533251-82be-4824-96c1-47b60b740d00\893dee8e-2bef-41e0-89c6-b55d0929964c'; $ac=(Get-ItemProperty -Path $p).ACSettingIndex; $dc=(Get-ItemProperty -Path $p).DCSettingIndex; if($ac -ne $null){ $s='  AC=' + $ac + '%%   DC=' + $dc + '%%' } else { $s='  (using scheme default)' }; $s | Out-File -FilePath (Join-Path $env:TEMP 'pt_mps.txt') -Encoding ASCII"
if exist "%TEMP%\pt_mps.txt" ( type "%TEMP%\pt_mps.txt" & del "%TEMP%\pt_mps.txt" >nul 2>&1 )
echo [DNS - adapters with DNS configured]
start "" /min /wait powershell -NoProfile -Command "Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.ServerAddresses} | ForEach-Object { '  ' + $_.InterfaceAlias + ': ' + ($_.ServerAddresses -join ', ') } | Out-File -FilePath (Join-Path $env:TEMP 'pt_dns.txt') -Encoding ASCII"
if exist "%TEMP%\pt_dns.txt" ( type "%TEMP%\pt_dns.txt" & del "%TEMP%\pt_dns.txt" >nul 2>&1 )
echo [Key tweaks]
call :ShowReg "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex"
call :ShowReg "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness"
call :ShowReg "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation"
call :ShowReg "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache"
call :ShowReg "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride"
call :ShowReg "HKCU\System\GameConfigStore" "GameDVR_Enabled"
call :ShowReg "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents"
echo [GPU scheduling / HAGS]  (0x2 = on/default, 0x1 = off; toggle under Advanced)
call :ShowReg "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode"
echo [TCP global]
netsh int tcp show global | findstr ":"
echo [CPU mitigations] FeatureSettingsOverride above: 3=disabled, 0/(not set)=on.
echo                   Detail: PowerShell ^> Get-SpeculationControlSettings
echo [Memory compression]  (True = on/default, False = disabled via Advanced)
start "" /min /wait powershell -NoProfile -Command "try{ $m=Get-MMAgent; $s='  MemoryCompression=' + $m.MemoryCompression + '   PageCombining=' + $m.PageCombining }catch{ $s='  (MMAgent not available on this system)' }; $s | Out-File -FilePath (Join-Path $env:TEMP 'pt_mma.txt') -Encoding ASCII"
if exist "%TEMP%\pt_mma.txt" ( type "%TEMP%\pt_mma.txt" & del "%TEMP%\pt_mma.txt" >nul 2>&1 )
echo [hosts file]
for /f %%c in ('find /c /v "" ^< "%SystemRoot%\System32\drivers\etc\hosts"') do echo   %%c lines total
echo [OpenAsar]  (app.asar well under 1 MB = OpenAsar; ~9 MB = stock Discord)
start "" /min /wait powershell -NoProfile -Command "Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Discord\app-*\resources\app.asar') -ErrorAction SilentlyContinue | ForEach-Object { '  ' + [math]::Round($_.Length/1MB,2) + ' MB  ' + $_.FullName } | Out-File -FilePath (Join-Path $env:TEMP 'pt_asar.txt') -Encoding ASCII"
if exist "%TEMP%\pt_asar.txt" ( type "%TEMP%\pt_asar.txt" & del "%TEMP%\pt_asar.txt" >nul 2>&1 )
echo =====================================================================================
pause
goto MenuBackups
rem =====================================================================================
rem  ACTION: Apply recommended safe set
rem =====================================================================================
:ApplyRecommended
cls
call :Logo
echo =========================  Apply recommended safe set  ============================
echo  Runs Cleanup + Privacy + Performance + Power + Network core tweaks with no prompts.
echo  Optional/risky items are NOT included. A restore point first is strongly advised.
echo =====================================================================================
set /p "_rp=Create a System Restore Point now? (Y/N): "
if /i "%_rp%"=="Y" call :CreateRestorePoint
set /p "_c=Proceed with the recommended set? (Y/N): "
if /i not "%_c%"=="Y" goto MainMenu
call :DoCleanupCore
call :DoPrivacyCore
call :DoPerformanceCore
call :DoPowerCore
call :DoNetworkCore
echo.
echo [OK] Recommended set applied. Reboot recommended.
pause
goto MainMenu
rem =====================================================================================
rem  INFO: What was excluded
rem =====================================================================================
:Excluded
cls
call :Logo
echo =========================  What was left out (and why)  ===========================
echo  This script intentionally does NOT include, by category:
echo.
echo  Security-weakening (excluded):
echo    - Disabling Windows Defender, Firewall, UAC or SmartScreen
echo    - Removing the "downloaded from the Internet" warning on executables
echo    - Fully disabling Windows Update or pointing it at a fake update server
echo    - Disabling VBS / HVCI via buggy boot edits
echo    - Boot flags that turn off DEP, anti-malware early launch, or the hypervisor
echo      (those also break WSL2 / Hyper-V / Sandbox)
echo.
echo  Placebo / obsolete / harmful (excluded):
echo    - XP-era "memory optimization" registry values (fixed pool/cache sizes etc.)
echo    - Forcing the large system file cache on by default (it is opt-in under Performance)
echo    - Clearing the pagefile at shutdown (only makes shutdown slower)
echo    - Firewall rules that block Google/YouTube IP ranges to "stop throttling" (a myth)
echo    - Deprecated TCP options (Chimney/NetDMA) removed by Microsoft years ago
echo    - Hardcoded MTU and other link-specific values copied from another PC
echo    - Uninstalling old Windows 7/8.1 "telemetry" updates (irrelevant on 10/11)
echo    - Bulk undocumented GPU registry dumps (only vendor telemetry-off is kept, in Advanced)
echo.
echo  From the gaming optimization guide (left out on purpose):
echo    - Windows activation scripts (MAS) - licensing/trust, not a performance tweak
echo    - Replacing Defender with a third-party AV (e.g. Panda) - no FPS gain, changes security
echo    - Aggressive RAM / standby "cleaners" (ISLC empty-standby-list) - placebo to harmful
echo    - Forcing MSI mode, and NIC edits (jumbo frames, offloads) - the guide advises against these
echo.
echo  Note: disabling CPU mitigations and the large system cache ARE available, but only as
echo  explicit opt-in choices (Advanced / Performance) - never in the recommended set.
echo =====================================================================================
pause
goto MainMenu
rem =====================================================================================
rem  HELPERS
rem =====================================================================================
:Logo
echo.
echo                           SSSS   III   N   N
echo                           S       I    NN  N
echo                           SSSS    I    N N N
echo                               S   I    N  NN
echo                           SSSS   III   N   N
echo.
goto :eof

:Log
rem  Capture the message first, then echo it via DELAYED expansion. A literal ">" inside the
rem  message (e.g. the "-> path" we log) must not be seen by the parser as a redirection - if
rem  it were, a path like "C:\Program Files\.." would be split and create a stray "C:\Program".
set "_LOGLN=%~1"
>>"%LOGFILE%" echo [%date% %time%] !_LOGLN!
goto :eof

:TimerResApply
cls
call :Logo
echo =========================  Apply timer resolution  ===============================
echo  Installs SetTimerResolution to run hidden at every logon (Task Scheduler) and hold
echo  a higher Windows timer resolution. On Windows 10 2004+ / 11 it also sets
echo  GlobalTimerResolutionRequests=1 so the change is system-wide (this needs a REBOOT).
echo  Reversible via option 7 (Remove timer resolution).
echo =====================================================================================
call :RequireBundledFile SetTimerResolution.exe "raises the Windows timer resolution (autostart helper)"
echo.
echo  Resolution is in 100ns units:  5000 = 0.5 ms (typical best),  10000 = 1 ms.
echo  The TimerResolution tool's MeasureSleep can find the best value for your PC.
set "_res="
set /p "_res=Resolution in 100ns units [Enter = 5000]: "
if not defined _res set "_res=5000"
set "_bad="
for /f "delims=0123456789" %%x in ("%_res%") do set "_bad=1"
if defined _bad (
    echo [ERROR] "%_res%" must be a whole number ^(100ns units^). Aborting.
    pause
    goto MenuApps
)
set "_c="
set /p "_c=Install the timer-resolution autostart with resolution %_res%? (Y/N): "
if /i not "%_c%"=="Y" goto MenuApps
set "_TRDIR=%ProgramData%\Sincript"
if not exist "%_TRDIR%" md "%_TRDIR%" >nul 2>&1
copy /y "%SCRIPT_DIR%SetTimerResolution.exe" "%_TRDIR%\SetTimerResolution.exe" >nul
if errorlevel 1 (
    echo [ERROR] Could not copy SetTimerResolution.exe to "%_TRDIR%".
    call :Log "TIMERRES copy failed"
    pause
    goto MenuApps
)
call :Log "TIMERRES helper copied to %_TRDIR%"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" REG_DWORD 1 "Global timer resolution requests on"
schtasks /Create /F /TN "Sincript Timer Resolution" /SC ONLOGON /RL HIGHEST /TR "%_TRDIR%\SetTimerResolution.exe --resolution %_res% --no-console" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Could not create the scheduled task ^(schtasks failed^).
    call :Log "TIMERRES schtasks create failed"
    pause
    goto MenuApps
)
call :Log "TIMERRES task created res=%_res%"
taskkill /f /im SetTimerResolution.exe >nul 2>&1
schtasks /Run /TN "Sincript Timer Resolution" >nul 2>&1
echo.
echo [OK] Timer-resolution autostart installed (resolution %_res%). Runs hidden at logon.
echo      REBOOT for the system-wide effect (GlobalTimerResolutionRequests) to take hold.
pause
goto MenuApps

:TimerResRemove
cls
call :Logo
echo ========================  Remove timer resolution  ===============================
echo  Removes the SetTimerResolution autostart: deletes the scheduled task, stops the
echo  hidden helper and deletes the copied file. You can also revert the system-wide
echo  registry switch (that revert needs a REBOOT).
echo =====================================================================================
set "_c="
set /p "_c=Remove the timer-resolution autostart? (Y/N): "
if /i not "%_c%"=="Y" goto MenuApps
schtasks /Delete /F /TN "Sincript Timer Resolution" >nul 2>&1
taskkill /f /im SetTimerResolution.exe >nul 2>&1
if exist "%ProgramData%\Sincript\SetTimerResolution.exe" del /f /q "%ProgramData%\Sincript\SetTimerResolution.exe" >nul 2>&1
rd "%ProgramData%\Sincript" >nul 2>&1
call :Log "TIMERRES removed (task + helper)"
echo [OK] Autostart removed and the helper stopped.
echo.
set "_c2="
set /p "_c2=Also revert GlobalTimerResolutionRequests to default (off)? (Y/N): "
if /i "%_c2%"=="Y" (
    call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolutionRequests" REG_DWORD 0 "Global timer resolution requests off"
    echo [OK] Reverted. REBOOT to fully apply.
)
pause
goto MenuApps

:Debloat
cls
call :Logo
echo ===============================  Remove built-in apps  ============================
echo  Removes built-in Microsoft Store apps (telemetry / ads / rarely-used). Each group
echo  is opt-in below. This is NOT covered by the .reg backups: to get an app back you
echo  reinstall it from the Microsoft Store. Apps you actually use, just answer N.
echo =====================================================================================
set "_c="
set /p "_c=Remove the standard bloat set (Copilot, Bing apps, Teams, Office hub, Solitaire, etc.)? (Y/N): "
if /i not "%_c%"=="Y" goto DebloatOpt
call :Log "DEBLOAT standard set"
echo Removing standard bloat (a minimized window may flash)...
start "" /min /wait powershell -NoProfile -Command "$p=@('MicrosoftCorporationII.QuickAssist','Microsoft.WindowsFeedbackHub','Microsoft.Copilot','Microsoft.BingWeather','MicrosoftCorporationII.MicrosoftFamily','Microsoft.MicrosoftOfficeHub','Microsoft.BingSearch','Clipchamp.Clipchamp','MSTeams','Microsoft.Todos','Microsoft.MicrosoftStickyNotes','Microsoft.BingNews','Microsoft.OutlookForWindows','Microsoft.WindowsAlarms','Microsoft.MicrosoftSolitaireCollection'); foreach($x in $p){Get-AppxPackage -AllUsers $x | Remove-AppxPackage -ErrorAction SilentlyContinue}"
echo [OK] Standard bloat removed where present.

:DebloatOpt
echo.
set "_c2="
set /p "_c2=Also remove optional apps (Camera, Sound Recorder, Snipping Tool, Power Automate, Xbox)? (Y/N): "
if /i not "%_c2%"=="Y" goto DebloatOneDrive
call :Log "DEBLOAT optional apps"
echo Removing optional apps (a minimized window may flash)...
start "" /min /wait powershell -NoProfile -Command "$p=@('Microsoft.WindowsCamera','Microsoft.WindowsSoundRecorder','Microsoft.ScreenSketch','Microsoft.PowerAutomateDesktop','Microsoft.Xbox.TCUI','Microsoft.GamingApp'); foreach($x in $p){Get-AppxPackage -AllUsers $x | Remove-AppxPackage -ErrorAction SilentlyContinue}"
echo [OK] Optional apps removed where present.

:DebloatOneDrive
echo.
set "_c4="
set /p "_c4=Also remove OneDrive (uninstall it and remove the sync app)? (Y/N): "
if /i not "%_c4%"=="Y" goto DebloatDone
call :Log "DEBLOAT OneDrive"
echo Removing OneDrive (a minimized window may flash)...
start "" /min /wait powershell -NoProfile -Command "Get-AppxPackage -AllUsers Microsoft.OneDriveSync | Remove-AppxPackage -ErrorAction SilentlyContinue; Start-Process -FilePath ($env:SystemRoot + '\System32\OneDriveSetup.exe') -ArgumentList '/uninstall' -NoNewWindow -Wait -ErrorAction SilentlyContinue"
echo [OK] OneDrive removed.

:DebloatDone
echo.
echo Done. Any removed app can be reinstalled later from the Microsoft Store.
pause
goto MenuApps

:RequireBundledFile
rem %1 = filename beside PerfTweaks.cmd   %2 = short description for messages/log
set "_bundled=%SCRIPT_DIR%%~1"
set "_bundled_sz="
if exist "%_bundled%" for %%F in ("%_bundled%") do set "_bundled_sz=%%~zF"
if exist "%_bundled%" if defined _bundled_sz if not "!_bundled_sz!"=="0" goto :eof
echo.
if not exist "%_bundled%" (
    echo [ERROR] Bundled file not found: %~1
) else (
    echo [ERROR] Bundled file is empty: %~1
)
echo.
echo   Expected location:
echo     %_bundled%
echo.
echo   Used for: %~2
echo.
echo   Fix: copy %~1 into the same folder as PerfTweaks.cmd, then run this option again.
echo        It is listed under "Optional bundled files" in the Sincript README.
call :Log "ABORT: missing/empty bundled %~1 (%~2)"
pause
goto MenuApps

:DetectUnityJobWorkers
rem Sets _JWCOUNT and _CORESRC. Logical processors (threads) - 1 when detectable; else prompt.
setlocal EnableDelayedExpansion
set "_JWCOUNT="
set "_CORESRC="
set "_LOGI=0"
rem  Run PowerShell in a SEPARATE minimized window (keeps this console's font intact),
rem  write the logical-processor (thread) count to a temp file, then read it back.
start "" /min /wait powershell -NoProfile -Command "try{$s=(Get-CimInstance Win32_Processor|Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum;if(-not $s){$s=0}}catch{$s=0}; $s | Out-File -FilePath (Join-Path $env:TEMP 'pt_cores.txt') -Encoding ASCII"
if exist "%TEMP%\pt_cores.txt" for /f "usebackq tokens=1 delims= " %%N in ("%TEMP%\pt_cores.txt") do set "_LOGI=%%N"
del "%TEMP%\pt_cores.txt" >nul 2>&1
if !_LOGI! gtr 0 (
    set /a "_JWCOUNT=!_LOGI!-1"
    set "_CORESRC=!_LOGI! logical processors"
    goto DetectUnityJobWorkers_clamp
)
for /f "tokens=2 delims==" %%C in ('wmic cpu get NumberOfLogicalProcessors /value 2^>nul ^| findstr /I "NumberOfLogicalProcessors"') do set /a "_LOGI+=%%C" 2>nul
if !_LOGI! gtr 0 (
    set /a "_JWCOUNT=!_LOGI!-1"
    set "_CORESRC=!_LOGI! logical processors (WMIC)"
    goto DetectUnityJobWorkers_clamp
)
if defined NUMBER_OF_PROCESSORS (
    set /a "_JWCOUNT=%NUMBER_OF_PROCESSORS%-1"
    set "_CORESRC=%NUMBER_OF_PROCESSORS% logical processors"
    goto DetectUnityJobWorkers_clamp
)
echo.
echo [WARN] Could not detect CPU core count automatically.

:DetectUnityJobWorkers_ask
set "_in="
set /p "_in=Enter job-worker count for Unity (usually logical CPUs minus 1, e.g. 7 for 8 threads): "
if not defined _in goto DetectUnityJobWorkers_ask
echo !_in!| findstr /R "^[0-9][0-9]*$" >nul || (
    echo [ERROR] Enter a whole number between 1 and 32.
    goto DetectUnityJobWorkers_ask
)
set "_JWCOUNT=!_in!"
set "_CORESRC=user specified"
goto DetectUnityJobWorkers_clamp

:DetectUnityJobWorkers_clamp
if !_JWCOUNT! lss 1 set "_JWCOUNT=1"
if !_JWCOUNT! gtr 32 set "_JWCOUNT=32"
set "_DJW=!_JWCOUNT!"
set "_DCS=!_CORESRC!"
endlocal & set "_JWCOUNT=%_DJW%" & set "_CORESRC=%_DCS%"
goto :eof

:PrepareBootConfig
rem %1=source boot.config  %2=temp output path  %3=job-worker count (both worker keys set to this)
rem  Run PowerShell in a SEPARATE minimized window (keeps this console's font intact);
rem  paths are passed via environment variables so spaces/quotes can't break the command,
rem  and start /wait hands the child's exit code back to errorlevel.
set "PT_SRC=%~1"
set "PT_OUT=%~2"
set "PT_JW=%~3"
start "" /min /wait powershell -NoProfile -Command "try{$n=$env:PT_JW;$out=@();foreach($line in Get-Content -LiteralPath $env:PT_SRC){if($line -match '^job-worker-count='){$out+='job-worker-count='+$n}elseif($line -match '^job-worker-maximum-count='){$out+='job-worker-maximum-count='+$n}else{$out+=$line}};Set-Content -LiteralPath $env:PT_OUT -Value $out -Encoding ASCII;exit 0}catch{exit 1}"
set "_pbc=%errorlevel%"
set "PT_SRC=" & set "PT_OUT=" & set "PT_JW="
if "%_pbc%"=="1" exit /b 1
if not exist "%~2" exit /b 1
exit /b 0

:Run
rem %1 = full command line (echoed, logged, run via cmd /s /c)
set "_cmd=%~1"
rem  Log a quote-stripped copy of the command: with the embedded quotes gone, the whole line
rem  is captured intact, and there is nothing the log step could misread as a redirection.
set "_cmdlog=%_cmd:"=%"
echo   ^> %_cmd%
call :Log "EXEC: %_cmdlog%"
cmd /s /c "%_cmd%" 1>>"%LOGFILE%" 2>>&1
if errorlevel 1 ( call :Log "FAIL: %_cmdlog%" ) else ( call :Log "OK: %_cmdlog%" )
goto :eof

:ApplyDns
rem %1 = friendly name ; uses %DNSSRV% as the PowerShell address list
echo Setting %~1 DNS (IPv4 + IPv6) on all active adapters...
call :Log "DNS -> %~1 : %DNSSRV%"
start "" /min /wait powershell -NoProfile -Command "Get-NetAdapter -Physical | ForEach-Object { try { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses @(%DNSSRV%) -ErrorAction Stop } catch {} }"
ipconfig /flushdns >nul 2>&1
echo [OK] %~1 DNS applied. Check it under Backups ^& status ^> Show current status.
goto :eof

:ShowReg
rem %1 = key ; %2 = value name ; prints "value = data" or "(not set)"
set "_found="
set "_srd="
for /f "tokens=2,*" %%a in ('reg query "%~1" /v "%~2" 2^>nul ^| findstr /I /C:"%~2"') do (set "_srd=%%b" & set "_found=1")
if not defined _found echo   %~2 = (not set)
if defined _found echo   %~2 = !_srd!
goto :eof

:SafeRegAdd
rem %1=Key %2=Value %3=Type %4=Data %5=Description.
rem Backs up ONLY the single value being changed (not the whole key + subkeys), so a tweak
rem under a big key (Memory Management, Power, etc.) no longer makes a 100+ MB .reg export.
setlocal EnableDelayedExpansion
set "_key=%~1"
set "_val=%~2"
set "_type=%~3"
set "_data=%~4"
set "_desc=%~5"
echo   [REG] !_desc!
set "_ln="
for /f "delims=" %%L in ('reg query "!_key!" /v "!_val!" 2^>nul ^| findstr /I /C:"REG_"') do set "_ln=%%L"
if defined PRESET_MODE goto _sraJson
rem  ----- manual mode: back up ONLY this single value to its own .reg file -----
set "_safe=!_key:\=_!"
set "_safe=!_safe::=!"
set "_safe=!_safe: =_!"
set "_bkp=%BACKUP_DIR%\!_safe!_%RANDOM%.reg"
rem  expand the hive short name to the full name a .reg file requires
set "_rk=!_key!"
set "_rk=!_rk:HKLM\=HKEY_LOCAL_MACHINE\!"
set "_rk=!_rk:HKCU\=HKEY_CURRENT_USER\!"
set "_rk=!_rk:HKCR\=HKEY_CLASSES_ROOT\!"
set "_rk=!_rk:HKU\=HKEY_USERS\!"
set "_rk=!_rk:HKCC\=HKEY_CURRENT_CONFIG\!"
> "!_bkp!" echo Windows Registry Editor Version 5.00
>>"!_bkp!" echo.
>>"!_bkp!" echo [!_rk!]
call :BackupValueLine
goto _sraApply

:_sraJson
rem  ----- preset mode: append this value's prior state to the JSON backup -----
call :BackupValueJson

:_sraApply
call :Log "REGADD !_key! !_val!=!_data! (!_desc!)"
reg add "!_key!" /v "!_val!" /t !_type! /d "!_data!" /f >nul 2>&1
if errorlevel 1 ( call :Log "  FAIL regadd !_key! !_val!" ) else ( call :Log "  OK regadd !_key! !_val!" )
endlocal
goto :eof

:SafeRegDelete
rem %1=Key %2=Value %3=Description. Backs up the single value (same as SafeRegAdd), then deletes it.
setlocal EnableDelayedExpansion
set "_key=%~1"
set "_val=%~2"
set "_desc=%~3"
echo   [REG] !_desc!
set "_ln="
for /f "delims=" %%L in ('reg query "!_key!" /v "!_val!" 2^>nul ^| findstr /I /C:"REG_"') do set "_ln=%%L"
if not defined _ln ( call :Log "REGDEL !_key! !_val! (already absent)" & endlocal & goto :eof )
if defined PRESET_MODE goto _srdJson
set "_safe=!_key:\=_!"
set "_safe=!_safe::=!"
set "_safe=!_safe: =_!"
set "_bkp=%BACKUP_DIR%\!_safe!_%RANDOM%.reg"
set "_rk=!_key!"
set "_rk=!_rk:HKLM\=HKEY_LOCAL_MACHINE\!"
set "_rk=!_rk:HKCU\=HKEY_CURRENT_USER\!"
set "_rk=!_rk:HKCR\=HKEY_CLASSES_ROOT\!"
set "_rk=!_rk:HKU\=HKEY_USERS\!"
set "_rk=!_rk:HKCC\=HKEY_CURRENT_CONFIG\!"
> "!_bkp!" echo Windows Registry Editor Version 5.00
>>"!_bkp!" echo.
>>"!_bkp!" echo [!_rk!]
call :BackupValueLine
goto _srdApply

:_srdJson
call :BackupValueJson

:_srdApply
call :Log "REGDEL !_key! !_val! (!_desc!)"
reg delete "!_key!" /v "!_val!" /f >nul 2>&1
if errorlevel 1 ( call :Log "  FAIL regdel !_key! !_val!" ) else ( call :Log "  OK regdel !_key! !_val!" )
endlocal
goto :eof

:BackupValueLine
rem  appends the prior state of ONE value to !_bkp! (runs inside SafeRegAdd's setlocal scope)
if not defined _ln (
    >>"!_bkp!" echo "!_val!"=-
    goto :eof
)
set "_td=REG_!_ln:*REG_=!"
for /f "tokens=1,*" %%a in ("!_td!") do ( set "_rt=%%a" & set "_rd=%%b" )
if /i "!_rt!"=="REG_DWORD" (
    set "_hx=0000000!_rd:~2!"
    >>"!_bkp!" echo "!_val!"=dword:!_hx:~-8!
    goto :eof
)
if /i "!_rt!"=="REG_SZ" (
    set "_sd=!_rd:\=\\!"
    >>"!_bkp!" echo "!_val!"="!_sd!"
    goto :eof
)
>>"!_bkp!" echo ; original value was !_rt! = !_rd!
>>"!_bkp!" echo ; not auto-restorable from this file - use the full registry backup or a restore point
goto :eof

:CreateRestorePoint
echo Creating a System Restore Point (may take a moment)...
call :Log "Creating restore point"
start "" /min /wait powershell -NoProfile -Command "& { try { Enable-ComputerRestore -Drive '%SystemDrive%\' -ErrorAction SilentlyContinue; Checkpoint-Computer -Description 'PerfTweaks' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop; 'Restore point created.' } catch { 'Restore point failed (System Protection off, or one was made in the last 24h): ' + $_.Exception.Message } } | Out-File -FilePath (Join-Path $env:TEMP 'pt_rp.txt') -Encoding ASCII"
if exist "%TEMP%\pt_rp.txt" ( type "%TEMP%\pt_rp.txt" & del "%TEMP%\pt_rp.txt" >nul 2>&1 )
goto :eof

:CreateRegBackup
echo Exporting HKLM and HKCU (this can take a minute)...
call :Log "Full registry export"
reg export HKLM "%BACKUP_DIR%\FullReg_HKLM_%RANDOM%.reg" /y >nul 2>&1
reg export HKCU "%BACKUP_DIR%\FullReg_HKCU_%RANDOM%.reg" /y >nul 2>&1
echo [OK] Saved to %BACKUP_DIR%
goto :eof

:InstallAsarInto
rem %1 = base dir (e.g. %LocalAppData%\Discord) ; %2 = flavor label ; %3 = source .asar
setlocal EnableDelayedExpansion
set "_base=%~1"
set "_flav=%~2"
set "_src=%~3"
set "_res="
for /f "delims=" %%A in ('dir /b /ad /o-n "%_base%\app-*" 2^>nul') do (
    if not defined _res if exist "%_base%\%%A\resources\" set "_res=%_base%\%%A\resources"
)
if not defined _res ( echo [SKIP] %_flav%: no app-*\resources folder. & endlocal & goto :eof )
set "_target=app.asar"
if exist "%_res%\_app.asar"     set "_target=_app.asar"
if exist "%_res%\app.orig.asar" set "_target=app.orig.asar"
if exist "%_res%\app.asar.orig" set "_target=app.asar.orig"
echo [%_flav%] Target: "%_res%\!_target!"
if exist "%_res%\!_target!" (
    copy /y "%_res%\!_target!" "%_res%\!_target!.bak" >nul 2>&1
    copy /y "%_res%\!_target!" "%BACKUP_DIR%\%_flav%_!_target!.bak" >nul 2>&1
)
copy /y "%_src%" "%_res%\!_target!" >nul
if errorlevel 1 (
    echo [WARN] %_flav%: copy failed ^(file in use? quit Discord fully and re-run^).
) else (
    echo [OK] %_flav%: OpenAsar installed. Backup: "!_target!.bak"
    endlocal & set "_DONE=1" & goto :eof
)
endlocal
goto :eof
rem =====================================================================================
rem  PRESETS  -  auto-apply groups of tweaks; registry changes saved to ONE JSON backup
rem =====================================================================================
:MenuPresets
cls
call :Logo
echo ==============================  AUTO-APPLY PRESETS  ===============================
echo  A preset applies a defined group of tweaks at once and saves ONE JSON backup of the
echo  registry values it changes (manual menu actions still save individual .reg files).
echo  Power-plan / DNS / BCD / service changes revert from their own menu items.
echo -----------------------------------------------------------------------------------
echo     1.  Light     (temp cleanup, privacy, TCP tweaks, DNS)
echo     2.  Moderate  (recommended safe set + power plan + OpenAsar)
echo     3.  Heavy     (most tweaks; NO repair / NO stack reset / NO debloat / NO mitigations)
echo     4.  Custom    (load a user preset from the sincript_presets folder)
echo     5.  Restore from a preset backup (JSON)
echo     0.  Back
echo =====================================================================================

:MenuPresets_ask
set "sel="
set /p "sel=Choose: "
if not defined sel goto MenuPresets_ask
if "%sel%"=="1" goto PresetLight
if "%sel%"=="2" goto PresetModerate
if "%sel%"=="3" goto PresetHeavy
if "%sel%"=="4" goto PresetCustom
if "%sel%"=="5" goto RestorePresetJson
if "%sel%"=="0" goto MainMenu
goto MenuPresets
rem ---------- preset capture helpers ----------
:PresetBegin
rem %1 = preset label used in the backup filename
set "_pname=%~1"
set "PRESET_JSON=%BACKUP_DIR%\Preset_%_pname%_%RANDOM%%RANDOM%.json"
set "PRESET_JSON_TMP=%PRESET_JSON%.tmp"
break>"%PRESET_JSON_TMP%"
set "PRESET_MODE=1"
call :Log "PRESET begin: %_pname%"
echo.
echo Applying preset "%_pname%" - registry changes are being captured to one JSON backup.
echo.
goto :eof

:PresetEnd
rem  Turn the captured JSONL temp into a proper JSON array, then drop the temp.
set "PRESET_MODE="
call :Log "PRESET end -> %PRESET_JSON%"
set "PT_TMP=%PRESET_JSON_TMP%"
set "PT_FINAL=%PRESET_JSON%"
start "" /min /wait powershell -NoProfile -Command "$t=$env:PT_TMP;$f=$env:PT_FINAL;if(Test-Path -LiteralPath $t){$o=@(Get-Content -LiteralPath $t | Where-Object {$_ -match '\S'});Set-Content -LiteralPath $f -Value ('['+($o -join ',')+']') -Encoding ASCII}else{Set-Content -LiteralPath $f -Value '[]' -Encoding ASCII}"
del "%PRESET_JSON_TMP%" >nul 2>&1
set "PRESET_LAST=%PRESET_JSON%"
set "PT_TMP="
set "PT_FINAL="
set "PRESET_JSON="
set "PRESET_JSON_TMP="
goto :eof

:PresetDnsChoice
rem  interactive DNS picker for the built-in presets (the user asked to be prompted)
echo.
echo  DNS for this preset:   1=Cloudflare   2=Google   3=Quad9   4=Skip (leave as-is)
set "_dc="
set /p "_dc=Choose DNS [1-4]: "
if "%_dc%"=="1" goto _pdnscf
if "%_dc%"=="2" goto _pdnsgg
if "%_dc%"=="3" goto _pdnsq9
echo  Leaving DNS unchanged.
goto :eof

:_pdnscf
set "DNSSRV='1.1.1.1','1.0.0.1','2606:4700:4700::1111','2606:4700:4700::1001'"
call :ApplyDns "Cloudflare"
goto :eof

:_pdnsgg
set "DNSSRV='8.8.8.8','8.8.4.4','2001:4860:4860::8888','2001:4860:4860::8844'"
call :ApplyDns "Google"
goto :eof

:_pdnsq9
set "DNSSRV='9.9.9.9','149.112.112.112','2620:fe::fe','2620:fe::9'"
call :ApplyDns "Quad9"
goto :eof

:PresetDnsByName
rem %1 = cloudflare | google | quad9   (used by custom presets, no prompt)
if /i "%~1"=="cloudflare" set "DNSSRV='1.1.1.1','1.0.0.1','2606:4700:4700::1111','2606:4700:4700::1001'"
if /i "%~1"=="google"     set "DNSSRV='8.8.8.8','8.8.4.4','2001:4860:4860::8888','2001:4860:4860::8844'"
if /i "%~1"=="quad9"      set "DNSSRV='9.9.9.9','149.112.112.112','2620:fe::fe','2620:fe::9'"
call :ApplyDns "%~1"
goto :eof
rem ---------- returnable tweak wrappers (reused by heavy + custom presets) ----------
:DoSysResp0
call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" REG_DWORD 0 "SystemResponsiveness 0"
goto :eof

:DoNetThrottleOff
call :SafeRegAdd "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" REG_DWORD 4294967295 "Network throttling off"
goto :eof

:DoWin32_42
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" REG_DWORD 42 "Win32PrioritySeparation = 42 (0x2A)"
goto :eof

:DoWin32_26
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" REG_DWORD 26 "Win32PrioritySeparation = 26 (0x1A)"
goto :eof

:DoWin32_2
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" REG_DWORD 2 "Win32PrioritySeparation default (2)"
goto :eof

:DoLargeCacheOn
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" REG_DWORD 1 "LargeSystemCache on"
goto :eof

:DoGameModeOff
call :SafeRegAdd "HKCU\Software\Microsoft\GameBar" "AutoGameModeEnabled" REG_DWORD 0 "Game Mode off"
call :SafeRegAdd "HKCU\Software\Microsoft\GameBar" "AllowAutoGameMode" REG_DWORD 0 "Auto Game Mode off"
goto :eof

:DoIpv6Off
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" REG_DWORD 255 "Disable IPv6 (0xFF)"
goto :eof

:DoNvmeFlags
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" "1176759950" REG_DWORD 1 "NVMe flag 1"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" "1853569164" REG_DWORD 1 "NVMe flag 2"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" "156965516" REG_DWORD 1 "NVMe flag 3"
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" "735209102" REG_DWORD 1 "NVMe flag 4"
goto :eof

:DoBcdTimers
call :Run "bcdedit /deletevalue useplatformclock"
call :Run "bcdedit /set useplatformtick yes"
call :Run "bcdedit /set disabledynamictick yes"
call :Run "bcdedit /set tscsyncpolicy enhanced"
goto :eof

:DoMemCompressOff
echo   ^> Disabling memory compression and page combining (separate window)...
call :Log "EXEC-PS (isolated): Disable-MMAgent (preset)"
start "" /min /wait powershell -NoProfile -Command "try{Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue}catch{}; try{Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue}catch{}"
goto :eof

:DoGpuTelemetryOff
if /i "%GPU%"=="amd" call :SafeRegAdd "HKLM\SOFTWARE\AMD\CN" "UserExperienceProgram" REG_DWORD 0 "AMD User Experience Program opt-out"
if /i not "%GPU%"=="nvidia" goto :eof
call :Run "schtasks /Change /Disable /TN ""NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :Run "schtasks /Change /Disable /TN ""NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"""
call :SafeRegAdd "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup" "SendTelemetryData" REG_DWORD 0 "NVIDIA telemetry off"
call :SafeRegAdd "HKLM\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" "OptInOrOutPreference" REG_DWORD 0 "NVIDIA opt-out"
goto :eof

:DoNagleOff
for /f "tokens=*" %%K in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" 2^>nul ^| findstr /R /C:"HKEY_LOCAL_MACHINE"') do (
    call :SafeRegAdd "%%K" "TcpAckFrequency" REG_DWORD 1 "Nagle: TcpAckFrequency"
    call :SafeRegAdd "%%K" "TCPNoDelay" REG_DWORD 1 "Nagle: TCPNoDelay"
    call :SafeRegAdd "%%K" "TcpDelAckTicks" REG_DWORD 0 "Nagle: TcpDelAckTicks"
)
goto :eof

:DoOpenAsarSilent
rem  Non-interactive OpenAsar install for presets: use a bundled app.asar if present,
rem  otherwise download the latest nightly. No prompts (Apps & files has the interactive one).
set "_SRC="
if exist "%SCRIPT_DIR%app.asar" set "_SRC=%SCRIPT_DIR%app.asar"
if defined _SRC goto _oasInstall
echo   ^> OpenAsar: no bundled app.asar found - downloading the latest nightly...
call :Log "PRESET OpenAsar: downloading nightly"
set "PT_OA=%TEMP%\openasar_nightly.asar"
del "%PT_OA%" >nul 2>&1
start "" /min /wait powershell -NoProfile -Command "try{Invoke-WebRequest -Uri 'https://github.com/GooseMod/OpenAsar/releases/download/nightly/app.asar' -OutFile $env:PT_OA -UseBasicParsing}catch{exit 1}"
if not exist "%PT_OA%" (
    echo [ERROR] OpenAsar download failed - skipping. Put app.asar next to the script and retry.
    call :Log "PRESET OpenAsar: download failed"
    set "PT_OA="
    goto :eof
)
set "_SRC=%PT_OA%"
set "PT_OA="

:_oasInstall
echo   ^> Installing OpenAsar into Discord (closing Discord first)...
call :Log "PRESET OpenAsar install from !_SRC!"
taskkill /f /im Discord.exe       >nul 2>&1
taskkill /f /im DiscordPTB.exe    >nul 2>&1
taskkill /f /im DiscordCanary.exe >nul 2>&1
timeout /t 2 >nul
set "_DONE=0"
for %%F in (Discord DiscordPTB DiscordCanary) do if exist "%LocalAppData%\%%F\" call :InstallAsarInto "%LocalAppData%\%%F" "%%F" "!_SRC!"
if "%_DONE%"=="0" echo [SKIP] OpenAsar: no Discord install with a resources\app.asar found.
if exist "%LocalAppData%\Discord\Update.exe" start "" "%LocalAppData%\Discord\Update.exe" --processStart Discord.exe
goto :eof
rem =====================================================================================
rem  PRESET: LIGHT
rem =====================================================================================
:PresetLight
cls
call :Logo
echo ==============================  PRESET: LIGHT  ====================================
echo  Applies: temp/log cleanup, privacy ^& telemetry hardening, TCP tuning, and a DNS
echo  choice. All registry changes go into ONE JSON backup. Reversible.
echo =====================================================================================
set "_c="
set /p "_c=Apply the LIGHT preset? (Y/N): "
if /i not "%_c%"=="Y" goto MenuPresets
call :PresetBegin light
call :DoCleanupCore
call :DoPrivacyCore
call :DoNetworkCore
call :PresetDnsChoice
call :PresetEnd
echo.
echo [OK] LIGHT preset applied. Registry backup:
echo      %PRESET_LAST%
echo      Reboot recommended.
pause
goto MenuPresets
rem =====================================================================================
rem  PRESET: MODERATE  (the recommended safe set + power + OpenAsar)
rem =====================================================================================
:PresetModerate
cls
call :Logo
echo =============================  PRESET: MODERATE  ==================================
echo  Applies the recommended safe set - cleanup, privacy, performance, power and network
echo  core tweaks - then offers to install OpenAsar. Registry changes go into ONE JSON
echo  backup. This is the same set as "Apply recommended safe set", plus OpenAsar.
echo =====================================================================================
set "_rp="
set /p "_rp=Create a System Restore Point first? (Y/N): "
if /i "%_rp%"=="Y" call :CreateRestorePoint
set "_c="
set /p "_c=Apply the MODERATE preset? (Y/N): "
if /i not "%_c%"=="Y" goto MenuPresets
call :PresetBegin moderate
call :DoCleanupCore
call :DoPrivacyCore
call :DoPerformanceCore
call :DoPowerCore
call :DoNetworkCore
call :PresetEnd
echo.
echo [OK] MODERATE preset applied. Registry backup:
echo      %PRESET_LAST%
echo.
set "_oa="
set /p "_oa=Also install OpenAsar into Discord now? (Y/N): "
if /i "%_oa%"=="Y" call :DoOpenAsarSilent
echo.
echo Reboot recommended.
pause
goto MenuPresets
rem =====================================================================================
rem  PRESET: HEAVY  (aggressive but reversible; no mitigations / repair / reset / debloat)
rem =====================================================================================
:PresetHeavy
cls
call :Logo
echo ==============================  PRESET: HEAVY  ====================================
echo  Aggressive but reversible. Applies the safe set PLUS: SystemResponsiveness=0,
echo  network throttling off, Win32PrioritySeparation=42, Game Mode off, Nagle/ACK off,
echo  IPv6 off, NVMe flags, GPU telemetry off (if applicable), BCD timer tweaks and
echo  memory compression off. It does NOT touch CPU mitigations, system repair, the
echo  network-stack reset, or debloat. Registry changes go into ONE JSON backup; the
echo  non-registry parts (DNS / BCD / memory compression) revert from their own menus.
echo  A REBOOT is required afterwards.
echo =====================================================================================
set "_rp="
set /p "_rp=Create a System Restore Point first? (strongly recommended) (Y/N): "
if /i "%_rp%"=="Y" call :CreateRestorePoint
set "_c="
set /p "_c=Apply the HEAVY preset? (Y/N): "
if /i not "%_c%"=="Y" goto MenuPresets
call :PresetBegin heavy
call :DoCleanupCore
call :DoPrivacyCore
call :DoPerformanceCore
call :DoPowerCore
call :DoNetworkCore
call :DoSysResp0
call :DoNetThrottleOff
call :DoWin32_42
call :DoGameModeOff
call :DoNagleOff
call :DoIpv6Off
call :DoNvmeFlags
call :DoGpuTelemetryOff
call :DoBcdTimers
call :DoMemCompressOff
call :PresetDnsChoice
call :PresetEnd
echo.
echo [OK] HEAVY preset applied. Registry backup:
echo      %PRESET_LAST%
echo      REBOOT required for the timer / IPv6 / memory-compression changes to take hold.
echo.
echo  Tip: to also enable a higher timer resolution, use  Apps ^& files ^> Apply timer
echo       resolution  (it needs the bundled SetTimerResolution.exe).
pause
goto MenuPresets
rem =====================================================================================
rem  PRESET: CUSTOM  (load a key=value file from sincript_presets\)
rem =====================================================================================
:PresetCustom
cls
call :Logo
echo ===============================  CUSTOM PRESET  ===================================
set "_pdir=%SCRIPT_DIR%sincript_presets"
if not exist "%_pdir%\" (
    echo  No "sincript_presets" folder was found next to the script.
    echo  Create it and add a text file named e.g.  mypreset.preset  with lines like:
    echo      cleanup=1
    echo      privacy=1
    echo      dns=cloudflare
    echo  See the Sincript README, section Custom presets, for the full list of keys.
    echo.
    pause
    goto MenuPresets
)
set "_pn=0"
for %%F in ("%_pdir%\*.preset") do (
    set /a _pn+=1
    set "_pf[!_pn!]=%%~fF"
    set "_pnm[!_pn!]=%%~nxF"
)
if "%_pn%"=="0" (
    echo  The "sincript_presets" folder has no *.preset files yet.
    echo  Add a text file named e.g.  mypreset.preset  - see the README for the key list.
    echo.
    pause
    goto MenuPresets
)
echo  Available preset files in sincript_presets\:
for /l %%I in (1,1,%_pn%) do echo     %%I.  !_pnm[%%I]!
echo     0.  Back
echo =====================================================================================

:PresetCustom_ask
set "sel="
set /p "sel=Choose a preset file: "
if not defined sel goto PresetCustom_ask
if "%sel%"=="0" goto MenuPresets
set "_pfile="
for /l %%I in (1,1,%_pn%) do if "%sel%"=="%%I" set "_pfile=!_pf[%%I]!"
if not defined _pfile goto PresetCustom_ask
set "_pshow="
for /l %%I in (1,1,%_pn%) do if "%sel%"=="%%I" set "_pshow=!_pnm[%%I]!"
set "_pbase="
for %%F in ("%_pfile%") do set "_pbase=%%~nF"
set "_pbase=%_pbase: =_%"
rem ---- validate: read each key=value once, record valid directives, collect problems ----
set "_perr=0"
set "_pgood=0"
set "_perrfile=%TEMP%\sincript_preset_err_%RANDOM%.txt"
break>"%_perrfile%"
for %%K in (CLEANUP PRIVACY PERFORMANCE POWER NETWORK OPENASAR GAMEMODE SYSRESP NETTHROTTLE LARGECACHE MINPROC BCDTIMERS IPV6 MEMCOMPRESS NVME GPUTEL NAGLE WIN32 DNS) do set "_P_%%K="
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%_pfile%") do call :PresetCheckLine "%%A" "%%B"
cls
call :Logo
echo ===============================  CUSTOM PRESET  ===================================
echo  Preset file:            %_pshow%
echo  Recognized directives:  %_pgood%
echo  Problems:               %_perr%
if %_perr% gtr 0 (
    echo -----------------------------------------------------------------------------------
    type "%_perrfile%"
)
del "%_perrfile%" >nul 2>&1
echo =====================================================================================
if %_pgood% geq 1 goto _pcHaveValid
echo [ABORT] No valid directives found - nothing to apply.
echo         Check the file against the key list in the README.
pause
goto MenuPresets

:_pcHaveValid
if %_perr% lss 1 goto _pcReady
set "_cc="
set /p "_cc=Apply the valid directives and skip the problems? (Y/N): "
if /i not "%_cc%"=="Y" goto MenuPresets

:_pcReady
set "_rp="
set /p "_rp=Create a System Restore Point first? (Y/N): "
if /i "%_rp%"=="Y" call :CreateRestorePoint
call :PresetBegin custom_%_pbase%
if defined _P_CLEANUP     call :DoCleanupCore
if defined _P_PRIVACY     call :DoPrivacyCore
if defined _P_PERFORMANCE call :DoPerformanceCore
if defined _P_POWER       call :DoPowerCore
if defined _P_NETWORK     call :DoNetworkCore
if defined _P_SYSRESP     call :DoSysResp0
if defined _P_NETTHROTTLE call :DoNetThrottleOff
if defined _P_LARGECACHE  call :DoLargeCacheOn
if defined _P_GAMEMODE    call :DoGameModeOff
if "%_P_WIN32%"=="42"     call :DoWin32_42
if "%_P_WIN32%"=="26"     call :DoWin32_26
if "%_P_WIN32%"=="2"      call :DoWin32_2
if defined _P_MINPROC     call :SetMinProcState
if defined _P_NAGLE       call :DoNagleOff
if defined _P_IPV6        call :DoIpv6Off
if defined _P_NVME        call :DoNvmeFlags
if defined _P_GPUTEL      call :DoGpuTelemetryOff
if defined _P_BCDTIMERS   call :DoBcdTimers
if defined _P_MEMCOMPRESS call :DoMemCompressOff
if defined _P_OPENASAR    call :DoOpenAsarSilent
if defined _P_DNS         call :PresetDnsByName "%_P_DNS%"
call :PresetEnd
echo.
echo [OK] Custom preset "%_pshow%" applied. Registry backup:
echo      %PRESET_LAST%
echo      Reboot recommended.
pause
goto MenuPresets

:PresetCheckLine
rem %1 = key   %2 = value   (validates + records a directive; logs problems)
set "_k=%~1"
set "_v=%~2"
if not defined _k goto :eof
if "%_k:~0,1%"==";" goto :eof
if "%_v:~-1%"==" " set "_v=%_v:~0,-1%"
set "_match="
if /i "%_k%"=="cleanup"               ( set "_match=1" & call :PVok CLEANUP "%_v%" 1 )
if /i "%_k%"=="privacy"               ( set "_match=1" & call :PVok PRIVACY "%_v%" 1 )
if /i "%_k%"=="performance"           ( set "_match=1" & call :PVok PERFORMANCE "%_v%" 1 )
if /i "%_k%"=="power"                 ( set "_match=1" & call :PVok POWER "%_v%" 1 )
if /i "%_k%"=="network"               ( set "_match=1" & call :PVok NETWORK "%_v%" 1 )
if /i "%_k%"=="openasar"              ( set "_match=1" & call :PVok OPENASAR "%_v%" 1 )
if /i "%_k%"=="gamemode_off"          ( set "_match=1" & call :PVok GAMEMODE "%_v%" 1 )
if /i "%_k%"=="systemresponsiveness"  ( set "_match=1" & call :PVok SYSRESP "%_v%" 0 )
if /i "%_k%"=="networkthrottling_off" ( set "_match=1" & call :PVok NETTHROTTLE "%_v%" 1 )
if /i "%_k%"=="largesystemcache"      ( set "_match=1" & call :PVok LARGECACHE "%_v%" 1 )
if /i "%_k%"=="minprocstate5"         ( set "_match=1" & call :PVok MINPROC "%_v%" 1 )
if /i "%_k%"=="bcdtimers"             ( set "_match=1" & call :PVok BCDTIMERS "%_v%" 1 )
if /i "%_k%"=="ipv6_off"              ( set "_match=1" & call :PVok IPV6 "%_v%" 1 )
if /i "%_k%"=="memcompress_off"       ( set "_match=1" & call :PVok MEMCOMPRESS "%_v%" 1 )
if /i "%_k%"=="nvme_flags"            ( set "_match=1" & call :PVok NVME "%_v%" 1 )
if /i "%_k%"=="gpu_telemetry_off"     ( set "_match=1" & call :PVok GPUTEL "%_v%" 1 )
if /i "%_k%"=="nagle_off"             ( set "_match=1" & call :PVok NAGLE "%_v%" 1 )
if /i "%_k%"=="win32priority"         ( set "_match=1" & call :PChkWin32 "%_v%" )
if /i "%_k%"=="dns"                   ( set "_match=1" & call :PChkDns "%_v%" )
if not defined _match (
    >>"%_perrfile%" echo   ignored - unknown key: %_k%
    set /a _perr+=1
)
goto :eof

:PVok
rem %1 = directive var name   %2 = value   %3 = expected value (1 or 0)
if "%~2"=="%~3" (
    set "_P_%~1=1"
    set /a _pgood+=1
) else (
    >>"%_perrfile%" echo   bad value "%~2" for key %_k% ^(expected %~3^)
    set /a _perr+=1
)
goto :eof

:PChkWin32
if "%~1"=="42" ( set "_P_WIN32=42" & set /a _pgood+=1 & goto :eof )
if "%~1"=="26" ( set "_P_WIN32=26" & set /a _pgood+=1 & goto :eof )
if "%~1"=="2"  ( set "_P_WIN32=2"  & set /a _pgood+=1 & goto :eof )
>>"%_perrfile%" echo   bad value "%~1" for key win32priority (use 42, 26 or 2)
set /a _perr+=1
goto :eof

:PChkDns
if /i "%~1"=="cloudflare" ( set "_P_DNS=cloudflare" & set /a _pgood+=1 & goto :eof )
if /i "%~1"=="google"     ( set "_P_DNS=google"     & set /a _pgood+=1 & goto :eof )
if /i "%~1"=="quad9"      ( set "_P_DNS=quad9"      & set /a _pgood+=1 & goto :eof )
>>"%_perrfile%" echo   bad value "%~1" for key dns (use cloudflare, google or quad9)
set /a _perr+=1
goto :eof
rem =====================================================================================
rem  RESTORE from a preset JSON backup (registry values only)
rem =====================================================================================
:RestorePresetJson
cls
call :Logo
echo =====================  Restore from a preset backup (JSON)  =======================
echo  Restores the registry values a preset changed, from one of its JSON backups.
echo  Power-plan, DNS, BCD and service changes are reverted from their own menu items.
echo =====================================================================================
set "_rn=0"
for /f "delims=" %%F in ('dir /b /o-d "%BACKUP_DIR%\Preset_*.json" 2^>nul') do (
    set /a _rn+=1
    set "_rf[!_rn!]=%BACKUP_DIR%\%%F"
    set "_rnm[!_rn!]=%%F"
)
if "%_rn%"=="0" (
    echo  No preset JSON backups were found in:
    echo     %BACKUP_DIR%
    echo.
    pause
    goto MenuBackups
)
echo  Preset backups (newest first):
for /l %%I in (1,1,%_rn%) do echo     %%I.  !_rnm[%%I]!
echo     0.  Back
echo =====================================================================================

:RestorePresetJson_ask
set "sel="
set /p "sel=Choose a backup to restore: "
if not defined sel goto RestorePresetJson_ask
if "%sel%"=="0" goto MenuBackups
set "_rfile="
for /l %%I in (1,1,%_rn%) do if "%sel%"=="%%I" set "_rfile=!_rf[%%I]!"
if not defined _rfile goto RestorePresetJson_ask
echo.
echo  About to restore registry values from:
echo     %_rfile%
set "_cc="
set /p "_cc=Proceed with the restore? (Y/N): "
if /i not "%_cc%"=="Y" goto MenuBackups
call :Log "PRESET restore from %_rfile%"
set "PT_FILE=%_rfile%"
start "" /min /wait powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue';$p=$env:PT_FILE;try{$items=Get-Content -Raw -LiteralPath $p | ConvertFrom-Json}catch{exit 1};foreach($it in $items){ if(-not $it.present){ reg delete $it.key /v $it.name /f | Out-Null } elseif($it.oldtype -eq 'REG_DWORD' -or $it.oldtype -eq 'REG_SZ'){ reg add $it.key /v $it.name /t $it.oldtype /d $it.olddata /f | Out-Null } }"
set "PT_FILE="
echo.
echo [OK] Restore finished (registry values). A reboot is recommended.
echo      Reminder: revert DNS, power plan and BCD timers from their own menu items if needed.
pause
goto MenuBackups
rem =====================================================================================
rem  RESTORE a single per-value .reg backup (re-import one of the tiny tweak backups)
rem =====================================================================================
:RestoreRegBackup
cls
call :Logo
echo ====================  Restore a single value backup (.reg)  =======================
echo  Re-imports one of the small per-value .reg backups this script writes before each
echo  registry tweak - the same files you can also double-click in the backup folder.
echo  Full-registry exports (FullReg_*.reg) are not listed here; import those manually.
echo =====================================================================================
set "_qn=0"
for /f "delims=" %%F in ('dir /b /a-d /o-d "%BACKUP_DIR%\*.reg" 2^>nul ^| findstr /I /V /B "FullReg_"') do (
    set /a _qn+=1
    set "_qf[!_qn!]=%BACKUP_DIR%\%%F"
    set "_qnm[!_qn!]=%%F"
)
if "%_qn%"=="0" (
    echo  No per-value .reg backups were found in:
    echo     %BACKUP_DIR%
    echo.
    pause
    goto MenuBackups
)
echo  Value backups (newest first):
for /l %%I in (1,1,%_qn%) do echo     %%I.  !_qnm[%%I]!
echo     0.  Back
echo =====================================================================================

:RestoreRegBackup_ask
set "sel="
set /p "sel=Choose a backup to restore: "
if not defined sel goto RestoreRegBackup_ask
if "%sel%"=="0" goto MenuBackups
set "_qfile="
set "_qshow="
for /l %%I in (1,1,%_qn%) do if "%sel%"=="%%I" set "_qfile=!_qf[%%I]!"
for /l %%I in (1,1,%_qn%) do if "%sel%"=="%%I" set "_qshow=!_qnm[%%I]!"
if not defined _qfile goto RestoreRegBackup_ask
echo.
echo  This backup will put the following value(s) back to their saved state:
echo -----------------------------------------------------------------------------------
type "%_qfile%"
echo -----------------------------------------------------------------------------------
echo  A line like  "Name"=-  means the value did not exist before and will be removed.
set "_cc="
set /p "_cc=Import this .reg backup now? (Y/N): "
if /i not "%_cc%"=="Y" goto MenuBackups
echo   ^> Importing "%_qshow%"...
call :Log "REG restore (import) from %_qshow%"
reg import "%_qfile%" 1>>"%LOGFILE%" 2>>&1
if errorlevel 1 (
    echo [WARN] Import reported an error - check the log for details.
    call :Log "  FAIL reg import %_qshow%"
) else (
    echo [OK] Backup imported. A sign out/in or reboot may be needed for some values.
    call :Log "  OK reg import %_qshow%"
)
pause
goto MenuBackups
rem =====================================================================================
rem  JSON value backup (called by SafeRegAdd when a preset is being applied)
rem =====================================================================================
:BackupValueJson
rem  Appends ONE JSON object (the value's prior state) to !PRESET_JSON_TMP!.
rem  Runs inside SafeRegAdd's setlocal, so !_key! !_val! !_ln! are in scope.
set "_jk=!_key:\=\\!"
set "_jv=!_val:\=\\!"
if not defined _ln goto _bvjAbsent
set "_td=REG_!_ln:*REG_=!"
for /f "tokens=1,*" %%a in ("!_td!") do ( set "_rt=%%a" & set "_rd=%%b" )
if /i "!_rt!"=="REG_DWORD" goto _bvjDword
if /i "!_rt!"=="REG_SZ" goto _bvjSz
>>"!PRESET_JSON_TMP!" echo {"key":"!_jk!","name":"!_jv!","present":true,"oldtype":"!_rt!","restorable":false}
goto :eof

:_bvjAbsent
>>"!PRESET_JSON_TMP!" echo {"key":"!_jk!","name":"!_jv!","present":false}
goto :eof

:_bvjDword
>>"!PRESET_JSON_TMP!" echo {"key":"!_jk!","name":"!_jv!","present":true,"oldtype":"REG_DWORD","olddata":"!_rd!"}
goto :eof

:_bvjSz
set "_sz=!_rd:"=!"
set "_sz=!_sz:\=\\!"
>>"!PRESET_JSON_TMP!" echo {"key":"!_jk!","name":"!_jv!","present":true,"oldtype":"REG_SZ","olddata":"!_sz!"}
goto :eof
