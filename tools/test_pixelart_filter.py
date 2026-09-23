#!/usr/bin/env python3
"""
Convert perfect 3D-baked sprite sheet into Spriterrific-style Pixel Art.
- Downscales and upscales (NEAREST) for macro-pixels
- Quantizes palette (posterize)
- (Optional) Black outline
"""
import sys, os
from PIL import Image, ImageFilter

IN_FILE = r"C:\Users\Administrator\mecha-forge\game\assets\mecha\darkstar_walk_front.png"
OUT_FILE = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\darkstar_pixelart_walk.png"
OUT_GIF = r"C:\Users\Administrator\.gemini\antigravity\brain\3e1e3261-469e-4c4e-bf60-d9871b15e4e0\darkstar_pixelart_walk.gif"

def process_pixelart(im, scale_down=3, colors=16):
    w, h = im.size
    # Downscale to force chunky pixels
    small = im.resize((max(1, w // scale_down), max(1, h // scale_down)), Image.Resampling.NEAREST)
    
    # Posterize to reduce colors (retro look)
    # small = small.convert("P", palette=Image.ADAPTIVE, colors=colors).convert("RGBA")
    
    # Upscale back
    pixelated = small.resize((w, h), Image.Resampling.NEAREST)
    return pixelated

def main():
    if not os.path.exists(IN_FILE):
        return
        
    sheet = Image.open(IN_FILE).convert("RGBA")
    pixel_sheet = process_pixelart(sheet, scale_down=4)
    pixel_sheet.save(OUT_FILE)
    
    # Generate GIF preview
    w, h = pixel_sheet.size
    frames = []
    frame_w = w // 8
    for i in range(8):
        frames.append(pixel_sheet.crop((i * frame_w, 0, (i + 1) * frame_w, h)))
        
    if frames:
        frames[0].save(
            OUT_GIF,
            save_all=True,
            append_images=frames[1:],
            duration=120,
            loop=0
        )
        print("Generated perfect pixel-art GIF!")

if __name__ == "__main__":
    main()
