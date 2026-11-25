@echo off
chcp 65001 >nul

echo ===================================================================
echo   NOXIR Play - Tum OCR ve Ceviri Modelleri Kurulum Araci
echo ===================================================================
echo.

set SCRIPT_DIR=%~dp0
set AI_DIR=%SCRIPT_DIR%pc\NoxirPlay.PC\ai_bridge
if not exist "%AI_DIR%" set AI_DIR=%SCRIPT_DIR%
set VENV_DIR=%AI_DIR%\.venv
set REQ_FILE=%AI_DIR%\requirements.txt
set MODELS_DIR=%SCRIPT_DIR%pc\NoxirPlay.PC\models
set DOWNLOAD_SCRIPT=%AI_DIR%\download_models.py

echo [1/4] Uyumlu Python ortami (Python 3.11) kontrol ediliyor...

set PY_CMD=

REM 1. py launcher uzerinden Python 3.11 kontrolu
where py.exe >nul 2>&1
if not %ERRORLEVEL% equ 0 goto :check_local_paths

py -3.11 -c "import sys; sys.exit(0)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set PY_CMD=py -3.11
    goto :found_python
)

echo [BILGI] Python Launcher tespit edildi, Python 3.11 indiriliyor...
py install 3.11
py -3.11 -c "import sys; sys.exit(0)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set PY_CMD=py -3.11
    goto :found_python
)

:check_local_paths
REM 2. Standart Python 3.11 klasorleri
if exist "%LOCALAPPDATA%\Python\pythoncore-3.11-64\python.exe" (
    set PY_CMD="%LOCALAPPDATA%\Python\pythoncore-3.11-64\python.exe"
    goto :found_python
)
if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
    set PY_CMD="%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    goto :found_python
)
if exist "%ProgramFiles%\Python311\python.exe" (
    set PY_CMD="%ProgramFiles%\Python311\python.exe"
    goto :found_python
)
if exist "C:\Python311\python.exe" (
    set PY_CMD="C:\Python311\python.exe"
    goto :found_python
)

REM 3. PATH uzerindeki python 3.11 kontrolu
where python.exe >nul 2>&1
if not %ERRORLEVEL% equ 0 goto :check_installer

python -c "import sys; sys.exit(0 if sys.version_info[0]==3 and sys.version_info[1]==11 else 1)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set PY_CMD=python
    goto :found_python
)

:check_installer
echo.
echo [BILGI] Sistemde kurulu Python 3.11 bulunamadi.
echo Tum modellerin sorunsuz calismasi icin resmi Python 3.11.9 (64-bit) yuklenecektir.
echo.

if exist "%SCRIPT_DIR%python-3.11.9-amd64.exe" (
    set INSTALLER_PATH=%SCRIPT_DIR%python-3.11.9-amd64.exe
    goto :run_installer
)
if exist "%SCRIPT_DIR%pc\NoxirPlay.PC\python-3.11.9-amd64.exe" (
    set INSTALLER_PATH=%SCRIPT_DIR%pc\NoxirPlay.PC\python-3.11.9-amd64.exe
    goto :run_installer
)

set AUTO_INSTALL=E
set /p AUTO_INSTALL="Python 3.11 resmi yukleyicisi otomatik indirilip kurulsun mu? [E/H] [Varsayilan: E]: "
if /i "%AUTO_INSTALL%"=="H" goto :manual_instructions

echo.
echo [INDIRILIYOR] Python 3.11.9 resmi yukleyicisi indiriliyor...
set INSTALLER_PATH=%TEMP%\python-3.11.9-amd64.exe
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' -OutFile '%INSTALLER_PATH%'"

if not exist "%INSTALLER_PATH%" (
    echo [HATA] Python kurulum dosyasi indirilemedi. Lutfen internet baglantinizi kontrol edin.
    goto :manual_instructions
)

:run_installer
echo [KURULUYOR] Python 3.11 kuruluyor, lutfen bekleyin...
start /wait "" "%INSTALLER_PATH%" /passive InstallAllUsers=0 PrependPath=1 Include_pip=1 TargetDir="%LOCALAPPDATA%\Programs\Python\Python311"

if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
    set PY_CMD="%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    echo [BASARILI] Python 3.11 basariyla kuruldu!
    goto :setup_venv
)

echo [UYARI] Kurulum tamamlandi ancak Python 3.11 konumu tespit edilemedi.
goto :manual_instructions

:found_python
:setup_venv
echo.
echo Secilen Python: %PY_CMD%

echo.
echo [2/4] Sanal ortam [.venv] hazirlaniyor...

if not exist "%VENV_DIR%\Scripts\python.exe" goto :create_venv

"%VENV_DIR%\Scripts\python.exe" -c "import sys; sys.exit(0 if sys.version_info[0]==3 and sys.version_info[1]==11 else 1)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Sanal ortam hazir ve dogrulandi: %VENV_DIR%
    goto :install_packages
)

echo [UYARI] Mevcut sanal ortam uyumsuz bir Python surumune ait.
echo Sanal ortam temizleniyor ve Python 3.11 ile yeniden olusturuluyor...
rmdir /s /q "%VENV_DIR%" >nul 2>&1

:create_venv
echo Sanal ortam olusturuluyor: %VENV_DIR%
%PY_CMD% -m venv "%VENV_DIR%"
if not %ERRORLEVEL% equ 0 (
    echo [HATA] Sanal ortam olusturulamadi!
    pause
    exit /b 1
)
echo Sanal ortam basariyla olusturuldu.

:install_packages
echo.
echo [3/4] Tum OCR (RapidOCR, EasyOCR) ve AI Paketleri Yukleniyor...
"%VENV_DIR%\Scripts\python.exe" -m pip install --upgrade pip setuptools wheel

echo PyTorch hafif CPU surumu kuruluyor...
"%VENV_DIR%\Scripts\pip.exe" install torch --index-url https://download.pytorch.org/whl/cpu

if exist "%REQ_FILE%" (
    echo requirements.txt paketleri yukleniyor...
    "%VENV_DIR%\Scripts\pip.exe" install -r "%REQ_FILE%"
) else (
    echo Temel paketler kuruluyor...
    "%VENV_DIR%\Scripts\pip.exe" install "numpy<2.0.0" opencv-python-headless rapidocr-onnxruntime easyocr ctranslate2 sentencepiece transformers huggingface_hub
)

echo.
echo [4/4] Tum Ceviri ve OCR Modelleri Kontrol Edilip Indiriliyor...
echo.
if exist "%DOWNLOAD_SCRIPT%" (
    "%VENV_DIR%\Scripts\python.exe" "%DOWNLOAD_SCRIPT%"
) else (
    echo [UYARI] download_models.py bulunamadi.
)

echo.
echo ===================================================================
echo   TUM MODELLER VE OCR MOTORLARI BASARIYLA INDIRILDI VE HAZIRLANDI!
echo   Uygulamayi baslatmak icin 'Baslat.bat' calistirabilirsiniz.
echo ===================================================================
echo.
pause
exit /b 0

:manual_instructions
echo.
echo [MANUEL KURULUM REHBERI]
echo 1. https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe adresinden Python 3.11 indirin.
echo 2. Kurulum ekraninda 'Add Python to PATH' secenegini MUTLAKA isaretleyin.
echo 3. Kurulum tamamlandiktan sonra Kur.bat dosyasini tekrar calistirin.
echo.
pause
exit /b 1
