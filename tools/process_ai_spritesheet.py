#!/usr/bin/env python3
"""
Process AI generated mecha sprite sheet:
1. Load 1024x1024 AI image.
2. Remove green background (chroma keying) -> RGBA transparent.
3. Save clean transparent PNG asset and catalog preview.
"""
import os
from PIL import Image, ImageDraw

IMG_PATH = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\darkstar_ai_spritesheet_1784820929076.jpg"
OUT_TRANSPARENT = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\ai_mecha_transparent.png"
OUT_PROJECT = r"C:\Users\Administrator\mecha-forge\ai_mecha_catalog.png"

def remove_background(im):
    im = im.convert("RGBA")
    datas = im.getdata()
    newData = []
    for item in datas:
        # Check green dominance for chroma keying
        r, g, b, a = item
        # Lime green background check: G is high, R and B lower
        if g > 150 and r < 140 and b < 140:
            newData.append((0, 0, 0, 0))
        elif g > 180 and (g - max(r, b)) > 40:
            newData.append((0, 0, 0, 0))
        else:
            newData.append(item)
    im.putdata(newData)
    return im

def main():
    if not os.path.exists(IMG_PATH):
        print("Image not found:", IMG_PATH)
        return
    
    raw = Image.open(IMG_PATH)
    clean = remove_background(raw)
    clean.save(OUT_TRANSPARENT)
    clean.save(OUT_PROJECT)
    print(f"Processed transparent AI sprite sheet saved to {OUT_TRANSPARENT}")

if __name__ == "__main__":
    main()
