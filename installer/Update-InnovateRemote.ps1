<#
  Innovate - Update-InnovateRemote.ps1  (Oct 3 2026)

  Keeps Innovate Remote up to date on this PC. Runs every night as a Windows scheduled task (set up by Install-InnovateRemote.ps1),
  or by hand:   powershell -NoProfile -ExecutionPolicy Bypass -File Update-InnovateRemote.ps1 [-DryRun] [-Force]

  What it does
    1. asks license.taquiai.ai which build is the newest (a plain number: bigger = newer)
    2. if this PC already has it, it only tells the server which build this PC runs (the Remote tab shows who is behind) and stops
    3. if a remote session is open on this PC it stops and tries again tomorrow night (never interrupts a session)
    4. downloads the new installer, checks its SHA-256 against the published value, installs it over the old one
    5. checks that the service came back, the PC's ID is unchanged and the firm id is still set; if not it puts the previous build back
    6. keeps the installer it just used (current) and the one before it (previous) in C:\ProgramData\Innovate\Remote, plus update.log

  -DryRun  : does steps 1-4 (download and checksum) but changes nothing on the PC.
  -Force   : installs the newest build even if this PC already reports it.
#>
param([switch]$DryRun, [switch]$Force)
$ErrorActionPreference = "Stop"
$Api = "https://license.taquiai.ai/api/remote"
$Dir = if ($env:INNOVATE_REMOTE_DIR) { $env:INNOVATE_REMOTE_DIR } else { Join-Path $env:ProgramData "Innovate\Remote" }
$Exe = if ($env:INNOVATE_REMOTE_EXE) { $env:INNOVATE_REMOTE_EXE } else { Join-Path $env:ProgramFiles "InnovateRemote\InnovateRemote.exe" }
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$LogFile = Join-Path $Dir "update.log"
$BuildFile = Join-Path $Dir "build.txt"
$Cur = Join-Path $Dir "current.exe"
$Prev = Join-Path $Dir "previous.exe"
$New = Join-Path $Dir "new.exe"

function Log($m) {
    $line = "[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] " + $m
    Write-Host $line
    try {
        Add-Content -Path $LogFile -Value $line
        if ((Get-Item $LogFile).Length -gt 200KB) { Get-Content $LogFile -Tail 400 | Set-Content ($LogFile + ".tmp"); Move-Item ($LogFile + ".tmp") $LogFile -Force }
    } catch {}
}
function Lastword($t) { $x = ($t | Out-String).Trim(); if (-not $x) { return "" }; ($x -split "\s+")[-1] }
function Run-Exe { param([string[]]$a) (& $Exe @a | Out-String).Trim() }   # piped, so the output of the Windows program is really returned
function Get-Build { if (Test-Path $BuildFile) { try { [int](Get-Content $BuildFile -TotalCount 1) } catch { 0 } } else { 0 } }
function Get-Svc { Get-Service | Where-Object { $_.Name -match 'InnovateRemote|Innovate Remote' } | Select-Object -First 1 }
function In-Session {
    # a session is open while a connection-manager / connect / file-transfer helper process of the app is running
    $p = Get-CimInstance Win32_Process -Filter "Name='InnovateRemote.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match '--cm|--connect|--file-transfer|--port-forward|--view-camera|--terminal' }
    return [bool]$p
}
function Report-Build($build) {
    try {
        $firm = Lastword (Run-Exe @('--option','innovate-firm-id'))
        $id = Lastword (Run-Exe @('--get-id'))
        if ($firm -and $id -and $build -gt 0) {
            $body = @{ firm_id = $firm; remote_id = $id; build = [int]$build } | ConvertTo-Json
            Invoke-RestMethod -Uri "$Api/report-build" -Method Post -ContentType "application/json" -Body $body | Out-Null
        }
    } catch { Log "could not report the build: $($_.Exception.Message)" }
}

try {
    if (-not (Test-Path $Exe)) { Log "Innovate Remote is not installed here - nothing to update."; exit 0 }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $have = Get-Build
    $latest = Invoke-RestMethod -Uri "$Api/latest" -TimeoutSec 30
    $want = [int]$latest.build
    Log "this PC: build $have; newest published: build $want"
    if ($want -le 0) { Log "nothing published yet."; exit 0 }
    if ($want -le $have -and -not $Force) { Report-Build $have; Log "up to date."; exit 0 }

    if (In-Session) { Log "a remote session is open - not updating now, trying again at the next run."; exit 0 }

    Log "downloading build $want ..."
    Invoke-WebRequest -Uri $latest.url -OutFile $New -UseBasicParsing -TimeoutSec 600
    $hash = (Get-FileHash -Algorithm SHA256 -Path $New).Hash.ToLower()
    if ($hash -ne ([string]$latest.sha256).ToLower()) {
        Remove-Item $New -Force -ErrorAction SilentlyContinue
        throw "the downloaded file does not match the published checksum - NOT installing it"
    }
    Log "checksum ok ($($hash.Substring(0,12))...)."
    if ($DryRun) { Log "DRY RUN - stopping here, nothing was changed."; Remove-Item $New -Force -ErrorAction SilentlyContinue; exit 0 }

    $id0 = Lastword (Run-Exe @('--get-id'))
    $firm0 = Lastword (Run-Exe @('--option','innovate-firm-id'))
    if (-not $id0) { throw "cannot read this PC's ID right now - not updating blind; will try again at the next run" }
    Log "installing build $want over build $have (ID $id0) ..."
    $svc = Get-Svc
    if ($svc) { Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue }
    Get-Process InnovateRemote -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 3
    Start-Process -FilePath $New -ArgumentList "--silent-install"
    $ok = $false
    for ($t = 0; $t -lt 150; $t += 3) {
        $s = Get-Svc
        if ((Test-Path $Exe) -and $s -and $s.Status -eq "Running") { $ok = $true; break }
        Start-Sleep 3
    }
    if ($ok) {
        Start-Sleep 10
        $id1 = Lastword (Run-Exe @('--get-id'))
        $firm1 = Lastword (Run-Exe @('--option','innovate-firm-id'))
        if ($id1 -ne $id0) { $ok = $false; Log "check failed: the PC's ID changed ($id0 -> $id1)." }
        elseif ($firm0 -and ($firm1 -ne $firm0)) { $ok = $false; Log "check failed: the firm id was lost." }
    } else { Log "check failed: the service did not start." }

    if ($ok) {
        if (Test-Path $Cur) { Copy-Item $Cur $Prev -Force }
        Move-Item $New $Cur -Force
        Set-Content -Path $BuildFile -Value "$want"
        Log "UPDATED to build $want."
        Report-Build $want
        exit 0
    }

    # ---- roll back ----------------------------------------------------------------------
    Log "rolling back ..."
    Remove-Item $New -Force -ErrorAction SilentlyContinue
    if (Test-Path $Cur) {
        Get-Service | Where-Object { $_.Name -match 'InnovateRemote|Innovate Remote' } | ForEach-Object { Stop-Service $_.Name -Force -ErrorAction SilentlyContinue }
        Get-Process InnovateRemote -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 3
        Start-Process -FilePath $Cur -ArgumentList "--silent-install"
        for ($t = 0; $t -lt 150; $t += 3) {
            $s = Get-Svc
            if ($s -and $s.Status -eq "Running") { break }
            Start-Sleep 3
        }
        Log "previous build $have put back (service: $((Get-Svc).Status))."
    } else {
        Log "no copy of the previous installer is stored on this PC - cannot roll back automatically; run Install-InnovateRemote.ps1 to repair."
    }
    exit 1
} catch {
    Log "update failed: $($_.Exception.Message)"
    exit 1
}
