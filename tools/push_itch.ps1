# Push the current web build + APK to itch.io via butler.
#
# The API key is read from C:\Users\Administrator\.itch_key (OUTSIDE the repo, never committed
# and never pasted into a chat). Get one at https://itch.io/user/settings/api-keys.
#
# butler uploads to named CHANNELS and handles replacement itself — no manual delete step, which
# is what made the browser upload risky before (the delete dialog could target the wrong file).
# It also diffs against the previous build, so repeat pushes only send what changed.
#
# 🚨 26/09 : ce script pushait un $APK qui pouvait dater de DEUX MOIS (personne ne le reconstruit
# ailleurs) — butler dit alors "Re-used 100.00% of old, added 0 B" (silencieux, pas une erreur) et
# itch affiche pourtant une nouvelle version sur le canal android, qui MENT (cf. reference
# reference_godot_geometrie_ui.md, piege #4). Consequence vecue : des correctifs de latence pousses
# et confirmes "en ligne" sur le canal android sans jamais atteindre l'appareil du patron. Les DEUX
# exports tournent maintenant ICI, depuis la source actuelle, avant tout push — plus jamais de canal
# qui ment sur ce qu'il contient.
# 🚨 Android en --export-release ECHOUE sur cette machine : aucun keystore de RELEASE nulle part
# (verifie : aucun .keystore/.jks sur le disque, aucune entree export/android/release_keystore dans
# editor_settings). Seul un keystore de DEBUG existe (auto-genere par Godot). --export-debug en
# est donc reduit a ca — fonctionnel et installable, mais PAS un vrai build de release Play Store.
# Si un vrai keystore de release existe un jour, remettre --export-release ici pour l'Android.
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools\push_itch.ps1

$ErrorActionPreference = "Stop"
$GODOT   = "C:\Users\Administrator\tools\godot\Godot_v4.3-stable_win64_console.exe"
$REPO    = "C:\Users\Administrator\mecha-forge"
$BUTLER  = "C:\Users\Administrator\tools\butler\butler.exe"
$KEYFILE = "C:\Users\Administrator\.itch_key"
$TARGET  = "whimora/mecha-forge"
$WEBDIR  = "C:\Users\Administrator\mecha-forge\web"
$APK     = "C:\Users\Administrator\mecha-forge\build\mecha-forge.apk"

if (-not (Test-Path $KEYFILE)) {
    Write-Error "Cle absente : $KEYFILE . Genere-la sur https://itch.io/user/settings/api-keys"
}
$env:BUTLER_API_KEY = (Get-Content $KEYFILE -Raw).Trim()

Write-Output "=== export Web + Android depuis la source actuelle ==="
Push-Location $REPO
& $GODOT --headless --path game --export-release "Web" ../web/index.html
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "export Web echoue" }
# Clean stale Godot temp APK files to avoid Windows file locks
Get-ChildItem "$env:LOCALAPPDATA\Godot\tmpexport*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
& $GODOT --headless --path game --export-debug "Android" ../build/mecha-forge.apk
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "export Android echoue" }
Pop-Location

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
