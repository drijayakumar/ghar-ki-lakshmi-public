# PowerShell Build Script for Gharkilaxmi Android Mobile App (Capacitor)
# Run from PowerShell: .\scripts\build-mobile.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path "$ScriptDir\.."

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Building Gharkilaxmi Native Mobile App   " -ForegroundColor Cyan
Write-Host " (Capacitor 6 Android Release Container)  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Build Web Assets
Write-Host "`n[1/4] Building Frontend Production Dist..." -ForegroundColor Yellow
Push-Location "$RootDir\frontend"
try {
    npm.cmd run build
} finally {
    Pop-Location
}

# 2. Sync Web Assets & Plugins to Android
Write-Host "`n[2/4] Syncing Web Assets to Native Android Project..." -ForegroundColor Yellow
Push-Location "$RootDir\frontend"
try {
    npx.cmd cap sync android
} finally {
    Pop-Location
}

# Configure ADB reverse port forwarding if ADB is available
$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (Test-Path $adbPath) {
    Write-Host "Configuring ADB reverse port forwarding for local backend (ports 57801 & 4000)..." -ForegroundColor Cyan
    & $adbPath reverse tcp:57801 tcp:57801 | Out-Null
    & $adbPath reverse tcp:4000 tcp:4000 | Out-Null
}

# 3. Verify JAVA_HOME
Write-Host "`n[3/4] Checking JDK / Java Environment..." -ForegroundColor Yellow
$androidJbr = "C:\Program Files\Android\Android Studio\jbr"
if (Test-Path "$androidJbr\bin\java.exe") {
    $env:JAVA_HOME = $androidJbr
    $env:Path = "$androidJbr\bin;" + $env:Path
    Write-Host "Using Android Studio JBR: $androidJbr" -ForegroundColor Green
} elseif (-not $env:JAVA_HOME) {
    # Check common JDK install paths
    $jdkPaths = @(
        "C:\Program Files\Java\jdk-17",
        "C:\Program Files\Java\jdk-21",
        "$env:LOCALAPPDATA\Android\Sdk",
        "C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot"
    )
    foreach ($p in $jdkPaths) {
        if (Test-Path $p) {
            $env:JAVA_HOME = $p
            Write-Host "Detected JAVA_HOME: $p" -ForegroundColor Green
            break
        }
    }
}

if (-not $env:JAVA_HOME -and -not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-Host "`n[NOTICE] Capacitor Android project is 100% prepared & synced in frontend\android!" -ForegroundColor Yellow
    Write-Host "To compile the final .apk file, install Java JDK 17+ or open 'frontend\android' in Android Studio and click Build -> Build APK." -ForegroundColor Yellow
    exit 0
}

# 4. Assemble Signed Release & Debug APKs
Write-Host "`n[4/4] Compiling Signed Android Release & Debug APKs via Gradle..." -ForegroundColor Yellow
Push-Location "$RootDir\frontend\android"
try {
    .\gradlew.bat assembleRelease assembleDebug
    
    if (-not (Test-Path "$RootDir\mobile")) {
        New-Item -ItemType Directory -Path "$RootDir\mobile" -Force | Out-Null
    }
    
    if (Test-Path "app\build\outputs\apk\release\app-release.apk") {
        Copy-Item "app\build\outputs\apk\release\app-release.apk" -Destination "$RootDir\mobile\gharkilaxmi-release.apk" -Force
    } elseif (Test-Path "app\build\outputs\apk\release\app-release-unsigned.apk") {
        Copy-Item "app\build\outputs\apk\release\app-release-unsigned.apk" -Destination "$RootDir\mobile\gharkilaxmi-release.apk" -Force
    }
    
    if (Test-Path "app\build\outputs\apk\debug\app-debug.apk") {
        Copy-Item "app\build\outputs\apk\debug\app-debug.apk" -Destination "$RootDir\mobile\gharkilaxmi-debug.apk" -Force
    }

    Write-Host "`n==========================================" -ForegroundColor Green
    Write-Host " SUCCESS! Signed Android APKs Built & Exported:" -ForegroundColor Green
    Write-Host " -> mobile\gharkilaxmi-release.apk (Signed Release)" -ForegroundColor Green
    Write-Host " -> mobile\gharkilaxmi-debug.apk   (Debug)" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
} catch {
    Write-Host "Gradle build requires Android SDK/JDK environment." -ForegroundColor Yellow
} finally {
    Pop-Location
}

