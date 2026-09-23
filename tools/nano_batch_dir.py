"""Generate a FULL walk cycle for one direction via Nano-Banana silhouette pose-transfer (one call per
george frame), then rembg + normalize (uniform scale, feet on a common baseline, centered) into an
8-frame preview strip + GIF so we can judge animation coherence before integrating.
Usage: python tools/nano_batch_dir.py <dir> [nframes]"""
import os, sys, json, base64, io, time, urllib.request, urllib.error
import numpy as np
from PIL import Image
from rembg import remove, new_session

TOK = os.environ["REPLICATE_API_TOKEN"]
MODEL = "google/nano-banana"
DIRN = sys.argv[1] if len(sys.argv) > 1 else "front"
NF = int(sys.argv[2]) if len(sys.argv) > 2 else 8
OUT = r"C:\Users\Administrator\mecha-forge\cine\gemini"
SESS = new_session("u2net")


def data_uri(im):
    b = io.BytesIO(); im.convert("RGBA").save(b, "PNG")
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


def gen(idx):
    sheet = Image.open(f"game/assets/mecha/george_walk_{DIRN}.png").convert("RGBA")
    fw = sheet.width // 8
    gi = round(idx * 8 / NF) % 8
    frame = sheet.crop((gi * fw, 0, (gi + 1) * fw, sheet.height))
    a = np.asarray(frame.getchannel("A"))
    sil = np.where(a[..., None] > 60, np.array([20, 20, 20], np.uint8), np.array([255, 255, 255], np.uint8))
    sil_im = Image.fromarray(sil.astype(np.uint8), "RGB")
    if DIRN == "front":
        char_im = Image.open(r"C:\Users\Administrator\mecha-forge\cine\pixel\hi_1.png")
    else:
        ish = Image.open(f"game/assets/mecha/lourd_idle_{DIRN}.png").convert("RGBA")
        char_im = ish.crop((0, 0, ish.width // 8, ish.height))
    face = {"front": "toward the viewer (front)", "back": "seen from BEHIND (its back)",
            "left": "in left-side profile", "right": "in right-side profile"}[DIRN]
    prompt = (
        "The FIRST image is a black POSE SILHOUETTE of a walking mecha " + face + " (only the shape/pose "
        "matters: leg positions — one leg stepping/lifted, the other planted — and arm positions). "
        "The SECOND image is the CHARACTER mecha, shown " + face + ". Redraw the CHARACTER mecha posed to "
        "EXACTLY fill that silhouette: same leg stance, same stride, same arm positions, same facing (" +
        face + ") and proportions — rendered with the CHARACTER's own design, armor, glowing blue core and "
        "orange/steel colors. ONE single mecha, full body, centered, plain flat neutral background, no text. "
        "Crisp game-ready pixel art." +
        (" IMPORTANT: this is the BACK viewed from behind — do NOT show the blue core, face or chest; show "
         "the REAR: backpack/reactor, two antennae, shoulder blades, thruster nozzles, backs of the legs." if DIRN == "back" else ""))
    body = {"input": {"prompt": prompt, "image_input": [data_uri(sil_im), data_uri(char_im)], "output_format": "png"}}
    req = urllib.request.Request(f"https://api.replicate.com/v1/models/{MODEL}/predictions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {TOK}", "Prefer": "wait"})
    for attempt in range(3):
        try:
            d = json.loads(urllib.request.urlopen(req, timeout=200).read().decode())
            o = d.get("output")
            if o:
                url = o if isinstance(o, str) else o[0]
                dst = os.path.join(OUT, f"pf_{DIRN}_{idx}.png")
                open(dst, "wb").write(urllib.request.urlopen(url, timeout=120).read())
                return dst
            print(f"  f{idx}: status={d.get('status')} err={str(d.get('error'))[:80]}")
        except urllib.error.HTTPError as e:
            print(f"  f{idx}: HTTP {e.code} {e.read().decode()[:100]}"); time.sleep(3)
    return None


# 1) generate
paths = []
for i in range(NF):
    p = gen(i)
    print("gen", i, "->", "ok" if p else "FAIL")
    paths.append(p)

# 2) rembg cutout + measure
cuts = []
for p in paths:
    if not p:
        cuts.append(None); continue
    cut = remove(Image.open(p).convert("RGB"), session=SESS).convert("RGBA")
    a = np.asarray(cut.getchannel("A"))
    ys, xs = np.where(a > 140)
    if len(xs) == 0:
        cuts.append(None); continue
    cuts.append((cut, xs.min(), ys.min(), xs.max(), ys.max()))

valid = [c for c in cuts if c]
maxh = max(c[4] - c[2] for c in valid)
FH = 300
scale = (FH * 0.92) / maxh                      # uniform scale so the tallest pose fits
FW = int(max((c[3] - c[1]) for c in valid) * scale) + 40

# 3) normalize: uniform scale, feet(bbox bottom) on common baseline, centered-x
frames = []
baseline = FH - 6
for c in cuts:
    canvas = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    if c:
        cut, x0, y0, x1, y1 = c
        crop = cut.crop((x0, y0, x1 + 1, y1 + 1))
        nw, nh = int(crop.width * scale), int(crop.height * scale)
        crop = crop.resize((nw, nh), Image.LANCZOS)
        canvas.alpha_composite(crop, ((FW - nw) // 2, baseline - nh))
    frames.append(canvas)

# 4) save sheet + gif
sheet = Image.new("RGBA", (FW * NF, FH), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, (i * FW, 0))
sheet.save(os.path.join(OUT, f"sheet_{DIRN}.png"))
disp = []
for f in frames:
    bg = Image.new("RGB", f.size, (28, 30, 38)); bg.paste(f, (0, 0), f); disp.append(bg)
pal = disp[0].quantize(colors=128)
q = [d.quantize(palette=pal) for d in disp]
q[0].save(os.path.join(OUT, f"anim_{DIRN}.gif"), save_all=True, append_images=q[1:], duration=110, loop=0, disposal=2)
strip = Image.new("RGB", (FW * NF, FH), (18, 20, 26))
for i, d in enumerate(disp):
    strip.paste(d, (i * FW, 0))
strip.save(os.path.join(r"C:\Users\Administrator\mecha-forge\cine\_show", f"nano_sheet_{DIRN}.png"))
print("DONE", DIRN, "frame", (FW, FH), "->", f"anim_{DIRN}.gif")
