"""Lecture des clés API, identique en local et dans le cloud.

Ordre : variable d'environnement (secrets du cloud : GitHub Actions/Codespaces,
Claude Code web, Cursor), puis fichier local hors git (`<repo>/.meshy_key`,
`~/.glm_key`…). On n'affiche jamais une clé, même partiellement.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.expanduser("~")

# nom canonique -> (variables d'environnement acceptées, fichiers de repli)
_SOURCES = {
    "meshy": (("MESHY_KEY", "MESHY_API_KEY"), (".meshy_key",)),
    "glm": (("GLM_API_KEY",), (".glm_key", ".zai_key")),
    "itch": (("BUTLER_API_KEY",), (".itch_key",)),
}


def get_key(name, required=True):
    envs, files = _SOURCES[name]
    for e in envs:
        v = os.environ.get(e, "").strip()
        if v:
            return v
    for f in files:
        for base in (ROOT, HOME):
            p = os.path.join(base, f)
            if os.path.isfile(p):
                v = open(p, encoding="utf-8").read().strip()
                if v:
                    return v
    if required:
        raise SystemExit(f"Clé '{name}' introuvable : définir {' ou '.join(envs)} "
                         f"(secret du cloud) ou créer le fichier {files[0]}.")
    return ""
