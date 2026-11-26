param([string]$UpdateCs, [string]$VersionJson, [string]$NewVer, [switch]$UseGitHubReleases)
$c = Get-Content $UpdateCs -Raw
$c = $c -replace 'CurrentVersion = "[^"]+"', ('CurrentVersion = "' + $NewVer + '"')
Set-Content $UpdateCs $c -Encoding UTF8

$d = Get-Date -Format 'yyyy-MM-dd'
$dlUrl = if ($UseGitHubReleases) {
    'https://github.com/nexusultraapp/nox-transletur/releases/download/v' + $NewVer + '/NOXIR_Play_Update_v' + $NewVer + '.exe'
} else {
    'https://raw.githubusercontent.com/nexusultraapp/nox-transletur/main/updates/NOXIR_Play_Update_v' + $NewVer + '.exe'
}
$fbUrl = if ($UseGitHubReleases) {
    'https://raw.githubusercontent.com/nexusultraapp/nox-transletur/main/updates/NOXIR_Play_Update_v' + $NewVer + '.exe'
} else {
    'https://nexusultraapp.github.io/nox-transletur/updates/NOXIR_Play_Update_v' + $NewVer + '.exe'
}
$o = [ordered]@{
    version = $NewVer
    minSupportedVersion = '1.0.0'
    releaseDate = $d
    title = 'NOXIR Play v' + $NewVer
    changelog = 'Performans ve ceviri iyilestirmeleri.'
    downloadUrl = $dlUrl
    fallbackDownloadUrl = $fbUrl
    modelVersion = '1.0.0'
    modelManifestUrl = 'https://raw.githubusercontent.com/nexusultraapp/nox-transletur/main/models/opus-mt-en-tr/manifest.json'
    isCritical = $false
}
$o | ConvertTo-Json -Depth 5 | Set-Content $VersionJson -Encoding UTF8
