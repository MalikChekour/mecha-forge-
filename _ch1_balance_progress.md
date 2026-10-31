# Ch1 balance - progres (30/10/2026)
## Etape 0 (17:3x PDT)
- Tentative 1 a deja commit 9b033c1 (v12.15) + push itch html5 #2256848 (17:11).
- Mesures (banc game/_bal_ch1.tscn, logs qa_ch1/):
  - AVANT (4cc6fea) Normal : victoire 921 s, 7205 kills, niv 41, pv_min 9% a 103 s puis PV pleins de 120 s a la fin ; degats 9712 / soins 9575.
  - AVANT Facile : victoire, pv_min 76%.
  - 9b033c1 Normal : morts a 88 s et 133 s (trop dur au debut). Facile : survit, pv_min 44%, PV pleins apres 5 min.
  - v4 non commitee (unlock bouclier 30/sniper 45, plancher t/20, soin 20, drop elite 0.5) : morts 80/97/222 s.
- Diagnostic : debut deja tendu pour le bot ; le vrai probleme = soins (bonus elites ~700 PV/min) + regen (6 PV/s) annulent tout apres 2 min.

## Etape 1-2 (v5 -> v6)
- v5 (plafond cache de soin 6 s Normal des t=0, regen +1/max 4, plancher tardif, murs 2:00/5:00/11:30) : Normal mort a 58-88 s (soins elites indispensables au debut). Facile OK.
- v6 : plafond de soin en rampe (0 avant 1:00, complet a 3:00), 1re vague 35 s, escouade 40 s. Runs v6_d1_s11..13 lances.
- v6 : Normal mort 130-191 s (mur 2:00 + mur 3:00). v7 : mur 2:00 retire, soin cache 25, drop elite 70 % (cadence plafonnee). Runs v7_d1_s11..14.
- v7 : Normal mort 85-159 s (fenetre 60-100 s critique pour le bot, deja 9 % PV avant). v8 : debut ramene a l'original (bouclier 35 s, sniper 50 s, vague 38 s / 50 s) ; la pression ajoutee passe en milieu/fin de partie.
- v8 : debut OK, mais 4/4 morts a 189-206 s (mini-boss + mur 3:00 + plafond soin complet). v9 : kit mini-boss x1.8/x2.2 (au lieu de 2.4/3.0), PV mini 8.5x, rampe plafond soin 1:30 -> 5:00.
