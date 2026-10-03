<#
  Innovate - Install-InnovateRemote.ps1  (rewritten Oct 3 2026 for the Innovate-branded app + licensing)

  Installs Innovate Remote on THIS computer, registers it as a licence under a firm, sets the unattended-access password.
  Easiest way: double-click "Install Innovate Remote.cmd" (same folder). It asks for what it needs.

  Run by hand (PowerShell opened with "Run as administrator"):
      .\Install-InnovateRemote.ps1 -Firm firm_xxxxxxxx -Passphrase "XXXX-XXXX-XXXX" -Password "<unattended password>" -Label "Front desk"

  What it does
    1. installs InnovateRemote-Setup.exe (next to this script; downloaded from the Innovate release page if it is not there) silently as a Windows SERVICE
       (so it works at the login screen, sees UAC prompts and survives restarts)
    2. writes the firm id into the app (the app checks the licence server with it)
    3. sets the unattended-access password (never printed, never logged)
    4. registers this PC under the firm on license.taquiai.ai (the firm passphrase proves you may add a PC to that firm)
    5. prints this PC's ID - the number you type in the viewer to connect

  Options: -Firm (id from the licence dashboard; or put it in firm.txt next to this script)  -Passphrase  -Password  -Label (default: computer name)
           -NoAutoUpdate (skip the nightly update task)  -IdleMinutes (default 15: a session with no activity closes; use 60 for client-firm support PCs, 0 = leave the built-in default)
           -InstallerPath <exe>   -Remove (uninstall)   -Pause (keep the window open at the end)
#>
param(
    [string]$Firm,
    [string]$Passphrase,
    [string]$Password,
    [string]$Label,
    [int]$IdleMinutes = 15,
    [string]$InstallerPath,
    [switch]$Remove,
    [switch]$NoAutoUpdate,
    [switch]$Pause
)
$ErrorActionPreference = "Stop"
$LicenseUrl = "https://license.taquiai.ai/api/remote/register"
$ReleaseUrl = "https://github.com/hasanalitaqui-design/innovate-remote/releases/download/innovate-latest/InnovateRemote-Setup.exe"
$UpdateScriptUrl = "https://raw.githubusercontent.com/hasanalitaqui-design/innovate-remote/innovate-scripts/installer/Update-InnovateRemote.ps1"
$UpdateApi = "https://license.taquiai.ai/api/remote"
$Exe = Join-Path $env:ProgramFiles "InnovateRemote\InnovateRemote.exe"

function Say($m) { Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] " + $m) }
function Finish($code) { if ($Pause) { Read-Host "Press Enter to close this window" | Out-Null }; exit $code }
trap { Write-Host ""; Write-Host ("FAILED - " + $_.Exception.Message) -ForegroundColor Red; Finish 1 }
function Plain($secure) { [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)) }
function Get-RemoteService { Get-Service | Where-Object { $_.Name -match 'InnovateRemote|Innovate Remote' } | Select-Object -First 1 }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($PSCommandPath) {
        Say "Not running as Administrator - asking Windows to restart this script elevated..."
        $a = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-Pause")
        foreach ($pair in @(@("-Firm", $Firm), @("-Passphrase", $Passphrase), @("-Password", $Password), @("-Label", $Label), @("-InstallerPath", $InstallerPath))) {
            if ($pair[1]) { $a += @($pair[0], "`"$($pair[1])`"") }
        }
        $a += @("-IdleMinutes", "$IdleMinutes")
        if ($Remove) { $a += "-Remove" }
        Start-Process powershell.exe -ArgumentList $a -Verb RunAs
        exit
    }
    throw "Please open PowerShell with 'Run as administrator' and run this again."
}

if ($Remove) {
    Say "Removing Innovate Remote..."
    Get-Service | Where-Object { $_.Name -match 'InnovateRemote|Innovate Remote' } | ForEach-Object { Stop-Service $_.Name -Force -ErrorAction SilentlyContinue }
    Get-Process InnovateRemote -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if (Test-Path $Exe) { & $Exe --uninstall | Out-Null; Start-Sleep 8 }
    Write-Host "DONE - removed. (The licence stays registered; suspend or delete it in the licence dashboard if the PC is retired.)" -ForegroundColor Green
    Finish 0
}

# ---- what we need ------------------------------------------------------------------------
$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $Firm -and (Test-Path (Join-Path $here "firm.txt"))) { $Firm = (Get-Content (Join-Path $here "firm.txt") -TotalCount 1).Trim() }
if (-not $Firm) { $Firm = (Read-Host "Firm id (from the licence dashboard, looks like firm_xxxxxxxxxxxxxxxx)").Trim() }
if (-not $Passphrase) { $Passphrase = (Read-Host "Install code (XXXX-XXXX-XXXX) - shown as you type so you can check it").Trim().ToUpper() }
if (-not $Password) {
    $p1 = Plain (Read-Host "Choose the unattended-access password for this PC (at least 8 characters)" -AsSecureString)
    $p2 = Plain (Read-Host "Type it again" -AsSecureString)
    if ($p1 -ne $p2) { throw "the two passwords are not the same - run it again" }
    $Password = $p1
}
if ($Password.Length -lt 8) { throw "The password needs at least 8 characters." }
if (-not $Label) { $Label = $env:COMPUTERNAME }

# ---- install -----------------------------------------------------------------------------
if (-not (Test-Path $Exe)) {
    if (-not $InstallerPath) { $InstallerPath = Join-Path $here "InnovateRemote-Setup.exe" }
    if (-not (Test-Path $InstallerPath)) {
        $InstallerPath = Join-Path $env:TEMP "InnovateRemote-Setup.exe"
        Say "Downloading Innovate Remote..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ReleaseUrl -OutFile $InstallerPath -UseBasicParsing
    }
    Say "Installing silently as a service (the installer stays running as the app, so it is not waited for)..."
    Start-Process -FilePath $InstallerPath -ArgumentList "--silent-install"
    $t = 0
    while ($t -lt 150) {
        $s = Get-RemoteService
        if ((Test-Path $Exe) -and $s -and $s.Status -eq "Running") { break }
        Start-Sleep 3; $t += 3
    }
    if (-not (Test-Path $Exe)) { throw "Innovate Remote was not installed (no $Exe)" }
    if (-not (Get-RemoteService)) { throw "Innovate Remote installed but its service was not found - run this script again" }
    Start-Sleep 5
} else {
    Say "Innovate Remote is already installed - only the licence, password and settings are set."
}

# ---- settings (through the running service) ---------------------------------------------
Say "Writing the firm id..."
& $Exe --option innovate-firm-id $Firm | Out-Null
if ($IdleMinutes -gt 0) { & $Exe --option allow-auto-disconnect Y | Out-Null; & $Exe --option auto-disconnect-timeout "$IdleMinutes" | Out-Null }
Say "Setting the unattended-access password..."
& $Exe --password $Password | Out-Null
Start-Sleep 2
$id = ((& $Exe --get-id | Out-String).Trim() -split "\s+")[-1]
if (-not $id -or $id.Length -lt 6) { throw "could not read this PC's ID - wait a minute and run the script again" }

# ---- licence -----------------------------------------------------------------------------
Say "Registering this PC (ID $id) under the firm..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$machine = ""
try {
    $guid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -ErrorAction Stop).MachineGuid
    $sha = [Security.Cryptography.SHA256]::Create()
    $machine = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("innovate-remote|" + $guid))) -replace "-", "").ToLower()
} catch {}
$body = @{ firm_id = $Firm; passphrase = $Passphrase; remote_id = $id; label = $Label; machine = $machine } | ConvertTo-Json
try {
    $r = Invoke-RestMethod -Uri $LicenseUrl -Method Post -ContentType "application/json" -Body $body
} catch {
    $msg = $_.Exception.Message
    try { $msg = (New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch {}
    throw "the licence server refused the registration: $msg  (Innovate Remote is installed but will not connect until this PC is registered - run the script again with the right firm id and passphrase)"
}
if ($r.status -ne "active") { Write-Host "WARNING - this PC is registered but its licence status is: $($r.status)" -ForegroundColor Yellow }

# ---- auto-update: a nightly task keeps this PC on the newest build --------------------------
if (-not $NoAutoUpdate) {
    try {
        $rdir = Join-Path $env:ProgramData "Innovate\Remote"
        New-Item -ItemType Directory -Force -Path $rdir | Out-Null
        $upd = Join-Path $rdir "Update-InnovateRemote.ps1"
        $src = Join-Path $here "Update-InnovateRemote.ps1"
        if (Test-Path $src) { Copy-Item $src $upd -Force } else { Invoke-WebRequest -Uri $UpdateScriptUrl -OutFile $upd -UseBasicParsing }
        # remember the installer this PC runs (for rolling back) and which build it is (for the dashboard)
        $build = 0
        if ($InstallerPath -and (Test-Path $InstallerPath)) {
            Copy-Item $InstallerPath (Join-Path $rdir "current.exe") -Force
            try {
                $latest = Invoke-RestMethod -Uri "$UpdateApi/latest" -TimeoutSec 30
                if ((Get-FileHash -Algorithm SHA256 -Path $InstallerPath).Hash.ToLower() -eq ([string]$latest.sha256).ToLower()) { $build = [int]$latest.build }
            } catch {}
        }
        Set-Content -Path (Join-Path $rdir "build.txt") -Value "$build"
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$upd`""
        $trigger = New-ScheduledTaskTrigger -Daily -At 2:30am -RandomDelay (New-TimeSpan -Minutes 45)
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        Register-ScheduledTask -TaskName "Innovate_RemoteUpdate" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        Say "Auto-update: a nightly task (about 2:30 AM) keeps this PC on the newest build."
        if ($build -gt 0) {
            $rb = @{ firm_id = $Firm; remote_id = $id; build = $build } | ConvertTo-Json
            try { Invoke-RestMethod -Uri "$UpdateApi/report-build" -Method Post -ContentType "application/json" -Body $rb | Out-Null } catch {}
        }
    } catch {
        Write-Host "WARNING - installed, but the nightly auto-update could not be set up: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Green
Write-Host " SUCCESS - Innovate Remote is installed on $env:COMPUTERNAME" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Say "This PC's ID: $id    (type it in the viewer to connect)"
Say "Licence: registered as '$Label' under the firm.  Idle timeout: $IdleMinutes minutes."
Say "To uninstall: run this script with -Remove"
Finish 0
