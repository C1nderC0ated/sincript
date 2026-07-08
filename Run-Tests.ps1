<#
.SYNOPSIS
    Static-analysis test harness for Sincript (PerfTweaks.cmd + bundled data files).

.DESCRIPTION
    PerfTweaks.cmd is a single large batch script, which is awkward to unit-test by
    execution (it mutates the real system, elevates, and is interactive). Instead this
    harness statically asserts the invariants that are most prone to silent regression:

      1. Label resolution   - every `goto X` / `call :X` targets a real `:X` label.
      2. boot.config keys    - no duplicate Unity directives (guards fix #1).
      3. Preset key drift     - every key in example.preset is one the script's validator
                                actually recognizes (catches README/example drift).
      4. Reg-backup honesty  - :CreateRegBackup verifies the export before printing [OK]
                                (regression guard for fix #2).

    No external modules (no Pester) so it runs on a stock Windows PowerShell 5.1.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tests\Run-Tests.ps1

.OUTPUTS
    Writes a PASS/FAIL line per test and a summary. Exit code 0 = all passed, 1 = failure.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---- locate the files under test (this script lives in <repo>\sincript\tests) ----
$TestsDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptRoot = Split-Path -Parent $TestsDir
$CmdPath    = Join-Path $ScriptRoot 'PerfTweaks.cmd'
$BootPath   = Join-Path $ScriptRoot 'boot.config'
$PresetPath = Join-Path $ScriptRoot 'sincript_presets\example.preset'

# ---- tiny assertion framework -------------------------------------------------
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Total    = 0

function Invoke-Test {
    param([string]$Name, [scriptblock]$Body)
    $script:Total++
    try {
        & $Body
        Write-Host ("  [PASS] {0}" -f $Name) -ForegroundColor Green
    }
    catch {
        Write-Host ("  [FAIL] {0}" -f $Name) -ForegroundColor Red
        Write-Host ("         {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow
        $script:Failures.Add($Name)
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Read-Lines {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "File under test not found: $Path" }
    return [System.IO.File]::ReadAllLines($Path)
}

# ---- helper: pull a `:label` routine body (until the next top-level label) -----
function Get-RoutineBody {
    param([string[]]$Lines, [string]$Label)
    # Real routine entry points are non-underscore labels, plus any label reached via `call`.
    # Internal goto-only sub-labels (e.g. :_sraDoWrite, :_slWritten) belong to their parent
    # routine and must stay in the body - otherwise a routine that flat-flows through an
    # internal label gets sliced short and later checks see a truncated body (false regression).
    $callTargets = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($ln in $Lines) {
        foreach ($m in [regex]::Matches($ln, '(?i)\bcall\s+:(\w+)')) { [void]$callTargets.Add($m.Groups[1].Value) }
    }
    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match ('^:{0}\b' -f [regex]::Escape($Label))) { $start = $i; break }
    }
    if ($start -lt 0) { throw "Label :$Label not found" }
    $body = New-Object System.Collections.Generic.List[string]
    for ($j = $start + 1; $j -lt $Lines.Count; $j++) {
        if ($Lines[$j] -match '^:(\w+)') {
            $lbl = $Matches[1]
            if ($lbl -notmatch '^_' -or $callTargets.Contains($lbl)) { break }   # next real routine
        }
        $body.Add($Lines[$j])
    }
    return ,$body.ToArray()
}

Write-Host ""
Write-Host "Sincript static-analysis tests" -ForegroundColor Cyan
Write-Host ("Target: {0}" -f $CmdPath) -ForegroundColor DarkGray
Write-Host ""

# ===============================================================================
# 1. Every goto / call target resolves to a defined label
# ===============================================================================
Invoke-Test 'All goto/call targets resolve to a real label' {
    $lines = Read-Lines $CmdPath

    $defined = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($ln in $lines) {
        if ($ln -match '^:(\w+)') { [void]$defined.Add($Matches[1]) }
    }
    Assert-True ($defined.Count -gt 0) 'No labels found - parser problem?'

    $missing = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        $trimmed = $ln.TrimStart()
        # skip comment lines so words inside :: / rem text are not read as references
        if ($trimmed -match '^(?i)(rem\b|::)') { continue }

        foreach ($m in [regex]::Matches($ln, '(?i)\bgoto\s+:?(\w+)')) {
            $t = $m.Groups[1].Value
            if ($t -ieq 'eof') { continue }
            if (-not $defined.Contains($t)) { $missing.Add(("line {0}: goto {1}" -f ($i+1), $t)) }
        }
        foreach ($m in [regex]::Matches($ln, '(?i)\bcall\s+:(\w+)')) {
            $t = $m.Groups[1].Value
            if ($t -ieq 'eof') { continue }
            if (-not $defined.Contains($t)) { $missing.Add(("line {0}: call :{1}" -f ($i+1), $t)) }
        }
    }
    Assert-True ($missing.Count -eq 0) ("Unresolved jump target(s):`n         " + ($missing -join "`n         "))
}

# ===============================================================================
# 2. boot.config has no duplicate keys  (guards fix #1)
# ===============================================================================
Invoke-Test 'boot.config has no duplicate keys' {
    $lines = Read-Lines $BootPath
    $seen = @{}
    $dupes = New-Object System.Collections.Generic.List[string]
    foreach ($raw in $lines) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
        $key = ($line -split '=', 2)[0].Trim()
        if ($key -eq '') { continue }
        if ($seen.ContainsKey($key)) { $dupes.Add($key) } else { $seen[$key] = $true }
    }
    Assert-True ($dupes.Count -eq 0) ("Duplicate key(s) in boot.config: " + ($dupes -join ', '))
}

# ===============================================================================
# 3. example.preset only uses keys the script's validator recognizes
#    (recognized set is parsed straight out of :PresetCheckLine so the test
#     tracks the real validator, not a hand-maintained copy)
# ===============================================================================
Invoke-Test 'example.preset keys are all recognized by the validator' {
    $cmd = Read-Lines $CmdPath
    $checkBody = Get-RoutineBody -Lines $cmd -Label 'PresetCheckLine'

    $recognized = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($ln in $checkBody) {
        # matches:  if /i "%_k%"=="cleanup" ( ...
        $m = [regex]::Match($ln, '(?i)"%_k%"=="([^"]+)"')
        if ($m.Success) { [void]$recognized.Add($m.Groups[1].Value) }
    }
    Assert-True ($recognized.Count -ge 10) ("Parsed too few recognized keys ({0}) - parser drift?" -f $recognized.Count)

    $preset = Read-Lines $PresetPath
    $unknown = New-Object System.Collections.Generic.List[string]
    $usedCount = 0
    foreach ($raw in $preset) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
        $key = ($line -split '=', 2)[0].Trim()
        if ($key -eq '') { continue }
        $usedCount++
        if (-not $recognized.Contains($key)) { $unknown.Add($key) }
    }
    Assert-True ($usedCount -gt 0) 'example.preset has no active directives - parser problem?'
    Assert-True ($unknown.Count -eq 0) ("example.preset uses key(s) the validator rejects: " + ($unknown -join ', '))
}

# ===============================================================================
# 4. :CreateRegBackup verifies the export before declaring success (fix #2)
# ===============================================================================
Invoke-Test ':CreateRegBackup checks errorlevel/existence before [OK]' {
    $cmd = Read-Lines $CmdPath
    $body = Get-RoutineBody -Lines $cmd -Label 'CreateRegBackup'
    $text = ($body -join "`n")

    Assert-True ($text -match '(?i)\[OK\]') ':CreateRegBackup has no [OK] message - routine changed shape?'
    Assert-True ($text -match '(?i)errorlevel')  'No errorlevel check in :CreateRegBackup - export success is not verified (regression of fix #2).'
    Assert-True ($text -match '(?i)if not exist') 'No "if not exist" file check in :CreateRegBackup - a missing export would still report success (regression of fix #2).'
    Assert-True ($text -match '(?i)\[ERROR\]')   ':CreateRegBackup has no failure ([ERROR]) branch - it cannot report a failed backup (regression of fix #2).'
}

# ===============================================================================
# 5. :Performance — the Win32PrioritySeparation writes are one mutually-exclusive
#    choice, i.e. both SafeRegAdd calls are gated by the SAME prompt variable.
#    (The bug was two independent yes/no prompts, _q3 + _q3b, which let a single
#     pass apply 42 and then reset to 2, corrupting the reset's per-value backup.)
# ===============================================================================
Invoke-Test ':Performance gates Win32PrioritySeparation on a single choice' {
    $cmd  = Read-Lines $CmdPath
    $body = Get-RoutineBody -Lines $cmd -Label 'Performance'

    $gates = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $writes = 0
    foreach ($ln in $body) {
        if ($ln -match '(?i)SafeRegAdd' -and $ln -match '(?i)Win32PrioritySeparation') {
            $writes++
            $m = [regex]::Match($ln, '%(_\w+)%')   # the prompt var this write is gated on
            Assert-True $m.Success ("Win32PrioritySeparation write is not gated by a prompt variable:`n         " + $ln.Trim())
            [void]$gates.Add($m.Groups[1].Value)
        }
    }
    Assert-True ($writes -ge 1) 'No Win32PrioritySeparation write found in :Performance - routine changed shape?'
    Assert-True ($gates.Count -le 1) ("Win32PrioritySeparation writes are gated by multiple prompts ({0}) - they must be one mutually-exclusive choice (regression of fix #3)." -f (($gates) -join ', '))
}

# ===============================================================================
# 6. :DoCleanupCore does not wipe the Prefetch folder (placebo; fix #4).
#    Checks for an actual delete of Prefetch, not the explanatory rem that
#    documents why it is skipped.
# ===============================================================================
Invoke-Test ':DoCleanupCore does not clear the Prefetch folder' {
    $cmd  = Read-Lines $CmdPath
    $body = Get-RoutineBody -Lines $cmd -Label 'DoCleanupCore'
    $bad = @($body | Where-Object { $_ -match '(?i)\bdel\b' -and $_ -match '(?i)Prefetch' })
    Assert-True ($bad.Count -eq 0) ("Prefetch is being deleted in :DoCleanupCore (placebo - regression of fix #4):`n         " + ($bad -join "`n         "))
}

# ===============================================================================
# 7. DNS apply/reset report the real outcome instead of an unconditional [OK].
#    Both routines must capture the child exit code and delegate to :DnsResult
#    (which has an [OK] and an [ERROR] branch), and must not print [OK] inline.
# ===============================================================================
Invoke-Test 'DNS apply/reset report real success, not an unconditional [OK]' {
    $cmd = Read-Lines $CmdPath
    foreach ($r in 'ApplyDns', 'DnsAuto') {
        $t = ((Get-RoutineBody -Lines $cmd -Label $r) -join "`n")
        Assert-True ($t -match '(?i)errorlevel')  ":$r does not capture the PS exit code (errorlevel) - DNS success is unverified (regression)."
        Assert-True ($t -match '(?i):DnsResult') ":$r does not delegate to :DnsResult for honest reporting (regression)."
        Assert-True ($t -notmatch '(?i)echo\s+\[OK\]') ":$r echoes an inline [OK] again - it must report via :DnsResult based on the exit code (regression)."
    }
    $dr = ((Get-RoutineBody -Lines $cmd -Label 'DnsResult') -join "`n")
    Assert-True ($dr -match '(?i)\[OK\]')    ':DnsResult has no [OK] branch - routine changed shape?'
    Assert-True ($dr -match '(?i)\[ERROR\]') ':DnsResult has no [ERROR] branch - it cannot report a failed DNS change (regression).'
}

# ===============================================================================
# 8. :InstallAsarInto verifies which OpenAsar backup actually landed before
#    reporting it, and keeps the Documents-folder fallback. (The old code wrote
#    both backups with errors silenced, then always claimed the in-folder one -
#    which Controlled Folder Access / AV often blocks.)
# ===============================================================================
Invoke-Test ':InstallAsarInto verifies which OpenAsar backup landed' {
    $cmd = Read-Lines $CmdPath
    $b = ((Get-RoutineBody -Lines $cmd -Label 'InstallAsarInto') -join "`n")
    Assert-True ($b -match '(?i)_bakloc')      ':InstallAsarInto no longer tracks which backup landed (regression - it would blindly claim the in-folder .bak again).'
    Assert-True ($b -match '(?i)BACKUP_DIR')   ':InstallAsarInto no longer writes the Documents-folder fallback backup (regression).'
    Assert-True ($b -match '(?i)if exist .*_localbak') ':InstallAsarInto does not check that the in-folder backup exists before reporting it (regression).'
}

# ===============================================================================
# 9. cmd parse safety: no unescaped ')' inside a ( ) block closes it early.
#    Inside a block cmd treats a bare ')' as the block terminator even mid-text,
#    and whatever follows raises "was unexpected at this time." - which aborts
#    the whole batch (this crashed the hosts restore/reset until fixed).
#    Per-line simulation of cmd's block parsing: quotes protect, ^ escapes,
#    '(' opens a block only at a command position, ')' closes anywhere; after a
#    close only else / & / | / ) / > / < / end-of-line are legal.
# ===============================================================================
Invoke-Test "No unescaped ')' closes a block early (hosts-restore crash class)" {
    $lines = Read-Lines $CmdPath
    $ifCond = '(?i)\bif\s+(?:/i\s+)?(?:not\s+)?(?:errorlevel\s+\S+|exist\s+(?:"[^"]*"|\S+)|defined\s+\S+|(?:"[^"]*"|\S+?)\s*(?:==|\bEQU\b|\bNEQ\b|\bLSS\b|\bLEQ\b|\bGTR\b|\bGEQ\b)\s*(?:"[^"]*"|\S+?))\s*$'
    $bad = New-Object System.Collections.Generic.List[string]
    for ($ln = 0; $ln -lt $lines.Count; $ln++) {
        $raw = $lines[$ln]
        if ($raw.TrimStart() -match '^(?i)(rem\b|::|:\w)') { continue }
        $depth = 0; $inQ = $false; $closed = $false; $pre = ''; $i = 0
        while ($i -lt $raw.Length) {
            $c = $raw[$i]
            if (-not $inQ -and $c -eq '^') { $i += 2; $pre += ' '; continue }
            if ($c -eq '"') { $inQ = -not $inQ; $i++; $closed = $false; continue }
            if ($inQ) { $i++; continue }
            if ($closed -and $c -ne ' ' -and $c -ne "`t") {
                if ($raw.Substring($i) -match '^(?i)(else\b|&|\||\)|>|<)') { $closed = $false }
                else {
                    $bad.Add(("line {0}: '{1}' follows a block close" -f ($ln + 1), $raw.Substring($i, [Math]::Min(40, $raw.Length - $i))))
                    $closed = $false
                }
            }
            if ($c -eq '(') {
                $s = $pre.TrimEnd()
                if ($s -eq '' -or $s.EndsWith('&') -or $s.EndsWith('|') -or $s.EndsWith('(') -or $s -match '(?i)\b(do|else)$' -or $s -match $ifCond) { $depth++ }
            }
            elseif ($c -eq ')') {
                if ($depth -gt 0) { $depth--; $closed = $true }
            }
            $pre += $c; $i++
        }
    }
    Assert-True ($bad.Count -eq 0) ("Unescaped ')' ends a block early - escape literal parens as ^( ^) inside blocks:`n         " + ($bad -join "`n         "))
}

# ===============================================================================
# 10. :DoPowerCore duplicates Ultimate ONTO its canonical GUID. Without the
#     destination GUID every run minted another random-GUID "Ultimate
#     Performance" clone that /setactive (which targets the canonical GUID)
#     never used - plans piled up and High was silently activated instead.
# ===============================================================================
Invoke-Test ':DoPowerCore duplicates Ultimate onto its canonical GUID' {
    $b = ((Get-RoutineBody -Lines (Read-Lines $CmdPath) -Label 'DoPowerCore') -join "`n")
    Assert-True ($b -match '(?i)duplicatescheme\s+e9a42b02-d5df-448d-aa00-03f14749eb61\s+e9a42b02-d5df-448d-aa00-03f14749eb61') 'duplicatescheme lost its destination GUID - every run would create another Ultimate clone and setactive would keep falling back to High (regression).'
}

# ===============================================================================
# 11. OpenAsar download honesty: a failed Invoke-WebRequest can leave a PARTIAL
#     file, and the old code only checked existence - so a broken .asar could be
#     installed into Discord. Both download paths must gate on the child exit
#     code and delete the leftover before the existence check.
# ===============================================================================
Invoke-Test 'OpenAsar download failure is detected and the partial file removed' {
    $cmd = Read-Lines $CmdPath
    foreach ($r in 'OpenAsar', 'DoOpenAsarSilent') {
        $t = ((Get-RoutineBody -Lines $cmd -Label $r) -join "`n")
        if ($t -notmatch '(?i)Invoke-WebRequest') { continue }
        Assert-True ($t -match '(?i)if\s+errorlevel\s+1\s+del\b') (":$r ignores the download exit code / keeps a partial file on failure (regression).")
    }
}

# ===============================================================================
# 12. Startup manager: a flip must write the value's prior state to a .reg
#     backup BEFORE changing StartupApproved, and must write via the
#     literal-safe Registry SetValue (entry names containing [ ] * ? must not
#     misfire onto a different value).
# ===============================================================================
Invoke-Test ':StartupWorker backs up the prior state before flipping' {
    $b = ((Get-RoutineBody -Lines (Read-Lines $CmdPath) -Label 'StartupWorker') -join "`n")
    Assert-True ($b -match '(?i)StartupApproved') ':StartupWorker no longer targets StartupApproved - routine changed shape?'
    Assert-True ($b -match 'Windows Registry Editor Version 5.00') ':StartupWorker no longer writes a .reg backup of the prior value (regression - flips would stop being undoable).'
    Assert-True ($b -match '(?i)SetValue') ':StartupWorker no longer writes via the literal-safe Registry SetValue.'
    Assert-True ($b.IndexOf('Windows Registry Editor Version 5.00') -lt $b.ToLower().IndexOf('setvalue')) ':StartupWorker writes the new value before the backup (regression - a failed backup would no longer protect the flip).'
}

# ===============================================================================
# 13. Honest registry reporting (Critical #1): :SafeRegAdd / :SafeRegDelete must
#     surface a failed write - print an inline [FAIL] AND propagate the result
#     into _FAILS across their endlocal - instead of swallowing the errorlevel
#     and letting the caller print an unconditional [OK]. (The apply tails live
#     under the :_sraApply / :_srdApply sub-labels.)
# ===============================================================================
Invoke-Test ':SafeRegAdd / :SafeRegDelete surface a failed write (no silent [OK])' {
    $cmd = Read-Lines $CmdPath
    foreach ($r in '_sraApply', '_srdApply') {
        $t = ((Get-RoutineBody -Lines $cmd -Label $r) -join "`n")
        Assert-True ($t -match '(?i)endlocal\s*&\s*set\s*/a\s*_FAILS\s*\+=') ":$r does not carry its result into _FAILS across endlocal - a failed reg write is invisible to the caller (regression of Critical #1)."
        Assert-True ($t -match '(?i)\[FAIL\]') ":$r no longer prints an inline [FAIL] when the write fails - failures would be silent (regression of Critical #1)."
    }
}

# ===============================================================================
# 14. :Summary consults _FAILS and has both an [OK] and a [WARN] branch, so an
#     action's final line reports the real outcome (fix for Critical #1).
# ===============================================================================
Invoke-Test ':Summary gates the final line on _FAILS (has [OK] and [WARN] branches)' {
    $b = ((Get-RoutineBody -Lines (Read-Lines $CmdPath) -Label 'Summary') -join "`n")
    # require the real statements, not a rem-comment mention of them
    Assert-True ($b -match '(?i)%_FAILS%')             ':Summary does not consult %_FAILS% - it cannot tell success from failure (regression of Critical #1).'
    Assert-True ($b -match '(?im)^\s*echo\s+\[OK\]')   ':Summary has no "echo [OK]" branch - routine changed shape?'
    Assert-True ($b -match '(?im)^\s*echo\s+\[WARN\]') ':Summary has no "echo [WARN]" branch - a failed write would still read as success (regression of Critical #1).'
}

# ===============================================================================
# 15. Registry actions reset _FAILS before their writes and route their final
#     line through :Summary (never a raw unconditional [OK]). Spot-checked on the
#     cleanly-bounded single-purpose routines, plus a global count sanity check.
# ===============================================================================
Invoke-Test 'Registry actions reset _FAILS and report via :Summary' {
    $cmd = Read-Lines $CmdPath
    foreach ($r in 'DisableMitigations','EnableMitigations','NvmeFlags','DisableIPv6','GpuAmd','HagsOff','HagsOn') {
        $t = ((Get-RoutineBody -Lines $cmd -Label $r) -join "`n")
        Assert-True ($t -match '(?i)set "_FAILS=0"') ":$r does not reset _FAILS before its writes - a stale count would mis-report (regression of Critical #1)."
        Assert-True ($t -match '(?i)call :Summary')  ":$r prints an unconditional status instead of routing through :Summary (regression of Critical #1)."
        Assert-True ($t -notmatch '(?i)echo\s+\[OK\]') ":$r still echoes an inline [OK] - it must gate that line on :Summary (regression of Critical #1)."
    }
    $all = ($cmd -join "`n")
    $sum = ([regex]::Matches($all, '(?i)call :Summary')).Count
    $rst = ([regex]::Matches($all, '(?i)set "_FAILS=0"')).Count
    Assert-True ($sum -ge 13) ("Expected >=13 :Summary call sites, found {0} - registry actions may have lost honest reporting (regression of Critical #1)." -f $sum)
    Assert-True ($rst -ge 13) ("Expected >=13 _FAILS resets, found {0} - a gated action may be missing its reset (regression of Critical #1)." -f $rst)
}

# ===============================================================================
# 16. Preset crash guard (Critical #2): :PresetCheckLine must not run the
#     trailing-space strip as an UNGUARDED substring on a possibly-empty value -
#     an empty preset value (key=) made cmd throw "syntax of the command is
#     incorrect" and abort the WHOLE script. The strip must be guarded by
#     `if defined _v` and use delayed (!) expansion, which is empty-safe.
# ===============================================================================
Invoke-Test 'Preset parser guards an empty value (no whole-script crash)' {
    $b = ((Get-RoutineBody -Lines (Read-Lines $CmdPath) -Label 'PresetCheckLine') -join "`n")
    Assert-True ($b -notmatch '%_v:~')      ':PresetCheckLine still uses an UNGUARDED %_v:~..% substring - an empty preset value crashes the entire script (regression of Critical #2).'
    Assert-True ($b -match '(?i)if defined _v\b') ':PresetCheckLine no longer guards the trailing-space strip with "if defined _v" - an empty value would abort the parse (regression of Critical #2).'
}

# ===============================================================================
# 17. Elevation honesty (Batch 2): the admin probe sets _ELEV=1 on the elevated
#     path, :AdminWarn sets _ELEV=0 and offers an explicit limited-mode opt-in
#     (no more silent "Continuing anyway"), and :Summary tailors its [WARN] to
#     the elevation state.
# ===============================================================================
Invoke-Test 'Non-elevated run is flagged via _ELEV and reported honestly' {
    $cmd = Read-Lines $CmdPath
    $all = ($cmd -join "`n")
    Assert-True ($all -match '(?im)^\s*if not errorlevel 1 \( set "_ELEV=1"') 'The admin probe no longer sets _ELEV=1 on the elevated path (regression of the elevation fix).'
    $aw = ((Get-RoutineBody -Lines $cmd -Label 'AdminWarn') -join "`n")
    Assert-True ($aw -match '(?i)set "_ELEV=0"')      ':AdminWarn no longer sets _ELEV=0 for the non-elevated path (regression).'
    Assert-True ($aw -notmatch '(?i)Continuing anyway') ':AdminWarn still silently continues ("Continuing anyway") instead of an explicit limited-mode opt-in (regression).'
    $sm = ((Get-RoutineBody -Lines $cmd -Label 'Summary') -join "`n")
    Assert-True ($sm -match '(?i)%_ELEV%') ':Summary no longer tailors its [WARN] to the elevation state (_ELEV) (regression).'
}

# ===============================================================================
# 18. hosts data-loss guard (Batch 2): :ApplyHosts must confirm a backup actually
#     landed (_hbak) and ABORT before overwriting if none did - the overwrite of
#     the bundled hosts must come AFTER that guard.
# ===============================================================================
Invoke-Test ':ApplyHosts verifies a backup landed before overwriting the system hosts' {
    $b = ((Get-RoutineBody -Lines (Read-Lines $CmdPath) -Label 'ApplyHosts') -join "`n").ToLower()
    Assert-True ($b -match '_hbak') ':ApplyHosts no longer tracks whether a hosts backup landed (regression - could overwrite with no backup).'
    $abortIdx = $b.IndexOf('!_hbak!"=="0"')
    $copyIdx  = $b.IndexOf('%script_dir%hosts')
    Assert-True ($abortIdx -ge 0) ':ApplyHosts has no "if no backup -> abort" guard on _hbak (regression - data-loss window).'
    Assert-True ($copyIdx  -ge 0) ':ApplyHosts no longer copies the bundled hosts over the system hosts - routine changed shape?'
    Assert-True ($abortIdx -lt $copyIdx) ':ApplyHosts overwrites the system hosts BEFORE confirming a backup landed (regression of the data-loss fix).'
}

# ===============================================================================
# 19. Preset-restore honesty (Batch 2): :RestorePresetJson must capture the
#     child's exit code and branch to [WARN]/[ERROR] instead of always printing
#     [OK]. (The restore logic lives under :RestorePresetJson_ask.)
# ===============================================================================
Invoke-Test ':RestorePresetJson reports the real restore outcome (not an unconditional [OK])' {
    $b = ((Get-RoutineBody -Lines (Read-Lines $CmdPath) -Label 'RestorePresetJson_ask') -join "`n")
    Assert-True ($b -match '(?i)errorlevel')          ':RestorePresetJson_ask does not capture the restore child exit code (regression - cannot tell success from failure).'
    Assert-True ($b -match '(?i)_prrc')               ':RestorePresetJson_ask no longer branches on the child result (_prrc) - [OK] would be unconditional again (regression).'
    Assert-True ($b -match '(?im)^\s*echo \[WARN\]')  ':RestorePresetJson_ask has no [WARN] branch for a partial/failed restore (regression).'
    Assert-True ($b -match '(?im)^\s*echo \[ERROR\]') ':RestorePresetJson_ask has no [ERROR] branch for an unreadable backup (regression).'
}

# ===============================================================================
# 20. OpenAsar build selection (Batch 2): :InstallAsarInto must pick the app-*
#     folder by real version, not an ASCII "dir /o-n" name sort (which targets
#     the OLD build at a version digit-rollover).
# ===============================================================================
Invoke-Test ':InstallAsarInto picks the Discord build by version, not ASCII name order' {
    $b = ((Get-RoutineBody -Lines (Read-Lines $CmdPath) -Label 'InstallAsarInto') -join "`n")
    Assert-True ($b -notmatch '(?i)dir /b /ad /o-n') ':InstallAsarInto still uses an ASCII "dir /o-n" sort for app-* - wrong build at a version digit-rollover (regression).'
    Assert-True ($b -match '(?i)Sort-Object')        ':InstallAsarInto no longer version-sorts the app-* folders (regression).'
    Assert-True ($b -match '(?i)\[version\]')         ':InstallAsarInto no longer parses folder names as [version] for the sort (regression).'
}

# ===============================================================================
# 21. Backup escaping (Batch 3): per-value backups must ESCAPE a quote in REG_SZ
#     data (" -> \"), not drop it - otherwise the prior value can't be restored.
#     :BackupValueLine writes the .reg; :_bvjSz writes the preset JSON (it used to
#     STRIP quotes, silently losing data).
# ===============================================================================
Invoke-Test 'Per-value backups escape quotes AND handle empty REG_SZ (undo integrity)' {
    $cmd = Read-Lines $CmdPath
    $bvl = ((Get-RoutineBody -Lines $cmd -Label 'BackupValueLine') -join "`n")
    Assert-True ($bvl -match '_sd:"=\\"')      ':BackupValueLine does not escape " to \" in REG_SZ data - a prior value containing a quote makes a corrupt .reg that will not restore (regression).'
    Assert-True ($bvl -match '(?i)if defined _rd') ':BackupValueLine does not guard the REG_SZ escape on "if defined _rd" - an EMPTY REG_SZ backs up as the literal \=\\ (corrupt .reg - regression).'
    $bvj = ((Get-RoutineBody -Lines $cmd -Label '_bvjSz') -join "`n")
    Assert-True ($bvj -match '_sz:"=\\"')       ':_bvjSz does not escape " to \" for the JSON backup - a prior REG_SZ with a quote is lost (regression).'
    Assert-True ($bvj -notmatch '_sz=!_rd:"=!') ':_bvjSz still STRIPS quotes from REG_SZ data instead of escaping them (data loss - regression).'
    Assert-True ($bvj -match '(?i)if defined _rd') ':_bvjSz does not guard the escape on "if defined _rd" - an EMPTY REG_SZ writes literal \=\\ (invalid JSON breaks the whole preset restore - regression).'
}

# ===============================================================================
# 22. Backup filename collisions (Batch 3): two values under one key share the
#     sanitized key prefix, so the per-value .reg name must use %RANDOM%%RANDOM%
#     (30-bit) - a single 15-bit %RANDOM% can birthday-collide within one apply
#     pass and one value's backup would overwrite another's.
# ===============================================================================
Invoke-Test 'Per-value backup filenames use %RANDOM%%RANDOM% (collision-resistant)' {
    $cmd = Read-Lines $CmdPath
    foreach ($r in 'SafeRegAdd','SafeRegDelete') {
        $t = ((Get-RoutineBody -Lines $cmd -Label $r) -join "`n")
        Assert-True ($t -match '_%RANDOM%%RANDOM%\.reg') ":$r backup filename no longer uses %RANDOM%%RANDOM% - two values under one key can collide on a single %RANDOM% and lose a per-value backup (regression)."
    }
}

# ===============================================================================
# 23. Quote-safe preset restore (Batch 3): reg.exe invoked from PowerShell 5.1
#     mangles embedded quotes, so REG_SZ values must be restored via the native
#     Set-ItemProperty cmdlet (with the hive short-name -> PSDrive conversion),
#     not "reg add /d". DWORD/delete stay on reg.exe (no quotes to mangle).
# ===============================================================================
Invoke-Test ':RestorePresetJson restores REG_SZ quote-safely (Set-ItemProperty, not reg add)' {
    $b = ((Get-RoutineBody -Lines (Read-Lines $CmdPath) -Label 'RestorePresetJson_ask') -join "`n")
    Assert-True ($b -match '(?i)Set-ItemProperty')     ':RestorePresetJson no longer uses Set-ItemProperty for REG_SZ - reg.exe from PowerShell mangles embedded quotes and corrupts the restore (regression).'
    Assert-True ($b -match '(?i)Registry::HKEY_USERS') ':RestorePresetJson lost the hive short-name -> PSDrive path conversion needed by Set-ItemProperty (regression).'
}

# ===============================================================================
# 24. Honest :Run reporting (Batch 4): a nonzero exit is counted into _FAILS ONLY
#     when the action is tracked (_RUNTRACK) AND the session is not elevated
#     (_ELEV=0) - where the command definitely couldn't do its privileged work.
#     When elevated, nonzero is usually benign (already-in-desired-state), so it
#     must NOT be counted (no crying wolf). :Summary clears _RUNTRACK per action.
# ===============================================================================
Invoke-Test ':Run counts failures only when tracked AND not elevated (no crying wolf)' {
    $cmd = Read-Lines $CmdPath
    $r = ((Get-RoutineBody -Lines $cmd -Label 'Run') -join "`n")
    Assert-True ($r -match '(?i)_RUNTRACK')      ':Run does not consult _RUNTRACK - best-effort cleanup deletes would be counted as failures (regression).'
    Assert-True ($r -match '(?i)%_ELEV%')        ':Run does not gate failure-counting on elevation (%_ELEV%) - it would cry wolf on benign elevated nonzero exits (regression).'
    Assert-True ($r -match '(?i)set /a _FAILS')  ':Run does not fold real failures into _FAILS - a Run-based action still cannot report honestly (regression).'
    $s = ((Get-RoutineBody -Lines $cmd -Label 'Summary') -join "`n")
    Assert-True ($s -match '(?i)set "_RUNTRACK="') ':Summary no longer clears _RUNTRACK - tracking would leak into a later untracked action (e.g. cleanup) and cry wolf (regression).'
}

# ===============================================================================
# 25. Run-based actions (Batch 4): must set _RUNTRACK=1 and report via :Summary,
#     so their sc/schtasks/netsh/bcdedit/powercfg work is honestly reported (a
#     not-elevated run shows [WARN], not a misleading [OK]).
# ===============================================================================
Invoke-Test 'Run-based actions track failures (_RUNTRACK) and report via :Summary' {
    $cmd = Read-Lines $CmdPath
    foreach ($r in 'Power','NetworkApply','NetReset','BcdTimers','BcdRevert','Privacy','GpuNvidia') {
        # Region = from :<r> to the next TOP-LEVEL label (not one starting with '_'), so a
        # sub-label like :_netNagDone / :_privSvcDone can't truncate the action before its Summary.
        $start = -1
        for ($i = 0; $i -lt $cmd.Count; $i++) { if ($cmd[$i] -match ('^:{0}\b' -f [regex]::Escape($r))) { $start = $i; break } }
        Assert-True ($start -ge 0) "Routine :$r not found - test needs updating."
        $body = New-Object System.Collections.Generic.List[string]
        for ($j = $start + 1; $j -lt $cmd.Count; $j++) {
            if ($cmd[$j] -match '^:(?!_)\w') { break }   # next top-level (non-underscore) label
            $body.Add($cmd[$j])
        }
        $t = ($body -join "`n")
        Assert-True ($t -match '(?i)set "_RUNTRACK=1"') ":$r does not set _RUNTRACK=1 - its service/boot/network failures go uncounted, so it can print [OK] when not elevated (regression)."
        Assert-True ($t -match '(?i)call :Summary')      ":$r no longer reports via :Summary - it may print an unconditional [OK] (regression)."
    }
}

# ===============================================================================
# 26. SteamLight (Batch 4): the Steam path must reach the shortcut PS command via
#     an env var, not be interpolated into a single-quoted PS literal - otherwise
#     a Steam path containing an apostrophe (C:\Users\O'Brien\...) breaks it.
# ===============================================================================
Invoke-Test ':SteamLight passes the Steam path via env var (apostrophe-safe)' {
    $b = ((Get-RoutineBody -Lines (Read-Lines $CmdPath) -Label 'SteamLight') -join "`n")
    Assert-True ($b -match '(?i)set "PT_SLDIR=') ':SteamLight no longer stages the Steam path in PT_SLDIR before the shortcut PS call (regression).'
    Assert-True ($b -match '(?i)\$env:PT_SLDIR')  ':SteamLight no longer reads the Steam path from $env:PT_SLDIR - it interpolates it into the PS string, which an apostrophe in the path would break (regression).'
}

# ===============================================================================
# 27. Preset honesty (Batch 5): :PresetBegin resets _FAILS so each preset's final
#     line (routed through :Summary) reflects only that preset's registry writes -
#     no preset prints an unconditional [OK].
# ===============================================================================
Invoke-Test 'Preset apply reports via :Summary (gated on _FAILS), not a blind [OK]' {
    $cmd = Read-Lines $CmdPath
    $pb = ((Get-RoutineBody -Lines $cmd -Label 'PresetBegin') -join "`n")
    Assert-True ($pb -match '(?i)set "_FAILS=0"') ':PresetBegin does not reset _FAILS - a preset :Summary would carry a stale count from a prior action (regression).'
    $all = ($cmd -join "`n")
    Assert-True ($all -notmatch '(?i)echo \[OK\] (LIGHT|MODERATE|HEAVY|Custom) preset') 'A preset still prints an unconditional [OK] instead of routing through :Summary (regression).'
    foreach ($r in 'PresetLight','PresetModerate','PresetHeavy') {
        $t = ((Get-RoutineBody -Lines $cmd -Label $r) -join "`n")
        Assert-True ($t -match '(?i)call :Summary') ":$r no longer reports via :Summary (regression)."
    }
}

# ===============================================================================
# 28. Repair/PS-action honesty (Batch 5): the admin-requiring repair actions gate
#     their status on elevation (a not-elevated run shows [WARN], not a blind [OK]).
# ===============================================================================
Invoke-Test 'Repair actions gate their status on elevation (not a blind [OK])' {
    $cmd = Read-Lines $CmdPath
    foreach ($r in 'SfcDism','WUReset','CompactWinSxS','MemCompress') {
        $t = ((Get-RoutineBody -Lines $cmd -Label $r) -join "`n")
        Assert-True ($t -match '(?im)^\s*if "%_ELEV%"=="0"') ":$r no longer gates its result on elevation (%_ELEV%) - it prints a blind [OK] even when not elevated (regression)."
        Assert-True ($t -match '(?i)\[WARN\]') ":$r has no [WARN] branch for the not-elevated case (regression)."
    }
}

# ---- summary ------------------------------------------------------------------
Write-Host ""
if ($script:Failures.Count -eq 0) {
    Write-Host ("All {0} test(s) passed." -f $script:Total) -ForegroundColor Green
    exit 0
}
else {
    Write-Host ("{0} of {1} test(s) FAILED: {2}" -f $script:Failures.Count, $script:Total, ($script:Failures -join ', ')) -ForegroundColor Red
    exit 1
}
