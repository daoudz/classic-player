# ---------------------------------------------------------------------------
# Classic Player - Build & Packaging Script for Windows
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot
$cacheDir = Join-Path $PSScriptRoot "cache"
$distDir = Join-Path $rootDir "dist\ClassicPlayer-Windows-Portable"

Write-Host "==> Ensuring directories exist..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force $cacheDir | Out-Null
New-Item -ItemType Directory -Force $distDir | Out-Null

$mpvExtracted = Join-Path $cacheDir "mpv-win\x"
if (-not (Test-Path (Join-Path $mpvExtracted "mpv.exe"))) {
    Write-Host "==> Fetching mpv portable build..." -ForegroundColor Cyan
    $zipPath = Join-Path $cacheDir "mpv-win.zip"
    if (-not (Test-Path $zipPath)) {
        $url = "https://github.com/mpv-player/mpv/releases/download/v0.41.0/mpv-v0.41.0-x86_64-w64-mingw32.zip"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $zipPath
    }
    
    Expand-Archive -Path $zipPath -DestinationPath (Join-Path $cacheDir "mpv-win") -Force
    $innerZip = (Get-ChildItem (Join-Path $cacheDir "mpv-win\*.zip")).FullName
    Expand-Archive -Path $innerZip -DestinationPath $mpvExtracted -Force
}

Write-Host "==> Compiling native ClassicPlayer.exe launcher..." -ForegroundColor Cyan
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$launcherSrc = Join-Path $rootDir "src\launcher\Launcher.cs"
$launcherIco = Join-Path $rootDir "src\launcher\app.ico"
$launcherOut = Join-Path $rootDir "src\launcher\ClassicPlayer.exe"

& $csc /target:winexe /optimize+ /win32icon:"$launcherIco" /out:"$launcherOut" "$launcherSrc"

Write-Host "==> Assembling Windows portable distribution..." -ForegroundColor Cyan
Copy-Item (Join-Path $mpvExtracted "*.dll") $distDir -Force
Copy-Item (Join-Path $mpvExtracted "*.exe") $distDir -Force
Copy-Item (Join-Path $mpvExtracted "*.com") $distDir -Force
Copy-Item $launcherOut $distDir -Force

$batchLauncher = Join-Path $distDir "Classic Player.bat"
Set-Content -Path $batchLauncher -Value @"
@echo off
setlocal
cd /d "%~dp0"
start "" "%~dp0ClassicPlayer.exe" %*
"@

# Copy portable_config
Copy-Item (Join-Path $rootDir "src\portable_config") $distDir -Recurse -Force

# Copy samples if present
if (Test-Path (Join-Path $rootDir "sample.mp4")) {
    Copy-Item (Join-Path $rootDir "sample.mp4") $distDir -Force
}
if (Test-Path (Join-Path $rootDir "sample.srt")) {
    Copy-Item (Join-Path $rootDir "sample.srt") $distDir -Force
}
if (Test-Path (Join-Path $rootDir "sample.wav")) {
    Copy-Item (Join-Path $rootDir "sample.wav") $distDir -Force
}

Write-Host "==> Classic Player Windows Portable built successfully in: $distDir" -ForegroundColor Green
