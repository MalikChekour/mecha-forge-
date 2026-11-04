# Anti-kite Plan B progress
- [x] tag pre_antikite_20261031 (base c4734d9 v12.16)
- [x] 1 directional spawn
- [x] 2 predictive aim
- [x] 3 chasseur
- [x] 4 arena wall
- [x] 5 drop despawn
- [x] 6 bench
- [x] 7 v12.17 push + screenshot

- [x] 1-5 code: commits 77ec06a (1-3), 734fed2 (4), b7fad3d (5), 451276d (banc). Smoke 150 s OK.
- [x] 6 bench ak1 lance 07:49 : qa_antikite\ak1_d{0,1}_s*.log (tools\_bench_ak.ps1)
- ak1 (lead sniper 0.6) Normal morts 110/251/296/371 s -> trop dur (sniper). ak2 : lead sniper 0.3 + rampe 2:30, bot --kite, flag --no-antikite (temoin). ak2/ak2kite/basekite lances 08:05.

- 04/11 23:3x reprise : diff trie. Stash 'nov2 non-antikite' (Player aim-lock+mojibake, SaveManager first_run/debug unlock, ArenaWall zone PUBG 4 phases) + patch complet _wip_dirty_20261104.patch. Commit d82072b reglages ak2 + flag --no-wall. Banc ak3 (d0/d1 x4) + ak3kite (2) + ak3nowall (1) lances.
- ak3 (04/11) : Normal morts 357/341/535/409 s (aucune avant 4:00), sniper 35-45 % des degats ; Facile s13/s14 survivent 960 s. ak3nowall : fuyard sans mur niv 6 a 11:00, 0 degat, 220 ennemis -> interception bloquee par ENEMY_CAP. Fix + sniper 0.22/rampe 3:00 commit. ak4 lance.
- ak4 (sniper 0.22) Normal 211/324/431/278 s : pire, sniper toujours 1er. Facile ak3 : 4/4 survivent 960 s. -> ak5 : sniper lead 0.08, autres 0.3 ; lance.
- ak5 (sniper 0.08) Normal 350/356/279/267 s (aucune avant 4:00) ; kite 162/379 s ; ak4nowall interceptions=8 (fix OK). ACCEPTE. Etape suivante : smoke+capture, version 12.17, push.
- smoke 150 s OK + captures qa_antikite\ak_mur_*.png. Version 12.17. Push en cours.
- [x] 7 PUSH v12.17 OK 05/11 00:28 : html5 #2301343, android #2301344. Captures qa_antikite\ak_mur_chasseurs.png / ak_mur_resserre2.png. PLAN B TERMINE.
