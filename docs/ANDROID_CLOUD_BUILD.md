# Build Android dans le cloud (GitHub Actions)

Le SDK Android n'est **pas** installé sur ce serveur (et on ne veut pas le faire) :
le build tourne dans le cloud, sur les runners GitHub. Tout est déjà prêt côté projet
(preset Android `game/export_presets.cfg` + workflow `.github/workflows/android.yml`).
Il reste l'étape **compte GitHub** (que je ne peux pas faire à ta place).

## Étapes (une seule fois)

1. **Crée un repo privé** sur https://github.com/new
   - Nom : `mecha-forge` · Visibilité : **Private** · **NE PAS** cocher "Add a README".

2. **Pousse le code** (depuis `C:\Users\Administrator\mecha-forge`) :
   ```bash
   git remote add origin https://github.com/<TON_USER>/mecha-forge.git
   git push -u origin master
   ```
   - À la demande de mot de passe : mets un **Personal Access Token** GitHub
     (Settings → Developer settings → Tokens → "repo" scope), pas ton mot de passe.
   - (Ou utilise **GitHub Desktop** / `gh auth login` si tu préfères le cliquable.)

3. **Le build démarre tout seul** au push. Sinon : onglet **Actions** → *Build Android (APK)*
   → **Run workflow**.

4. Quand c'est **vert** : ouvre le run → section **Artifacts** → télécharge
   **`mecha-forge-apk`** → dézippe → `mecha-forge.apk`.

5. **Installe sur ton téléphone** : transfère l'APK, autorise "installer apps inconnues",
   ouvre-le. (APK **debug-signé** = pour tester en sideload.)

## Si le build échoue

Je n'ai pas pu tester le workflow ici (pas de SDK local). S'il rate à la 1re fois,
**copie-moi le log de l'étape rouge** et je corrige le YAML (souvent 1-2 itérations
sur les versions SDK/templates).

## Pour Google Play (plus tard)

- Il faudra un **AAB** (pas APK) signé avec un **vrai keystore de release** :
  **⚠️ sauvegarde ce keystore + ses mots de passe sur 3 clouds** — si tu le perds
  avec Play App Signing activé, tu ne peux **plus jamais** mettre à jour l'app.
- Puis : fiche Play Console + déclaration **Data Safety** + SDK pub avec **consentement UMP** (RGPD).
- Le workflow actuel produit un APK debug ; je l'adapterai en AAB release (keystore via
  *GitHub Secrets*) quand tu voudras publier.
