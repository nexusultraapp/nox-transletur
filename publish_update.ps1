param(
    [string]$Version,
    [string]$Changelog
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $rootDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   NOXIR Play - Web Sitesine Otomatik Guncelleme Yayinlayici" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Mevcut surumu UpdateService.cs icinden oku
$updateServicePath = Join-Path $rootDir "pc\NoxirPlay.PC\UpdateService.cs"
$updateServiceText = [System.IO.File]::ReadAllText($updateServicePath, [System.Text.Encoding]::UTF8)
$currentVer = "1.0.15"
if ($updateServiceText -match 'CurrentVersion\s*=\s*"([^"]+)"') {
    $currentVer = $Matches[1]
}

# Bir sonraki surumu oner (1.0.15 -> 1.0.16)
$parts = $currentVer.Split('.')
if ($parts.Length -eq 3 -and [int]::TryParse($parts[2], [ref]$null)) {
    $suggestedVer = "$($parts[0]).$($parts[1]).$([int]$parts[2] + 1)"
} else {
    $suggestedVer = $currentVer
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $newVer = Read-Host "Yeni surum numarasi (Mevcut: $currentVer | Enter = $suggestedVer)"
    if ([string]::IsNullOrWhiteSpace($newVer)) {
        $newVer = $suggestedVer
    }
} else {
    $newVer = $Version
}
$newVer = $newVer.Trim().TrimStart('v', 'V')

Write-Host ""
if ([string]::IsNullOrWhiteSpace($Changelog)) {
    Write-Host "Guncelleme notlarini girin (birden fazla madde icin araya ; koyabilirsiniz):" -ForegroundColor Yellow
    $rawNotes = Read-Host "Bunlar getirildi"
    if ([string]::IsNullOrWhiteSpace($rawNotes)) {
        $rawNotes = "Performans iyilestirmeleri ve hata duzeltmeleri yapildi."
    }
} else {
    $rawNotes = $Changelog
}

$noteLines = $rawNotes.Split(';') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
$changelogBulletsJson = ($noteLines | ForEach-Object { "• $_" }) -join "`n"
$changelogBulletsXaml = ($noteLines | ForEach-Object { "• $_" }) -join "&#10;"
$today = (Get-Date).ToString("yyyy-MM-dd")
$todayTr = (Get-Date).ToString("dd.MM.yyyy")

Write-Host ""
Write-Host "[1/5] Surum dosyalari v$newVer olarak guncelleniyor..." -ForegroundColor Green

# 1. UpdateService.cs
$updateServiceText = [regex]::Replace($updateServiceText, 'CurrentVersion\s*=\s*"[^"]+"', "CurrentVersion = `"$newVer`"")
[System.IO.File]::WriteAllText($updateServicePath, $updateServiceText, [System.Text.UTF8Encoding]::new($false))

# 2. NoxirPlay.PC.csproj
$csprojPath = Join-Path $rootDir "pc\NoxirPlay.PC\NoxirPlay.PC.csproj"
$csprojText = [System.IO.File]::ReadAllText($csprojPath, [System.Text.Encoding]::UTF8)
$csprojText = [regex]::Replace($csprojText, '<Version>[^<]+</Version>', "<Version>$newVer</Version>")
[System.IO.File]::WriteAllText($csprojPath, $csprojText, [System.Text.UTF8Encoding]::new($false))

# 3. MainWindow.xaml
$xamlPath = Join-Path $rootDir "pc\NoxirPlay.PC\MainWindow.xaml"
$xamlText = [System.IO.File]::ReadAllText($xamlPath, [System.Text.Encoding]::UTF8)
$xamlText = [regex]::Replace($xamlText, '((?:x:)?Name="SettingsVersionText"\s+Text=")Mevcut Sürüm: v[^"]+(")', "`${1}Mevcut Sürüm: v$newVer (Resmi Yayın)`$2")
$xamlText = [regex]::Replace($xamlText, '((?:x:)?Name="SettingsVersionBadgeText"\s+Text=")v[^"]+(")', "`${1}v$newVer Güncel`$2")
$xamlText = [regex]::Replace($xamlText, '((?:x:)?Name="AboutVersionBadgeText"\s+Text=")v[^"]+(")', "`${1}v$newVer`$2")
$xamlText = [regex]::Replace($xamlText, '((?:x:)?Name="AboutChangelogTitleText"\s+Text=")v[^"]+(")', "`${1}v$newVer Güncellemesi ile Bunlar Getirildi`$2")
$xamlText = [regex]::Replace($xamlText, '(<TextBlock\s+(?:x:)?Name="AboutChangelogBodyText"\s+Text=")[^"]*(")', "`${1}$changelogBulletsXaml`$2")
[System.IO.File]::WriteAllText($xamlPath, $xamlText, [System.Text.UTF8Encoding]::new($false))

# 4. noxirplay.iss & noxirplay_update.iss
foreach ($issName in @("noxirplay.iss", "noxirplay_update.iss")) {
    $issPath = Join-Path $rootDir $issName
    if (Test-Path $issPath) {
        $issText = [System.IO.File]::ReadAllText($issPath, [System.Text.Encoding]::UTF8)
        $issText = [regex]::Replace($issText, '#define MyAppVersion "[^"]+"', "#define MyAppVersion `"$newVer`"")
        $issText = [regex]::Replace($issText, 'OutputBaseFilename=NOXIR_Play_Setup_v[^\r\n]+', "OutputBaseFilename=NOXIR_Play_Setup_v$newVer")
        $issText = [regex]::Replace($issText, 'OutputBaseFilename=NOXIR_Play_Update_v[^\r\n]+', "OutputBaseFilename=NOXIR_Play_Update_v$newVer")
        [System.IO.File]::WriteAllText($issPath, $issText, [System.Text.UTF8Encoding]::new($false))
    }
}

# 5. website/version.json
$versionJsonPath = Join-Path $rootDir "website\version.json"
$versionObj = [ordered]@{
    version = $newVer
    minSupportedVersion = "1.0.0"
    releaseDate = $today
    title = "NOXIR Play v$newVer"
    changelog = $changelogBulletsJson
    downloadUrl = "https://raw.githubusercontent.com/nexusultraapp/nox-transletur/main/updates/NOXIR_Play_Update_v$newVer.exe"
    fallbackDownloadUrl = "https://nexusultraapp.github.io/nox-transletur/updates/NOXIR_Play_Update_v$newVer.exe"
    modelVersion = "1.0.0"
    modelManifestUrl = "https://raw.githubusercontent.com/nexusultraapp/nox-transletur/main/models/opus-mt-en-tr/manifest.json"
    isCritical = $false
}
$jsonOut = $versionObj | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($versionJsonPath, $jsonOut + "`n", [System.Text.UTF8Encoding]::new($false))

# 6. website/index.html
$indexPath = Join-Path $rootDir "website\index.html"
$indexText = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
$indexText = [regex]::Replace($indexText, 'Yeni Nesil Yapay Zeka Oyun Çevirisi · v[0-9\.]+', "Yeni Nesil Yapay Zeka Oyun Çevirisi · v$newVer")
$indexText = [regex]::Replace($indexText, 'id="siteChangelogMeta"([^>]*)>Sürüm: v[^<]+<', "id=`"siteChangelogMeta`"`$1>Sürüm: v$newVer · $todayTr<")
$indexText = [regex]::Replace($indexText, 'id="siteChangelogTitle"([^>]*)>NOXIR Play v[^<]+<', "id=`"siteChangelogTitle`"`$1>NOXIR Play v$newVer ile Bunlar Getirildi<")
[System.IO.File]::WriteAllText($indexPath, $indexText, [System.Text.UTF8Encoding]::new($false))

Write-Host "[2/5] Uygulama derleniyor (dotnet publish self-contained + framework-dependent)..." -ForegroundColor Green
$pubSc = Join-Path $rootDir "pc\NoxirPlay.PC\bin\Release\publish_sc"
$pubFd = Join-Path $rootDir "pc\NoxirPlay.PC\bin\Release\publish_fd"
& dotnet publish "pc\NoxirPlay.PC\NoxirPlay.PC.csproj" -c Release -r win-x64 --self-contained true -o $pubSc
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish (self-contained) basarisiz oldu (ExitCode: $LASTEXITCODE)"
}
& dotnet publish "pc\NoxirPlay.PC\NoxirPlay.PC.csproj" -c Release -r win-x64 --self-contained false -o $pubFd
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish (framework-dependent) basarisiz oldu (ExitCode: $LASTEXITCODE)"
}

Write-Host "[3/5] Guncel uygulama dosyalari dist\app klasorune kopyalaniyor..." -ForegroundColor Green
New-Item -ItemType Directory -Force -Path "dist\app\runtime_sc", "dist\app\runtime_fd", "dist\app\ai_bridge", "dist\app\tv\dist", "dist\app\tv\tv\dist", "dist\app\tv\noxirplay-tv" | Out-Null
Copy-Item "$pubFd\NoxirPlay.PC.*" "dist\app\" -Force
Copy-Item "$pubSc\NoxirPlay.PC.exe", "$pubSc\NoxirPlay.PC.deps.json", "$pubSc\NoxirPlay.PC.runtimeconfig.json" "dist\app\runtime_sc\" -Force
Copy-Item "$pubFd\NoxirPlay.PC.exe", "$pubFd\NoxirPlay.PC.deps.json", "$pubFd\NoxirPlay.PC.runtimeconfig.json" "dist\app\runtime_fd\" -Force
if (Test-Path "pc\NoxirPlay.PC\ai_bridge\server.py") {
    Copy-Item "pc\NoxirPlay.PC\ai_bridge\server.py" "dist\app\ai_bridge\server.py" -Force
}
if (Test-Path "pc\NoxirPlay.PC\ai_bridge\translation_memory.py") {
    Copy-Item "pc\NoxirPlay.PC\ai_bridge\translation_memory.py" "dist\app\ai_bridge\translation_memory.py" -Force
}
if (Test-Path "pc\NoxirPlay.PC\ai_bridge\gpu_manager.py") {
    Copy-Item "pc\NoxirPlay.PC\ai_bridge\gpu_manager.py" "dist\app\ai_bridge\gpu_manager.py" -Force
}
if (Test-Path "pc\NoxirPlay.PC\ai_bridge\lingua_manager.py") {
    Copy-Item "pc\NoxirPlay.PC\ai_bridge\lingua_manager.py" "dist\app\ai_bridge\lingua_manager.py" -Force
}
if (Test-Path "pc\NoxirPlay.PC\native") {
    New-Item -ItemType Directory -Force -Path "dist\app\native" | Out-Null
    Copy-Item "pc\NoxirPlay.PC\native\*.dll" "dist\app\native\" -Force
    Copy-Item "pc\NoxirPlay.PC\native\*.dll" "dist\app\" -Force
}
if (Test-Path "tv\dist\com.noxir.play.tv_1.0.1_all.ipk") {
    Copy-Item "tv\dist\com.noxir.play.tv_1.0.1_all.ipk" "dist\app\tv\dist\com.noxir.play.tv_1.0.1_all.ipk" -Force
    Copy-Item "tv\dist\com.noxir.play.tv_1.0.1_all.ipk" "dist\app\tv\tv\dist\com.noxir.play.tv_1.0.1_all.ipk" -Force
}
if (Test-Path "tv\noxirplay-tv") {
    Copy-Item "tv\noxirplay-tv\*" "dist\app\tv\noxirplay-tv\" -Force
}

Write-Host "[4/5] Hafif guncelleme paketi olusturuluyor (NOXIR_Play_Update_v$newVer.exe)..." -ForegroundColor Green
$isccCandidates = @(
    (Join-Path $rootDir ".tools\InnoSetup\ISCC.exe"),
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw "ISCC.exe (Inno Setup 6) bulunamadi!"
}
& $iscc "noxirplay_update.iss"
if ($LASTEXITCODE -ne 0) {
    throw "ISCC.exe basarisiz oldu (ExitCode: $LASTEXITCODE)"
}

Write-Host "[5/5] Web sitesi ve guncelleme paketi GitHub'a gonderiliyor..." -ForegroundColor Green
git -C "website" add version.json index.html "updates/NOXIR_Play_Update_v$newVer.exe"
git -C "website" commit -m "Release v$newVer"
git -C "website" push origin main
if ($LASTEXITCODE -ne 0) {
    throw "git push basarisiz oldu!"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  [BASARILI] NOXIR Play v$newVer yayinlandi!" -ForegroundColor Green
Write-Host "  - Web Sitesi: https://nexusultraapp.github.io/nox-transletur/" -ForegroundColor White
Write-Host "  - Paket: website\updates\NOXIR_Play_Update_v$newVer.exe" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green
