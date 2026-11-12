import math
from PIL import Image, ImageDraw, ImageFont

# Canvas representing 3x3 chunks (3600 x 3600 px) scaled down for preview (1800 x 1800)
W, H = 1800, 1800
CHUNK = 1200.0
SCALE = 0.5  # 1200 -> 600 px per chunk

img = Image.new("RGBA", (W, H), (20, 24, 30, 255))
draw = ImageDraw.Draw(img)

# Draw chunk grid lines
for i in range(4):
    pos = int(i * 600)
    draw.line([(pos, 0), (pos, H)], fill=(40, 50, 65, 255), width=2)
    draw.line([(0, pos), (W, pos)], fill=(40, 50, 65, 255), width=2)

def to_screen(gx, gy):
    # center is (900, 900)
    sx = 900 + gx * SCALE
    sy = 900 + gy * SCALE
    return sx, sy

def draw_wall_h(x, y, color=(70, 90, 120, 255)):
    sx, sy = to_screen(x, y)
    w, h = 260.0 * SCALE, 90.0 * SCALE
    draw.rectangle([sx - w/2, sy - h/2, sx + w/2, sy + h/2], fill=color, outline=(140, 180, 220, 255), width=2)

def draw_wall_v(x, y, color=(70, 90, 120, 255)):
    sx, sy = to_screen(x, y)
    w, h = 90.0 * SCALE, 260.0 * SCALE
    draw.rectangle([sx - w/2, sy - h/2, sx + w/2, sy + h/2], fill=color, outline=(140, 180, 220, 255), width=2)

def draw_pillar(x, y, ptype="vent"):
    sx, sy = to_screen(x, y)
    if ptype == "reactor":
        r = 75.0 * SCALE
        draw.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(0, 160, 220, 255), outline=(100, 240, 255, 255), width=3)
        draw.ellipse([sx - r*0.4, sy - r*0.4, sx + r*0.4, sy + r*0.4], fill=(220, 255, 255, 255))
    else:
        s = 150.0 * SCALE
        draw.rectangle([sx - s/2, sy - s/2, sx + s/2, sy + s/2], fill=(60, 75, 95, 255), outline=(200, 210, 225, 255), width=2)
        draw.line([sx - s/2, sy - s/2, sx + s/2, sy + s/2], fill=(100, 120, 140, 255), width=1)
        draw.line([sx - s/2, sy + s/2, sx + s/2, sy - s/2], fill=(100, 120, 140, 255), width=1)

def draw_barrier(x, y):
    sx, sy = to_screen(x, y)
    w, h = 190.0 * SCALE, 55.0 * SCALE
    draw.rectangle([sx - w/2, sy - h/2, sx + w/2, sy + h/2], fill=(180, 140, 40, 255), outline=(255, 220, 80, 255), width=2)

def draw_cannon(x, y, aim_deg):
    sx, sy = to_screen(x, y)
    r = 50.0 * SCALE
    # Base circle
    draw.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(160, 40, 30, 255), outline=(255, 100, 80, 255), width=2)
    # Barrel line
    rad = math.radians(aim_deg)
    bx = sx + math.cos(rad) * (r * 2.2)
    by = sy + math.sin(rad) * (r * 2.2)
    draw.line([sx, sy, bx, by], fill=(255, 120, 40, 255), width=4)
    # Firing cone (telegraph)
    arc = math.radians(30.0)
    c1x = sx + math.cos(rad - arc) * 120 * SCALE
    c1y = sy + math.sin(rad - arc) * 120 * SCALE
    c2x = sx + math.cos(rad + arc) * 120 * SCALE
    c2y = sy + math.sin(rad + arc) * 120 * SCALE
    draw.polygon([(sx, sy), (c1x, c1y), (c2x, c2y)], fill=(255, 100, 50, 40))

# ----------------- CHUNKS SIMULATION -----------------
# Central Hub at (0, 0)
def build_central_hub(ox, oy):
    # North terminal wall
    draw_wall_h(ox - 140, oy - 280, (50, 100, 140, 255))
    draw_wall_h(ox + 100, oy - 280, (50, 100, 140, 255))
    draw_pillar(ox - 280, oy - 280, "vent")
    draw_pillar(ox + 240, oy - 280, "vent")
    # West conduit wing
    draw_wall_v(ox - 280, oy - 140, (50, 120, 130, 255))
    draw_pillar(ox - 280, oy, "vent")
    # East generator platform
    draw_wall_v(ox + 240, oy - 140, (70, 90, 120, 255))
    draw_pillar(ox + 240, oy, "vent")
    # Central reactor core offset slightly north of spawn
    draw_pillar(ox, oy - 80, "reactor")
    draw_barrier(ox, oy + 20)
    # Defense Cannons at strategic chokepoints
    draw_cannon(ox + 220, oy + 160, 135.0)  # guards South-East avenue
    draw_cannon(ox - 220, oy - 160, 315.0)  # guards North-West avenue

# Archetype 0: Power Substation (L-shaped)
def build_power_substation(ox, oy):
    # West generator hall
    draw_wall_h(ox - 120, oy - 240, (50, 100, 140, 255))
    draw_pillar(ox - 260, oy - 240, "vent")
    draw_wall_v(ox - 260, oy - 100, (50, 120, 130, 255))
    draw_wall_v(ox - 260, oy + 100, (50, 120, 130, 255))
    draw_pillar(ox - 260, oy + 240, "vent")
    draw_wall_h(ox - 120, oy + 240, (140, 100, 40, 255))
    draw_pillar(ox + 20, oy + 240, "vent")
    # Inner reactor core
    draw_pillar(ox - 120, oy, "reactor")
    draw_barrier(ox - 120, oy + 100)
    # East substation yard
    draw_pillar(ox + 260, oy - 120, "vent")
    draw_barrier(ox + 160, oy - 120)
    # Defense Cannon guarding eastern approach avenue
    draw_cannon(ox + 220, oy + 140, 120.0)

# Archetype 1: Cooling Facility (Staggered)
def build_cooling_facility(ox, oy):
    # North-East cooling flank
    draw_wall_h(ox + 80, oy - 240, (140, 100, 40, 255))
    draw_pillar(ox + 240, oy - 240, "vent")
    draw_pillar(ox - 60, oy - 240, "vent")
    draw_wall_v(ox + 240, oy - 100, (140, 100, 40, 255))
    # South-West intake wing
    draw_wall_v(ox - 240, oy + 40, (50, 120, 130, 255))
    draw_pillar(ox - 240, oy + 180, "vent")
    draw_wall_h(ox - 100, oy + 180, (140, 100, 40, 255))
    # Turbines
    draw_pillar(ox + 40, oy - 40, "reactor")
    draw_pillar(ox - 80, oy + 40, "vent")
    draw_barrier(ox + 140, oy + 80)
    # Defense Cannon guarding western crossroad
    draw_cannon(ox - 180, oy - 120, 210.0)

# Archetype 2: Warehouse Bay (Wide depot + East dock)
def build_warehouse_bay(ox, oy):
    # Main storage hall
    draw_wall_h(ox - 140, oy - 240, (70, 90, 120, 255))
    draw_pillar(ox - 280, oy - 240, "vent")
    draw_wall_v(ox - 280, oy - 80, (70, 90, 120, 255))
    draw_wall_v(ox - 280, oy + 120, (70, 90, 120, 255))
    draw_pillar(ox - 280, oy + 240, "vent")
    draw_wall_h(ox - 140, oy + 240, (140, 100, 40, 255))
    # East cargo platform
    draw_pillar(ox + 80, oy - 140, "reactor")
    draw_pillar(ox + 240, oy - 140, "vent")
    draw_barrier(ox - 60, oy)
    draw_barrier(ox + 60, oy + 80)
    # Defense Cannon protecting the loading dock
    draw_cannon(ox + 240, oy + 140, 60.0)

# Archetype 3: Security Bastion (Chicane roadblock)
def build_security_bastion(ox, oy):
    # North-West deflector
    draw_pillar(ox - 260, oy - 180, "vent")
    draw_wall_h(ox - 100, oy - 180, (140, 100, 40, 255))
    draw_pillar(ox + 40, oy - 180, "vent")
    # South-East deflector
    draw_pillar(ox - 40, oy + 180, "vent")
    draw_wall_h(ox + 100, oy + 180, (140, 100, 40, 255))
    draw_pillar(ox + 260, oy + 180, "vent")
    # Central security terminal
    draw_pillar(ox, oy, "reactor")
    draw_wall_v(ox - 160, oy + 40, (140, 100, 40, 255))
    # Defense Cannon covering the chicane bottleneck
    draw_cannon(ox + 140, oy - 60, 180.0)

# Archetype 4: Refinery Complex (Pipeline & tanks)
def build_refinery_complex(ox, oy):
    # Northwest reactor cracking alcove
    draw_pillar(ox - 180, oy - 160, "reactor")
    draw_wall_h(ox - 60, oy - 220, (50, 100, 140, 255))
    draw_pillar(ox - 240, oy - 60, "vent")
    draw_wall_v(ox - 60, oy - 80, (50, 120, 130, 255))
    # Plasma conduit pipeline
    draw_wall_h(ox + 100, oy - 60, (50, 120, 130, 255))
    draw_pillar(ox + 220, oy - 60, "vent")
    # Southern tank farm
    draw_pillar(ox + 140, oy + 180, "vent")
    draw_barrier(ox, oy + 180)
    # Defense Cannon
    draw_cannon(ox + 200, oy + 80, 90.0)

# Archetype 5: Repair Hangar (3-sided workshop)
def build_repair_hangar(ox, oy):
    # North diagnostic wall
    draw_wall_h(ox - 140, oy - 220, (50, 100, 140, 255))
    draw_wall_h(ox + 80, oy - 220, (50, 100, 140, 255))
    draw_pillar(ox - 280, oy - 220, "vent")
    draw_pillar(ox + 220, oy - 220, "vent")
    # West tool wall
    draw_wall_v(ox - 280, oy - 60, (50, 120, 130, 255))
    draw_pillar(ox - 280, oy + 100, "vent")
    # Charging station
    draw_pillar(ox - 80, oy, "reactor")
    draw_barrier(ox + 60, oy)
    draw_barrier(ox - 100, oy + 140)
    # Defense Cannon guarding the hangar bay door
    draw_cannon(ox + 220, oy + 80, 45.0)

# Render 3x3 layout:
# (-1,-1): Arch 0 | (0,-1): Arch 1 | (1,-1): Arch 2
# (-1, 0): Arch 3 | (0, 0): Hub    | (1, 0): Arch 4
# (-1, 1): Arch 5 | (0, 1): Arch 0 | (1, 1): Arch 1

build_power_substation(-1200, -1200)
build_cooling_facility(0, -1200)
build_warehouse_bay(1200, -1200)

build_security_bastion(-1200, 0)
build_central_hub(0, 0)
build_refinery_complex(1200, 0)

build_repair_hangar(-1200, 1200)
build_power_substation(0, 1200)
build_cooling_facility(1200, 1200)

out_path = "C:/Users/Administrator/.gemini/antigravity-ide/brain/57e87bbd-6285-4159-a061-1b83a072c5b4/test_asym_3x3_with_cannons.png"
img.save(out_path)
print("Saved 3x3 layout test to:", out_path)
