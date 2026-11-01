@echo off
echo ========================================================
echo   Echo-Thief: Live Android Fast Deploy and Runner
echo ========================================================

set "TEMP=Q:\tmp"
set "TMP=Q:\tmp"
set "_JAVA_OPTIONS=-Djava.io.tmpdir=Q:\tmp"

set "ADB=C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe"
set "GODOT=D:\download\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
set "APK=q:\GODOT WORKS\echo-thief\build\android\echo_thief.apk"

echo [1/3] Checking connected Android devices...
"%ADB%" devices
for /f "tokens=1,2" %%A in ('"%ADB%" devices') do (
    if "%%B"=="device" (
        set "DEVICE_ID=%%A"
        goto :found_device
    )
)

echo [ERROR] No authorized Android device detected via ADB!
echo Please ensure USB Debugging is ON and tap 'Allow' on your phone.
pause
exit /b 1

:found_device
echo [OK] Connected Device Detected: %DEVICE_ID%

echo.
echo [2/3] Building and exporting Android APK...
"%GODOT%" --headless --path "%~dp0." --export-debug "Android" "%APK%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Godot export failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Installing and launching live on %DEVICE_ID%...
"%ADB%" -s %DEVICE_ID% install -r "%APK%"
"%ADB%" -s %DEVICE_ID% shell am start -n com.echothief.game/com.godot.game.GodotApp

echo.
echo ========================================================
echo   HEIST GAME IS NOW RUNNING LIVE ON YOUR ANDROID PHONE!
echo ========================================================
