import os
from PIL import Image

src_dir = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\e26b9fa8-c0c4-4c36-a205-58749b2eeeaf"
dest_dir = r"C:\Users\Administrator\mecha-forge\game\assets\decor"

files = [
    ("ground_tech_1791186177915.png", "ground_tech.png", False),
    ("g_cyber_reactor_1791186188403.png", "g_cyber_reactor.png", True),
    ("g_cyber_pillar_1791186199463.png", "g_cyber_pillar.png", True),
    ("g_cyber_crate_1791186213242.png", "g_cyber_crate.png", True),
]

for src_name, dest_name, make_transparent in files:
    src_path = os.path.join(src_dir, src_name)
    dest_path = os.path.join(dest_dir, dest_name)
    
    if not os.path.exists(src_path):
        print(f"Skipping {src_name}, not found.")
        continue
        
    img = Image.open(src_path).convert("RGBA")
    
    if make_transparent:
        data = img.getdata()
        new_data = []
        for item in data:
            # Check for white or near-white
            if item[0] > 240 and item[1] > 240 and item[2] > 240:
                new_data.append((255, 255, 255, 0))
            else:
                new_data.append(item)
        img.putdata(new_data)
        
    img.save(dest_path)
    print(f"Saved {dest_name}")
