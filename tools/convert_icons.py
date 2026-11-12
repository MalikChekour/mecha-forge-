import os
import glob
from PIL import Image

icons_dir = r"C:\Users\Administrator\mecha-forge\game\assets\icons"
png_files = glob.glob(os.path.join(icons_dir, "*.png"))

print(f"Found {len(png_files)} icons to convert in {icons_dir}")

for p in png_files:
    if p.endswith(".import"):
        continue
    with Image.open(p) as img:
        print(f"Converting {os.path.basename(p)}: format={img.format}, size={img.size}, mode={img.mode}")
        # Convert to RGBA
        rgba = img.convert("RGBA")
        # Resize to clean 128x128 crisp game icon
        resized = rgba.resize((128, 128), Image.Resampling.LANCZOS)
        # Save as genuine PNG
        resized.save(p, format="PNG", optimize=True)
        print(f"  -> Saved genuine PNG 128x128: {os.path.getsize(p)} bytes")

# Remove obsolete .import files so Godot reimports clean PNGs
for imp in glob.glob(os.path.join(icons_dir, "*.import")):
    os.remove(imp)
    print(f"Removed stale import: {os.path.basename(imp)}")

print("Done converting icons!")
