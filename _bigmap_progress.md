# Grande carte PUBG progress (base v12.18 b27bdec)
- Carte avant : INFINIE (Game.BOUNDED=false), sol shader tuile monde, decor PropScatter STREAME en tranches 1000 px (5x5 autour du joueur, graine par tranche), camera zoom <=1 (base 1280x720), vitesse joueur 320 px/s.
- [x] 1 ArenaWall.gd reecrit : MAP_R 10000 (bord dur), phase 0 sans cercle 0:00-2:00, 8 phases 6500/4200/2700/1700/1100/750/520/420, 19 POI (7 caches, 4 depots d'armes, 5 camps d'elite, 3 ateliers), minicarte carte entiere puis rapprochee.
- [x] 2 spawner : _in_map (aucune apparition hors carte), biais zone 30 % seulement hors/pres du bord (>0,8 R). Bot : explore les POI.
- [ ] 3 smoke
- [ ] 4 banc bm1
- [ ] 5 captures qa_bigmap
- [ ] 6 v12.19 push
