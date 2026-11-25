param([string]$UpdateCs, [string]$OutCurrent, [string]$OutNext)
$c = Get-Content $UpdateCs -Raw
if ($c -match 'CurrentVersion = "([^"]+)"') {
    $cur = $matches[1]
    [System.IO.File]::WriteAllText($OutCurrent, $cur, [System.Text.Encoding]::ASCII)
    $p = $cur.Split('.')
    if ($p.Length -eq 3) {
        $p[2] = [int]$p[2] + 1
        [System.IO.File]::WriteAllText($OutNext, ($p -join '.'), [System.Text.Encoding]::ASCII)
    }
}
