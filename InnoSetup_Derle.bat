@echo off
chcp 65001 >nul
echo ===================================================================
echo   NOXIR Play - Inno Setup Kurulum Paketi Derleyici
echo ===================================================================
echo.

set SCRIPT_DIR=%~dp0
set ISCC_EXE=%SCRIPT_DIR%.tools\InnoSetup\ISCC.exe
set ISS_FILE=%SCRIPT_DIR%noxirplay.iss

if not exist "%ISCC_EXE%" (
    echo [HATA] Inno Setup derleyicisi bulunamadi: %ISCC_EXE%
    pause
    exit /b 1
)

if not exist "%ISS_FILE%" (
    echo [HATA] noxirplay.iss dosyasi bulunamadi: %ISS_FILE%
    pause
    exit /b 1
)

echo [BILGI] Inno Setup derleniyor, lutfen bekleyin...
echo.
"%ISCC_EXE%" "%ISS_FILE%"

if %ERRORLEVEL% equ 0 (
    echo.
    echo ===================================================================
    echo   KURULUM PAKETI BASARIYLA DERLENDI!
    echo   Cikti Klasoru: %SCRIPT_DIR%InnoSetup_Output
    echo ===================================================================
) else (
    echo.
    echo [HATA] Derleme sirasinda bir hata olustu.
)

echo.
pause
