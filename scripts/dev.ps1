#!/usr/bin/env pwsh
# ─────────────────────────────────────────────────────────────────────────────
# RBX Rewards — Developer CLI
# Usage:
#   .\scripts\dev.ps1 run       → Run app on connected device
#   .\scripts\dev.ps1 test      → Run all E2E tests
#   .\scripts\dev.ps1 test 01   → Run single E2E test suite (01_onboarding...)
#   .\scripts\dev.ps1 build     → Build release APK
#   .\scripts\dev.ps1 setup     → First-time setup (copy env template)
# ─────────────────────────────────────────────────────────────────────────────

param(
    [Parameter(Position = 0)]
    [string]$Command = "run",

    [Parameter(Position = 1)]
    [string]$Suite = ""
)

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

$EnvFile     = "env.json"
$EnvTestFile = "env.test.json"
$EnvExample  = "env.example.json"

# ── Guard: env.json must exist ───────────────────────────────────────────────
function Assert-EnvExists {
    param([string]$File)
    if (-not (Test-Path $File)) {
        Write-Host ""
        Write-Host "  ERROR: $File not found." -ForegroundColor Red
        Write-Host "  Copy the template and fill in your real keys:" -ForegroundColor Yellow
        Write-Host "    Copy-Item $EnvExample $File" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
}

# ── Detect connected Android device ──────────────────────────────────────────
function Get-AndroidDevice {
    $devices = flutter devices 2>&1 | Select-String "android-arm"
    if ($devices) {
        $line = $devices[0].Line
        if ($line -match '• ([a-f0-9]+) •') {
            return $Matches[1]
        }
    }
    return $null
}

switch ($Command.ToLower()) {

    # ── flutter run ───────────────────────────────────────────────────────────
    "run" {
        Assert-EnvExists $EnvFile
        $device = Get-AndroidDevice
        $deviceArg = if ($device) { "-d $device" } else { "" }
        Write-Host "▶  Running RBX Rewards (dev mode)..." -ForegroundColor Cyan
        Invoke-Expression "flutter run $deviceArg --dart-define-from-file=$EnvFile"
    }

    # ── E2E tests ─────────────────────────────────────────────────────────────
    "test" {
        Assert-EnvExists $EnvTestFile
        $device = Get-AndroidDevice
        if (-not $device) {
            Write-Host "  ERROR: No Android device connected. Plug in your device and enable USB Debugging." -ForegroundColor Red
            exit 1
        }

        if ($Suite -ne "") {
            # Run specific suite e.g. .\scripts\dev.ps1 test 05
            $pattern = "integration_test\${Suite}_*.dart"
            $file = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $file) {
                Write-Host "  ERROR: No test file matching '$pattern' found." -ForegroundColor Red
                exit 1
            }
            Write-Host "▶  Running E2E suite: $($file.Name)" -ForegroundColor Cyan
            flutter test $file.FullName -d $device --dart-define-from-file=$EnvTestFile -v
        } else {
            Write-Host "▶  Running all E2E suites on device $device..." -ForegroundColor Cyan
            flutter test integration_test/ -d $device --dart-define-from-file=$EnvTestFile -v
        }
    }

    # ── Release build ─────────────────────────────────────────────────────────
    "build" {
        Assert-EnvExists $EnvFile
        Write-Host "▶  Building release APK..." -ForegroundColor Cyan
        flutter build apk --release --dart-define-from-file=$EnvFile --obfuscate --split-debug-info=build/debug-info
        Write-Host ""
        Write-Host "  APK: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
    }

    # ── First-time setup ──────────────────────────────────────────────────────
    "setup" {
        if (-not (Test-Path $EnvFile)) {
            Copy-Item $EnvExample $EnvFile
            Write-Host "  Created $EnvFile from template." -ForegroundColor Green
            Write-Host "  Open it and fill in your real API keys." -ForegroundColor Yellow
        } else {
            Write-Host "  $EnvFile already exists." -ForegroundColor Green
        }
        if (-not (Test-Path $EnvTestFile)) {
            Copy-Item "env.example.json" $EnvTestFile
            Write-Host "  Created $EnvTestFile — set INTEGRATION_TEST to true inside it." -ForegroundColor Yellow
        }
        flutter pub get
        Write-Host ""
        Write-Host "  Setup complete!" -ForegroundColor Green
    }

    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host "Usage: .\scripts\dev.ps1 [run|test|build|setup] [suite_number]"
        exit 1
    }
}
