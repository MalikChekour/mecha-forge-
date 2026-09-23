#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont

ASSET_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\mecha"
OUT_ROOT = r"C:\Users\Administrator\mecha-forge\sprites_catalog.png"
OUT_PREVIEW = r"C:\Users\Administrator\mecha-forge\meshy_in\previews\darkstar_catalog.png"
CHASSIS = "darkstar"

ANIMS = ["idle", "walk", "run", "attack", "hit", "die", "melee"]
DIRS = ["front", "back", "left", "right"]
FRAME_W = 256
FRAME_H = 256

PADDING = 40
HEADER_H = 60

img_w = len(DIRS) * FRAME_W + PADDING * 2
img_h = len(ANIMS) * FRAME_H + HEADER_H + PADDING * 2

catalog = Image.new("RGBA", (img_w, img_h), (30, 32, 40, 255))
draw = ImageDraw.Draw(catalog)

try:
    font = ImageFont.truetype("arial.ttf", 24)
except:
    font = ImageFont.load_default()

draw.text((PADDING, PADDING // 2), f"CATALOGUE DES SPRITES : {CHASSIS.upper()} (Fill Height Test)", fill=(200, 220, 255, 255), font=font)

for x, d in enumerate(DIRS):
    draw.text((PADDING + x * FRAME_W + FRAME_W//2 - 20, PADDING + 20), d.upper(), fill=(150, 150, 150, 255), font=font)

y_offset = PADDING + HEADER_H
for anim in ANIMS:
    draw.text((PADDING - 30, y_offset + FRAME_H//2 - 10), anim.upper(), fill=(255, 200, 100, 255), font=font)
    
    for x, d in enumerate(DIRS):
        filepath = os.path.join(ASSET_DIR, f"{CHASSIS}_{anim}_{d}.png")
        if os.path.exists(filepath):
            sheet = Image.open(filepath).convert("RGBA")
            frame = sheet.crop((0, 0, FRAME_W, FRAME_H))
            bbox = frame.getbbox()
            h = bbox[3] - bbox[1] if bbox else 0
            pct = (h / float(FRAME_H)) * 100.0
            
            catalog.paste(frame, (PADDING + x * FRAME_W, y_offset), frame)
            # Annotate bbox height & % filling
            draw.text((PADDING + x * FRAME_W + 5, y_offset + 5), f"{h}px ({pct:.0f}%)", fill=(0, 255, 180, 255), font=font)
        else:
            draw.rectangle([PADDING + x * FRAME_W, y_offset, PADDING + (x+1)*FRAME_W, y_offset+FRAME_H], outline=(255,0,0,255))
            
    y_offset += FRAME_H

catalog.save(OUT_ROOT)
catalog.save(OUT_PREVIEW)
print(f"Catalog saved to {OUT_ROOT} and {OUT_PREVIEW}")
