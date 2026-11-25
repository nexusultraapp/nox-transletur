@echo off
setlocal
cd /d "%~dp0.."

echo =======================================================
echo [NOXIR Play] LG webOS TV'ye Yukleme ve Baslatma
echo =======================================================

set "IPK=tv\dist\com.noxir.play.tv_1.0.0_all.ipk"
if not exist "%IPK%" (
    echo [BILGI] IPK paketi bulunamadi, once paketleniyor...
    call ares-package.cmd tv\noxirplay-tv -o tv\dist
)

echo.
echo 1. TV'ye paket yukleniyor (noxir-tv)...
call ares-install.cmd -d noxir-tv "%IPK%"
if %ERRORLEVEL% neq 0 (
    echo.
    echo [UYARI] TV baglantisi saglanamadi!
    echo Lutfen sunlari kontrol edin:
    echo 1. TV acik mi ve ayni Wi-Fi/Ethernet agina bagli mi?
    echo 2. TV'de "Developer Mode" uygulamasinda "Key Server" ON durumunda mi?
    echo 3. TV'nin IP adresi degisti mi? (Gerekiyorsa TV_Baglanti_Ayarla.bat calistirin)
    echo.
    pause
    exit /b 1
)

echo.
echo 2. TV'de NOXIR Play baslatiliyor...
call ares-launch.cmd -d noxir-tv com.noxir.play.tv
if %ERRORLEVEL% equ 0 (
    echo.
    echo =======================================================
    echo [BASARILI] NOXIR Play televizyonda acildi!
    echo PS5'in HDMI 1 goruntusu ekranda olmali.
    echo =======================================================
) else (
    echo.
    echo [HATA] Uygulama baslatilamadi.
)

echo.
pause
