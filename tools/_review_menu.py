import os
from PIL import Image, ImageDraw
D = r"C:\Users\Administrator\.gemini\antigravity\scratch\mecha-forge\refs\menu"
items = [("splash", "splash 9:16"), ("menu_bg", "menu_bg 9:16"), ("emblem", "emblem 1:1"),
         ("cine1", "cine1 guerre"), ("cine2", "cine2 forge"), ("cine3", "cine3 pilote"),
         ("cine4", "cine4 reveil"), ("cine5", "cine5 horde"), ("cine6", "cine6 charge")]
CW, CH, pad, lh, cols, rows = 430, 300, 8, 24, 3, 3
sheet = Image.new("RGB", (cols * CW + pad * (cols + 1), rows * (CH + lh) + pad), (12, 14, 18))
d = ImageDraw.Draw(sheet)
for i, (f, lbl) in enumerate(items):
    p = os.path.join(D, f + ".png")
    orig = Image.open(p)
    im = orig.convert("RGB")
    im.thumbnail((CW, CH))
    c, r = i % cols, i // cols
    x, y = pad + c * (CW + pad), pad + r * (CH + lh)
    sheet.paste(im, (x + (CW - im.width) // 2, y + lh))
    d.text((x + 4, y + 5), "%s  %s" % (lbl, orig.size), fill=(120, 230, 240))
out = r"C:\Users\Administrator\mecha-forge\cine\_gemini_review.png"
sheet.save(out)
print("ok", out)
