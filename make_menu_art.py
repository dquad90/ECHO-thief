import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = r"q:\GODOT WORKS\echo-thief\assets"
os.makedirs(OUT_DIR, exist_ok=True)

def generate_menu_bg():
    w, h = 1280, 720
    img = Image.new("RGBA", (w, h), (10, 12, 18, 255))
    draw = ImageDraw.Draw(img)
    
    # 1. Subtle tactical grid
    grid_color = (25, 55, 75, 45)
    for x in range(0, w, 40):
        draw.line([(x, 0), (x, h)], fill=grid_color, width=1)
    for y in range(0, h, 40):
        draw.line([(0, y), (w, y)], fill=grid_color, width=1)
    
    # 2. Concentric radar circles from center
    cx, cy = w // 2, h // 2
    for r in [120, 240, 360, 480, 600]:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(35, 80, 110, 40), width=1)
    
    # 3. Tactical crosshair lines across center
    draw.line([(cx - 200, cy), (cx + 200, cy)], fill=(40, 100, 130, 35), width=1)
    draw.line([(cx, cy - 150), (cx, cy + 150)], fill=(40, 100, 130, 35), width=1)
    
    # 4. Corner bracket accents
    bracket_color = (0, 180, 220, 70)
    for (bx, by, dx, dy) in [
        (40, 40, 1, 1),
        (w - 40, 40, -1, 1),
        (40, h - 40, 1, -1),
        (w - 40, h - 40, -1, -1)
    ]:
        draw.line([(bx, by), (bx + 30 * dx, by)], fill=bracket_color, width=2)
        draw.line([(bx, by), (bx, by + 30 * dy)], fill=bracket_color, width=2)
    
    # 5. Vignette mask for depth
    vignette = Image.new("L", (w, h), 0)
    v_draw = ImageDraw.Draw(vignette)
    max_d = math.hypot(w / 2, h / 2)
    # create smooth radial gradient
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            dist = math.hypot(x - cx, y - cy)
            val = int(255 * (1.0 - min(dist / max_d, 1.0) ** 1.8))
            v_draw.point((x, y), val)
            v_draw.point((x+1, y), val)
            v_draw.point((x, y+1), val)
            v_draw.point((x+1, y+1), val)
    
    vignette = vignette.filter(ImageFilter.GaussianBlur(12))
    
    # Composite dark tint
    dark_overlay = Image.new("RGBA", (w, h), (4, 6, 10, 255))
    final_img = Image.composite(img, dark_overlay, vignette)
    
    final_img.save(os.path.join(OUT_DIR, "menu_bg.png"))
    print("Created menu_bg.png successfully")

def generate_thief_emblem():
    size = 180
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    # Outer glowing ring
    draw.ellipse([8, 8, size - 8, size - 8], outline=(40, 180, 220, 180), width=3)
    draw.ellipse([14, 14, size - 14, size - 14], outline=(20, 100, 140, 90), width=1)
    
    # Top and bottom ticks
    draw.line([(cx, 2), (cx, 12)], fill=(0, 240, 255, 255), width=2)
    draw.line([(cx, size - 12), (cx, size - 2)], fill=(0, 240, 255, 255), width=2)
    draw.line([(2, cy), (12, cy)], fill=(0, 240, 255, 255), width=2)
    draw.line([(size - 12, cy), (size - 2, cy)], fill=(0, 240, 255, 255), width=2)
    
    # Thief hood & mask silhouette (stylized vector)
    # Head
    draw.ellipse([cx - 36, cy - 36, cx + 36, cy + 36], fill=(15, 30, 45, 240), outline=(0, 220, 255, 220), width=2)
    
    # Glowing Goggles / Visor
    draw.rounded_rectangle([cx - 26, cy - 8, cx + 26, cy + 8], radius=6, fill=(0, 230, 255, 240), outline=(255, 255, 255, 220), width=2)
    draw.line([(cx - 4, cy - 8), (cx - 4, cy + 8)], fill=(10, 40, 60, 255), width=2)
    draw.line([(cx + 4, cy - 8), (cx + 4, cy + 8)], fill=(10, 40, 60, 255), width=2)
    
    # Audio waves on sides of head
    for r, a in [(46, 180), (54, 130), (62, 80)]:
        # Left waves
        draw.arc([cx - r - 8, cy - 24, cx - r + 24, cy + 24], start=135, end=225, fill=(0, 230, 255, a), width=2)
        # Right waves
        draw.arc([cx + r - 24, cy - 24, cx + r + 8, cy + 24], start=-45, end=45, fill=(0, 230, 255, a), width=2)
    
    img.save(os.path.join(OUT_DIR, "thief_emblem.png"))
    print("Created thief_emblem.png successfully")

if __name__ == "__main__":
    generate_menu_bg()
    generate_thief_emblem()
