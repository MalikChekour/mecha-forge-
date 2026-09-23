"""Integrate the Nano-Banana walk sheets into the game:
  cine/gemini/final_<dir>.png  ->  lourd_walk_<dir>.png  (+ lourd_run_<dir>.png = same, played faster)
  idle_<dir> = walk frame 0 tiled x8 (standing pose that matches the new look).
Backs up the current sheets to cine/_bak_walk2 first. All sheets stay 8 frames -> Player.gd unchanged."""
import os, shutil
from PIL import Image

MECHA = r"C:\Users\Administrator\mecha-forge\game\assets\mecha"
GEM = r"C:\Users\Administrator\mecha-forge\cine\gemini"
BAK = r"C:\Users\Administrator\mecha-forge\cine\_bak_walk2"
os.makedirs(BAK, exist_ok=True)
DIRS = ["front", "back", "left", "right"]
NF = 8

for d in DIRS:
    for a in ["walk", "run", "idle"]:
        p = os.path.join(MECHA, f"lourd_{a}_{d}.png")
        if os.path.exists(p):
            shutil.copy(p, os.path.join(BAK, f"lourd_{a}_{d}.png"))

for d in DIRS:
    src = os.path.join(GEM, f"final_{d}.png")
    sheet = Image.open(src).convert("RGBA")
    FW = sheet.width // NF
    H = sheet.height
    # walk + run = the full sheet
    sheet.save(os.path.join(MECHA, f"lourd_walk_{d}.png"))
    sheet.save(os.path.join(MECHA, f"lourd_run_{d}.png"))
    # idle = frame 0 tiled x8
    f0 = sheet.crop((0, 0, FW, H))
    idle = Image.new("RGBA", (FW * NF, H), (0, 0, 0, 0))
    for i in range(NF):
        idle.alpha_composite(f0, (i * FW, 0))
    idle.save(os.path.join(MECHA, f"lourd_idle_{d}.png"))
    print(f"{d}: frame {FW}x{H}  walk+run+idle written")
print("done — backup in cine/_bak_walk2")
