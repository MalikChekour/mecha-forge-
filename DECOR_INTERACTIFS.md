# Decors interactifs - liste, perimetre, verdict (audit 17/10)

Genere depuis `PropScatter.DECOR` + `_test_decor_perimetre.gd` (mesure a 0,5 r / 0,9 r / 1,25 r). Lettres : D degats, S ralentissement, M poussee, H soin, Z zone de sol, E projectile/effet cree, N/n ennemi deplace/touche, K butin attire.

| Biome | Objet | Effet (pancarte) | Rayon | Sprite | Mesure | Verdict |
|---|---|---|---|---|---|---|
| tech | aimant | Tant que vous restez près de lui, il repousse les ennemis. | 170 | 128.0 | N72/N36/- | OK |
| tech | antenne | Fait apparaître des drones tant qu'elle est debout : détruisez-la en priorité. | - | 190.0 | - | Evenement/obstacle (pas de rayon) |
| tech | archives | Marque l'ennemi le plus proche : vos tirs le visent en priorité. | 340 | 185.0 | -/-/- | **Faible** - Aucun degat : marque l'ennemi le plus proche (priorite de visee). Bonus indirect. |
| tech | baril | S'arme quand vous approchez, puis explose. Tirez dessus de loin pour blesser la horde. | - | 118.0 | - | Evenement/obstacle (pas de rayon) |
| tech | bras_presseur | Écrase une ligne au sol à intervalle. Quittez la bande marquée avant l'impact. | 240 | 160.0 | -/-/- | **OK (aleatoire)** - Ligne de 240 u toutes les 8-15 s. |
| tech | capaciteur | Balaie un rayon à cycle fixe qui blesse vous ET la horde (bien plus la horde). Esquivez latéralement. | - | 140.0 | - | Evenement/obstacle (pas de rayon) |
| tech | conduit | Ralentit vous ET la horde dans sa zone. Détruisez-le pour l'éteindre. | 200 | 145.0 | S0.50/S0.50/- | OK |
| tech | console_convoyeur | RESTEZ dans son cercle : arrête les tapis proches pendant 8 s. | 400 | 118.0 | -/-/- | **OK (jauge)** - Inverse les tapis voisins apres jauge. |
| tech | container_mobile | Glisse sur un rail : obstacle mouvant, ne vous faites pas coincer. | - | 185.0 | - | Evenement/obstacle (pas de rayon) |
| tech | convoyeur | Pousse les ennemis proches sur son axe. | 280 | 150.0 | S0.52 M152 E6 N182/S0.52 M32 E6 N50/E6 | OK |
| tech | convoyeur_sol | Vous ralentit et vous entraîne dans le sens des chevrons, vous et la horde. Une console voisine l'arrête 8 s. | 280 | 150.0 | S0.52 M152 E6 N182/S0.52 M32 E6 N50/E6 | OK |
| tech | emetteur | Soigne les ennemis proches : cible prioritaire. | 260 | 148.0 | -/-/- | **Malus joueur** - Soigne les ENNEMIS proches (r 260) : a detruire en priorite. |
| tech | generateur | Foudroie les ennemis proches. Détruit, il libère une onde EMP. | 300 | 175.0 | n88/-/- | OK |
| tech | piston_hydraulique | Barrière qui sort et rentre toutes les 2 s : passez quand elle est rentrée. | - | 155.0 | - | Evenement/obstacle (pas de rayon) |
| tech | porte_automatique | S'ouvre et se ferme à intervalle : franchissez-la quand elle est ouverte. | - | 185.0 | - | Evenement/obstacle (pas de rayon) |
| tech | quai | Apparaît et disparaît : bloque le passage par intervalles. | - | 140.0 | - | Evenement/obstacle (pas de rayon) |
| tech | surchauffe_sol | Zone de feu qui grandit par à-coups : ne restez pas dessus. | - | 150.0 | - | Evenement/obstacle (pas de rayon) |
| tech | tech_portique_laser | Une tête laser glisse et trace une ligne de découpe au sol toutes les 6 s (marquée 1,2 s avant). Évitez la lig | 240 | 170.0 | E1/E1/E1 | OK |
| tech | tech_soudeuse | Balaie un arc de soudure électrique sur ±45° pendant 3 s puis se refroidit. Restez hors de son arc ! | - | 165.0 | - | Evenement/obstacle (pas de rayon) |
| tech | terminal | RESTEZ dans son cercle ~1 s : onde de choc qui repousse les ennemis proches. | 100 | 118.0 | -/-/- | **OK (jauge)** - Onde de choc apres 1,2 s dans le cercle. |
| tech | tourelle | Tire un rayon selon un axe fixe. Affaiblie, elle est piratée et foudroie les ennemis. | - | 160.0 | - | Evenement/obstacle (pas de rayon) |
| tech | vanne_refroidissement | RESTEZ dans son cercle : soigne 20 % de vos PV et éteint les sols en surchauffe proches (recharge 30 s). | 150 | 118.0 | -/-/- | **OK (jauge)** - Zone sure + soin 20 %. |
| tech | zone_chargement | Marque des impacts au sol à intervalle : sortez des cercles. | - | 150.0 | - | Evenement/obstacle (pas de rayon) |
| desert | desert_collecteur_solaire | RESTEZ 1,5 s dedans : recharge +25 % de votre jauge de surcharge (recharge 40 s). | 100 | 145.0 | -/-/- | **OK (jauge)** - +25 % de surcharge toutes les 40 s. |
| desert | desert_fosse_aspiration | Attire vers son centre et ralentit tout ce qui entre dans ses sables mouvants. | 150 | 150.0 | S0.50 M73 N73/S0.50 M134 N133/- | OK |
| desert | desert_fumerolle_vapeur | Geyser brûlant à intervalle régulier : repousse et inflige des dégâts. | 120 | 125.0 | M50 Z1(15)/M50 Z1(15)/M50 Z2(30) | OK |
| desert | desert_generateur_tempete | Libère périodiquement un tourbillon de sable qui pousse et blesse pendant 8 s. | - | 190.0 | - | Evenement/obstacle (pas de rayon) |
| desert | desert_miroir_solaire | Charge 1,8 s puis tire un rayon qui vitrifie le sol pendant 3 s : restez hors du sillon. | - | 165.0 | - | Evenement/obstacle (pas de rayon) |
| desert | desert_projecteur_mirage | RESTEZ dedans : projette un leurre holographique qui détourne la horde pendant 6 s. | 340 | 135.0 | -/-/- | **OK (aleatoire)** - Leurre r 340, 6 s. |
| desert | desert_ver_foreur | Épave piégée : si vous approchez, le ver jaillit du sol. Écartez-vous de la zone ! | 220 | 175.0 | Z1(25)/Z1(25)/- | OK |
| jungle | jungle_arbre_ruche | Arbre-ruche biomécanique : génère des drones-guêpes tant qu'il n'est pas abattu. | - | 200.0 | - | Evenement/obstacle (pas de rayon) |
| jungle | jungle_fleur_catapulte | Marchez dessus pour être propulsé de 300 unités dans votre direction de déplacement. | 300 | 135.0 | -/-/- | **CORRIGE** - Declenchement 80 -> 100 u : propulse de 300 u. |
| jungle | jungle_fruit_grenade | Fruit instable : explose après amorçage si vous restez trop près ou s'il est touché. | - | 110.0 | - | Evenement/obstacle (pas de rayon) |
| jungle | jungle_liane_fouet | Fouette violemment un arc de 120 degrés autour de sa base : surveillez le sol. | 160 | 180.0 | M120 Z2(44)/M60 Z1(22)/Z1(22) | OK |
| jungle | jungle_mortier_plante | Tire des cosses de graines en cloche par-dessus les obstacles : explose en nuage d'épines. | 90 | 170.0 | E1/E1/E2 | OK |
| jungle | jungle_nuee_lucioles | RESTEZ dans la lueur : régénère vos PV (+3 PV/s) pendant 10 s avant de s'épuiser. | 110 | 120.0 | H21/H21/- | OK |
| jungle | jungle_plante_lasso | Piège naturel : se referme sur la première cible qui entre et l'immobilise pendant 1,5 s. | 85 | 140.0 | D8 S0.05/D8 S0.05/- | **CORRIGE** - Rayon 85 -> 115 : immobilise 1,5 s + 8 degats. |
| volcanic | volcanic_bassin_trempe | RESTEZ 1 s dedans : éteint les brûlures et réduit de 50 % les dégâts de feu pendant 8 s. | 120 | 160.0 | H15/H15/- | OK |
| volcanic | volcanic_creuset_basculant | Bascule périodiquement et déverse une ligne de métal en fusion incandescente. | 260 | 180.0 | E1/E1/E1 | OK |
| volcanic | volcanic_electroaimant | Approchez-vous : attire puissamment tous les pickups et gemmes dans un rayon de 450 u. | 450 | 155.0 | -/-/- | **CORRIGE** - Attraction active a < 220 u au lieu de 450 u ; force 320 -> 420. |
| volcanic | volcanic_event_magma | Éruption volcanique périodique : jaillissement de lave qui enflamme le sol pendant 3 s. | 110 | 160.0 | Z2(40)/Z1(20)/Z1(20) | OK |
| volcanic | volcanic_marteau_pilon | Frappe lourde toutes les 7 s : onde de choc écrasante qui repousse et inflige de lourds dégâts. | 140 | 200.0 | M65 Z1(35)/M65 Z1(35)/M65 Z1(35) | OK |
| volcanic | volcanic_mortier_scories | Tire des obus de lave en cloche qui laissent une flaque de magma brûlante pendant 5 s. | 95 | 175.0 | E1/E1/E1 | OK |
| volcanic | volcanic_soufflerie_braises | Rafale brûlante périodique : repousse violemment et applique une brûlure pendant 4 s. | 170 | 140.0 | M55 Z1(18)/M55 Z1(18)/Z1(18) | OK |
| swamp | swamp_bouee_mine | Mine dérivante armée : explose au contact ou après amorçage si vous vous approchez. | 160 | 120.0 | Z5(175)/Z5(175)/- | OK |
| swamp | swamp_brouilleur_radio | Tour de brouillage : ralentit de 50 % tous les projectiles ennemis dans un rayon de 300 u. | 300 | 190.0 | -/-/- | **OK** - Ralentit x0,5 les projectiles ennemis (r 300). |
| swamp | swamp_lampadaire_phare | Projecteur rotatif : balaye la zone et excite les ennemis touchés. Destructible. | 280 | 180.0 | -/-/- | **Malus** - Eclaire un point : ennemis proches x1,4 en vitesse si vous y etes. |
| swamp | swamp_tourelle_dca | Tire une salve de 4 obus à fusée qui éclatent en anneau de shrapnel dévastateur. | 110 | 170.0 | E4/E4/E8 | OK |
| swamp | swamp_vanne_barrage | RESTEZ 1,5 s dedans : assèche la zone et annule le ralentissement de l'eau pendant 10 s. | 130 | 160.0 | -/-/- | OK (jauge de presence 1,5 s, abaisse le niveau d eau) |
| swamp | swamp_vanne_crue | Libère périodiquement une vague torrentielle sur 400 u qui repousse violemment. | 400 | 170.0 | M80 E1/M80 E1/E1 | OK |
| cryo | borne_thermique | RESTEZ dans son cercle : soigne 20 % de vos PV (recharge 25 s). | 150 | 118.0 | -/-/- | **OK (jauge)** - Soin 20 %. |
| cryo | brouillard_froid | Nuage glacial mobile : ralentit tout ce qui le traverse, vous comme la horde. Un radiateur proche le dissipe. | 260 | 20.0 | S0.72/S0.72/- | **Malus** - Ralentit x0,72 (joueur et ennemis), derive lentement. |
| cryo | capsule_cryogenique | Détruisez-la : un bonus… ou un ennemi en sort (1 chance sur 3). | - | 130.0 | - | Evenement/obstacle (pas de rayon) |
| cryo | cryo_canon_azote | Tire des orbes de givre lents explosant en nova glacée qui ralentit et laisse du verglas. | 100 | 170.0 | E1/E1/E1 | OK |
| cryo | cryo_condenseur_givre | Émet des anneaux de givre concentriques qui s'étendent et ralentissent les mechas. | 250 | 165.0 | Z3(36)/Z3(36)/Z3(36) | OK |
| cryo | cryo_mur_glace_regen | Bloc de glace défensif arrêtant les tirs : se reforme entièrement 10 s après destruction. | - | 170.0 | - | Evenement/obstacle (pas de rayon) |
| cryo | cryo_teleporteur_paire | Marcher sur la dalle vous téléporte instantanément sur sa balise jumelle (recharge 6 s). | 80 | 160.0 | M319/M72/- | OK |
| cryo | glace_fragile | Se fissure puis s'effondre en obstacle solide au bout de 10 à 20 s. | - | 130.0 | - | Evenement/obstacle (pas de rayon) |
| cryo | jet_de_cryo | Gèle (étourdit) quiconque reste dans le cercle marqué. | 70 | 110.0 | -/-/- | **CORRIGE** - Rayon 70 -> 110 (insignifiant vs sprite 110) : zone de gel 1 s toutes les 6-12 s. |
| cryo | pic_de_glace | Éclat périodique au sol : ralentit si vous êtes dessus. | - | 120.0 | - | Evenement/obstacle (pas de rayon) |
| cryo | plaque_de_glace | Vous fait glisser : votre mecha perd de l'adhérence tant que vous êtes dessus. | 130 | 140.0 | P/P/- | **Malus leger** - Sol glissant (inertie 0,8). |
| cryo | radiateur | Dissipe le brouillard glacial proche, donc supprime son ralentissement. | 320 | 118.0 | -/-/- | **OK (indirect)** - Dissipe les brouillards froids voisins. |
| reacteur | bassin_toxique | Dégâts continus tant que vous restez dedans. Une vanne de drainage le suspend. | 150 | 180.0 | D42/D42/- | OK |
| reacteur | console_vent | RESTEZ dans son cercle : inverse le sens des turbines proches. | 400 | 118.0 | -/-/- | **OK (jauge)** - Inverse les poches de vent voisines apres jauge. |
| reacteur | cristal_instable | Le toucher l'arme : il explose 3 s plus tard. Éloignez-vous (ou attirez-y la horde). | - | 125.0 | - | Evenement/obstacle (pas de rayon) |
| reacteur | grille_ventilation | Souffle à intervalle : sortez du cercle marqué. | - | 110.0 | - | Evenement/obstacle (pas de rayon) |
| reacteur | poche_de_vent | Pousse en continu vous ET les ennemis dans une direction. Une console de vent l'inverse. | 220 | 205.0 | M110 N192/M23 N97/- | OK |
| reacteur | pulse_energie | Émet trois anneaux qui s'étendent : sortez de leur trajet. | - | 140.0 | - | Evenement/obstacle (pas de rayon) |
| reacteur | reacteur_barre_controle | RESTEZ 1,5 s près d'elle : réduit de 60 % tous les dégâts reçus pendant 8 s. | 120 | 160.0 | -/-/- | **CORRIGE** - Promettait -60 % de degats mais rien ne le lisait : le joueur recoit 40 % des degats pendant 8 s. |
| reacteur | reacteur_bobine_tesla | Deux bobines reliées par un arc électrique continu qui inflige de lourds dégâts. | 300 | 150.0 | E2/E2/E2 | OK |
| reacteur | reacteur_canon_particules | Tir à charge qui se divise en 3 fragments. En surchauffe, il explose. | 350 | 160.0 | E1/E1/E1 | OK |
| reacteur | reacteur_cellule_confinement | Active un dôme protecteur de 220 u bloquant tous les projectiles ennemis pendant 6 s. | 220 | 150.0 | -/-/- | **OK** - Idem 6 s, r 220. |
| reacteur | vanne_drainage | RESTEZ dans son cercle : suspend les bassins toxiques proches pendant 10 s. | 250 | 118.0 | -/-/- | **OK (jauge)** - Suspend les bassins toxiques voisins 10 s. |
| reacteur | zone_alternante | Alterne danger et sécurité : le cercle clignote juste avant de devenir dangereux. | 100 | 150.0 | D50/D50/- | OK |
| ruche | cocon | Détruisez-le : un bonus… ou un ennemi en sort (1 chance sur 3). | - | 155.0 | - | Evenement/obstacle (pas de rayon) |
| ruche | nuage_spores | Dérive et inflige des dégâts continus. Une plante lumineuse proche le dissipe. | 220 | 20.0 | D35/D9/- | OK |
| ruche | plante_lumineuse | RESTEZ dans son cercle : dissipe les nuages de spores proches pendant 8 s. | 300 | 115.0 | -/-/- | **OK (indirect)** - Supprime les nuages de spores voisins 8 s. |
| ruche | residu_biomecanique | Vous ralentit et attire les ennemis vers son centre. | 150 | 140.0 | S0.60 N75/S0.60 N135/- | OK |
| ruche | ruche_organe_acide | Crache 3 globules d'acide en cloche créant des flaques toxiques corrosives. | 320 | 150.0 | E6/E6/E3 | OK |
| ruche | ruche_pondoir | Pond régulièrement des larves agressives : cible prioritaire à détruire. | - | 165.0 | - | Evenement/obstacle (pas de rayon) |
| ruche | ruche_veine_pulsatile | Pulse violemment toutes les 3 s et repousse tout le long de son axe. | 250 | 160.0 | M144 N216/M72 N108/- | OK |
| ruche | ruche_vessie_explosive | Touchée, elle explose violemment en projetant une gerbe d'acide corrosive. | - | 130.0 | - | Evenement/obstacle (pas de rayon) |
| ruche | sol_collant | Ralentit fortement tout ce qui y marche. | 150 | 140.0 | S0.45/S0.45/- | OK |
| ruche | tentacule_emergence | Jaillit du sol à intervalle : quittez le cercle marqué. | - | 155.0 | - | Evenement/obstacle (pas de rayon) |
| citadelle | citadelle_dome_bouclier | Projette une barrière énergétique impénétrable repoussant les assauts. | 200 | 160.0 | -/-/- | **OK** - Detruit les projectiles ennemis dans r 200 pendant 8 s. |
| citadelle | citadelle_grappin_magnetique | Attire périodiquement les ennemis et débris vers son ancrage. | 250 | 150.0 | N120/N240/- | OK |
| citadelle | citadelle_lanceur_guide | Tire des missiles guidés à tête chercheuse qui traquent le mecha. | 400 | 165.0 | E6/E6/E6 | OK |
| citadelle | citadelle_relais_satellite | Émet des pulsations orbitales périodiques électrifiant la zone. | 350 | 155.0 | Z1(20)/Z1(20)/Z1(20) | OK |
| citadelle | citadelle_sas_pressurise | Sas orbital étanche qui s'ouvre et se ferme selon un cycle régulier. | - | 170.0 | - | Evenement/obstacle (pas de rayon) |
| citadelle | emetteur_laser_rotatif | Balaie une ligne qui tourne à chaque tir : évitez la bande marquée. | - | 150.0 | - | Evenement/obstacle (pas de rayon) |
| citadelle | pilier_energie | Détruit, il repousse violemment les ennemis proches. | - | 255.0 | - | Evenement/obstacle (pas de rayon) |
| citadelle | porte_securite_orbitale | S'ouvre et se ferme à intervalle : franchissez-la quand elle est ouverte. | - | 185.0 | - | Evenement/obstacle (pas de rayon) |
| citadelle | segment_mur_modulaire | Apparaît et disparaît par intervalles : bloque le passage quand il est là. | - | 170.0 | - | Evenement/obstacle (pas de rayon) |
| citadelle | zone_depressurisation | Aspire vers son centre à intervalle (clignote avant) : éloignez-vous avant l'aspiration. | 200 | 150.0 | -/-/- | **CORRIGE** - Aspiration 26 px (insignifiante) -> 110 px, joueur ET ennemis. |
| citadelle | zone_push_pull | Repousse puis attire en alternance : teinte bleue = pousse, orange = attire. | 180 | 150.0 | M90/M18/- | OK |
| ice | glace | Ralentit fortement les ennemis proches : attirez la horde à côté. | 170 | 150.0 | -/-/- | **Bonus** - Ralentit uniquement les ennemis (x0,4). |
| spaceship | impulsion | Repousse vous ET les ennemis proches à intervalle régulier. | 260 | 118.0 | M91 N91/M46 N91/- | OK |
| ? | cristaux | Brisés, ils projettent des éclats qui blessent la horde. | - | 125.0 | - | Evenement/obstacle (pas de rayon) |
| ? | epave | Un robot s'y réveille si vous approchez. Détruisez-la de loin pour l'achever dans son sommeil. | - | 215.0 | - | Evenement/obstacle (pas de rayon) |
| ? | lave | Brûle tout ce qui s'y tient, vous compris. | 130 | 145.0 | D170 n238/D170 n238/- | OK |
| ? | plante | Nuage de spores : poison et ralentissement autour d'elle, pour vous comme pour la horde. | 150 | 115.0 | D119 S0.70 n119/D119 S0.70 n119/- | OK |
| ? | racines | Piège : ralentit à l'extrême ce qui entre dans leur zone. | 120 | 132.0 | S0.35/S0.35/- | OK |

102 objets interactifs.