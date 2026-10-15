# -*- coding: utf-8 -*-
"""Bible des Niveaux Pipeline: parse, generate, transparent-cutout, and integrate
assets and mechanics for MECHA-FORGE 9 biomes.
"""
import os
import sys
import re
import json
import urllib.request
import urllib.error
from PIL import Image, ImageFilter
import numpy as np

BIBLE_PATH = r"C:\Users\Administrator\Desktop\Bible_niveaux_prompts.md"
DECOR_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\decor"
VFX_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\vfx"
RAW_GEN_DIR = r"C:\Users\Administrator\mecha-forge\tools\bible_raw_gen"

os.makedirs(DECOR_DIR, exist_ok=True)
os.makedirs(VFX_DIR, exist_ok=True)
os.makedirs(RAW_GEN_DIR, exist_ok=True)

FAL_KEY = os.environ.get("FAL_KEY")
FAL_ENDPOINTS = ["fal-ai/flux-pro/v1.1-ultra", "fal-ai/flux/dev"]

def parse_bible():
    with open(BIBLE_PATH, "r", encoding="utf-8") as f:
        lines = f.readlines()

    levels = []
    curr_lvl = None
    curr_item = None
    i = 0
    while i < len(lines):
        line = lines[i]
        m_lvl = re.match(r'^##\s+Niveau\s+(\d+)\s+[—\-]\s+(.*)', line.strip())
        if m_lvl:
            curr_lvl = {
                "num": int(m_lvl.group(1)),
                "name": m_lvl.group(2).strip(),
                "items": []
            }
            levels.append(curr_lvl)
            curr_item = None
            i += 1
            continue

        m_item = re.match(r'^###\s+(.*?)\s+[—\-]\s+`([^`]+)`\s+\((.*?)\)', line.strip())
        if m_item and curr_lvl:
            curr_item = {
                "title": m_item.group(1).strip(),
                "file": m_item.group(2).strip(),
                "category": m_item.group(3).strip(),
                "game": "",
                "vfx": "",
                "code": "",
                "prompt": ""
            }
            curr_lvl["items"].append(curr_item)
            i += 1
            continue

        if curr_item:
            if line.strip().startswith("- **Jeu**"):
                curr_item["game"] = line.strip().split(":", 1)[-1].strip()
            elif line.strip().startswith("- **Effet visuel**"):
                curr_item["vfx"] = line.strip().split(":", 1)[-1].strip()
            elif line.strip().startswith("- **Code**"):
                curr_item["code"] = line.strip().split(":", 1)[-1].strip()
            elif line.strip().startswith("```"):
                p_lines = []
                i += 1
                while i < len(lines) and not lines[i].strip().startswith("```"):
                    p_lines.append(lines[i].strip())
                    i += 1
                curr_item["prompt"] = " ".join(p_lines).strip()
        i += 1

    return levels

def is_fx_item(item):
    return "FX" in item["category"] or item["file"].endswith("_fx_") or "_fx_" in item["file"]

def get_target_path(item):
    if is_fx_item(item):
        return os.path.join(VFX_DIR, item["file"])
    return os.path.join(DECOR_DIR, item["file"])

CF_ACCOUNT_ID = os.environ.get("CF_ACCOUNT_ID")
CF_API_TOKEN = os.environ.get("CF_API_TOKEN")

def sanitize_prompt_for_cf(prompt: str) -> str:
    replacements = {
        r"\bfleshy\b": "organic",
        r"\bflesh\b": "alien tissue",
        r"\bskin\b": "membrane",
        r"\bmaw\b": "aperture",
        r"\bbladder\b": "sac",
    }
    p = prompt
    for pattern, repl in replacements.items():
        p = re.sub(pattern, repl, p, flags=re.IGNORECASE)
    return p

def generate_cloudflare_flux(prompt, out_path):
    if not (CF_ACCOUNT_ID and CF_API_TOKEN):
        return False
    cf_prompt = sanitize_prompt_for_cf(prompt)
    url = f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT_ID}/ai/run/@cf/black-forest-labs/flux-1-schnell"
    req = urllib.request.Request(
        url,
        data=json.dumps({"prompt": cf_prompt, "steps": 4}).encode("utf-8"),
        headers={"Authorization": f"Bearer {CF_API_TOKEN}", "Content-Type": "application/json"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            d = json.loads(r.read().decode("utf-8"))
            if d.get("success") and "result" in d and "image" in d["result"]:
                import base64
                with open(out_path, "wb") as f:
                    f.write(base64.b64decode(d["result"]["image"]))
                print(f"  [Cloudflare FLUX] -> {out_path}")
                return True
            else:
                print(f"  [Cloudflare FLUX] failed: {d.get('errors')}")
    except Exception as e:
        print(f"  [Cloudflare FLUX error]: {e}")
    return False

def fal_post(url, payload, timeout=180):
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": f"Key {FAL_KEY}"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))

def fal_download(url, out_path):
    with urllib.request.urlopen(url, timeout=120) as r:
        data = r.read()
    with open(out_path, "wb") as f:
        f.write(data)

def generate_item_raw(prompt, out_path, is_fx=False):
    # Try FAL first if key is present
    if FAL_KEY:
        for ep in FAL_ENDPOINTS:
            try:
                body = {
                    "prompt": prompt,
                    "num_images": 1,
                    "enable_safety_checker": False
                }
                if "ultra" in ep:
                    body["aspect_ratio"] = "1:1"
                else:
                    body["image_size"] = "square_hd"
                
                d = fal_post(f"https://fal.run/{ep}", body)
                url = d["images"][0]["url"]
                fal_download(url, out_path)
                return True
            except Exception as e:
                # print concise error
                pass
    
    # Cloudflare FLUX fallback
    if generate_cloudflare_flux(prompt, out_path):
        return True
        
    return False

def process_item_image(raw_path, final_path, is_fx=False):
    im = Image.open(raw_path)
    if is_fx:
        # FX is on solid black background for additive blending
        # Ensure it is RGB, 1024x1024
        im = im.convert("RGB")
        im.save(final_path, "PNG")
        print(f"  [FX saved directly] -> {final_path}")
        return True
    else:
        # Prop on white background -> remove background with rembg
        from rembg import remove
        transparent = remove(im)
        
        # Trim transparent margins with a modest border
        bbox = transparent.getbbox()
        if bbox:
            w, h = transparent.size
            x0, y0, x1, y1 = bbox
            pad = 16
            crop_box = (max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad))
            transparent = transparent.crop(crop_box)
        
        transparent.save(final_path, "PNG")
        print(f"  [Prop transparent cutout saved] -> {final_path} (size {transparent.size})")
        return True

def cmd_list():
    levels = parse_bible()
    print(f"=== BIBLE DES NIVEAUX ({len(levels)} NIVEAUX) ===")
    total = 0
    ready = 0
    for lvl in levels:
        lvl_ready = 0
        for it in lvl["items"]:
            target = get_target_path(it)
            if os.path.exists(target):
                lvl_ready += 1
        print(f"\nNiveau {lvl['num']}: {lvl['name']} ({lvl_ready}/{len(lvl['items'])} prets)")
        for it in lvl["items"]:
            target = get_target_path(it)
            status = "[OK]" if os.path.exists(target) else "[TODO]"
            print(f"  {status} {it['title']} -> {it['file']} ({it['category']})")
        total += len(lvl["items"])
        ready += lvl_ready
    print(f"\nTOTAL: {ready}/{total} assets generes.")

def cmd_generate(target_level=None):
    levels = parse_bible()
    for lvl in levels:
        if target_level is not None and lvl["num"] != target_level:
            continue
        print(f"\n==========================================")
        print(f"GENERATION NIVEAU {lvl['num']}: {lvl['name']}")
        print(f"==========================================")
        for it in lvl["items"]:
            final_p = get_target_path(it)
            raw_p = os.path.join(RAW_GEN_DIR, it["file"])
            is_fx = is_fx_item(it)
            
            if os.path.exists(final_p):
                print(f"  [SKIP DEJA EXISTANT] {it['file']}")
                continue
                
            print(f"\n-> Generating {it['title']} ({it['file']})...")
            if not os.path.exists(raw_p):
                ok = generate_item_raw(it["prompt"], raw_p, is_fx=is_fx)
                if not ok:
                    print(f"  [FAILED FAL GENERATION] {it['file']}")
                    continue
            
            print(f"  Processing transparency / cutout...")
            try:
                process_item_image(raw_p, final_p, is_fx=is_fx)
            except Exception as e:
                print(f"  [FAILED PROCESSING] {it['file']}: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "list":
        cmd_list()
    elif len(sys.argv) > 1 and sys.argv[1] == "gen":
        target = int(sys.argv[2]) if len(sys.argv) > 2 else None
        cmd_generate(target)
    else:
        print("Usage: python bible_pipeline.py [list | gen <level_num>]")
