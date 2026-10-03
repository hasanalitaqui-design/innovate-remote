<#
  Innovate - Replace-PlainClient.ps1  (Oct 3 2026)

  For a PC that runs the PLAIN RustDesk client (our early test install): asks for what it needs FIRST, then removes the plain client
  and installs the Innovate Remote build, registered under a firm. The connection you are using right now WILL drop for about two minutes
  (the PC gets a new ID: it appears in the licence dashboard, Remote tab, with the label you choose).

  Run in a PowerShell window opened as Administrator:
      powershell -NoProfile -ExecutionPolicy Bypass -File .\Replace-PlainClient.ps1 -Firm firm_xxxxxxxxxxxxxxxx -Label "TESTWS"

  Nothing is removed until the new installer has been downloaded and its checksum checked, and the install code has been typed.
#>
param(
    [Parameter(Mandatory = $true)][string]$Firm,
    [string]$Label = $env:COMPUTERNAME
)
$ErrorActionPreference = "Stop"
$Api = "https://license.taquiai.ai/api/remote"
$Work = "C:\Temp\IR"
function Say($m) { Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] " + $m) }
function Plain($secure) { [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)) }
trap { Write-Host ""; Write-Host ("STOPPED - " + $_.Exception.Message) -ForegroundColor Red; Read-Host "Press Enter to close" | Out-Null; exit 1 }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Open PowerShell with 'Run as administrator' and run this again."
}
New-Item -ItemType Directory -Force -Path $Work | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. everything is prepared BEFORE anything is removed
Say "Getting the newest Innovate Remote installer..."
$latest = Invoke-RestMethod -Uri "$Api/latest" -TimeoutSec 30
if (-not $latest.build) { throw "no build is published yet" }
$exe = Join-Path $Work "InnovateRemote-Setup.exe"
Invoke-WebRequest -Uri $latest.url -OutFile $exe -UseBasicParsing -TimeoutSec 600
if ((Get-FileHash -Algorithm SHA256 -Path $exe).Hash.ToLower() -ne ([string]$latest.sha256).ToLower()) { throw "the installer does not match its checksum - nothing was changed" }
Say "Installer ok (build $($latest.build))."
foreach ($f in @("Install-InnovateRemote.ps1", "Update-InnovateRemote.ps1")) {
    Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/hasanalitaqui-design/innovate-remote/innovate-scripts/installer/$f" -OutFile (Join-Path $Work $f)
}
$code = (Read-Host "Install code (XXXX-XXXX-XXXX) - shown as you type so you can check it").Trim().ToUpper()
$p1 = Plain (Read-Host "Choose the password for THIS PC (at least 8 characters)" -AsSecureString)
$p2 = Plain (Read-Host "Type it again" -AsSecureString)
if ($p1 -ne $p2) { throw "the two passwords are not the same - nothing was changed" }
if ($p1.Length -lt 8) { throw "the password needs at least 8 characters - nothing was changed" }

# 2. remove the plain client (this is where your remote connection drops)
Say "Removing the plain RustDesk client. Your connection drops now; find this PC in the dashboard's Remote tab in about 2 minutes."
Get-Service | Where-Object { $_.Name -match '^RustDesk$' } | ForEach-Object { Stop-Service $_.Name -Force -ErrorAction SilentlyContinue }
$plain = "$env:ProgramFiles\RustDesk\rustdesk.exe"
if (Test-Path $plain) { & $plain --uninstall | Out-Null; Start-Sleep 8 }
Get-Process rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# 3. install the Innovate build, registered under the firm
Say "Installing Innovate Remote..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Work "Install-InnovateRemote.ps1") -Firm $Firm -Passphrase $code -Password $p1 -Label $Label -InstallerPath $exe
Say "Finished. Look at the Remote tab in the licence dashboard for this PC's new ID."
Read-Host "Press Enter to close" | Out-Null
