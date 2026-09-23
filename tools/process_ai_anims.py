#!/usr/bin/env python3
"""
Process multi-frame AI animation sprite sheets (Walk, Attack):
1. Chroma key green background removal.
2. Save clean transparent PNGs.
"""
import os
from PIL import Image

WALK_PATH = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\darkstar_walk_anim_grid_1784821070836.jpg"
ATTACK_PATH = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\darkstar_attack_anim_grid_1784821082142.jpg"

OUT_WALK = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\ai_walk_transparent.png"
OUT_ATTACK = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\ai_attack_transparent.png"

OUT_PROJ_WALK = r"C:\Users\Administrator\mecha-forge\ai_walk_transparent.png"
OUT_PROJ_ATTACK = r"C:\Users\Administrator\mecha-forge\ai_attack_transparent.png"

def remove_background(im):
    im = im.convert("RGBA")
    datas = im.getdata()
    newData = []
    for item in datas:
        r, g, b, a = item
        if g > 140 and (g - max(r, b)) > 30:
            newData.append((0, 0, 0, 0))
        elif g > 170 and r < 150 and b < 150:
            newData.append((0, 0, 0, 0))
        else:
            newData.append(item)
    im.putdata(newData)
    return im

def main():
    if os.path.exists(WALK_PATH):
        w = remove_background(Image.open(WALK_PATH))
        w.save(OUT_WALK)
        w.save(OUT_PROJ_WALK)
        print("Saved transparent walk anim grid")
        
    if os.path.exists(ATTACK_PATH):
        a = remove_background(Image.open(ATTACK_PATH))
        a.save(OUT_ATTACK)
        a.save(OUT_PROJ_ATTACK)
        print("Saved transparent attack anim grid")

if __name__ == "__main__":
    main()
