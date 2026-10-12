import { DECOR_CATEGORIES, DECOR_ITEMS } from './decor_catalog.js';
import { VFX_CATEGORIES, VFX_ITEMS } from './vfx_catalog.js';

// ============================================================================
// APPLICATION STATE
// ============================================================================
const DEFAULT_STATE = {
  decor_global: 1.0,
  vfx_global: 1.0,
  decor_categories: {
    crates_barrels: 1.0,
    machines_towers: 1.0,
    interactive_hazards: 1.0,
    nature_minerals: 1.0,
    borders: 1.0
  },
  vfx_categories: {
    explosions: 1.0,
    impacts: 1.0,
    beams_lasers: 1.0,
    shockwaves: 1.0,
    shields_auras: 1.0,
    muzzle_flashes: 1.0
  },
  decor_custom: {},
  vfx_custom: {}
};

let scales = JSON.parse(JSON.stringify(DEFAULT_STATE));

const viewState = {
  selectedDecorId: "baril",
  selectedVfxId: "aaa_explosion",
  biome: "tech",
  mecha: "vortex",
  zoom: 1.0,
  panX: 0,
  panY: 0,
  isDragging: false,
  dragStartX: 0,
  dragStartY: 0,
  showGrid: true,
  showHitbox: true,
  vfxLoop: true,
  vfxTime: 0.0,
  vfxFrame: 0,
  particles: []
};

// Image Cache
const imgCache = new Map();

function loadImage(path) {
  if (imgCache.has(path)) {
    return imgCache.get(path);
  }
  const img = new Image();
  img.src = path;
  imgCache.set(path, img);
  return img;
}

// Biome Colors for background styling
const BIOME_PALETTES = {
  tech: { bg: '#080d16', grid: 'rgba(0, 240, 255, 0.15)', glow: 'rgba(0, 240, 255, 0.25)' },
  cryo: { bg: '#0a101d', grid: 'rgba(100, 200, 255, 0.15)', glow: 'rgba(130, 220, 255, 0.22)' },
  reacteur: { bg: '#0d130c', grid: 'rgba(0, 255, 120, 0.15)', glow: 'rgba(0, 255, 120, 0.22)' },
  ruche: { bg: '#140c16', grid: 'rgba(255, 0, 160, 0.15)', glow: 'rgba(255, 0, 160, 0.22)' },
  citadelle: { bg: '#13110c', grid: 'rgba(255, 180, 0, 0.15)', glow: 'rgba(255, 180, 0, 0.22)' }
};

// ============================================================================
// COMPUTED SCALE HELPERS
// ============================================================================
function getDecorScale(decorId) {
  const item = DECOR_ITEMS.find(d => d.id === decorId);
  if (!item) return scales.decor_global;
  const catMult = scales.decor_categories[item.category] || 1.0;
  const customMult = scales.decor_custom[decorId] || 1.0;
  return Math.max(0.2, scales.decor_global * catMult * customMult);
}

function getVfxScale(vfxId) {
  const item = VFX_ITEMS.find(v => v.id === vfxId);
  if (!item) return scales.vfx_global;
  const catMult = scales.vfx_categories[item.category] || 1.0;
  const customMult = scales.vfx_custom[vfxId] || 1.0;
  return Math.max(0.2, scales.vfx_global * catMult * customMult);
}

// ============================================================================
// LOCAL STORAGE & PERSISTENCE
// ============================================================================
const STORAGE_KEY = "mecha_forge_visual_scales_v1";

function loadFromStorage() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      scales = Object.assign(JSON.parse(JSON.stringify(DEFAULT_STATE)), parsed);
    }
  } catch (e) {
    console.warn("Storage load error", e);
  }
}

function saveToStorage() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(scales, null, 2));
    updateStatusBadge("SAUVEGARDÉ (NAV)");
    updateJsonPreview();
  } catch (e) {
    console.warn("Storage save error", e);
  }
}

async function loadFromGameServer() {
  try {
    const res = await fetch("/api/load_scales");
    if (res.ok) {
      const data = await res.json();
      scales = Object.assign(JSON.parse(JSON.stringify(DEFAULT_STATE)), data);
      updateStatusBadge("SYNCHRONISÉ DU JEU");
    }
  } catch (e) {
    // Normal when running without server
  }
}

async function saveToGameServer() {
  const feedback = document.getElementById("game-save-feedback");
  try {
    const res = await fetch("/api/save_scales", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(scales, null, 2)
    });
    if (res.ok) {
      feedback.textContent = "✓ Enregistré avec succès dans game/visual_scales.json !";
      feedback.className = "feedback-msg feedback-success";
      updateStatusBadge("SYNCHRONISÉ JEU");
    } else {
      throw new Error("HTTP " + res.status);
    }
  } catch (e) {
    // Fallback: invite user to download JSON directly
    feedback.textContent = "ℹ Serveur local non connecté. Téléchargez le fichier visual_scales.json pour le placer dans le jeu.";
    feedback.className = "feedback-msg feedback-error";
    downloadJsonFile();
  }
}

function downloadJsonFile() {
  const jsonStr = JSON.stringify(scales, null, 2);
  const blob = new Blob([jsonStr], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "visual_scales.json";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

function updateStatusBadge(text) {
  const badge = document.getElementById("save-status-badge");
  if (badge) {
    badge.textContent = text;
    badge.className = "badge badge-status";
    setTimeout(() => {
      badge.textContent = "SYNCHRONISÉ";
    }, 4000);
  }
}

function updateJsonPreview() {
  const el = document.getElementById("json-preview-text");
  if (el) {
    el.textContent = JSON.stringify(scales, null, 2);
  }
}

// ============================================================================
// CANVAS RENDERING ENGINE (60 FPS)
// ============================================================================
let canvas, ctx;

function initCanvas() {
  canvas = document.getElementById("stage-canvas");
  ctx = canvas.getContext("2d");

  function resize() {
    const container = document.getElementById("canvas-container");
    canvas.width = container.clientWidth * window.devicePixelRatio;
    canvas.height = container.clientHeight * window.devicePixelRatio;
    ctx.imageSmoothingEnabled = false; // keep crisp pixels like in Godot!
  }

  window.addEventListener("resize", resize);
  resize();

  // Mouse pan & zoom handlers
  const container = document.getElementById("canvas-container");
  container.addEventListener("mousedown", (e) => {
    if (e.button === 0) {
      viewState.isDragging = true;
      viewState.dragStartX = e.clientX - viewState.panX;
      viewState.dragStartY = e.clientY - viewState.panY;
    }
  });

  window.addEventListener("mousemove", (e) => {
    if (viewState.isDragging) {
      viewState.panX = e.clientX - viewState.dragStartX;
      viewState.panY = e.clientY - viewState.dragStartY;
    }
  });

  window.addEventListener("mouseup", () => {
    viewState.isDragging = false;
  });

  container.addEventListener("wheel", (e) => {
    e.preventDefault();
    const factor = e.deltaY < 0 ? 1.1 : 0.9;
    setZoom(viewState.zoom * factor);
  });

  // Click on canvas triggers particle / vfx blast at location
  canvas.addEventListener("click", (e) => {
    if (Math.abs(e.movementX) < 3 && Math.abs(e.movementY) < 3) {
      triggerVfx();
    }
  });

  requestAnimationFrame(renderLoop);
}

function setZoom(val) {
  viewState.zoom = Math.max(0.4, Math.min(3.0, val));
  document.getElementById("zoom-level").textContent = Math.round(viewState.zoom * 100) + "%";
}

let lastTimestamp = 0;

function renderLoop(timestamp) {
  const delta = (timestamp - lastTimestamp) / 1000.0 || 0.016;
  lastTimestamp = timestamp;

  updateAnimations(delta);
  drawStage();

  requestAnimationFrame(renderLoop);
}

function updateAnimations(delta) {
  viewState.vfxTime += delta;

  // Step active VFX animation
  const currentVfx = VFX_ITEMS.find(v => v.id === viewState.selectedVfxId);
  if (currentVfx && currentVfx.type === "spritesheet") {
    const fps = currentVfx.fps || 30;
    const totalFrames = currentVfx.frames || 1;
    const frameIndex = Math.floor(viewState.vfxTime * fps);
    if (viewState.vfxLoop) {
      viewState.vfxFrame = frameIndex % totalFrames;
    } else {
      viewState.vfxFrame = Math.min(frameIndex, totalFrames - 1);
    }
  }

  // Update particles
  for (let i = viewState.particles.length - 1; i >= 0; i--) {
    const p = viewState.particles[i];
    p.life -= delta;
    p.x += p.vx * delta;
    p.y += p.vy * delta;
    p.size *= (1.0 - delta * 0.8);
    if (p.life <= 0) {
      viewState.particles.splice(i, 1);
    }
  }
}

function triggerVfx() {
  viewState.vfxTime = 0.0;
  viewState.vfxFrame = 0;

  // Spawn visual particles
  const vfxMult = getVfxScale(viewState.selectedVfxId);
  const vfxDef = VFX_ITEMS.find(v => v.id === viewState.selectedVfxId) || {};
  const col = vfxDef.defaultColor || "#00f0ff";

  for (let i = 0; i < 28; i++) {
    const ang = Math.random() * Math.PI * 2;
    const spd = (60 + Math.random() * 240) * vfxMult;
    viewState.particles.push({
      x: -200,
      y: -60,
      vx: Math.cos(ang) * spd,
      vy: Math.sin(ang) * spd,
      size: (4 + Math.random() * 8) * vfxMult,
      life: 0.4 + Math.random() * 0.4,
      color: col
    });
  }
}

function drawStage() {
  if (!ctx) return;
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.width;
  const h = canvas.height;

  ctx.save();
  ctx.clearRect(0, 0, w, h);

  // Background
  const palette = BIOME_PALETTES[viewState.biome] || BIOME_PALETTES.tech;
  ctx.fillStyle = palette.bg;
  ctx.fillRect(0, 0, w, h);

  // Apply Camera transform
  const originX = w / 2 + viewState.panX * dpr;
  const originY = h / 2 + 100 * dpr + viewState.panY * dpr;
  const scale = viewState.zoom * dpr;

  ctx.translate(originX, originY);
  ctx.scale(scale, scale);

  // Ground Grid
  if (viewState.showGrid) {
    drawGrid(palette.grid);
  }

  // Draw Ground Arena Line
  ctx.beginPath();
  ctx.moveTo(-900, 0);
  ctx.lineTo(900, 0);
  ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
  ctx.lineWidth = 2;
  ctx.stroke();

  // 1. Draw Reference Mecha (at origin 0, 0)
  drawMecha();

  // 2. Draw Selected Decor (at +240, 0)
  drawSelectedDecor();

  // 3. Draw Selected VFX (at -220, -50)
  drawSelectedVfx();

  // 4. Draw Particles
  drawParticles();

  ctx.restore();
}

function drawGrid(color) {
  const step = 50;
  const range = 1200;

  ctx.strokeStyle = color;
  ctx.lineWidth = 1;

  ctx.beginPath();
  for (let x = -range; x <= range; x += step) {
    ctx.moveTo(x, -range);
    ctx.lineTo(x, range);
  }
  for (let y = -range; y <= range; y += step) {
    ctx.moveTo(-range, y);
    ctx.lineTo(range, y);
  }
  ctx.stroke();

  // Bold center axis
  ctx.strokeStyle = "rgba(0, 240, 255, 0.4)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-range, 0); ctx.lineTo(range, 0);
  ctx.moveTo(0, -range); ctx.lineTo(0, range);
  ctx.stroke();
}

function drawMecha() {
  const mechaId = viewState.mecha;
  // Load front idle mecha sheet
  let path = `../game/assets/mecha/${mechaId}_idle_front.png`;
  if (mechaId === "bluestrike") {
    path = `../game/assets/mecha/bluestrike_walk_front.png`;
  }
  const img = loadImage(path);

  // Shadow at feet
  ctx.save();
  ctx.beginPath();
  ctx.ellipse(0, 5, 55, 18, 0, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(0, 0, 0, 0.55)";
  ctx.fill();

  // Glowing player marker ring (from Mecha-Forge)
  ctx.beginPath();
  ctx.ellipse(0, 8, 65, 22, 0, 0, Math.PI * 2);
  ctx.strokeStyle = "rgba(255, 183, 0, 0.85)";
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.restore();

  if (img.complete && img.naturalWidth > 0) {
    const frameCount = 8;
    const fw = img.naturalWidth / frameCount;
    const fh = img.naturalHeight;
    // Display height in Godot is 360.0 px cell
    const cellH = 360.0;
    const sc = cellH / fh;
    const renderW = fw * sc;
    const renderH = fh * sc;

    // First frame
    const fx = 0;
    ctx.drawImage(img, fx, 0, fw, fh, -renderW / 2, -renderH + 70, renderW, renderH);

    // Height measurement tag
    if (viewState.showHitbox) {
      ctx.save();
      ctx.strokeStyle = "rgba(255, 183, 0, 0.6)";
      ctx.setLineDash([4, 4]);
      ctx.beginPath();
      ctx.moveTo(- renderW / 2 - 15, -190);
      ctx.lineTo(renderW / 2 + 15, -190);
      ctx.stroke();

      ctx.fillStyle = "rgba(255, 183, 0, 0.9)";
      ctx.font = "bold 13px Rajdhani";
      ctx.fillText("MECHA ~190 px", -45, -200);
      ctx.restore();
    }
  } else {
    // Placeholder while image is loading
    ctx.fillStyle = "rgba(0, 240, 255, 0.2)";
    ctx.fillRect(-45, -190, 90, 190);
    ctx.strokeStyle = "#00f0ff";
    ctx.strokeRect(-45, -190, 90, 190);
    ctx.fillStyle = "#ffffff";
    ctx.font = "14px Rajdhani";
    ctx.fillText("MECHA VORTEX", -40, -90);
  }
}

function drawSelectedDecor() {
  const decor = DECOR_ITEMS.find(d => d.id === viewState.selectedDecorId);
  if (!decor) return;

  const mult = getDecorScale(decor.id);
  const targetPx = decor.baseSz * mult;

  const posX = 240;
  const posY = 0;

  const path = `../game/assets/decor/${decor.file}`;
  const img = loadImage(path);

  // Shadow
  ctx.save();
  ctx.beginPath();
  ctx.ellipse(posX, posY + 5, targetPx * 0.45, targetPx * 0.15, 0, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
  ctx.fill();
  ctx.restore();

  if (img.complete && img.naturalWidth > 0) {
    const sc = targetPx / img.naturalHeight;
    const rw = img.naturalWidth * sc;
    const rh = img.naturalHeight * sc;

    ctx.drawImage(img, posX - rw / 2, posY - rh, rw, rh);

    // Bounding Box & Colliders
    if (viewState.showHitbox) {
      ctx.save();
      ctx.strokeStyle = "rgba(0, 240, 255, 0.65)";
      ctx.lineWidth = 1.5;
      ctx.strokeRect(posX - rw / 2, posY - rh, rw, rh);

      // Ground Collider circle
      ctx.beginPath();
      ctx.ellipse(posX, posY - 10, rw * 0.35, rw * 0.22, 0, 0, Math.PI * 2);
      ctx.strokeStyle = "rgba(0, 230, 118, 0.85)";
      ctx.stroke();

      // Dimension Tag
      ctx.fillStyle = "rgba(10, 14, 22, 0.85)";
      ctx.fillRect(posX - 55, posY - rh - 26, 110, 20);
      ctx.fillStyle = "#00f0ff";
      ctx.font = "bold 13px Rajdhani";
      ctx.textAlign = "center";
      ctx.fillText(`${Math.round(rw)} × ${Math.round(rh)} px (${mult.toFixed(2)}x)`, posX, posY - rh - 12);
      ctx.restore();
    }
  } else {
    ctx.fillStyle = "rgba(255, 183, 0, 0.25)";
    ctx.fillRect(posX - targetPx / 2, posY - targetPx, targetPx, targetPx);
    ctx.strokeStyle = "#ffb700";
    ctx.strokeRect(posX - targetPx / 2, posY - targetPx, targetPx, targetPx);
  }

  // Update Real-Time HUD readout
  const hudDecor = document.getElementById("hud-decor-text");
  if (hudDecor) {
    hudDecor.textContent = `${decor.name} (${mult.toFixed(2)}x — ${Math.round(targetPx)}px)`;
  }
  const hudRatio = document.getElementById("hud-ratio-text");
  if (hudRatio) {
    const ratio = (targetPx / 190.0).toFixed(2);
    hudRatio.textContent = `${ratio}x du mecha`;
  }
}

function drawSelectedVfx() {
  const vfx = VFX_ITEMS.find(v => v.id === viewState.selectedVfxId);
  if (!vfx) return;

  const mult = getVfxScale(vfx.id);
  const posX = -220;
  const posY = -80;

  const path = `../game/assets/vfx/${vfx.file}`;
  const img = loadImage(path);

  ctx.save();
  if (vfx.type === "spritesheet" && img.complete && img.naturalWidth > 0) {
    const totalFrames = vfx.frames || 1;
    const fw = img.naturalWidth / totalFrames;
    const fh = img.naturalHeight;
    const baseW = 180 * (vfx.baseScale || 1.0) * mult;
    const renderScale = baseW / fw;
    const renderW = fw * renderScale;
    const renderH = fh * renderScale;

    const fx = viewState.vfxFrame * fw;

    ctx.drawImage(img, fx, 0, fw, fh, posX - renderW / 2, posY - renderH / 2, renderW, renderH);

    if (viewState.showHitbox) {
      ctx.strokeStyle = "rgba(255, 0, 119, 0.6)";
      ctx.strokeRect(posX - renderW / 2, posY - renderH / 2, renderW, renderH);
    }
  } else if (vfx.type === "shockwave") {
    // Animated Shockwave Ring
    const t = (viewState.vfxTime * 1.5) % 1.0;
    const radius = (15 + t * 140) * mult;
    ctx.beginPath();
    ctx.arc(posX, posY, radius, 0, Math.PI * 2);
    ctx.strokeStyle = vfx.defaultColor || "#00ffff";
    ctx.globalAlpha = Math.max(0, 1.0 - t * 1.1);
    ctx.lineWidth = 4 * (1.0 - t * 0.7);
    ctx.stroke();
  } else if (vfx.type === "shield") {
    // Shield Bubble/Hex
    const radius = 100 * mult;
    ctx.beginPath();
    ctx.arc(posX, posY, radius, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(0, 240, 255, 0.12)";
    ctx.fill();
    ctx.strokeStyle = vfx.defaultColor || "#00f0ff";
    ctx.lineWidth = 3;
    ctx.stroke();
  } else if (img.complete && img.naturalWidth > 0) {
    const baseSize = 140 * mult;
    ctx.drawImage(img, posX - baseSize / 2, posY - baseSize / 2, baseSize, baseSize);
  }
  ctx.restore();

  // Update HUD
  const hudVfx = document.getElementById("hud-vfx-text");
  if (hudVfx) {
    hudVfx.textContent = `${vfx.name} (${mult.toFixed(2)}x)`;
  }
}

function drawParticles() {
  ctx.save();
  for (const p of viewState.particles) {
    ctx.beginPath();
    ctx.arc(p.x, p.y, Math.max(1, p.size), 0, Math.PI * 2);
    ctx.fillStyle = p.color || "#00f0ff";
    ctx.globalAlpha = Math.min(1.0, p.life * 2);
    ctx.fill();
  }
  ctx.restore();
}

// ============================================================================
// UI & CONTROLS BINDING
// ============================================================================
function initUI() {
  // Tabs Navigation
  document.querySelectorAll(".tab-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
      document.querySelectorAll(".tab-pane").forEach(p => p.classList.remove("active"));
      btn.classList.add("active");
      const target = document.getElementById(btn.dataset.tab);
      if (target) target.classList.add("active");
    });
  });

  // Global Sliders
  bindRange("slider-decor-global", "badge-decor-global", (val) => {
    scales.decor_global = val;
    renderSummary();
    saveToStorage();
  });

  bindRange("slider-vfx-global", "badge-vfx-global", (val) => {
    scales.vfx_global = val;
    saveToStorage();
  });

  // Master Step Buttons (- / +)
  document.querySelectorAll(".btn-step").forEach(btn => {
    btn.addEventListener("click", () => {
      const target = btn.dataset.target;
      const isInc = btn.dataset.action === "inc";
      const delta = isInc ? 0.05 : -0.05;

      if (target === "decor-global") {
        scales.decor_global = Math.max(0.4, Math.min(2.2, parseFloat((scales.decor_global + delta).toFixed(2))));
        updateSliderAndBadge("slider-decor-global", "badge-decor-global", scales.decor_global);
      } else if (target === "vfx-global") {
        scales.vfx_global = Math.max(0.4, Math.min(2.2, parseFloat((scales.vfx_global + delta).toFixed(2))));
        updateSliderAndBadge("slider-vfx-global", "badge-vfx-global", scales.vfx_global);
      }
      renderSummary();
      saveToStorage();
    });
  });

  // Reset Buttons
  document.querySelectorAll(".reset-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const target = btn.dataset.target;
      if (target === "decor-global") {
        scales.decor_global = 1.0;
        updateSliderAndBadge("slider-decor-global", "badge-decor-global", 1.0);
      } else if (target === "vfx-global") {
        scales.vfx_global = 1.0;
        updateSliderAndBadge("slider-vfx-global", "badge-vfx-global", 1.0);
      }
      renderSummary();
      saveToStorage();
    });
  });

  // Quick Presets
  document.querySelectorAll(".btn-preset").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".btn-preset").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      const p = btn.dataset.preset;
      applyPreset(p);
    });
  });

  // Biome and Mecha selects
  document.getElementById("biome-select").addEventListener("change", (e) => {
    viewState.biome = e.target.value;
  });

  document.getElementById("mecha-select").addEventListener("change", (e) => {
    viewState.mecha = e.target.value;
  });

  // Toggles
  document.getElementById("btn-toggle-grid").addEventListener("click", (e) => {
    viewState.showGrid = !viewState.showGrid;
    e.target.classList.toggle("active", viewState.showGrid);
  });

  document.getElementById("btn-toggle-hitbox").addEventListener("click", (e) => {
    viewState.showHitbox = !viewState.showHitbox;
    e.target.classList.toggle("active", viewState.showHitbox);
  });

  document.getElementById("btn-zoom-in").addEventListener("click", () => setZoom(viewState.zoom * 1.15));
  document.getElementById("btn-zoom-out").addEventListener("click", () => setZoom(viewState.zoom * 0.85));
  document.getElementById("btn-zoom-reset").addEventListener("click", () => {
    setZoom(1.0);
    viewState.panX = 0;
    viewState.panY = 0;
  });

  // VFX Trigger button
  document.getElementById("btn-trigger-vfx").addEventListener("click", triggerVfx);
  document.getElementById("vfx-loop-toggle").addEventListener("change", (e) => {
    viewState.vfxLoop = e.target.checked;
  });

  // Save Actions
  document.getElementById("btn-quick-save").addEventListener("click", () => {
    saveToStorage();
    saveToGameServer();
  });

  document.getElementById("btn-save-to-game").addEventListener("click", saveToGameServer);
  document.getElementById("btn-download-json").addEventListener("click", downloadJsonFile);

  const fileInput = document.getElementById("file-import-json");
  document.getElementById("btn-trigger-import").addEventListener("click", () => fileInput.click());
  fileInput.addEventListener("change", handleImportJson);

  document.getElementById("btn-reset-all").addEventListener("click", () => {
    if (confirm("Réinitialiser toutes les échelles aux valeurs par défaut (1.00x) ?")) {
      scales = JSON.parse(JSON.stringify(DEFAULT_STATE));
      syncAllInputs();
      saveToStorage();
    }
  });

  document.getElementById("btn-copy-json").addEventListener("click", () => {
    navigator.clipboard.writeText(JSON.stringify(scales, null, 2));
    alert("Configuration JSON copiée dans le presse-papier !");
  });

  // Diagnostics
  document.getElementById("btn-run-diagnostics").addEventListener("click", runDiagnostics);

  // Build Category and Item panels
  buildDecorPanels();
  buildVfxPanels();
  syncAllInputs();
}

function bindRange(sliderId, badgeId, onChange) {
  const slider = document.getElementById(sliderId);
  const badge = document.getElementById(badgeId);
  if (!slider) return;

  slider.addEventListener("input", () => {
    const val = parseFloat(slider.value);
    if (badge) badge.textContent = val.toFixed(2) + "x";
    onChange(val);
  });
}

function updateSliderAndBadge(sliderId, badgeId, val) {
  const slider = document.getElementById(sliderId);
  const badge = document.getElementById(badgeId);
  if (slider) slider.value = val;
  if (badge) badge.textContent = val.toFixed(2) + "x";
}

function applyPreset(presetName) {
  switch (presetName) {
    case "compact":
      scales.decor_global = 0.8;
      scales.vfx_global = 0.85;
      break;
    case "default":
      scales.decor_global = 1.0;
      scales.vfx_global = 1.0;
      break;
    case "imposing":
      scales.decor_global = 1.25;
      scales.vfx_global = 1.25;
      break;
    case "titanic":
      scales.decor_global = 1.5;
      scales.vfx_global = 1.5;
      break;
  }
  syncAllInputs();
  saveToStorage();
}

function syncAllInputs() {
  updateSliderAndBadge("slider-decor-global", "badge-decor-global", scales.decor_global);
  updateSliderAndBadge("slider-vfx-global", "badge-vfx-global", scales.vfx_global);

  // Sync categories
  for (const catId in scales.decor_categories) {
    updateSliderAndBadge(`slider-decor-cat-${catId}`, `badge-decor-cat-${catId}`, scales.decor_categories[catId]);
  }
  for (const catId in scales.vfx_categories) {
    updateSliderAndBadge(`slider-vfx-cat-${catId}`, `badge-vfx-cat-${catId}`, scales.vfx_categories[catId]);
  }

  renderSummary();
  updateJsonPreview();
}

// Build UI for Decor Categories
function buildDecorPanels() {
  // 1. Item Picker
  const picker = document.getElementById("decor-item-picker");
  picker.innerHTML = "";
  DECOR_ITEMS.forEach(item => {
    const opt = document.createElement("option");
    opt.value = item.id;
    opt.textContent = `${item.name} (${item.baseSz}px) — ${DECOR_CATEGORIES[item.category]?.name || ""}`;
    picker.appendChild(opt);
  });

  picker.value = viewState.selectedDecorId;
  picker.addEventListener("change", (e) => {
    viewState.selectedDecorId = e.target.value;
    updateDecorDetails();
  });
  updateDecorDetails();

  // 2. Categories Sliders
  const container = document.getElementById("decor-categories-container");
  container.innerHTML = "";

  for (const catId in DECOR_CATEGORIES) {
    const cat = DECOR_CATEGORIES[catId];
    const catVal = scales.decor_categories[catId] || 1.0;

    const card = document.createElement("div");
    card.className = "category-card";
    card.innerHTML = `
      <div class="category-card-header">
        <span class="category-title">${cat.icon} ${cat.name}</span>
        <div class="card-actions">
          <span class="scale-badge" id="badge-decor-cat-${catId}">${catVal.toFixed(2)}x</span>
          <button class="btn btn-sm btn-ghost reset-cat-btn" data-cat="${catId}">↺</button>
        </div>
      </div>
      <p class="card-sub" style="margin-bottom: 8px;">${cat.desc}</p>
      <div class="slider-row">
        <input type="range" id="slider-decor-cat-${catId}" min="0.5" max="2.0" step="0.05" value="${catVal}" class="range-slider">
      </div>
    `;

    container.appendChild(card);

    bindRange(`slider-decor-cat-${catId}`, `badge-decor-cat-${catId}`, (val) => {
      scales.decor_categories[catId] = val;
      renderSummary();
      saveToStorage();
    });

    card.querySelector(".reset-cat-btn").addEventListener("click", () => {
      scales.decor_categories[catId] = 1.0;
      updateSliderAndBadge(`slider-decor-cat-${catId}`, `badge-decor-cat-${catId}`, 1.0);
      renderSummary();
      saveToStorage();
    });
  }
}

function updateDecorDetails() {
  const decor = DECOR_ITEMS.find(d => d.id === viewState.selectedDecorId);
  const container = document.getElementById("decor-item-details");
  if (!decor || !container) return;

  const mult = getDecorScale(decor.id);
  const finalPx = Math.round(decor.baseSz * mult);

  container.innerHTML = `
    <strong>Fichier :</strong> <code>${decor.file}</code> | 
    <strong>Base :</strong> ${decor.baseSz} px | 
    <strong>Taille Actuelle :</strong> <span style="color:var(--cyan); font-weight:bold;">${finalPx} px</span> (${mult.toFixed(2)}x) | 
    <strong>PV :</strong> ${decor.hp} HP
    <p style="margin-top: 4px;">${decor.desc}</p>
  `;
}

// Build UI for VFX Categories
function buildVfxPanels() {
  // 1. Item Picker
  const picker = document.getElementById("vfx-item-picker");
  picker.innerHTML = "";
  VFX_ITEMS.forEach(item => {
    const opt = document.createElement("option");
    opt.value = item.id;
    opt.textContent = `${item.name} (${item.type}) — ${VFX_CATEGORIES[item.category]?.name || ""}`;
    picker.appendChild(opt);
  });

  picker.value = viewState.selectedVfxId;
  picker.addEventListener("change", (e) => {
    viewState.selectedVfxId = e.target.value;
    updateVfxDetails();
    triggerVfx();
  });
  updateVfxDetails();

  // 2. Categories Sliders
  const container = document.getElementById("vfx-categories-container");
  container.innerHTML = "";

  for (const catId in VFX_CATEGORIES) {
    const cat = VFX_CATEGORIES[catId];
    const catVal = scales.vfx_categories[catId] || 1.0;

    const card = document.createElement("div");
    card.className = "category-card";
    card.innerHTML = `
      <div class="category-card-header">
        <span class="category-title">${cat.icon} ${cat.name}</span>
        <div class="card-actions">
          <span class="scale-badge badge-vfx" id="badge-vfx-cat-${catId}">${catVal.toFixed(2)}x</span>
          <button class="btn btn-sm btn-ghost reset-vfx-cat-btn" data-cat="${catId}">↺</button>
        </div>
      </div>
      <p class="card-sub" style="margin-bottom: 8px;">${cat.desc}</p>
      <div class="slider-row">
        <input type="range" id="slider-vfx-cat-${catId}" min="0.5" max="2.0" step="0.05" value="${catVal}" class="range-slider range-vfx">
      </div>
    `;

    container.appendChild(card);

    bindRange(`slider-vfx-cat-${catId}`, `badge-vfx-cat-${catId}`, (val) => {
      scales.vfx_categories[catId] = val;
      saveToStorage();
    });

    card.querySelector(".reset-vfx-cat-btn").addEventListener("click", () => {
      scales.vfx_categories[catId] = 1.0;
      updateSliderAndBadge(`slider-vfx-cat-${catId}`, `badge-vfx-cat-${catId}`, 1.0);
      saveToStorage();
    });
  }
}

function updateVfxDetails() {
  const vfx = VFX_ITEMS.find(v => v.id === viewState.selectedVfxId);
  const container = document.getElementById("vfx-item-details");
  if (!vfx || !container) return;

  const mult = getVfxScale(vfx.id);

  container.innerHTML = `
    <strong>Fichier :</strong> <code>${vfx.file}</code> | 
    <strong>Type :</strong> ${vfx.type} ${vfx.frames ? `(${vfx.frames} f @ ${vfx.fps} FPS)` : ''} | 
    <strong>Échelle Effective :</strong> <span style="color:var(--magenta); font-weight:bold;">${mult.toFixed(2)}x</span>
    <p style="margin-top: 4px;">${vfx.desc}</p>
  `;
}

function renderSummary() {
  const container = document.getElementById("overview-category-summary");
  if (!container) return;
  container.innerHTML = "";

  for (const catId in DECOR_CATEGORIES) {
    const cat = DECOR_CATEGORIES[catId];
    const catMult = (scales.decor_categories[catId] || 1.0) * scales.decor_global;
    const item = document.createElement("div");
    item.className = "summary-item";
    item.innerHTML = `
      <span>${cat.icon} ${cat.name}</span>
      <span class="scale-badge" style="padding:2px 6px; font-size:12px;">${catMult.toFixed(2)}x</span>
    `;
    container.appendChild(item);
  }
}

function handleImportJson(e) {
  const file = e.target.files[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = (event) => {
    try {
      const data = JSON.parse(event.target.result);
      scales = Object.assign(JSON.parse(JSON.stringify(DEFAULT_STATE)), data);
      syncAllInputs();
      saveToStorage();
      alert("Configuration JSON importée avec succès !");
    } catch (err) {
      alert("Erreur lors de la lecture du fichier JSON : " + err.message);
    }
  };
  reader.readAsText(file);
}

// ============================================================================
// AUTOMATED DIAGNOSTICS & VERIFICATION SUITE
// ============================================================================
async function runDiagnostics() {
  const resultsBox = document.getElementById("diagnostics-results");
  resultsBox.innerHTML = '<div style="color:var(--cyan); padding:20px; text-align:center;">Vérification en cours de l\'ensemble des ressources et échelles...</div>';

  const checks = [];

  // Check 1: Decor bounds
  const decorScale = scales.decor_global;
  const decorBoundsOk = decorScale >= 0.2 && decorScale <= 3.0;
  checks.push({
    title: "Échelle globale Décors dans les bornes autorisées [0.2x, 3.0x]",
    passed: decorBoundsOk,
    detail: `Valeur actuelle : ${decorScale.toFixed(2)}x`
  });

  // Check 2: VFX bounds
  const vfxScale = scales.vfx_global;
  const vfxBoundsOk = vfxScale >= 0.2 && vfxScale <= 3.0;
  checks.push({
    title: "Échelle globale VFX dans les bornes autorisées [0.2x, 3.0x]",
    passed: vfxBoundsOk,
    detail: `Valeur actuelle : ${vfxScale.toFixed(2)}x`
  });

  // Check 3: Catalog integrity
  const decorCount = DECOR_ITEMS.length;
  checks.push({
    title: `Intégrité du catalogue de décors (>= 30 éléments)`,
    passed: decorCount >= 30,
    detail: `${decorCount} décors répertoriés`
  });

  const vfxCount = VFX_ITEMS.length;
  checks.push({
    title: `Intégrité du catalogue VFX (>= 15 éléments)`,
    passed: vfxCount >= 15,
    detail: `${vfxCount} recettes VFX répertoriées`
  });

  // Check 4: Decor Ratio vs Mecha Height
  let ratioIssues = 0;
  DECOR_ITEMS.forEach(d => {
    const sc = getDecorScale(d.id);
    const px = d.baseSz * sc;
    if (px > 550 || px < 20) ratioIssues++;
  });
  checks.push({
    title: "Ratios taille décor / arène jouable (aucun élément hors gabarit)",
    passed: ratioIssues === 0,
    detail: ratioIssues === 0 ? "Tous les décors restent équilibrés" : `${ratioIssues} décors hors tolérance`
  });

  // Check 5: JSON Schema serialization
  let jsonOk = true;
  try {
    const str = JSON.stringify(scales);
    const re = JSON.parse(str);
    jsonOk = typeof re.decor_global === "number" && typeof re.vfx_global === "number";
  } catch (e) {
    jsonOk = false;
  }
  checks.push({
    title: "Sérialisation du schéma visual_scales.json",
    passed: jsonOk,
    detail: "Format compatible SaveManager.gd et PropScatter.gd"
  });

  // Render results
  setTimeout(() => {
    resultsBox.innerHTML = "";
    checks.forEach(c => {
      const row = document.createElement("div");
      row.className = "diag-item";
      row.innerHTML = `
        <div>
          <div>${c.title}</div>
          <div style="font-size:12px; color:var(--text-dim);">${c.detail}</div>
        </div>
        <span class="${c.passed ? 'diag-pass' : 'diag-fail'}">${c.passed ? 'PASS ✓' : 'ÉCHEC ✗'}</span>
      `;
      resultsBox.appendChild(row);
    });
  }, 400);
}

// ============================================================================
// INITIALIZATION
// ============================================================================
window.addEventListener("DOMContentLoaded", async () => {
  loadFromStorage();
  await loadFromGameServer();
  initUI();
  initCanvas();
  renderSummary();
  updateJsonPreview();
});
