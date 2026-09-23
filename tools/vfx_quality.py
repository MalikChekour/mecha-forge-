#!/usr/bin/env python3
"""
HIGH-QUALITY weapon VFX catalog. Each effect is rendered ISOLATED on black (exactly how it blends
additively in-game), through an HDR light-accumulation -> multi-scale bloom -> filmic tonemap pipe.
Outputs refs/vfx_hq/<ID>.gif + .png sheet. IDs are copy-pasteable (e.g. FX08_railgun_beam).
"""
import numpy as np, os, math
from scipy.ndimage import gaussian_filter
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "refs", "vfx_hq")
os.makedirs(OUT, exist_ok=True)
S = 200; NF = 28; C = S / 2.0
rng = np.random.default_rng(42)
YY, XX = np.mgrid[0:S, 0:S].astype(np.float32)

def hdr():
    return np.zeros((S, S, 3), np.float32)

def glow(b, x, y, r, col, inten):
    m = np.exp(-(((XX - x) ** 2 + (YY - y) ** 2) / (2 * r * r))).astype(np.float32) * inten
    for c in range(3): b[..., c] += col[c] * m
    return b

def core(b, x, y, r, col, inten):            # hard bright core (for white-hot centers)
    d = np.hypot(XX - x, YY - y)
    m = np.clip(1 - d / r, 0, 1) ** 2 * inten
    for c in range(3): b[..., c] += col[c] * m
    return b

def beam(b, x0, y0, x1, y1, w, col, inten):
    dx, dy = x1 - x0, y1 - y0; L2 = dx * dx + dy * dy + 1e-6
    t = np.clip(((XX - x0) * dx + (YY - y0) * dy) / L2, 0, 1)
    px, py = x0 + t * dx, y0 + t * dy
    m = np.exp(-(((XX - px) ** 2 + (YY - py) ** 2) / (2 * w * w))) * inten
    for c in range(3): b[..., c] += col[c] * m
    return b

def ring(b, x, y, rad, thick, col, inten):
    d = np.hypot(XX - x, YY - y)
    m = np.exp(-(((d - rad) / thick) ** 2)) * inten
    for c in range(3): b[..., c] += col[c] * m
    return b

def noise(cell, seed):
    from scipy.ndimage import zoom
    low = rng.integers(0, 2 ** 31) if False else np.random.default_rng(seed).random((S // cell + 2, S // cell + 2))
    return zoom(low, cell, order=1)[:S, :S].astype(np.float32)

def bloom(h):
    b = np.zeros_like(h)
    for sig, wt in [(2, 0.6), (5, 0.45), (12, 0.30), (26, 0.18)]:
        for c in range(3):
            b[..., c] += gaussian_filter(h[..., c], sig) * wt
    return h + b

def tonemap(h):                               # ACES filmic
    x = np.clip(h, 0, None)
    a, bb, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    return np.clip((x * (a * x + bb)) / (x * (c * x + d) + e), 0, 1)

def render(frames_hdr):
    gif = []
    for h in frames_hdr:
        img = tonemap(bloom(h))
        gif.append(Image.fromarray((img * 255).astype(np.uint8)))
    return gif

def save(idn, frames_hdr):
    gif = render(frames_hdr)
    p = [im.convert("P", palette=Image.ADAPTIVE) for im in gif]
    p[0].save(os.path.join(OUT, idn + ".gif"), save_all=True, append_images=p[1:], duration=60, loop=0, disposal=2)
    # also a static sheet (8 frames) for fallback
    n = 8; step = max(1, len(gif) // n)
    sh = Image.new("RGB", (S * n, S), (0, 0, 0))
    for i in range(n): sh.paste(gif[min(i * step, len(gif) - 1)], (i * S, 0))
    sh.save(os.path.join(OUT, idn + ".png"))
    print(" ", idn)

# palettes
WHITE=(1,1,1); GOLD=(1.6,1.2,0.4); AMBER=(1.7,0.8,0.2); RED=(1.8,0.4,0.2)
CYAN=(0.4,1.2,1.8); BLUE=(0.5,0.8,1.8); VIO=(1.1,0.5,1.7); GREEN=(0.4,1.6,0.7); TEAL=(0.3,1.5,1.3)

def E01_muzzle_kinetic():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); fade=(1-t)**1.4
        cone_len=18+40*(1-t*0.4)
        for k in range(28):
            p=k/28; x=C+p*cone_len; sp=(1-p)*11
            glow(b,x,C+rng.normal(0,sp),4+ (1-p)*6, GOLD, 2.2*fade*(1-p*0.5))
        core(b,C+6,C,10,WHITE,3*fade)
        for s in range(8):                     # muzzle sparks
            a=rng.uniform(-0.5,0.5); d=t*60; glow(b,C+math.cos(a)*d, C+math.sin(a)*d,2,AMBER,1.5*fade)
        fr.append(b)
    return fr

def E02_tracer_kinetic():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); x=20+t*160
        beam(b,x-30,C,x,C,3,WHITE,2.5); core(b,x,C,6,WHITE,4); glow(b,x,C,12,BLUE,1.5)
        fr.append(b)
    return fr

def E03_impact_kinetic():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); fade=(1-t)**1.5
        core(b,C,C,8*(1-t)+2,WHITE,3*fade)
        for k in range(14):
            a=k/14*6.28; d=t*46; glow(b,C+math.cos(a)*d,C+math.sin(a)*d,2.5,GOLD,2*fade)
        fr.append(b)
    return fr

def E05_missile_trail():
    fr=[]; path=[(20,C)]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); x=20+t*160; y=C+math.sin(t*7)*26
        path.append((x,y)); path[:]=path[-16:]
        for j,(px,py) in enumerate(path):
            f=j/len(path); glow(b,px,py,3+ (1-f)*5, (0.5,0.5,0.55), 0.8*f)      # smoke
            if f>0.6: glow(b,px,py,4,AMBER,1.2*f)                                # fire
        core(b,x,y,5,WHITE,2.5); glow(b,x,y,10,AMBER,1.8)
        fr.append(b)
    return fr

def E06_missile_explosion():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); r=6+t*46
        n=gaussian_filter(noise(14,7),1.5); n/=n.max()
        d=np.hypot(XX-C,YY-C); mask=np.clip(1-d/r,0,1)*(0.5+0.8*n)
        heat=np.clip(mask*(1.6-t),0,2)
        col=np.stack([heat*1.8, heat*0.7*(1-t*0.5), heat*0.2*(1-t)],-1)
        b+=col
        ring(b,C,C,r,4,AMBER,1.5*(1-t))
        fr.append(b)
    return fr

def E07_railgun_charge():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr()
        for k in range(16):
            a=k/16*6.28; d=40*(1-t); glow(b,C+math.cos(a)*d,C+math.sin(a)*d,3,BLUE,1.5*t)
        core(b,C,C,6+8*t,WHITE,2.5*t); glow(b,C,C,16*t+4,CYAN,2*t)
        fr.append(b)
    return fr

def E08_railgun_beam():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); flick=0.8+0.2*math.sin(i*3)
        w=(6 if t<0.3 else max(1,6*(1-(t-0.3)/0.7)))
        beam(b,0,C,S,C,w*1.6,BLUE,1.6*flick)
        beam(b,0,C,S,C,w*0.5,WHITE,3*flick)
        core(b,C,C,10,WHITE,3*(1-t))
        fr.append(b)
    return fr

def E09_pierce_impact():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); fade=(1-t)**1.4
        beam(b,C-40,C,C+40,C,3*fade,WHITE,3*fade)         # lance of light
        ring(b,C,C,t*40,3,CYAN,2*fade)
        core(b,C,C,6,WHITE,3*fade)
        fr.append(b)
    return fr

def E10_plasma_charge():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); rot=t*8
        n=gaussian_filter(noise(10,40+i),1.2); n/=n.max()
        rad=8+10*t
        d=np.hypot(XX-C,YY-C); orb=np.clip(1-d/rad,0,1)**1.3*(0.6+0.7*n)
        for c,cc in enumerate(VIO): b[...,c]+=cc*orb*(0.8+t)
        for k in range(3):
            a=rot+k*2.1; glow(b,C+math.cos(a)*rad,C+math.sin(a)*rad,4,(1.4,0.8,1.8),1.5)
        core(b,C,C,5,WHITE,1.5*t)
        fr.append(b)
    return fr

def E11_plasma_aoe():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); r=6+t*70
        d=np.hypot(XX-C,YY-C)
        dome=np.clip(1-d/r,0,1)**2*(1-t)*0.9
        for c,cc in enumerate(VIO): b[...,c]+=cc*dome
        ring(b,C,C,r,5,(1.3,0.7,1.9),2*(1-t*0.7))
        ring(b,C,C,r*0.6,3,WHITE,1.5*(1-t))
        fr.append(b)
    return fr

def E13_sabre_arc():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); base=-1.2+t*2.4
        ang=np.arctan2(YY-C,XX-C); r=np.hypot(XX-C,YY-C)
        for tr,inten in [(0,1.0),(-0.18,0.5),(-0.34,0.25)]:      # motion-blur trail
            arc=np.exp(-((((ang-(base+tr)+math.pi)%6.283)-math.pi)/0.4)**2)*np.exp(-((r-38)/13)**2)
            for c,cc in enumerate(TEAL): b[...,c]+=cc*arc*inten*1.6
        arc2=np.exp(-((((ang-base+math.pi)%6.283)-math.pi)/0.15)**2)*np.exp(-((r-38)/10)**2)
        b+=np.stack([arc2*2]*3,-1)                               # white edge
        fr.append(b)
    return fr

def E15_mine_blast():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr()
        if t<0.25:
            bl=abs(math.sin(t*40)); glow(b,C,C,7,RED,1.5+bl)
        else:
            tt=(t-0.25)/0.75; r=6+tt*60
            n=gaussian_filter(noise(12,9),1.3); n/=n.max()
            d=np.hypot(XX-C,YY-C); m=np.clip(1-d/r,0,1)*(0.5+0.7*n)*(1-tt)
            b+=np.stack([m*1.8,m*0.8,m*0.2],-1)
            ring(b,C,C,r,4,AMBER,2*(1-tt))
            for k in range(10):
                a=k/10*6.28; dd=tt*60; glow(b,C+math.cos(a)*dd,C+math.sin(a)*dd,2,AMBER,1.5*(1-tt))
        fr.append(b)
    return fr

def E16_boomerang():
    fr=[]; path=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); reach=math.sin(t*math.pi)*70
        x=C+reach; y=C+math.sin(t*6.28)*22; path.append((x,y)); path[:]=path[-12:]
        for j,(px,py) in enumerate(path):
            f=j/len(path); glow(b,px,py,3,GOLD,0.9*f)
        rota=i*0.9
        for k in range(2):
            a=rota+k*math.pi; glow(b,x+math.cos(a)*7,y+math.sin(a)*7,4,GOLD,2)
        core(b,x,y,4,WHITE,1.5)
        fr.append(b)
    return fr

def E17_shield_raise():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); r=10+t*46; a=min(1,t*2)*(1-max(0,(t-0.7)/0.3))
        ang=np.arctan2(YY-C,XX-C); d=np.hypot(XX-C,YY-C)
        hexp=0.5+0.5*np.cos(ang*6)
        shell=np.exp(-((d-r)/4)**2)*(0.5+0.5*hexp)
        fill=np.clip(1-d/r,0,1)*0.12
        for c,cc in enumerate(CYAN): b[...,c]+=cc*(shell*a+fill*a)
        fr.append(b)
    return fr

def E18_shield_ripple():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); d=np.hypot(XX-C,YY-C); r=48
        ang=np.arctan2(YY-C,XX-C); hexp=0.5+0.5*np.cos(ang*6)
        shell=np.exp(-((d-r)/5)**2)*(0.4+0.6*hexp)*(1-t)
        hit=np.exp(-((d-(10+t*40))/5)**2)*(1-t)                  # impact wave travelling the shell
        for c,cc in enumerate(CYAN): b[...,c]+=cc*(shell+hit*1.2)
        fr.append(b)
    return fr

def E20_drone_shot():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); x=40+t*130
        glow(b,40,C,6,TEAL,2*(1-t))                              # drone body
        beam(b,44,C,x,C,2,TEAL,1.5); core(b,x,C,4,WHITE,3)
        fr.append(b)
    return fr

def E21_aura_field():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr(); r=44+8*math.sin(t*6.28)
        d=np.hypot(XX-C,YY-C)
        ring(b,C,C,r,6,TEAL,1.6);
        fill=np.clip(1-d/r,0,1)*0.10
        for c,cc in enumerate(TEAL): b[...,c]+=cc*fill
        if i%9<2:
            for c,cc in enumerate(WHITE): b[...,c]+=cc*np.exp(-((d-r)/8)**2)*1.5   # discharge flash
        fr.append(b)
    return fr

def E23_overdrive_aura():
    fr=[]
    for i in range(NF):
        t=i/(NF-1); b=hdr()
        n=gaussian_filter(noise(10,60+i),1.5); n/=n.max()
        d=np.hypot(XX-C,YY-C); flame=np.clip(1-d/46,0,1)*(0.4+0.9*n)*(0.9+0.3*math.sin(t*6.28))
        b+=np.stack([flame*1.8,flame*1.2,flame*0.4],-1)
        core(b,C,C,10,WHITE,2)
        fr.append(b)
    return fr

CATALOG = [
    ("FX01_muzzle_kinetic", "Flash de bouche — cinétique", "Autocanon : éclair court jaune-blanc + étincelles.", E01_muzzle_kinetic),
    ("FX02_tracer_kinetic", "Traçante — cinétique", "Balle blanche incandescente étirée + traînée.", E02_tracer_kinetic),
    ("FX03_impact_kinetic", "Impact — cinétique", "Éclat sec d'étincelles dorées.", E03_impact_kinetic),
    ("FX05_missile_trail", "Traînée de missile", "Fumée + feu qui serpente derrière le projectile.", E05_missile_trail),
    ("FX06_missile_explosion", "Explosion de missile", "Boule de feu turbulente + anneau.", E06_missile_explosion),
    ("FX07_railgun_charge", "Charge railgun", "Énergie qui converge vers un cœur blanc.", E07_railgun_charge),
    ("FX08_railgun_beam", "Rayon railgun perçant", "Faisceau bleu-blanc net qui traverse tout.", E08_railgun_beam),
    ("FX09_pierce_impact", "Impact perçant", "Lance de lumière + onde de choc.", E09_pierce_impact),
    ("FX10_plasma_charge", "Charge plasma", "Orbe violette tourbillonnante qui grossit.", E10_plasma_charge),
    ("FX11_plasma_aoe", "Explosion plasma (zone)", "Dôme de zone violet + double anneau.", E11_plasma_aoe),
    ("FX13_sabre_arc", "Arc de sabre", "Croissant de lame teal avec flou de mouvement.", E13_sabre_arc),
    ("FX15_mine_blast", "Déflagration de mine", "Amorce clignotante → explosion + éclats.", E15_mine_blast),
    ("FX16_boomerang", "Disque boomerang", "Disque doré rotatif + traînée courbe.", E16_boomerang),
    ("FX17_shield_raise", "Bouclier levé", "Dôme hexagonal qui se forme.", E17_shield_raise),
    ("FX18_shield_ripple", "Ondulation de bouclier", "Onde hex qui parcourt le dôme à l'impact.", E18_shield_ripple),
    ("FX20_drone_shot", "Tir de drone", "Petit bolt teal depuis le satellite.", E20_drone_shot),
    ("FX21_aura_field", "Champ d'aura", "Anneau de dégâts pulsé + décharge.", E21_aura_field),
    ("FX23_overdrive_aura", "Aura d'overdrive", "Flammes d'énergie montantes autour du cœur.", E23_overdrive_aura),
]

if __name__ == "__main__":
    print("HQ VFX ->", OUT)
    for idn, _, _, fn in CATALOG:
        save(idn, fn())
    # write catalog metadata for the html builder
    import json
    json.dump([[i, t, d] for i, t, d, _ in CATALOG], open(os.path.join(OUT, "_meta.json"), "w"), ensure_ascii=False)
    print("DONE", len(CATALOG))
