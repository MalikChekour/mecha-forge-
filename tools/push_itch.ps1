# Push the current web build + APK to itch.io via butler.
#
# The API key is read from C:\Users\Administrator\.itch_key (OUTSIDE the repo, never committed
# and never pasted into a chat). Get one at https://itch.io/user/settings/api-keys.
#
# butler uploads to named CHANNELS and handles replacement itself — no manual delete step, which
# is what made the browser upload risky before (the delete dialog could target the wrong file).
# It also diffs against the previous build, so repeat pushes only send what changed.
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools\push_itch.ps1

$ErrorActionPreference = "Stop"
$BUTLER  = "C:\Users\Administrator\tools\butler\butler.exe"
$KEYFILE = "C:\Users\Administrator\.itch_key"
$TARGET  = "whimora/mecha-forge"
$WEBDIR  = "C:\Users\Administrator\mecha-forge\web"
$APK     = "C:\Users\Administrator\mecha-forge\build\mecha-forge.apk"

if (-not (Test-Path $KEYFILE)) {
    Write-Error "Cle absente : $KEYFILE . Genere-la sur https://itch.io/user/settings/api-keys"
}
$env:BUTLER_API_KEY = (Get-Content $KEYFILE -Raw).Trim()

# version stamped on the itch build list, read from the same source the game displays on its hub
$ver = (Select-String -Path "C:\Users\Administrator\mecha-forge\game\project.godot" `
        -Pattern '^config/version="(.+)"').Matches.Groups[1].Value
Write-Output "=== push MECHA-FORGE v$ver vers $TARGET ==="

# --- web: only the files the browser needs, not the live1xx archive folders ---
$staging = "$env:TEMP\mecha-forge-web-push"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Force $staging | Out-Null
Copy-Item "$WEBDIR\index.*" $staging -Force
Write-Output "web stage : $((Get-ChildItem $staging | Measure-Object).Count) fichiers"

& $BUTLER push $staging "${TARGET}:html5" --userversion $ver
if ($LASTEXITCODE -ne 0) { Write-Error "push web echoue" }

if (Test-Path $APK) {
    & $BUTLER push $APK "${TARGET}:android" --userversion $ver
    if ($LASTEXITCODE -ne 0) { Write-Error "push apk echoue" }
} else {
    Write-Output "APK absent, ignore : $APK"
}

Remove-Item $staging -Recurse -Force
Write-Output "=== statut des canaux ==="
& $BUTLER status $TARGET
