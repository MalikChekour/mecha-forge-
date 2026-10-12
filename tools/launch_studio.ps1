# Lance le Studio d'Étalonnage Décor & VFX pour MECHA-FORGE
# Usage: powershell -ExecutionPolicy Bypass -File tools\launch_studio.ps1

$scriptPath = Join-Path $PSScriptRoot "launch_studio.py"
Write-Host "Lancement du Studio d'Étalonnage Décor & VFX..." -ForegroundColor Cyan
python $scriptPath
