@echo off
setlocal
cd /d "%~dp0.."
echo [NOXIR Play] LG webOS TV uygulamasi paketleniyor...
call ares-package.cmd tv\noxirplay-tv -o tv\dist
if %ERRORLEVEL% equ 0 (
    echo.
    echo [BASARILI] tv\dist\com.noxir.play.tv_1.0.0_all.ipk olusturuldu!
) else (
    echo.
    echo [HATA] Paketleme basarisiz oldu.
)
echo.
pause
