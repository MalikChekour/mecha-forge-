$KEYFILE = "C:\Users\Administrator\.itch_key"
$env:BUTLER_API_KEY = (Get-Content $KEYFILE -Raw).Trim()
$BUTLER = "C:\Users\Administrator\tools\butler\butler.exe"
$TARGET = "whimora/mecha-forge"
$WEBDIR = "C:\Users\Administrator\mecha-forge\web"
$APK    = "C:\Users\Administrator\mecha-forge\build\mecha-forge.apk"
$ver    = "12.34"

Write-Output "=== Push MECHA-FORGE v12.34 vers itch.io ==="
$staging = "$env:TEMP\mecha-forge-web-push"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Force $staging | Out-Null
Copy-Item "$WEBDIR\index.*" $staging -Force
Write-Output "Fichiers Web prepares : $((Get-ChildItem $staging).Count)"

Write-Output "Poussee HTML5..."
& $BUTLER push $staging "${TARGET}:html5" --userversion $ver
if ($LASTEXITCODE -ne 0) { Write-Error "Push Web echoue"; exit 1 }

Write-Output "Poussee Android APK..."
& $BUTLER push $APK "${TARGET}:android" --userversion $ver
if ($LASTEXITCODE -ne 0) { Write-Error "Push APK echoue"; exit 1 }

Remove-Item $staging -Recurse -Force
Write-Output "=== Statut final des canaux itch.io ==="
& $BUTLER status $TARGET
