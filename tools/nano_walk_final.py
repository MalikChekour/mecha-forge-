"""Anti-boil walk cycle via Nano-Banana: CHAIN each frame on the previous one (keep appearance
identical, only re-pose to the george silhouette) so the mecha stays temporally stable. Then rembg +
normalize (uniform scale, feet on a common baseline, centered) into an 8-frame game sheet + preview GIF.
Usage: python tools/nano_walk_final.py <dir>"""
import os, sys, json, base64, io, time, urllib.request, urllib.error
import numpy as np
from PIL import Image
from rembg import remove, new_session

TOK = os.environ["REPLICATE_API_TOKEN"]
MODEL = "google/nano-banana"
DIRN = sys.argv[1] if len(sys.argv) > 1 else "front"
NF = 8
OUT = r"C:\Users\Administrator\mecha-forge\cine\gemini"
SHOW = r"C:\Users\Administrator\mecha-forge\cine\_show"
SESS = new_session("u2net")
FACE = {"front": "toward the viewer (front)", "back": "seen from BEHIND (its back)",
        "left": "in left-side profile", "right": "in right-side profile"}[DIRN]
BACK_CLAUSE = (" IMPORTANT: this is the BACK viewed from behind — do NOT show the blue core, face or "
               "chest; show the REAR: backpack/reactor, two antennae, shoulder blades, thruster nozzles, "
               "backs of the legs." if DIRN == "back" else "")


def data_uri(im):
    b = io.BytesIO(); im.convert("RGBA").save(b, "PNG")
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


def silhouette(gi):
    sheet = Image.open(f"game/assets/mecha/george_walk_{DIRN}.png").convert("RGBA")
    fw = sheet.width // 8
    fr = sheet.crop((gi * fw, 0, (gi + 1) * fw, sheet.height))
    a = np.asarray(fr.getchannel("A"))
    sil = np.where(a[..., None] > 60, np.array([20, 20, 20], np.uint8), np.array([255, 255, 255], np.uint8))
    return Image.fromarray(sil.astype(np.uint8), "RGB")


def call(sil_im, anchor_im, first):
    # Same STRONG articulation prompt for every frame (this is what actually made the legs move); the
    # second image only supplies the LOOK/colors. Anchoring later frames to frame-0's pixel render (not
    # the photo artwork) keeps the style stable -> less boil, without freezing the pose.
    prompt = ("The FIRST image is a black POSE SILHOUETTE of a mecha mid-WALK, facing " + FACE + " — study "
              "its LEG STANCE and STRIDE (one leg is clearly stepping forward or lifted, the other planted) "
              "and its arm positions. The SECOND image only tells you the mecha's LOOK. Draw the mecha posed "
              "to fill the FIRST silhouette EXACTLY: the legs and arms MUST match the silhouette's walking "
              "stride, not a standing pose — bend the knees and move the legs into that exact stance. Facing "
              + FACE + ". Use the SECOND image's design, armor, glowing blue core and orange/steel colors. "
              "One mecha, full body, centered, plain flat neutral background, no text, crisp game-ready "
              "pixel art." + BACK_CLAUSE)
    body = {"input": {"prompt": prompt, "image_input": [data_uri(sil_im), data_uri(anchor_im)], "output_format": "png"}}
    req = urllib.request.Request(f"https://api.replicate.com/v1/models/{MODEL}/predictions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {TOK}", "Prefer": "wait"})
    for _ in range(4):
        try:
            d = json.loads(urllib.request.urlopen(req, timeout=200).read().decode())
            o = d.get("output")
            if o:
                url = o if isinstance(o, str) else o[0]
                return Image.open(io.BytesIO(urllib.request.urlopen(url, timeout=120).read())).convert("RGBA")
            print("   status", d.get("status"), str(d.get("error"))[:70])
        except urllib.error.HTTPError as e:
            print("   HTTP", e.code, e.read().decode()[:80]); time.sleep(4)
    return None


# facing char anchor for frame 0
if DIRN == "front":
    anchor0 = Image.open(r"C:\Users\Administrator\mecha-forge\cine\pixel\hi_1.png").convert("RGBA")
else:
    ish = Image.open(f"game/assets/mecha/lourd_idle_{DIRN}.png").convert("RGBA")
    anchor0 = ish.crop((0, 0, ish.width // 8, ish.height))

results = []
anchor = anchor0                                     # FIXED appearance anchor (set to frame 0's render)
for i in range(NF):
    gi = round(i * 8 / NF) % 8
    r = call(silhouette(gi), anchor, first=(i == 0))
    print("frame", i, "gi", gi, "->", "ok" if r else "FAIL")
    if r is not None:
        r.save(os.path.join(OUT, f"fw_{DIRN}_{i}.png"))
        if i == 0:
            anchor = r                               # canonical look; stays fixed for all later frames
    results.append(r)

# rembg + measure
cuts = []
for r in results:
    if r is None:
        cuts.append(None); continue
    cut = remove(r.convert("RGB"), session=SESS).convert("RGBA")
    a = np.asarray(cut.getchannel("A"))
    ys, xs = np.where(a > 140)
    cuts.append((cut, xs.min(), ys.min(), xs.max(), ys.max()) if len(xs) else None)

valid = [c for c in cuts if c]
maxh = max(c[4] - c[2] for c in valid)
FH = 300
scale = (FH * 0.92) / maxh
FW = int(max(c[3] - c[1] for c in valid) * scale) + 44
baseline = FH - 6
frames = []
for c in cuts:
    cv = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    if c:
        cut, x0, y0, x1, y1 = c
        crop = cut.crop((x0, y0, x1 + 1, y1 + 1)).resize(
            (int((x1 - x0 + 1) * scale), int((y1 - y0 + 1) * scale)), Image.LANCZOS)
        cv.alpha_composite(crop, ((FW - crop.width) // 2, baseline - crop.height))
    frames.append(cv)

sheet = Image.new("RGBA", (FW * NF, FH), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, (i * FW, 0))
sheet.save(os.path.join(OUT, f"final_{DIRN}.png"))
disp = [Image.new("RGB", f.size, (28, 30, 38)) for f in frames]
for d, f in zip(disp, frames):
    d.paste(f, (0, 0), f)
pal = disp[0].quantize(colors=128)
q = [d.quantize(palette=pal) for d in disp]
q[0].save(os.path.join(OUT, f"final_{DIRN}.gif"), save_all=True, append_images=q[1:], duration=110, loop=0, disposal=2)
strip = Image.new("RGB", (FW * NF, FH), (18, 20, 26))
for i, d in enumerate(disp):
    strip.paste(d, (i * FW, 0))
strip.save(os.path.join(SHOW, f"final_{DIRN}.png"))
print("DONE", DIRN, "frame", (FW, FH))
