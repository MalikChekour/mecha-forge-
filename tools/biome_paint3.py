"""Recolor v3 : segmentation multi-materiau + YEUX ROUGES (cle magenta -> rouge
+ bloom, signature Terminator, identique sur tous les biomes) + reflet d'armure
teinte biome (relief, moins 'uni')."""
import sys, os, numpy as np
from scipy import ndimage
from PIL import Image
sys.path.insert(0, os.path.abspath("tools"))
from biome_paint2 import _hsv, _ramp, BIOMES  # reuse ramps + biome table

EYE=(255,46,28)

def recolor(arr, armor_ramp, trim, energy, glow=0.9, eye=EYE):
    a=arr[:,:,3]; rgb=arr[:,:,:3].astype(float)
    R,G,B=rgb[...,0],rgb[...,1],rgb[...,2]
    # --- eye KEY (magenta) : strong R+B, low G ---
    eye_mask=((R>172)&(B>172)&(G<100)&(a>8)).astype(float)
    eye_soft=ndimage.gaussian_filter(eye_mask,0.4)
    L=0.299*R+0.587*G+0.114*B
    Ls=ndimage.median_filter(L,3); Ls=ndimage.gaussian_filter(Ls,0.5)
    detail=Ls-ndimage.gaussian_filter(Ls,2.0)   # unsharp -> crisp panel lines
    Lr=np.clip((Ls-6)*1.24 + detail*0.85,0,255)  # contrast + sharpened relief
    Li=Lr.astype(int)
    h,s,v=_hsv(rgb)
    m_trim=(((h<46)|(h>334)) & (s>0.26) & (v>0.14)).astype(float)
    m_energy=((h>150)&(h<205)&(s>0.34)&(v>0.50)).astype(float)
    m_energy=np.maximum(m_energy, ((v>0.82)&(s>0.20)&((h<150)|(h>205))).astype(float))
    keep=(1-eye_mask)
    m_trim*=keep*(1-m_energy); m_energy*=keep
    m_trim=ndimage.gaussian_filter(m_trim,0.6); m_energy=ndimage.gaussian_filter(m_energy,0.6)
    m_armor=np.clip((a>8).astype(float)*keep - m_trim - m_energy,0,1)
    # paint : ARMURE = gunmetal sombre (armor_ramp = GUNMETAL, constant) ; seuls les LISERES
    # et le COEUR prennent la couleur d'accent du biome (= les "quelques elements visibles").
    armor=_ramp(armor_ramp)[Li]
    en=np.array(energy,float)                                             # accent biome
    trimc=np.clip(en*(0.50+0.68*(Lr/255.0))[...,None],0,255)             # liseres en accent (visibles)
    enc=np.clip(en*(0.85+0.40*(Lr/255.0))[...,None],0,255)               # coeur (le plus brillant)
    out=armor*m_armor[...,None]+trimc*m_trim[...,None]+enc*m_energy[...,None]
    # liseré d'accent sur les ARÊTES metalliques (le metal capte un reflet de la couleur biome)
    hi=np.clip((Lr-186)/70.0,0,1)[...,None]
    out=out+en*hi*m_armor[...,None]*0.22
    # energy core additive bloom (moderate, not washed)
    out=out+en*(m_energy[...,None]*glow*0.24)
    # RED EYES : deep-red optic + WHITE-HOT core + red bloom halo (menacing glow)
    eye_core=(eye_mask>0.5)
    eye_big=ndimage.binary_dilation(eye_core, iterations=1).astype(float)
    eye_hot=ndimage.binary_erosion(eye_core, iterations=1).astype(float)  # inner incandescent center
    EYE=np.array(eye,float); HOT=np.array((255,158,132),float)
    out=out*(1-eye_big[...,None])+EYE*eye_big[...,None]
    out=out*(1-eye_hot[...,None])+HOT*eye_hot[...,None]
    bloom=ndimage.gaussian_filter(eye_big,2.4)
    out=out+EYE*(bloom[...,None]*1.0)
    a=np.maximum(a, (eye_big*255).astype(a.dtype))
    res=np.zeros_like(arr); res[...,:3]=np.clip(out,0,255).astype(np.uint8)
    res[...,3]=np.clip(a.astype(float)+eye_soft*80,0,255).astype(np.uint8)
    return res

if __name__=="__main__":
    sheet=np.array(Image.open("meshy_in/bluestrike_eyebase/walk_front.png").convert("RGBA"))
    fw=sheet.shape[1]//8
    pick=["tech","volcanic","ice","swamp","ruines"]
    mont=Image.new("RGB",(300*len(pick),300),(24,26,32))
    for i,key in enumerate(pick):
        b=[x for x in BIOMES if x[0]==key][0]
        cell=recolor(sheet[:,2*fw:3*fw], b[3],b[4],b[5],b[6])
        im=Image.fromarray(cell,"RGBA"); bg=Image.new("RGBA",im.size,(24,26,32,255)); bg.alpha_composite(im)
        mont.paste(bg.convert("RGB").resize((300,300)),(i*300,0))
    mont.save("cine/_show/paint_check3.png"); print("ok")
