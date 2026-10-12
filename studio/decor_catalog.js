// Mecha-Forge Decor Catalog
// Synchronized with game/actors/PropScatter.gd DECOR dictionary

export const DECOR_CATEGORIES = {
  crates_barrels: {
    id: "crates_barrels",
    name: "Caisses & Barils",
    icon: "📦",
    desc: "Conteneurs destructibles, barils de carburant et réserves de compétences"
  },
  machines_towers: {
    id: "machines_towers",
    name: "Installations & Tourelles",
    icon: "📡",
    desc: "Pylônes à arc, balises ennemies, émetteurs de réparation et tourelles d'artillerie"
  },
  interactive_hazards: {
    id: "interactive_hazards",
    name: "Mécanismes & Dangers",
    icon: "⚠️",
    desc: "Convoyeurs, pistons, surchauffes, bassins toxiques, vannes et turbines"
  },
  nature_minerals: {
    id: "nature_minerals",
    name: "Nature & Minéraux",
    icon: "🪨",
    desc: "Rochers, cristaux, arbres cyber, glace, lave, arches et piliers rocheux"
  },
  borders: {
    id: "borders",
    name: "Bordures & Murs",
    icon: "🧱",
    desc: "Segments de mur d'arène, barrières défensives et pylônes périmétriques"
  }
};

export const DECOR_ITEMS = [
  // --- Caisses & Barils ---
  {
    id: "baril",
    category: "crates_barrels",
    name: "Baril de Carburant",
    file: "g20.png",
    baseSz: 90.0,
    hp: 40.0,
    destructible: true,
    desc: "S'arme à l'approche et explose en infligeant des dégâts radiaux"
  },
  {
    id: "caisses",
    category: "crates_barrels",
    name: "Caisse de Compétence",
    file: "g21.png",
    baseSz: 92.0,
    hp: 38.0,
    destructible: true,
    desc: "Peut libérer un coffre de compétence doré lors de sa destruction"
  },
  {
    id: "container",
    category: "crates_barrels",
    name: "Conteneur Blindé",
    file: "g28.png",
    baseSz: 140.0,
    hp: 45.0,
    destructible: true,
    desc: "Conteneur tactique lourd avec fort taux de butin"
  },
  {
    id: "crate",
    category: "crates_barrels",
    name: "Caisse Cyber",
    file: "crate.png",
    baseSz: 90.0,
    hp: 35.0,
    destructible: true,
    desc: "Caisse de fret renforcée"
  },

  // --- Installations & Tourelles ---
  {
    id: "generateur",
    category: "machines_towers",
    name: "Pylône à Arc Électrique",
    file: "g22.png",
    baseSz: 140.0,
    hp: 170.0,
    destructible: true,
    desc: "Électrocute les ennemis proches et génère une onde EMP à sa destruction"
  },
  {
    id: "antenne",
    category: "machines_towers",
    name: "Balise de Brouillage",
    file: "g23.png",
    baseSz: 150.0,
    hp: 220.0,
    destructible: true,
    desc: "Fait apparaître des vagues de drones ennemis tant qu'elle n'est pas détruite"
  },
  {
    id: "conduit",
    category: "machines_towers",
    name: "Conduit Réducteur de Flux",
    file: "g24.png",
    baseSz: 118.0,
    hp: 90.0,
    destructible: true,
    desc: "Génère un champ de ralentissement affectant joueurs et ennemis"
  },
  {
    id: "emetteur",
    category: "machines_towers",
    name: "Émetteur de Réparation",
    file: "g25.png",
    baseSz: 118.0,
    hp: 90.0,
    destructible: true,
    desc: "Régénère la santé des unités ennemies dans son rayon d'action"
  },
  {
    id: "epave",
    category: "machines_towers",
    name: "Épave de Mecha",
    file: "g26.png",
    baseSz: 168.0,
    hp: 130.0,
    destructible: true,
    desc: "Robot de guerre endormi qui peut s'éveiller en ennemi agressif"
  },
  {
    id: "tourelle",
    category: "machines_towers",
    name: "Tourelle Fixe Embusquée",
    file: "g27.png",
    baseSz: 130.0,
    hp: 140.0,
    destructible: true,
    desc: "Batterie d'artillerie automatique fixe avec cône de tir directionnel"
  },
  {
    id: "capaciteur",
    category: "machines_towers",
    name: "Capaciteur à Faisceau",
    file: "g25.png",
    baseSz: 140.0,
    hp: 220.0,
    destructible: true,
    desc: "Balaye périodiquement l'arène avec un rayon destructeur"
  },

  // --- Mécanismes & Dangers ---
  {
    id: "convoyeur_sol",
    category: "interactive_hazards",
    name: "Convoyeur Industriel",
    file: "convoyeur_sol.png",
    baseSz: 130.0,
    hp: 150.0,
    destructible: true,
    desc: "Tapis roulant motorisé déplaçant rapidement les entités"
  },
  {
    id: "console_convoyeur",
    category: "interactive_hazards",
    name: "Console de Commande",
    file: "console_convoyeur.png",
    baseSz: 118.0,
    hp: 90.0,
    destructible: true,
    desc: "Pupitre de contrôle interactif pour inverser les systèmes"
  },
  {
    id: "bras_presseur",
    category: "interactive_hazards",
    name: "Bras Presseur Hydraulique",
    file: "bras_presseur.png",
    baseSz: 130.0,
    hp: 150.0,
    destructible: true,
    desc: "Bras mécanique qui écrase et étourdit tout ce qui passe dessous"
  },
  {
    id: "surchauffe_sol",
    category: "interactive_hazards",
    name: "Dalle de Surchauffe",
    file: "surchauffe_sol.png",
    baseSz: 150.0,
    hp: 90.0,
    destructible: false,
    desc: "Surface métallique brûlante accumulant l'énergie thermique"
  },
  {
    id: "plaque_de_glace",
    category: "interactive_hazards",
    name: "Plaque de Glace Vive",
    file: "plaque_de_glace.png",
    baseSz: 140.0,
    hp: 90.0,
    destructible: false,
    desc: "Surface glissante réduisant drastiquement l'adhérence du mecha"
  },
  {
    id: "jet_de_cryo",
    category: "interactive_hazards",
    name: "Éjecteur Cryogénique",
    file: "jet_de_cryo.png",
    baseSz: 110.0,
    hp: 90.0,
    destructible: true,
    desc: "Buse d'azote liquide projetant un souffle réfrigérant étourdissant"
  },
  {
    id: "bassin_toxique",
    category: "interactive_hazards",
    name: "Bassin Acide Corrosif",
    file: "bassin_liquide_toxique.png",
    baseSz: 150.0,
    hp: 90.0,
    destructible: false,
    desc: "Nappe toxique infligeant des dégâts continus de corrosion"
  },
  {
    id: "poche_de_vent",
    category: "interactive_hazards",
    name: "Turbine Géante de Flux",
    file: "turbine_geante.png",
    baseSz: 170.0,
    hp: 130.0,
    destructible: true,
    desc: "Rotor de ventilation générant une violente poussée aérodynamique"
  },
  {
    id: "zone_alternante",
    category: "interactive_hazards",
    name: "Zone Pulsée Déphasée",
    file: "zone_alternante.png",
    baseSz: 150.0,
    hp: 110.0,
    destructible: true,
    desc: "Réseau électromagnétique alternant phases sûres et décharges mortelles"
  },
  {
    id: "zone_depressurisation",
    category: "interactive_hazards",
    name: "Vortex de Dépressurisation",
    file: "zone_depressurisation.png",
    baseSz: 150.0,
    hp: 110.0,
    destructible: true,
    desc: "Aspiration orbitale entraînant les débris et les cibles vers son centre"
  },

  // --- Nature & Minéraux ---
  {
    id: "rocher",
    category: "nature_minerals",
    name: "Monolithe Rocheux",
    file: "g29.png",
    baseSz: 140.0,
    hp: 170.0,
    destructible: false,
    desc: "Bloc massif indestructible bloquant tirs et déplacements"
  },
  {
    id: "cristaux",
    category: "nature_minerals",
    name: "Cristaux Résonnants",
    file: "g30.png",
    baseSz: 100.0,
    hp: 70.0,
    destructible: true,
    desc: "Éclatent en esquilles acérées et chargent la jauge d'Overdrive"
  },
  {
    id: "arbre",
    category: "nature_minerals",
    name: "Arbre Cyber-Organique",
    file: "g31.png",
    baseSz: 178.0,
    hp: 70.0,
    destructible: false,
    desc: "Végétation métallique imposante offrant une couverture verticale"
  },
  {
    id: "plante",
    category: "nature_minerals",
    name: "Plante à Spores Vénéneuses",
    file: "g32.png",
    baseSz: 78.0,
    hp: 55.0,
    destructible: true,
    desc: "Libère un nuage gazeux persistant qui empoisonne la zone"
  },
  {
    id: "glace",
    category: "nature_minerals",
    name: "Bloc de Glace Éternelle",
    file: "g33.png",
    baseSz: 122.0,
    hp: 70.0,
    destructible: true,
    desc: "Génère une aura de givre engourdissante"
  },
  {
    id: "arche",
    category: "nature_minerals",
    name: "Arche Monolithique",
    file: "g34.png",
    baseSz: 196.0,
    hp: 190.0,
    destructible: false,
    desc: "Structure monumentale formant un goulet d'étranglement défensif"
  },
  {
    id: "lave",
    category: "nature_minerals",
    name: "Fissure Magmatique",
    file: "g35.png",
    baseSz: 112.0,
    hp: 150.0,
    destructible: true,
    desc: "Cratère de lave en fusion brûlant quiconque le traverse"
  },
  {
    id: "racines",
    category: "nature_minerals",
    name: "Entrelacs de Racines",
    file: "g36.png",
    baseSz: 132.0,
    hp: 95.0,
    destructible: true,
    desc: "Réseau racinaire dense piégeant les marcheurs"
  },
  {
    id: "pilier_energie",
    category: "nature_minerals",
    name: "Pilier de Confinement",
    file: "pilier_energie.png",
    baseSz: 220.0,
    hp: 260.0,
    destructible: true,
    desc: "Pilier massif haute tension déflagrant à sa destruction"
  },

  // --- Bordures d'arène ---
  {
    id: "segment_mur_modulaire",
    category: "borders",
    name: "Segment de Mur Orbital",
    file: "segment_mur_modulaire.png",
    baseSz: 170.0,
    hp: 220.0,
    destructible: false,
    desc: "Paroi périmétrique blindée délimitant le secteur"
  },
  {
    id: "barrier",
    category: "borders",
    name: "Barrière de Sécurité",
    file: "barrier.png",
    baseSz: 160.0,
    hp: 180.0,
    destructible: false,
    desc: "Barrière défensive d'enceinte"
  },
  {
    id: "d_pylon_1",
    category: "borders",
    name: "Pylône Périmétrique",
    file: "d_pylon_1.png",
    baseSz: 180.0,
    hp: 200.0,
    destructible: false,
    desc: "Balise de délimitation de la bordure d'arène"
  }
];
