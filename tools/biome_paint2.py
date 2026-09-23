"""Recolor v2 MULTI-MATERIAU : segmente le mecha original par matiere
(armure bleu-gris / liseres orange / coeur cyan) et peint chaque zone d'une
couleur differente par biome -> garde le relief, pas un lavis uni."""
import numpy as np
from scipy import ndimage
from PIL import Image

def _hsv(rgb):
    r,g,b=rgb[...,0]/255.,rgb[...,1]/255.,rgb[...,2]/255.
    mx=np.maximum(np.maximum(r,g),b); mn=np.minimum(np.minimum(r,g),b); d=mx-mn
    v=mx; s=np.where(mx>1e-6,d/np.maximum(mx,1e-6),0)
    h=np.zeros_like(mx)
    dz=d>1e-6
    idx=dz&(mx==r); h=np.where(idx,60*(((g-b)/np.where(d==0,1,d))%6),h)
    idx=dz&(mx==g); h=np.where(idx,60*(((b-r)/np.where(d==0,1,d))+2),h)
    idx=dz&(mx==b); h=np.where(idx,60*(((r-g)/np.where(d==0,1,d))+4),h)
    return h,s,v

def _ramp(stops):
    xs=[p[0] for p in stops]; c=np.array([p[1] for p in stops],float)
    t=np.linspace(0,1,256); return np.stack([np.interp(t,xs,c[:,k]) for k in range(3)],1)

def recolor(arr, armor_ramp, trim, energy, glow=0.9):
    """armor_ramp: rampe (armure). trim: (r,g,b) liseres. energy: (r,g,b) coeur."""
    a=arr[:,:,3]; rgb=arr[:,:,:3].astype(float)
    R,G,B=rgb[...,0],rgb[...,1],rgb[...,2]
    L=0.299*R+0.587*G+0.114*B
    Ls=ndimage.median_filter(L,3); Ls=ndimage.gaussian_filter(Ls,0.5)
    Lr=np.clip((Ls-6)*1.22,0,255).astype(int)
    h,s,v=_hsv(rgb)
    # --- material masks (from the ORIGINAL blue/orange/cyan mech) ---
    m_trim  = (((h<46)|(h>334)) & (s>0.26) & (v>0.14)).astype(float)          # orange liseres
    m_energy= ((h>150)&(h<205) & (s>0.34) & (v>0.50)).astype(float)           # cyan glow core
    m_energy=np.maximum(m_energy, ((v>0.82)&(s>0.20)).astype(float))          # + tres brillants
    m_trim*= (1-m_energy)
    m_armor = (a>8).astype(float)*(1-m_trim)*(1-m_energy)
    # soften mask edges so zones blend
    for m in ("m_trim","m_energy","m_armor"): pass
    m_trim=ndimage.gaussian_filter(m_trim,0.6); m_energy=ndimage.gaussian_filter(m_energy,0.6)
    m_armor=np.clip(1-m_trim-m_energy,0,1)
    # --- paint each zone ---
    armor = _ramp(armor_ramp)[Lr]
    tr=np.array(trim,float); shade=(0.42+0.72*(Lr/255.0))[...,None]
    trimc = np.clip(tr*shade,0,255)
    en=np.array(energy,float); enc = np.clip(en*(0.75+0.45*(Lr/255.0))[...,None],0,255)
    out = armor*m_armor[...,None] + trimc*m_trim[...,None] + enc*m_energy[...,None]
    # additive glow bloom on energy
    out = out + en*(m_energy[...,None]*glow*0.5)
    res=np.zeros_like(arr); res[...,:3]=np.clip(out,0,255).astype(np.uint8); res[...,3]=a
    return res

# (cle, Nom, "peinture", armor_ramp[IGNORE - gunmetal fixe], trim[IGNORE], accent_biome, glow, spec)
# Nouvelle direction : ARMURE = gunmetal sombre CONSTANT (tranche sur le décor) ; seul
# l'ACCENT (coeur + liserés + reflets d'arêtes) prend la couleur de la carte. Le 3e/4e champ
# ne sert plus (compat signature) ; le 5e = la couleur d'accent bien visible du biome.
GUNMETAL=[(0,(15,16,20)),(.32,(46,50,58)),(.6,(96,102,114)),(.82,(160,168,182)),(1,(222,228,240))]
BIOMES = [
 ("tech","Tech / Usine","Énergie violette",
   GUNMETAL,(0,0,0),(165,95,255),1.0,
   "Rusher standard — référence d'équilibrage."),
 ("earth","Terre","Ambre",
   GUNMETAL,(0,0,0),(255,140,30),0.95,
   "+PV, plus lent (chargeur lourd)."),
 ("spaceship","Vaisseau","Magenta spectral",
   GUNMETAL,(0,0,0),(255,90,205),0.95,
   "Plus rapide, erratique (dasher)."),
 ("volcanic","Volcan","Lave",
   GUNMETAL,(0,0,0),(255,78,18),1.12,
   "Agressif, +dégâts au contact."),
 ("desert","Désert","Or",
   GUNMETAL,(0,0,0),(255,205,55),0.95,
   "Raider rapide, en meute."),
 ("ice","Glace","Cyan glacé",
   GUNMETAL,(0,0,0),(120,225,255),1.0,
   "Lent mais blindé (+PV / bouclier)."),
 ("jungle","Jungle","Vert acide",
   GUNMETAL,(0,0,0),(140,255,65),0.98,
   "Vif, arrive en essaim."),
 ("swamp","Marais","Lime toxique",
   GUNMETAL,(0,0,0),(200,240,35),1.02,
   "Toxique — dégâts continus, plus lent."),
 ("ruines","Ruines","Bronze",
   GUNMETAL,(0,0,0),(255,165,75),0.95,
   "Équilibré, +ferraille."),
]

if __name__=="__main__":
    sheet=np.array(Image.open("game/assets/enemies/bluestrike_walk_front.png").convert("RGBA"))
    fw=sheet.shape[1]//8
    pick=["tech","volcanic","swamp","ice","ruines"]
    mont=Image.new("RGB",(240*len(pick),240),(24,26,32))
    for i,key in enumerate(pick):
        b=[x for x in BIOMES if x[0]==key][0]
        cell=recolor(sheet[:,2*fw:3*fw], b[3],b[4],b[5],b[6])
        im=Image.fromarray(cell,"RGBA"); bg=Image.new("RGBA",im.size,(24,26,32,255)); bg.alpha_composite(im)
        mont.paste(bg.convert("RGB").resize((240,240)),(i*240,0))
    mont.save("cine/_show/paint_check2.png"); print("ok")
