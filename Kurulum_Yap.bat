@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ===================================================================
echo   NOXIR Play & NEXSUS Translate Kurulum Sihirbazi Baslatiliyor...
echo ===================================================================
if exist "InnoSetup_Output\NOXIR_Play_Setup_v1.0.17.exe" (
    start "" "InnoSetup_Output\NOXIR_Play_Setup_v1.0.17.exe"
) else if exist "NOXIR_Play_Setup.exe" (
    start "" "NOXIR_Play_Setup.exe"
)
exit /b 0
