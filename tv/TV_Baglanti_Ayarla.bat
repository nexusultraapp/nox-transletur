@echo off
setlocal
cd /d "%~dp0.."
echo =======================================================
echo [NOXIR Play] LG webOS TV Baglanti Bilgilerini Guncelle
echo =======================================================
echo.
echo TV'deki "Developer Mode" uygulamasindaki bilgileri girin:
echo.
set /p TV_IP="TV IP Adresi (ornek 192.168.1.31): "
set /p TV_PASS="Passphrase (TV ekranindaki 6 karakterli kod): "

if "%TV_IP%"=="" (
    echo [HATA] IP adresi bos birakilamaz.
    pause
    exit /b 1
)

echo.
echo Cihaz yapilandiriliyor...
call ares-setup-device.cmd -m noxir-tv -i "host=%TV_IP%" -i "port=9922" -i "username=prisoner" -i "passphrase=%TV_PASS%"
if %ERRORLEVEL% neq 0 (
    call ares-setup-device.cmd -a noxir-tv -i "host=%TV_IP%" -i "port=9922" -i "username=prisoner" -i "passphrase=%TV_PASS%"
)

echo.
echo TV anahtari (SSH key) aliniyor...
call ares-novacom.cmd --getkey -d noxir-tv
echo.
echo Test ediliyor:
call ares-device.cmd -i -d noxir-tv
echo.
pause
