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
set "GET_VER=%~dp0get_version.ps1"
set "SET_VER=%~dp0set_version.ps1"
set "TMPVER=%TEMP%\noxir_ver.txt"
set "TMPNXT=%TEMP%\noxir_next.txt"

if not exist "%UPDATE_CS%" ( echo [HATA] UpdateService.cs bulunamadi! & pause & exit /b 1 )
if not exist "%ISCC_EXE%" ( echo [HATA] Inno Setup bulunamadi! & pause & exit /b 1 )
if not exist "%ISS_FILE%" ( echo [HATA] noxirplay.iss bulunamadi! & pause & exit /b 1 )
if not exist "%GET_VER%" ( echo [HATA] get_version.ps1 bulunamadi! & pause & exit /b 1 )
if not exist "%SET_VER%" ( echo [HATA] set_version.ps1 bulunamadi! & pause & exit /b 1 )
if not exist "%UPDATES_DIR%" mkdir "%UPDATES_DIR%"

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%GET_VER%" -UpdateCs "%UPDATE_CS%" -OutCurrent "%TMPVER%" -OutNext "%TMPNXT%"
if %ERRORLEVEL% neq 0 ( echo [HATA] Surum scripti calistirilamadi! & pause & exit /b 1 )
set /p CUR_VER=<"%TMPVER%"
set /p NEXT_VER=<"%TMPNXT%"
del /f /q "%TMPVER%" "%TMPNXT%" >nul 2>&1
if "!CUR_VER!"=="" ( echo [HATA] Surum okunamadi! & pause & exit /b 1 )
if "!NEXT_VER!"=="" set "NEXT_VER=!CUR_VER!"

echo Mevcut Surum : !CUR_VER!
set /p "NEW_VER=Yeni Surum (Enter = !NEXT_VER!): "
if "!NEW_VER!"=="" set "NEW_VER=!NEXT_VER!"
echo Yayinlanacak : v!NEW_VER!
echo.

set "USE_GH_RELEASE=0"
where gh.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    gh auth status >nul 2>&1
    if !ERRORLEVEL! equ 0 set "USE_GH_RELEASE=1"
)

echo [1/4] Surum numaralari guncelleniyor...
if "!USE_GH_RELEASE!"=="1" (
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%SET_VER%" -UpdateCs "%UPDATE_CS%" -VersionJson "%VER_JSON%" -NewVer "!NEW_VER!" -UseGitHubReleases
) else (
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%SET_VER%" -UpdateCs "%UPDATE_CS%" -VersionJson "%VER_JSON%" -NewVer "!NEW_VER!"
)
if %ERRORLEVEL% neq 0 ( echo [HATA] Surum numaralari guncellenemedi! & pause & exit /b 1 )

echo.
echo [2/4] Uygulama derleniyor...
taskkill /f /im NoxirPlay.PC.exe >nul 2>&1
dotnet publish "%CSPROJ%" -c Release -r win-x64 --self-contained false -o "%DIST_APP%" --verbosity minimal
if %ERRORLEVEL% neq 0 ( echo [HATA] Derleme basarisiz! & pause & exit /b 1 )

echo.
echo [3/4] Guncelleme paketi olusturuluyor...
"%ISCC_EXE%" /DMyAppVersion=!NEW_VER! /O"%UPDATES_DIR%" /F"NOXIR_Play_Update_v!NEW_VER!" "%ISS_FILE%"
if %ERRORLEVEL% neq 0 ( echo [HATA] Paket olusturulamadi! & pause & exit /b 1 )

echo.
echo [4/4] GitHub'a gonderiliyor...
if "!USE_GH_RELEASE!"=="1" (
    echo [BILGI] GitHub Releases ile .exe yukleniyor (repo sismesi onlenir)...
    gh release create "v!NEW_VER!" "%UPDATES_DIR%\NOXIR_Play_Update_v!NEW_VER!.exe" --title "NOXIR Play v!NEW_VER!" --notes "NOXIR Play v!NEW_VER! guncellemesi"
    if !ERRORLEVEL! neq 0 (
        echo [UYARI] GitHub Release olusturulamadi, klasik updates/ yuklemesine geciliyor...
        git add -f "updates/NOXIR_Play_Update_v!NEW_VER!.exe"
    )
    git add -A
) else (
    git add -A
    git add -f "updates/NOXIR_Play_Update_v!NEW_VER!.exe"
)
git diff --cached --quiet
if %ERRORLEVEL% neq 0 (
    git commit -m "Release v!NEW_VER!"
    if %ERRORLEVEL% neq 0 ( echo [HATA] Git commit basarisiz! & pause & exit /b 1 )
) else (
    echo [BILGI] Commit edilecek yeni degisiklik yok, push adimina geciliyor...
)
git branch -M main
git push -u origin main
if %ERRORLEVEL% neq 0 ( echo [HATA] GitHub push basarisiz! & pause & exit /b 1 )

echo.
echo ===================================================================
echo   YAYINLAMA TAMAMLANDI! (v!NEW_VER!)
echo ===================================================================
echo.
pause
