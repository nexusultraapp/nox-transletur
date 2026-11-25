@echo off
chcp 65001 >nul
title NOXIR Play - GitHub Web Sitesi Yukleme Sihirbazi
cls

echo ============================================================
echo   NOXIR PLAY - GITHUB PAGES WEB SITESI YUKLEME
echo ============================================================
echo.
echo [GUVENLIK ONAYI]:
echo Bu islem YALNIZCA "website" klasorundeki HTML/CSS/JS dosyalarini
echo GitHub'a yukler. C# kaynak kodlariniz, Python scriptleriniz
echo ve yapay zeka modelleriniz KESINLIKLE YUKLENMEZ VE SAKLI KALIR.
echo.
echo ============================================================
echo.

cd /d "%~dp0\website"

if not exist "index.html" (
    echo [HATA] website klasoru bulunamadi!
    pause
    exit /b 1
)

echo 1. Git baslatiliyor...
if not exist ".git" (
    git init -b main
)

echo.
echo 2. Web sitesi dosyalari listeleniyor:
git status -s

echo.
echo 3. Dosyalar pakete ekleniyor...
git add .
git commit -m "NOXIR Play v1.0 Resmi Web Sitesi ve Tanitim"

echo.
echo ============================================================
echo GitHub'da actiginiz repository adresini yapistirin:
echo Ornek: https://github.com/kullaniciadi/noxirplay-web.git
echo ============================================================
set /p REPO_URL="GitHub Repo URL: "

if "%REPO_URL%"=="" (
    echo Repo adresi girilmedi. Islem iptal edildi.
    pause
    exit /b 0
)

git remote remove origin >nul 2>&1
git remote add origin %REPO_URL%
git branch -M main

echo.
echo GitHub'a yukleniyor...
git push -u origin main --force

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================================
    echo [BASARILI] Web sitesi GitHub'a yuklendi!
    echo.
    echo Simdi GitHub repo sayfaniza gidip:
    echo   Settings -^> Pages -^> Branch: main -^> Save
    echo secerek sitenizi ucretsiz yayina alabilirsiniz!
    echo ============================================================
) else (
    echo.
    echo [UYARI] Yukleme sirasinda hata olustu.
    echo GitHub kullanici adi / Personal Access Token yetkinizi kontrol edin.
)

echo.
pause
