# Bolt CLI Installer (Windows) — https://sparcle.app/install-cli.ps1
# Installs the `bolt-cli` command-line tool on Windows x64.
#
# Usage:
#   irm https://sparcle.app/install-cli.ps1 | iex                      # latest
#   $env:BOLT_VERSION='0.1.138'; irm https://sparcle.app/install-cli.ps1 | iex   # pin
#
# PowerShell counterpart to install-cli.sh. Same contract, same asset naming,
# same version-resolution + walk-back behavior; only the OS mechanics differ
# (no `uname`, no chmod, PATH lives in the user environment registry rather than
# a shell rc). Kept deliberately parallel to the .sh so the two can be diffed.
#
# After install, run:
#   bolt-cli connect --token <TOKEN>

$ErrorActionPreference = 'Stop'

$FallbackVersion = '0.1.0'
$GitHubRepo      = 'SparcleHQ/sparcle.app'
# Only x64 ships today — same single-triple story as Linux in the .sh.
$RustTriple      = 'x86_64-pc-windows-msvc'
$InstallDir      = Join-Path $env:LOCALAPPDATA 'Bolt\bin'

function Info($m) { Write-Host "==> $m" -ForegroundColor Blue }
function Ok($m)   { Write-Host " OK  $m" -ForegroundColor Green }
function Warn($m) { Write-Host " !   $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host " X   $m" -ForegroundColor Red; exit 1 }

# ── Architecture gate ────────────────────────────────────────────────────────
# ARM64 Windows can run x64 binaries under emulation, but we ship no native
# arm64 bolt-cli, so say so plainly rather than silently installing a slow one.
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -eq 'ARM64') {
    Warn 'Native ARM64 bolt-cli is not published yet; installing the x64 build (runs under emulation).'
} elseif ($arch -ne 'AMD64') {
    Fail "Unsupported architecture: $arch. bolt-cli requires x64."
}

# ── Resolve target version ───────────────────────────────────────────────────
# Precedence matches the .sh: $BOLT_VERSION > /releases/latest > fallback.
$Version = $env:BOLT_VERSION
if ([string]::IsNullOrWhiteSpace($Version)) {
    $VersionPinned = $false
    try {
        $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubRepo/releases/latest" `
            -Headers @{ 'User-Agent' = 'bolt-cli-installer' } -TimeoutSec 15
        $Version = ($latest.tag_name -replace '^v', '')
    } catch {
        $Version = $FallbackVersion
        Warn "Could not fetch latest version - using v$Version"
    }
} else {
    $VersionPinned = $true
    $Version = ($Version -replace '^v', '')
}

function Get-AssetUrl($v) {
    "https://github.com/$GitHubRepo/releases/download/v$v/bolt-cli-$v-$RustTriple.exe"
}
function Test-AssetExists($url) {
    try {
        $r = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -MaximumRedirection 5 -UseBasicParsing
        return ($r.StatusCode -eq 200)
    } catch { return $false }
}

$FileUrl = Get-AssetUrl $Version

# ── Per-platform walk-back ───────────────────────────────────────────────────
# Same rationale as the .sh: a partial ship (or a single-asset upload that 502'd
# from GitHub) can leave /releases/latest without THIS platform's bolt-cli. Walk
# back to the newest release that actually has it. Skipped when pinned.
if (-not $VersionPinned -and -not (Test-AssetExists $FileUrl)) {
    Warn "v$Version does not yet have bolt-cli for $RustTriple - checking earlier releases..."
    try {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubRepo/releases?per_page=10" `
            -Headers @{ 'User-Agent' = 'bolt-cli-installer' } -TimeoutSec 15
        foreach ($r in $releases) {
            $v = ($r.tag_name -replace '^v', '')
            if ($v -eq $Version) { continue }
            if (Test-AssetExists (Get-AssetUrl $v)) {
                Warn "Installing bolt-cli v$v (latest v$Version is mid-ship for $RustTriple)"
                $Version = $v
                $FileUrl = Get-AssetUrl $v
                break
            }
        }
    } catch {
        Warn 'Could not enumerate releases; continuing with the resolved version.'
    }
}

Write-Host ''
Write-Host '  Bolt CLI Installer'
Write-Host '  -------------------------------------'
Write-Host "  Version:   $Version"
Write-Host "  Platform:  $RustTriple"
Write-Host "  Install:   $InstallDir"
Write-Host ''

# ── Download ─────────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$target = Join-Path $InstallDir 'bolt-cli.exe'
$tmp    = "$target.download"

Info "Downloading bolt-cli v$Version..."
try {
    Invoke-WebRequest -Uri $FileUrl -OutFile $tmp -TimeoutSec 300 -UseBasicParsing
} catch {
    Fail "Download failed from $FileUrl - $($_.Exception.Message)"
}
if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -lt 10000) {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Fail 'Downloaded file looks truncated. Try again, or pin a version with $env:BOLT_VERSION.'
}

# Replace atomically-ish. A running bolt-cli holds a lock on Windows, so say so
# rather than leaving a half-written binary in place.
try {
    Move-Item -Force $tmp $target
} catch {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Fail "Could not replace $target - close any running bolt-cli and re-run."
}
Ok "Installed to $target"

# ── PATH ─────────────────────────────────────────────────────────────────────
# User-scope PATH only: no admin rights needed, mirroring the .sh's ~/.local/bin.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$InstallDir*") {
    $newPath = if ([string]::IsNullOrEmpty($userPath)) { $InstallDir } else { "$userPath;$InstallDir" }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Ok "Added $InstallDir to your PATH"
    Warn 'Open a NEW terminal for the PATH change to take effect.'
} else {
    Ok 'PATH already contains the install directory'
}
# Make it usable in THIS session too, so the connect command below just works.
if ($env:Path -notlike "*$InstallDir*") { $env:Path = "$env:Path;$InstallDir" }

Write-Host ''
Ok 'bolt-cli is ready'
Write-Host '  Next:  bolt-cli connect --token <TOKEN>'
Write-Host ''
