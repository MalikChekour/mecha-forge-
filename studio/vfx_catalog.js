// Mecha-Forge VFX Catalog
// Synchronized with game/scenes/FxKit.gd and game/assets/vfx

export const VFX_CATEGORIES = {
  explosions: {
    id: "explosions",
    name: "Explosions & Déflagrations",
    icon: "💥",
    desc: "Détonations d'obus, explosions de missiles, ogives lourdes et barils"
  },
  impacts: {
    id: "impacts",
    name: "Impacts & Étincelles",
    icon: "⚡",
    desc: "Éclats métalliques au contact des blindages, étincelles et flashs critiques"
  },
  beams_lasers: {
    id: "beams_lasers",
    name: "Lasers & Faisceaux",
    icon: "✨",
    desc: "Rayons continus, lasers orbitaux, arcs plasma et traçantes cinétiques"
  },
  shockwaves: {
    id: "shockwaves",
    name: "Ondes de Choc & Cercles",
    icon: "⭕",
    desc: "Anneaux de surpression, impulsions EMP et zones de souffle radial"
  },
  shields_auras: {
    id: "shields_auras",
    name: "Boucliers & Auras",
    icon: "🛡️",
    desc: "Dômes de protection Fresnel, boucliers hexagonaux et barrières réactives"
  },
  muzzle_flashes: {
    id: "muzzle_flashes",
    name: "Tirs & Bouches de Canon",
    icon: "🔥",
    desc: "Éclats d'allumage en sortie de canon, flashs anamorphiques et gerbes de poudre"
  }
};

export const VFX_ITEMS = [
  // --- Explosions ---
  {
    id: "aaa_explosion",
    category: "explosions",
    name: "Explosion Cinématique AAA",
    file: "aaa_explosion.png",
    type: "spritesheet",
    frames: 30,
    fps: 58,
    baseScale: 1.0,
    defaultColor: "#ffaa33",
    desc: "Animation complète en 30 images : cœur blanc, plasma chaud et volutes de fumée"
  },
  {
    id: "dp_blast",
    category: "explosions",
    name: "Déflagration Plasma Lourde",
    file: "dp_blast.png",
    type: "spritesheet",
    frames: 24,
    fps: 30,
    baseScale: 1.15,
    defaultColor: "#33aaff",
    desc: "Déflagration énergétique bleue pour les armes lourdes et canons de siège"
  },
  {
    id: "explosion",
    category: "explosions",
    name: "Noyau d'Explosion Compact",
    file: "explosion.png",
    type: "sprite",
    baseScale: 1.0,
    defaultColor: "#ff6600",
    desc: "Flash de détonation rapide pour roquettes et tirs secondaires"
  },
  {
    id: "fire_blast",
    category: "explosions",
    name: "Souffle Incandescent",
    file: "fire_blast.png",
    type: "sprite",
    baseScale: 1.1,
    defaultColor: "#ff4411",
    desc: "Onde thermique brûlante avec propagation de braises incandescentes"
  },

  // --- Impacts ---
  {
    id: "aaa_impact",
    category: "impacts",
    name: "Impact de Blindage AAA",
    file: "aaa_impact.png",
    type: "spritesheet",
    frames: 28,
    fps: 72,
    baseScale: 0.9,
    defaultColor: "#ffffff",
    desc: "Éclatement ultra-rapide au point de pénétration balistique"
  },
  {
    id: "impact",
    category: "impacts",
    name: "Éclat d'Énergie",
    file: "impact.png",
    type: "sprite",
    baseScale: 0.85,
    defaultColor: "#00e5ff",
    desc: "Éclat énergétique conique dans l'axe d'arrivée du projectile"
  },
  {
    id: "crit",
    category: "impacts",
    name: "Flash de Coup Critique",
    file: "crit.png",
    type: "sprite",
    baseScale: 1.2,
    defaultColor: "#ffe600",
    desc: "Marqueur visuel percutant indiquant une perforation critique"
  },

  // --- Lasers & Faisceaux ---
  {
    id: "aaa_beam",
    category: "beams_lasers",
    name: "Rayon Ionique Haute Fréquence",
    file: "aaa_beam.png",
    type: "beam",
    baseScale: 1.0,
    defaultColor: "#00f0ff",
    desc: "Faisceau continu de canon laser avec halo anamorphique pulsé"
  },
  {
    id: "elec_beam",
    category: "beams_lasers",
    name: "Faisceau Électrique / Arc",
    file: "elec_beam.png",
    type: "beam",
    baseScale: 1.1,
    defaultColor: "#9944ff",
    desc: "Décharge électrique ramifiée reliant deux pôles conducteurs"
  },
  {
    id: "dp_tracer",
    category: "beams_lasers",
    name: "Traçante Balistique",
    file: "dp_tracer.png",
    type: "tracer",
    baseScale: 1.0,
    defaultColor: "#ffcc44",
    desc: "Sillage lumineux étiré suivant la trajectoire des tirs d'autocanon"
  },

  // --- Ondes de choc ---
  {
    id: "aaa_shockwave",
    category: "shockwaves",
    name: "Onde de Choc Supersonique AAA",
    file: "aaa_shockwave.png",
    type: "shockwave",
    baseScale: 1.1,
    defaultColor: "#00ffff",
    desc: "Anneau de compression net avec fondu de dissipation exponentiel"
  },
  {
    id: "shockwave",
    category: "shockwaves",
    name: "Anneau d'Impulsion",
    file: "shockwave.png",
    type: "shockwave",
    baseScale: 1.0,
    defaultColor: "#ffffff",
    desc: "Anneau d'expansion radial accompagnant chaque déflagration lourde"
  },
  {
    id: "aaa_aoe",
    category: "shockwaves",
    name: "Zone d'Effet Annulaire AAA",
    file: "aaa_aoe.png",
    type: "spritesheet",
    frames: 28,
    fps: 54,
    baseScale: 1.2,
    defaultColor: "#ff0077",
    desc: "Champ énergétique circulaire pulsant avec motif d'activation"
  },
  {
    id: "dp_aoe",
    category: "shockwaves",
    name: "Anneau d'Énergie Cinétique",
    file: "dp_aoe.png",
    type: "sprite",
    baseScale: 1.05,
    defaultColor: "#00e5ff",
    desc: "Onde circulaire pour les attaques radiales et auras tactiques"
  },

  // --- Boucliers & Auras ---
  {
    id: "shield_hex",
    category: "shields_auras",
    name: "Bouclier Hexagonal Tactique",
    file: "shield_hex.png",
    type: "shield",
    baseScale: 1.15,
    defaultColor: "#6ad0ff",
    desc: "Barrière protectrice à maillage hexagonal avec résonance de choc"
  },
  {
    id: "shield_bubble",
    category: "shields_auras",
    name: "Dôme Protecteur Fresnel",
    file: "shield_bubble.png",
    type: "shield",
    baseScale: 1.1,
    defaultColor: "#ffbe37",
    desc: "Membrane sphérique translucide entourant le mecha"
  },
  {
    id: "shield_electric",
    category: "shields_auras",
    name: "Barrière Électrostatique",
    file: "shield_electric.png",
    type: "shield",
    baseScale: 1.12,
    defaultColor: "#ff7a45",
    desc: "Champ d'ionisation crépitant déviant les tirs ennemis"
  },

  // --- Bouches de canons ---
  {
    id: "aaa_muzzle",
    category: "muzzle_flashes",
    name: "Flash Anamorphique AAA",
    file: "aaa_muzzle.png",
    type: "muzzle",
    baseScale: 0.95,
    defaultColor: "#ffffaa",
    desc: "Étoile de sortie de canon avec traînée latérale et cœur blanc aveuglant"
  },
  {
    id: "muzzle",
    category: "muzzle_flashes",
    name: "Étincelle de Culasse",
    file: "muzzle.png",
    type: "muzzle",
    baseScale: 0.85,
    defaultColor: "#ff9900",
    desc: "Flash classique pour mitrailleuses et canons automatiques légers"
  },
  {
    id: "dp_muzzle",
    category: "muzzle_flashes",
    name: "Flamme Cinétique Renforcée",
    file: "dp_muzzle.png",
    type: "muzzle",
    baseScale: 1.05,
    defaultColor: "#00ccff",
    desc: "Flash bleu de culasse haute pression pour canons électromagnétiques"
  }
];
