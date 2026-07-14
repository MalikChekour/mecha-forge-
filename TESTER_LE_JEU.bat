@echo off
chcp 65001 >nul
title MECHA-FORGE - lien de test
cd /d "%~dp0"

echo ============================================================
echo   MECHA-FORGE  --  creation d'un lien de test public
echo ============================================================
echo.
echo [1/2] Demarrage du serveur local (port 8872)...
start "MECHA-FORGE serveur" /min python "%~dp0serve_web.py"
timeout /t 2 >nul
echo       OK.
echo.
echo [2/2] Ouverture du tunnel public...
echo.
echo   >>> UNE URL du type  https://XXXXX.lhr.life  VA S'AFFICHER CI-DESSOUS.
echo   >>> Ouvre-la sur ton telephone / navigateur (la racine charge le jeu).
echo   >>> GARDE CETTE FENETRE OUVERTE tant que tu testes. Ferme-la pour couper.
echo.
echo ------------------------------------------------------------
ssh -o StrictHostKeyChecking=accept-new -R 80:localhost:8872 nokey@localhost.run
echo ------------------------------------------------------------
echo.
echo Tunnel ferme. Tu peux fermer cette fenetre.
pause
