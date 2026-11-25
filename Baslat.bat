@echo off
setlocal
cd /d "%~dp0"

set "PROJECT=pc\NoxirPlay.PC\NoxirPlay.PC.csproj"
set "APP_PATH=pc\NoxirPlay.PC\bin\Debug\net8.0-windows10.0.19041.0\NoxirPlay.PC.exe"

REM Onceki acik kalan ornegi kapat (dosya kilitleme hatasini onler)
taskkill /f /im NoxirPlay.PC.exe >nul 2>&1

dotnet build "%PROJECT%"
if errorlevel 1 (
    echo.
    echo Derleme basarisiz oldu. Uygulama baslatilmadi.
    pause
    exit /b 1
)

if not exist "%APP_PATH%" (
    echo Derleme tamamlandi ancak uygulama dosyasi bulunamadi: %APP_PATH%
    pause
    exit /b 1
)

"%APP_PATH%"
set "APP_EXIT=%ERRORLEVEL%"
if not "%APP_EXIT%"=="0" (
    echo.
    echo NOXIR Play kapandi. Cikis kodu: %APP_EXIT%
    if exist "%LOCALAPPDATA%\NOXIR Play\native-crash.log" (
        echo Yerel hata ayrintisi:
        type "%LOCALAPPDATA%\NOXIR Play\native-crash.log"
    )
    pause
)
exit /b %APP_EXIT%
