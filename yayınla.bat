@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ===================================================================
echo   NOXIR Play - Otomatik Guncelleme Yayinlama (GitHub / Site)
echo ===================================================================
echo.

set "UPDATE_CS=%~dp0pc\NoxirPlay.PC\UpdateService.cs"
set "VER_JSON=%~dp0version.json"

if not exist "%UPDATE_CS%" (
    echo [HATA] UpdateService.cs bulunamadi!
    pause
    exit /b 1
)

:: 1. Mevcut surumu UpdateService.cs'den oku ve bir sonraki surumu oner
for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "$c = Get-Content '%UPDATE_CS%' -Raw; if ($c -match 'CurrentVersion = \"([^\"]+)\"') { $matches[1] }"`) do set "CUR_VER=%%v"
for /f "usebackq delims=" %%n in (`powershell -NoProfile -Command "$p = '%CUR_VER%'.Split('.'); if ($p.Length -eq 3) { $p[2] = [int]$p[2] + 1; $p -join '.' } else { '%CUR_VER%' }"`) do set "NEXT_VER=%%n"

echo Mevcut Surum : %CUR_VER%
set /p "NEW_VER=Yeni Surum (Enter = %NEXT_VER%): "
if "%NEW_VER%"=="" set "NEW_VER=%NEXT_VER%"

echo.
echo [1/3] Surum numarasi %NEW_VER% olarak guncelleniyor...
powershell -NoProfile -Command "$c = Get-Content '%UPDATE_CS%' -Raw; $c = $c -replace 'CurrentVersion = \"[^\"]+\"', 'CurrentVersion = \"%NEW_VER%\"'; Set-Content '%UPDATE_CS%' $c -Encoding UTF8"

if exist "%VER_JSON%" (
    powershell -NoProfile -Command "$j = Get-Content '%VER_JSON%' -Raw | ConvertFrom-Json; $j.version = '%NEW_VER%'; $j | ConvertTo-Json -Depth 10 | Set-Content '%VER_JSON%' -Encoding UTF8"
) else (
    echo {"version":"%NEW_VER%"} > "%VER_JSON%"
)

echo.
echo [2/3] Degisiklikler Git'e ekleniyor...
git add -A
git commit -m "Release v%NEW_VER%"

echo.
echo [3/3] GitHub'a (siteye) gonderiliyor...
git branch -M main
git push -u origin main
if %ERRORLEVEL% neq 0 (
    echo.
    echo [HATA] GitHub'a gonderilemedi! Git giris bilgilerini veya ag baglantisini kontrol et.
    pause
    exit /b 1
)

echo.
echo ===================================================================
echo   GUNCELLEME SITEDE YAYINLANDI! (v%NEW_VER%)
echo ===================================================================
echo.
pause
