#!/usr/bin/env python3
"""
Process Spriterrific pixel art animation row into a playing animated GIF preview:
1. Load pixel art animation row.
2. Chroma key green background.
3. Slice 8 sequential frames.
4. Scale up with NEAREST filter for crisp pixel art pixels.
5. Save animated preview GIF.
"""
import os
from PIL import Image

ROW_PATH = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\spriterrific_walk_row_1784822658639.jpg"
OUT_ARTIFACT = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\spriterrific_anim_preview.gif"
OUT_PROJECT = r"C:\Users\Administrator\mecha-forge\meshy_in\previews\spriterrific_anim_preview.gif"
OUT_ROOT = r"C:\Users\Administrator\mecha-forge\spriterrific_anim_preview.gif"

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
    if not os.path.exists(ROW_PATH):
        print("Row image missing:", ROW_PATH)
        return
    
    raw = Image.open(ROW_PATH)
    clean = remove_background(raw)
    
    w, h = clean.size
    n_frames = 8
    frame_w = w // n_frames
    
    frames = []
    for i in range(n_frames):
        box = (i * frame_w, 0, (i + 1) * frame_w, h)
        frame = clean.crop(box)
        
        # Pixelate & scale up with NEAREST filter to preserve retro pixel edges
        fw, fh = frame.size
        small = frame.resize((max(1, fw // 2), max(1, fh // 2)), Image.Resampling.NEAREST)
        scaled = small.resize((256, 256), Image.Resampling.NEAREST)
        frames.append(scaled)
        
    if frames:
        frames[0].save(
            OUT_ARTIFACT,
            save_all=True,
            append_images=frames[1:],
            duration=110,
            loop=0,
        )
        frames[0].save(
            OUT_PROJECT,
            save_all=True,
            append_images=frames[1:],
            duration=110,
            loop=0,
        )
        frames[0].save(
            OUT_ROOT,
            save_all=True,
            append_images=frames[1:],
            duration=110,
            loop=0,
        )
        print("Animated GIF saved successfully!")

if __name__ == "__main__":
    main()
