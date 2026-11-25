param([string]$UpdateCs, [string]$VersionJson, [string]$NewVer)
$c = Get-Content $UpdateCs -Raw
$c = $c -replace 'CurrentVersion = "[^"]+"', ('CurrentVersion = "' + $NewVer + '"')
Set-Content $UpdateCs $c -Encoding UTF8

$d = Get-Date -Format 'yyyy-MM-dd'
$o = [ordered]@{
    version = $NewVer
    minSupportedVersion = '1.0.0'
    releaseDate = $d
    title = 'NOXIR Play v' + $NewVer
    changelog = 'Performans ve ceviri iyilestirmeleri.'
    downloadUrl = 'https://raw.githubusercontent.com/nexusultraapp/nox-transletur/main/updates/NOXIR_Play_Update_v' + $NewVer + '.exe'
    fallbackDownloadUrl = 'https://nexusultraapp.github.io/nox-transletur/updates/NOXIR_Play_Update_v' + $NewVer + '.exe'
    modelVersion = '1.0.0'
    modelManifestUrl = 'https://raw.githubusercontent.com/nexusultraapp/nox-transletur/main/models/opus-mt-en-tr/manifest.json'
    isCritical = $false
}
$o | ConvertTo-Json -Depth 5 | Set-Content $VersionJson -Encoding UTF8
