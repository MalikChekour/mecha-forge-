#!/usr/bin/env python3
"""
Process Spriterrific-style pixel art sprite sheet:
- Chroma key green background removal
- Nearest-neighbor pixelation filtering to ensure 100% crisp pixel art edges
- Save transparent PNGs for artifacts and project root
"""
import os
from PIL import Image

RAW_PATH = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\spriterrific_pixelart_mecha_1784822595737.jpg"
OUT_ARTIFACT = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\spriterrific_pixelart.png"
OUT_PROJECT = r"C:\Users\Administrator\mecha-forge\spriterrific_mecha.png"

def remove_background(im):
    im = im.convert("RGBA")
    datas = im.getdata()
    newData = []
    for item in datas:
        r, g, b, a = item
        if g > 130 and (g - max(r, b)) > 25:
            newData.append((0, 0, 0, 0))
        elif g > 160 and r < 140 and b < 140:
            newData.append((0, 0, 0, 0))
        else:
            newData.append(item)
    im.putdata(newData)
    return im

def main():
    if not os.path.exists(RAW_PATH):
        print("Raw image missing:", RAW_PATH)
        return
    
    raw = Image.open(RAW_PATH)
    clean = remove_background(raw)
    
    # Downscale and upscale with NEAREST filter to guarantee crisp pixel art grid!
    w, h = clean.size
    small = clean.resize((w // 4, h // 4), Image.Resampling.NEAREST)
    pixelated = small.resize((w, h), Image.Resampling.NEAREST)
    
    pixelated.save(OUT_ARTIFACT)
    pixelated.save(OUT_PROJECT)
    print(f"Saved Spriterrific-style pixel art to {OUT_ARTIFACT} and {OUT_PROJECT}")

if __name__ == "__main__":
    main()
