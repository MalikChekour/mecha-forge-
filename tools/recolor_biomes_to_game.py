"""Genere les 9 versions peintes de Blue Strike (ennemi de base) pour chaque biome
et les ecrit dans game/assets/enemies/bs_<biome>_walk_<dir>.png (4 directions).
Base = meshy_in/bluestrike_eyebase/walk_<dir>.png (yeux keyés)."""
import sys, os, numpy as np
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
from biome_paint3 import recolor
from biome_paint2 import BIOMES

SRC="meshy_in/bluestrike_eyebase"
OUT="game/assets/enemies"
DIRS=["front","back","left","right"]

for key,bname,pname,ramp,trim,energy,glow,spec in BIOMES:
    for d in DIRS:
        p=os.path.join(SRC,f"walk_{d}.png")
        arr=np.array(Image.open(p).convert("RGBA"))
        fw=arr.shape[1]//8
        outsheet=Image.new("RGBA",(arr.shape[1],arr.shape[0]),(0,0,0,0))
        for i in range(8):
            cell=recolor(arr[:,i*fw:(i+1)*fw], ramp,trim,energy,glow)
            outsheet.paste(Image.fromarray(cell,"RGBA"),(i*fw,0))
        outsheet.save(os.path.join(OUT,f"bs_{key}_walk_{d}.png"))
    print("PAINTED bs_"+key)
print("DONE 9 biomes x 4 dirs")
