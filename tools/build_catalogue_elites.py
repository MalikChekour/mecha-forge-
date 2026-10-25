#!/usr/bin/env python3
"""
Générateur du catalogue HTML premium des 18 Méchas Supérieurs Gundam (Élites)
"""
import os, sys, html
from generate_meshy_elites import ELITE_MECHAS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PATH = os.path.join(ROOT, "catalogue_mechas.html")

COLOR_MAP = {
    1: "#eab308", 2: "#d97706", 3: "#10b981", 4: "#ef4444", 5: "#84cc16",
    6: "#06b6d4", 7: "#22c55e", 8: "#a855f7", 9: "#f59e0b", 10: "#0ea5e9",
    11: "#d946ef", 12: "#f97316", 13: "#38bdf8", 14: "#8b5cf6", 15: "#eab308",
    16: "#ec4899", 17: "#b45309", 18: "#dc2626"
}

HTML_HEADER = """<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MECHA-FORGE — 18 Méchas Supérieurs Gundam (Dual-Arms, Cockpit, Effets Spéciaux & Rig)</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@400;600;700&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<style>
  :root {
    --bg-dark: #080b11;
    --card-bg: rgba(15, 21, 34, 0.9);
    --card-border: rgba(255, 255, 255, 0.08);
    --text-main: #f8fafc;
    --text-muted: #94a3b8;
    --neon-cyan: #06b6d4;
    --neon-gold: #f59e0b;
    --neon-crimson: #ef4444;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background-color: var(--bg-dark);
    background-image: 
      radial-gradient(circle at 10% 10%, rgba(6, 182, 212, 0.08) 0%, transparent 40%),
      radial-gradient(circle at 90% 90%, rgba(245, 158, 11, 0.08) 0%, transparent 40%),
      linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px),
      linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px);
    background-size: 100% 100%, 100% 100%, 36px 36px, 36px 36px;
    color: var(--text-main);
    font-family: 'Inter', system-ui, sans-serif;
    padding: 30px 20px 80px;
    min-height: 100vh;
  }
  .container { max-width: 1520px; margin: 0 auto; }
  header {
    text-align: center;
    margin-bottom: 35px;
    padding: 36px 28px;
    background: rgba(15, 23, 42, 0.75);
    border: 1px solid var(--card-border);
    border-radius: 18px;
    backdrop-filter: blur(16px);
    box-shadow: 0 12px 45px rgba(0,0,0,0.6);
  }
  .eyebrow {
    font-family: 'Chakra Petch', sans-serif;
    font-size: 13px;
    letter-spacing: 0.3em;
    color: var(--neon-cyan);
    text-transform: uppercase;
    margin-bottom: 12px;
  }
  h1 {
    font-family: 'Chakra Petch', sans-serif;
    font-size: 38px;
    font-weight: 700;
    background: linear-gradient(135deg, #ffffff 0%, #cbd5e1 50%, #94a3b8 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    margin-bottom: 14px;
  }
  .subtitle {
    font-size: 15.5px;
    color: var(--text-muted);
    max-width: 980px;
    margin: 0 auto 24px;
    line-height: 1.6;
  }
  .specs-bar {
    display: flex;
    justify-content: center;
    gap: 14px;
    flex-wrap: wrap;
    margin-bottom: 24px;
  }
  .spec-badge {
    background: rgba(6, 182, 212, 0.1);
    border: 1px solid rgba(6, 182, 212, 0.3);
    color: var(--neon-cyan);
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 12.5px;
    font-family: 'JetBrains Mono', monospace;
    font-weight: 600;
  }
  .filter-bar {
    display: flex;
    justify-content: center;
    gap: 12px;
    margin-top: 15px;
  }
  .btn-filter {
    font-family: 'Chakra Petch', sans-serif;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.12);
    color: var(--text-main);
    padding: 8px 18px;
    border-radius: 8px;
    cursor: pointer;
    font-size: 13.5px;
    font-weight: 600;
    transition: all 0.2s;
  }
  .btn-filter:hover, .btn-filter.active {
    background: var(--neon-cyan);
    color: #000;
    border-color: var(--neon-cyan);
    box-shadow: 0 0 15px rgba(6, 182, 212, 0.4);
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(420px, 1fr));
    gap: 26px;
  }
  .mecha-card {
    background: var(--card-bg);
    border: 1px solid var(--card-border);
    border-radius: 14px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    transition: transform 0.25s ease, box-shadow 0.25s ease, border-color 0.25s ease;
    backdrop-filter: blur(12px);
  }
  .mecha-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 16px 40px rgba(0, 0, 0, 0.7), 0 0 24px rgba(var(--accent-rgb, 6, 182, 212), 0.25);
    border-color: var(--accent);
  }
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 14px 18px;
    background: rgba(0, 0, 0, 0.35);
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  .ch-tag {
    font-family: 'Chakra Petch', sans-serif;
    font-size: 12px;
    font-weight: 700;
    color: var(--accent);
    letter-spacing: 0.15em;
  }
  .badge-gundam {
    font-size: 11px;
    padding: 3px 10px;
    border-radius: 12px;
    background: rgba(245, 158, 11, 0.15);
    border: 1px solid rgba(245, 158, 11, 0.4);
    color: #fbbf24;
    font-weight: 700;
    font-family: 'JetBrains Mono', monospace;
  }
  .card-body {
    padding: 20px;
    display: flex;
    flex-direction: column;
    flex: 1;
    gap: 14px;
  }
  .mecha-title-wrap {
    margin-bottom: 2px;
  }
  .mecha-code {
    font-family: 'Chakra Petch', sans-serif;
    font-size: 21px;
    font-weight: 700;
    color: #fff;
    margin-bottom: 4px;
  }
  .biome-tag {
    font-size: 12.5px;
    color: var(--text-muted);
    font-weight: 500;
  }
  .box-section {
    background: rgba(0, 0, 0, 0.35);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-left: 3px solid var(--accent);
    padding: 12px 14px;
    border-radius: 6px;
  }
  .box-title {
    font-family: 'Chakra Petch', sans-serif;
    font-size: 13px;
    font-weight: 700;
    color: #fff;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .box-desc {
    font-size: 12px;
    line-height: 1.5;
    color: #cbd5e1;
  }
  .rig-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
    font-size: 11px;
    font-family: 'JetBrains Mono', monospace;
    color: #94a3b8;
    margin-top: 6px;
  }
  .rig-item {
    background: rgba(255, 255, 255, 0.03);
    padding: 4px 8px;
    border-radius: 4px;
  }
  .rig-label {
    color: var(--accent);
    font-weight: 600;
  }
  .prompt-box {
    background: rgba(0, 0, 0, 0.55);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 6px;
    padding: 12px;
    font-size: 11px;
    font-family: 'JetBrains Mono', monospace;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .prompt-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    color: var(--text-muted);
    font-weight: 600;
  }
  .btn-copy {
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: var(--text-main);
    padding: 4px 10px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 11px;
    transition: all 0.2s;
  }
  .btn-copy:hover {
    background: var(--neon-cyan);
    color: #000;
    border-color: var(--neon-cyan);
  }
  .prompt-content {
    color: #94a3b8;
    line-height: 1.45;
    max-height: 75px;
    overflow-y: auto;
    word-break: break-word;
  }
</style>
</head>
<body>
<div class="container">
  <header>
    <div class="eyebrow">MECHA-FORGE /// CLASSIFIED COMBAT ASSETS</div>
    <h1>Catalogue des 18 Méchas Supérieurs Gundam (Élites)</h1>
    <p class="subtitle">Chaque chapitre dispose d'un Mobile Suit d'élite de type Gundam armé pour le double combat : canon lourd à distance (bras droit) et épée de contact / corps-à-corps (bras gauche). Tous intègrent un cockpit pilote central bien visible, deux jambes de marcheur militaire non-humanoïde et un effet spécial caractéristique unique.</p>
    <div class="specs-bar">
      <span class="spec-badge">✓ 18/18 BIOMES COUVERTS</span>
      <span class="spec-badge">✓ DUAL-ARMS : TIR + ÉPÉE</span>
      <span class="spec-badge">✓ COCKPIT PILOTE VISIBLE</span>
      <span class="spec-badge">✓ BIPÈDE GUNDAM (NON-HUMANOÏDE)</span>
      <span class="spec-badge">✓ RIGGING & ANIMATIONS PRÊTS</span>
      <span class="spec-badge">✓ TEXT-TO-3D MESHY COMPATIBLE</span>
    </div>
    <div class="filter-bar">
      <button class="btn-filter active" onclick="filterCards('all', event)">Tous les 18 Méchas</button>
      <button class="btn-filter" onclick="filterCards('campagne', event)">Campagne Principale (Ch 1-9)</button>
      <button class="btn-filter" onclick="filterCards('post', event)">Post-Campagne / Bonus (Ch 10-18)</button>
    </div>
  </header>

  <div class="grid">
"""

HTML_FOOTER = """
  </div>
</div>

<script>
  function filterCards(type, e) {
    document.querySelectorAll('.btn-filter').forEach(btn => btn.classList.remove('active'));
    e.target.classList.add('active');
    const cards = document.querySelectorAll('.mecha-card');
    cards.forEach(card => {
      const ch = parseInt(card.getAttribute('data-chapter'));
      if (type === 'all') {
        card.style.display = 'flex';
      } else if (type === 'campagne') {
        card.style.display = ch <= 9 ? 'flex' : 'none';
      } else if (type === 'post') {
        card.style.display = ch >= 10 ? 'flex' : 'none';
      }
    });
  }

  function copyPrompt(text, btn) {
    navigator.clipboard.writeText(text).then(() => {
      const orig = btn.textContent;
      btn.textContent = '✓ Copié !';
      btn.style.background = '#10b981';
      btn.style.color = '#fff';
      setTimeout(() => {
        btn.textContent = orig;
        btn.style.background = '';
        btn.style.color = '';
      }, 2000);
    }).catch(err => {
      alert('Erreur de copie : ' + err);
    });
  }
</script>
</body>
</html>
"""

def generate_card(num, m):
    col = COLOR_MAP.get(num, "#06b6d4")
    rig = m["rig_profile"]
    escaped_prompt = html.escape(m["meshy_prompt"]).replace("'", "\\'")
    return f"""
    <div class="mecha-card" style="--accent: {col};" data-chapter="{num}">
      <div class="card-header">
        <span class="ch-tag">CHAPITRE {num:02d} — {m['chapter_name'].upper()}</span>
        <span class="badge-gundam">GUNDAM ÉLITE</span>
      </div>
      <div class="card-body">
        <div class="mecha-title-wrap">
          <h2 class="mecha-code">{m['id']} {m['name']}</h2>
          <span class="biome-tag">📍 Biome : {m['biome']}</span>
        </div>

        <div class="box-section">
          <div class="box-title">⚡ EFFET SPÉCIAL CARACTÉRISTIQUE</div>
          <div class="box-desc"><strong>{m['vfx_effect']}</strong> : {m['vfx_desc']}</div>
        </div>

        <div class="box-section">
          <div class="box-title">🦴 SQUELETTE DE RIGGING & ANIMATIONS</div>
          <div class="box-desc">Compatible Auto-Rig Bipède Meshy / Mixamo (Cockpit amorti, Hardpoint d'arme et Socket d'épée).</div>
          <div class="rig-grid">
            <div class="rig-item"><span class="rig-label">Cockpit:</span> {rig['cockpit_bone']}</div>
            <div class="rig-item"><span class="rig-label">Bras D:</span> {rig['weapon_r']}</div>
            <div class="rig-item"><span class="rig-label">Bras G:</span> {rig['weapon_l']}</div>
            <div class="rig-item"><span class="rig-label">Jambes:</span> {rig['legs']}</div>
          </div>
          <div style="font-size: 11px; margin-top: 6px; color: #94a3b8;">
            <span class="rig-label">Pack Anims Cuites:</span> {", ".join(rig['anims'])}
          </div>
        </div>

        <div class="prompt-box">
          <div class="prompt-header">
            <span>PROMPT MESHY TEXT-TO-3D (600 CHARS)</span>
            <button class="btn-copy" onclick="copyPrompt('{escaped_prompt}', this)">Copier Prompt 3D</button>
          </div>
          <div class="prompt-content">{m['meshy_prompt']}</div>
        </div>
      </div>
    </div>
"""

def main():
    cards = []
    for num in range(1, 19):
        m = ELITE_MECHAS[num]
        cards.append(generate_card(num, m))
    
    content = HTML_HEADER + "\n".join(cards) + HTML_FOOTER
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"SUCCESS: Generated {OUT_PATH} with all 18 elite mechas!")

if __name__ == "__main__":
    main()
