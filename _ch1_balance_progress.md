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
- v9 : Normal mort 85/159/246/247 s. v10 : rampe plafond soin 2:00 -> 6:00, regen +1.5 max 4.5, XP 6.8, elites lachent toujours un soin avant 1:30. Runs v10_d1_s11..15.
- DECOUVERTE : le banc tirait des PROTOCOLES aleatoires (degats ennemis jusqu'a x1.6, spawn x2) -> variance enorme. Mesures desormais avec --no-protocols. Base 4cc6fea (base_d1_s11..14) et v10 (v10np_d1_s11..14) lancees en parallele.
- Sans protocoles : BASE 4cc6fea Normal = 1 mort/4 (251 s), les autres a PV pleins presque tout le temps. v10 = 4 morts/4 (154-342 s) -> trop dur. v11 : heal_cd 2.5/4/6/8 s, plancher tardif plus doux (+1 par 40 s apres 3:20).
- v11 (74db123) : Normal 4/4 morts (87/276/294/398 s), Facile OK a 7 min. v12 (iteration 1/2) : heal_cd 2/3/5/7 s, sniper Ch1 11.5 -> 9.5, part rafale/zigzag Ch1 0.15 -> 0.08.
- v12 : Normal morts 262/364/463 s, s11 vivant a 8:00 (65/205 PV) ; aucune mort avant 3:00. Facile : PV > 80 % a 7:00. v13 (iteration 2/2) : heal_cd Normal 3 -> 2.5 s.
- v13 (heal_cd Normal 2.5) : 4/4 morts 294-396 s -> bruit, pas mieux. RETENU : v12 (heal_cd 3 s). Ch2 Normal (v13, s11) : mort a 48 s -> reste plus dur que Ch1. _test_div : OK (0 echec). Version 12.16.
- Web 12.16 exporte, teste dans Chromium headless (box) : menu v12.16 -> Jouer -> Ch1 deploye, vague dense a 0:40, aucune erreur de script. Push itch lance.
