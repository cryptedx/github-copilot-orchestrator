# Installiert die Custom Agents persönlich für GitHub Copilot (App und CLI) unter Windows.
# Aufruf: powershell -ExecutionPolicy Bypass -File .\install.ps1
$ErrorActionPreference = 'Stop'

$Src = Join-Path $PSScriptRoot 'agents'
$Dest = if ($env:COPILOT_AGENTS_DIR) { $env:COPILOT_AGENTS_DIR } else { Join-Path $HOME '.copilot\agents' }

New-Item -ItemType Directory -Force -Path $Dest | Out-Null
foreach ($f in Get-ChildItem -Path $Src -Filter '*.agent.md' -File) {
    $target = Join-Path $Dest $f.Name
    if ((Test-Path $target) -and ((Get-FileHash $f.FullName).Hash -ne (Get-FileHash $target).Hash)) {
        Copy-Item $target "$target.bak" -Force
        Write-Host "Sicherung: $target.bak"
    }
    Copy-Item $f.FullName $target -Force
    Write-Host "Installiert: $($f.Name)"
}

Write-Host "Fertig. Neue Copilot-Session starten, dann den Agenten 'orchestrator' wählen."
