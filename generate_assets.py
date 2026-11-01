import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = r"q:\GODOT WORKS\echo-thief\assets"
os.makedirs(OUT_DIR, exist_ok=True)

# 1. Light Circle (256x256) - Radial gradient for PointLight2D
def create_light_circle():
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    center = size / 2.0
    radius = size / 2.0
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            dx = x - center
            dy = y - center
            dist = math.hypot(dx, dy)
            if dist < radius:
                # Smooth cosine falloff
                factor = 0.5 * (1.0 + math.cos(math.pi * (dist / radius)))
                alpha = int(255 * factor)
                pixels[x, y] = (255, 255, 255, alpha)
    img.save(os.path.join(OUT_DIR, "light_circle.png"))

# 2. Light Cone (256x256) - Flashlight cone pointing to the right (+X)
def create_light_cone():
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Origin at (16, 128) pointing right
    ox, oy = 16.0, 128.0
    max_range = 230.0
    max_angle = math.radians(35) # 70 degree cone total
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            dx = x - ox
            dy = y - oy
            dist = math.hypot(dx, dy)
            if 0 < dist < max_range and dx > 0:
                angle = abs(math.atan2(dy, dx))
                if angle < max_angle:
                    dist_factor = (1.0 - (dist / max_range)) ** 1.5
                    angle_factor = math.cos((angle / max_angle) * (math.pi / 2))
                    alpha = int(255 * dist_factor * angle_factor)
                    pixels[x, y] = (255, 255, 230, alpha)
    img.save(os.path.join(OUT_DIR, "light_cone.png"))

# 3. Sonar Ring (256x256) - Wave pulse ring
def create_sonar_ring():
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    center = size / 2.0
    ring_radius = 110.0
    ring_thickness = 14.0
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            dx = x - center
            dy = y - center
            dist = math.hypot(dx, dy)
            diff = abs(dist - ring_radius)
            if diff < ring_thickness:
                factor = 1.0 - (diff / ring_thickness)
                alpha = int(255 * (factor ** 2))
                pixels[x, y] = (120, 240, 255, alpha)
    img.save(os.path.join(OUT_DIR, "sonar_ring.png"))

# 4. Player Sprite (64x64, facing +X)
def create_player():
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Body (dark stealth cloak)
    draw.ellipse([14, 18, 46, 46], fill=(30, 36, 48), outline=(60, 75, 95), width=2)
    # Head / Hood
    draw.ellipse([20, 20, 44, 44], fill=(20, 24, 32), outline=(40, 50, 65), width=1)
    # Glowing audio visor / goggles facing right
    draw.rounded_rectangle([38, 26, 46, 38], radius=2, fill=(60, 255, 180), outline=(20, 180, 100))
    # Subtle shoulder pads
    draw.ellipse([24, 14, 38, 22], fill=(45, 54, 70))
    draw.ellipse([24, 42, 38, 50], fill=(45, 54, 70))
    img.save(os.path.join(OUT_DIR, "player.png"))

# 5. Guard Sprite (64x64, facing +X)
def create_guard():
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Body (Navy security uniform)
    draw.ellipse([14, 16, 46, 48], fill=(25, 45, 85), outline=(50, 80, 140), width=2)
    # Head with security cap
    draw.ellipse([20, 20, 44, 44], fill=(210, 180, 150))
    # Cap visor facing right
    draw.arc([22, 20, 48, 44], start=-60, end=60, fill=(15, 25, 55), width=6)
    # Flashlight in hand
    draw.rectangle([40, 38, 54, 46], fill=(70, 70, 80), outline=(30, 30, 35))
    draw.ellipse([52, 39, 56, 45], fill=(255, 250, 160)) # bulb
    img.save(os.path.join(OUT_DIR, "guard.png"))

# 6. Pebble (32x32)
def create_pebble():
    size = 32
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 9, 24, 23], fill=(130, 135, 145), outline=(75, 80, 90), width=2)
    draw.ellipse([12, 11, 18, 16], fill=(190, 195, 205)) # highlight
    img.save(os.path.join(OUT_DIR, "pebble.png"))

# 7. Artifact (64x64) - Royal Diamond on Gold Stand
def create_artifact():
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Pedestal plate
    draw.ellipse([12, 42, 52, 56], fill=(180, 140, 40), outline=(240, 200, 70), width=2)
    # Glowing jewel (hexagonal cut)
    pts = [(32, 14), (48, 26), (42, 44), (22, 44), (16, 26)]
    draw.polygon(pts, fill=(255, 60, 100), outline=(255, 180, 200), width=2)
    # Inner facet
    draw.polygon([(32, 20), (40, 28), (36, 38), (28, 38), (24, 28)], fill=(255, 140, 170))
    img.save(os.path.join(OUT_DIR, "artifact.png"))

# 8. Carpet Tile (64x64)
def create_carpet():
    size = 64
    img = Image.new("RGBA", (size, size), (130, 30, 40, 255))
    draw = ImageDraw.Draw(img)
    # Gold border
    draw.rectangle([3, 3, 60, 60], outline=(200, 160, 60), width=3)
    # Corner ornaments
    draw.rectangle([8, 8, 16, 16], fill=(160, 45, 55))
    draw.rectangle([48, 8, 56, 16], fill=(160, 45, 55))
    draw.rectangle([8, 48, 16, 56], fill=(160, 45, 55))
    draw.rectangle([48, 48, 56, 56], fill=(160, 45, 55))
    img.save(os.path.join(OUT_DIR, "carpet.png"))

# 9. Broken Glass Tile (64x64)
def create_glass():
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Shards
    shards = [
        [(15, 10), (25, 8), (20, 22)],
        [(35, 14), (50, 20), (42, 28)],
        [(10, 35), (28, 45), (18, 52)],
        [(38, 40), (55, 38), (48, 55)],
        [(24, 25), (32, 36), (22, 38)],
        [(45, 8), (58, 12), (52, 18)]
    ]
    for shard in shards:
        draw.polygon(shard, fill=(180, 240, 255, 200), outline=(255, 255, 255, 240))
    img.save(os.path.join(OUT_DIR, "glass_debris.png"))

# 10. Wall Tile (64x64)
def create_wall():
    size = 64
    img = Image.new("RGBA", (size, size), (40, 44, 52, 255))
    draw = ImageDraw.Draw(img)
    # Brick lines
    draw.line([(0, 31), (63, 31)], fill=(25, 28, 35), width=2)
    draw.line([(0, 63), (63, 63)], fill=(25, 28, 35), width=2)
    draw.line([(31, 0), (31, 31)], fill=(25, 28, 35), width=2)
    draw.line([(15, 32), (15, 63)], fill=(25, 28, 35), width=2)
    draw.line([(47, 32), (47, 63)], fill=(25, 28, 35), width=2)
    # Bevel
    draw.rectangle([0, 0, 63, 63], outline=(60, 65, 78), width=1)
    img.save(os.path.join(OUT_DIR, "wall.png"))

# 11. Floor Tile (64x64)
def create_floor():
    size = 64
    img = Image.new("RGBA", (size, size), (75, 55, 40, 255))
    draw = ImageDraw.Draw(img)
    # Wooden planks
    draw.line([(0, 16), (63, 16)], fill=(55, 38, 25), width=2)
    draw.line([(0, 32), (63, 32)], fill=(55, 38, 25), width=2)
    draw.line([(0, 48), (63, 48)], fill=(55, 38, 25), width=2)
    draw.line([(0, 63), (63, 63)], fill=(55, 38, 25), width=2)
    draw.line([(28, 0), (28, 16)], fill=(55, 38, 25), width=2)
    draw.line([(45, 16), (45, 32)], fill=(55, 38, 25), width=2)
    draw.line([(20, 32), (20, 48)], fill=(55, 38, 25), width=2)
    draw.line([(50, 48), (50, 64)], fill=(55, 38, 25), width=2)
    img.save(os.path.join(OUT_DIR, "floor.png"))

# 12. Virtual Joystick Textures
def create_joystick():
    # Base (160x160)
    base = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    d_base = ImageDraw.Draw(base)
    d_base.ellipse([6, 6, 154, 154], fill=(20, 30, 45, 110), outline=(80, 140, 200, 180), width=3)
    d_base.ellipse([30, 30, 130, 130], outline=(80, 140, 200, 70), width=1)
    base.save(os.path.join(OUT_DIR, "joystick_base.png"))

    # Knob (72x72)
    knob = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
    d_knob = ImageDraw.Draw(knob)
    d_knob.ellipse([4, 4, 68, 68], fill=(60, 180, 240, 210), outline=(180, 235, 255, 250), width=3)
    d_knob.ellipse([18, 18, 54, 54], fill=(90, 210, 255, 240))
    knob.save(os.path.join(OUT_DIR, "joystick_knob.png"))

# 13. Alert Icons (? and !)
def create_alert_icons():
    # Question icon (32x32)
    q = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    dq = ImageDraw.Draw(q)
    dq.ellipse([2, 2, 30, 30], fill=(230, 180, 30), outline=(255, 230, 100), width=2)
    dq.arc([10, 6, 22, 18], start=160, end=20, fill=(20, 20, 20), width=3)
    dq.line([(16, 17), (16, 21)], fill=(20, 20, 20), width=3)
    dq.rectangle([15, 24, 17, 26], fill=(20, 20, 20))
    q.save(os.path.join(OUT_DIR, "alert_question.png"))

    # Exclamation icon (32x32)
    e = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    de = ImageDraw.Draw(e)
    de.ellipse([2, 2, 30, 30], fill=(225, 45, 45), outline=(255, 120, 120), width=2)
    de.line([(16, 7), (16, 19)], fill=(255, 255, 255), width=3)
    de.rectangle([15, 22, 17, 25], fill=(255, 255, 255))
    e.save(os.path.join(OUT_DIR, "alert_exclamation.png"))

if __name__ == "__main__":
    create_light_circle()
    create_light_cone()
    create_sonar_ring()
    create_player()
    create_guard()
    create_pebble()
    create_artifact()
    create_carpet()
    create_glass()
    create_wall()
    create_floor()
    create_joystick()
    create_alert_icons()
    print("All assets generated successfully!")
