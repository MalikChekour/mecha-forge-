import os
from PIL import Image

src_dir = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\f4d60812-8c84-40f0-9aad-921d86be3fca"
dest_dir = r"C:\Users\Administrator\mecha-forge\game\assets\chapters"

mapping = {
    "chap_10_abyss.jpg": "chap_abyss_banner_1792418056832.jpg",
    "chap_11_ether.jpg": "chap_psyche_banner_1792418083370.jpg",
    "chap_12_titans.jpg": "chap_titans_banner_1792418102887.jpg",
    "chap_13_orbit.jpg": "chap_orbit_banner_1792418123515.jpg",
    "chap_14_quantum.jpg": "chap_quantum_banner_1792418145390.jpg",
    "chap_15_ozone.jpg": "chap_ozone_banner_1792418164547.jpg",
    "chap_16_prism.jpg": "chap_prism_banner_1792418185629.jpg",
    "chap_17_steampunk.jpg": "chap_steampunk_banner_1792418206800.jpg",
    "chap_18_colosseum.jpg": "chap_colosseum_banner_1792418226306.jpg",
}

for dest_name, src_name in mapping.items():
    src_path = os.path.join(src_dir, src_name)
    dest_path = os.path.join(dest_dir, dest_name)
    if not os.path.exists(src_path):
        print(f"Error: {src_path} does not exist!")
        continue
    img = Image.open(src_path)
    # Resize with high-quality Lanczos to match 960x536
    resized = img.resize((960, 536), Image.Resampling.LANCZOS)
    resized.save(dest_path, "JPEG", quality=92, optimize=True)
    print(f"Deployed {dest_name} (from {src_name}) -> {resized.size}")

print("All 9 chapter banners successfully deployed!")
