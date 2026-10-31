# Ch1 balance - progres (30/10/2026)
## Etape 0 (17:3x PDT)
- Tentative 1 a deja commit 9b033c1 (v12.15) + push itch html5 #2256848 (17:11).
- Mesures (banc game/_bal_ch1.tscn, logs qa_ch1/):
  - AVANT (4cc6fea) Normal : victoire 921 s, 7205 kills, niv 41, pv_min 9% a 103 s puis PV pleins de 120 s a la fin ; degats 9712 / soins 9575.
  - AVANT Facile : victoire, pv_min 76%.
  - 9b033c1 Normal : morts a 88 s et 133 s (trop dur au debut). Facile : survit, pv_min 44%, PV pleins apres 5 min.
  - v4 non commitee (unlock bouclier 30/sniper 45, plancher t/20, soin 20, drop elite 0.5) : morts 80/97/222 s.
- Diagnostic : debut deja tendu pour le bot ; le vrai probleme = soins (bonus elites ~700 PV/min) + regen (6 PV/s) annulent tout apres 2 min.
