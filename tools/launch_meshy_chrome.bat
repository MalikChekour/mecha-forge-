@echo off
REM Lance Chrome avec debug CDP (port 9223) + profil dedie Meshy. Connecte-toi a Meshy dedans.
taskkill /F /IM chrome.exe /FI "WINDOWTITLE eq Meshy*" >nul 2>&1
set P=C:\Users\Administrator\mecha-forge\.chrome_meshy
del "%P%\Default\LOCK" >nul 2>&1
del "%P%\SingletonLock" >nul 2>&1
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9223 --user-data-dir="%P%" --no-first-run --start-maximized https://www.meshy.ai/
