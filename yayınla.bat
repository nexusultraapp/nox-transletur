@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ===================================================================
echo   NOXIR Play - Tam Otomatik Guncelleme Yayinlama
echo ===================================================================
echo.

set "UPDATE_CS=%~dp0pc\NoxirPlay.PC\UpdateService.cs"
set "VER_JSON=%~dp0version.json"
set "CSPROJ=%~dp0pc\NoxirPlay.PC\NoxirPlay.PC.csproj"
set "DIST_APP=%~dp0dist\app"
set "ISCC_EXE=%~dp0.tools\InnoSetup\ISCC.exe"
set "ISS_FILE=%~dp0noxirplay.iss"
set "UPDATES_DIR=%~dp0updates"

if not exist "%UPDATE_CS%" (
    echo [HATA] UpdateService.cs bulunamadi!
    pause & exit /b 1
)
if not exist "%ISCC_EXE%" (
    echo [HATA] Inno Setup bulunamadi: %ISCC_EXE%
    pause & exit /b 1
)

:: --- Surum oku ---
powershell -NoProfile -Command ^
  "$c=Get-Content '%UPDATE_CS%' -Raw;" ^
  "if($c -match 'CurrentVersion = \"([^\"]+)\"'){$matches[1] | Out-File '%TEMP%\noxir_ver.txt' -Encoding ascii -NoNewline}"

set /p CUR_VER=<"%TEMP%\noxir_ver.txt"
if "%CUR_VER%"=="" ( echo [HATA] Surum okunamadi! & pause & exit /b 1 )

powershell -NoProfile -Command ^
  "$p='%CUR_VER%'.Split('.');" ^
  "if($p.Length-eq 3){$p[2]=[int]$p[2]+1;($p -join '.') | Out-File '%TEMP%\noxir_next.txt' -Encoding ascii -NoNewline}"

set /p NEXT_VER=<"%TEMP%\noxir_next.txt"
if "%NEXT_VER%"=="" set "NEXT_VER=%CUR_VER%"

echo Mevcut Surum : %CUR_VER%
set /p "NEW_VER=Yeni Surum (Enter = %NEXT_VER%): "
if "!NEW_VER!"=="" set "NEW_VER=%NEXT_VER%"
echo Yayinlanacak Surum: !NEW_VER!
echo.

:: --- 1. Surum guncelle ---
echo [1/4] UpdateService.cs ve version.json guncelleniyor...
powershell -NoProfile -Command ^
  "$c=Get-Content '%UPDATE_CS%' -Raw;" ^
  "$c=$c -replace 'CurrentVersion = \"[^\"]+\"','CurrentVersion = \"!NEW_VER!\"';" ^
  "Set-Content '%UPDATE_CS%' $c -Encoding UTF8"

powershell -NoProfile -Command ^
  "$d=Get-Date -Format 'yyyy-MM-dd';" ^
  "$v='!NEW_VER!';" ^
  "$o=[ordered]@{version=$v;minSupportedVersion='1.0.0';releaseDate=$d;title='NOXIR Play v'+$v;" ^
  "changelog='Performans ve ceviri iyilestirmeleri.';" ^
  "downloadUrl='https://raw.githubusercontent.com/nexusultraapp/nox-transletur/main/updates/NOXIR_Play_Update_v'+$v+'.exe';" ^
  "fallbackDownloadUrl='https://nexusultraapp.github.io/nox-transletur/updates/NOXIR_Play_Update_v'+$v+'.exe';" ^
  "modelVersion='1.0.0';" ^
  "modelManifestUrl='https://raw.githubusercontent.com/nexusultraapp/nox-transletur/main/models/opus-mt-en-tr/manifest.json';" ^
  "isCritical=$false};" ^
  "$o | ConvertTo-Json -Depth 5 | Set-Content '%VER_JSON%' -Encoding UTF8"

:: --- 2. Derle ---
echo.
echo [2/4] Uygulama derleniyor (Release)...
dotnet publish "%CSPROJ%" -c Release -r win-x64 --self-contained false -o "%DIST_APP%" --verbosity minimal
if %ERRORLEVEL% neq 0 ( echo [HATA] Derleme basarisiz! & pause & exit /b 1 )

:: --- 3. Paket olustur ---
echo.
echo [3/4] Guncelleme paketi olusturuluyor...
"%ISCC_EXE%" /DMyAppVersion=!NEW_VER! /O"%UPDATES_DIR%" /F"NOXIR_Play_Update_v!NEW_VER!" "%ISS_FILE%"
if %ERRORLEVEL% neq 0 ( echo [HATA] Paket olusturulamadi! & pause & exit /b 1 )

:: --- 4. GitHub ---
echo.
echo [4/4] GitHub'a gonderiliyor...
git add -A
git add -f "updates/NOXIR_Play_Update_v!NEW_VER!.exe"
git commit -m "Release v!NEW_VER!"
git branch -M main
git push -u origin main
if %ERRORLEVEL% neq 0 ( echo [HATA] GitHub push basarisiz! & pause & exit /b 1 )

echo.
echo ===================================================================
echo   YAYINLAMA TAMAMLANDI! (v!NEW_VER!)
echo ===================================================================
echo.
pause
