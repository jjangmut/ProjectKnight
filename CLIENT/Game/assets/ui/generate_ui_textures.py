"""
High-Resolution Fantasy Action RPG UI Texture Pack Generator
Inspired by classic mobile action RPG masterpieces:
- Dungeon Hunter 1 & 2 (Gothic winged filigree, forged brass bezels, ruby crystal gauges)
- Zenonia / Inotia (Parchment scrolls, heraldic knight crests, faceted soul gems)
- Third Blade (Dynamic metallic slash frames, vibrant combo badges)
- Solomon's Boneyard / Pocket RPG (Rune compass disks, crystal orb knobs)
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = "CLIENT/Game/assets/ui"
os.makedirs(OUTPUT_DIR, exist_ok=True)


def create_radial_gradient(size, inner_color, outer_color, center=None, radius=None):
    """Generates a smooth RGBA radial gradient image."""
    w, h = size
    if center is None:
        cx, cy = w / 2.0, h / 2.0
    else:
        cx, cy = center
    if radius is None:
        radius = min(w, h) / 2.0

    img = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = img.load()

    for y in range(h):
        for x in range(w):
            dist = math.hypot(x - cx, y - cy)
            t = min(max(dist / radius, 0.0), 1.0)
            # Smoothstep
            t = t * t * (3.0 - 2.0 * t)
            r = int(inner_color[0] + (outer_color[0] - inner_color[0]) * t)
            g = int(inner_color[1] + (outer_color[1] - inner_color[1]) * t)
            b = int(inner_color[2] + (outer_color[2] - inner_color[2]) * t)
            a = int(inner_color[3] + (outer_color[3] - inner_color[3]) * t)
            pixels[x, y] = (r, g, b, a)
    return img


# ==============================================================================
# 1. Joypad Base (256x256) - Dark Obsidian Rune Disk with Forged Brass Bezel
# ==============================================================================
def generate_joypad_base():
    size = (256, 256)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 128, 128

    # Outer Drop Shadow
    for r in range(124, 114, -1):
        alpha = int(40 * (124 - r) / 10.0)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, alpha))

    # Forged Brass Outer Bezel Rim
    outer_grad = create_radial_gradient(size, (215, 180, 110, 230), (110, 80, 35, 230), (cx, cy), 116)
    mask = Image.new("L", size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse([cx - 116, cy - 116, cx + 116, cy + 116], fill=255)
    mask_draw.ellipse([cx - 98, cy - 98, cx + 98, cy + 98], fill=0)
    img.paste(outer_grad, (0, 0), mask)

    # Bevel Highlight Wire
    draw.ellipse([cx - 115, cy - 115, cx + 115, cy + 115], outline=(255, 235, 170, 240), width=2)
    draw.ellipse([cx - 99, cy - 99, cx + 99, cy + 99], outline=(60, 45, 20, 220), width=2)

    # Translucent Obsidian Glass Core Plate
    core_grad = create_radial_gradient(size, (28, 38, 54, 180), (10, 14, 22, 220), (cx, cy), 98)
    core_mask = Image.new("L", size, 0)
    core_mask_draw = ImageDraw.Draw(core_mask)
    core_mask_draw.ellipse([cx - 98, cy - 98, cx + 98, cy + 98], fill=255)
    img.paste(core_grad, (0, 0), core_mask)

    # Inner Rune Ring
    draw.ellipse([cx - 72, cy - 72, cx + 72, cy + 72], outline=(180, 150, 95, 140), width=2)
    draw.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], outline=(140, 120, 80, 100), width=1)

    # 8-Directional Rune Compass Marks
    directions = [0, 45, 90, 135, 180, 225, 270, 315]
    for angle in directions:
        rad = math.radians(angle)
        # Major cardinal vs diagonal
        is_cardinal = (angle % 90 == 0)
        dist_out = 92
        dist_in = 76 if is_cardinal else 82
        p1 = (cx + dist_out * math.cos(rad), cy + dist_out * math.sin(rad))
        p2 = (cx + dist_in * math.cos(rad), cy + dist_in * math.sin(rad))
        line_col = (255, 225, 140, 220) if is_cardinal else (190, 160, 105, 150)
        draw.line([p1, p2], fill=line_col, width=3 if is_cardinal else 2)

        # Rune Diamond Pointers on Cardinals
        if is_cardinal:
            mid = (cx + 84 * math.cos(rad), cy + 84 * math.sin(rad))
            pr = math.radians(angle + 90)
            d1 = (mid[0] + 4 * math.cos(rad), mid[1] + 4 * math.sin(rad))
            d2 = (mid[0] + 3 * math.cos(pr), mid[1] + 3 * math.sin(pr))
            d3 = (mid[0] - 4 * math.cos(rad), mid[1] - 4 * math.sin(rad))
            d4 = (mid[0] - 3 * math.cos(pr), mid[1] - 3 * math.sin(pr))
            draw.polygon([d1, d2, d3, d4], fill=(255, 215, 110, 240))

    # Top Arrow Glyph (Jump)
    jump_pts = [
        (cx, cy - 90),
        (cx + 8, cy - 78),
        (cx + 3, cy - 78),
        (cx + 3, cy - 70),
        (cx - 3, cy - 70),
        (cx - 3, cy - 78),
        (cx - 8, cy - 78)
    ]
    draw.polygon(jump_pts, fill=(255, 235, 160, 240), outline=(80, 55, 20, 200))

    img.save(os.path.join(OUTPUT_DIR, "joypad_base.png"))
    print("-> joypad_base.png generated")


# ==============================================================================
# 2. Joypad Knob (128x128) - 3D Sapphire Crystal Orb with Gold Crown Claws
# ==============================================================================
def generate_joypad_knob():
    size = (128, 128)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 64, 64

    # Drop shadow
    for r in range(62, 54, -1):
        alpha = int(45 * (62 - r) / 8.0)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, alpha))

    # Gold Base Bezel
    gold_grad = create_radial_gradient(size, (240, 205, 130, 255), (120, 85, 35, 255), (cx, cy), 54)
    g_mask = Image.new("L", size, 0)
    g_draw = ImageDraw.Draw(g_mask)
    g_draw.ellipse([cx - 54, cy - 54, cx + 54, cy + 54], fill=255)
    img.paste(gold_grad, (0, 0), g_mask)
    draw.ellipse([cx - 53, cy - 53, cx + 53, cy + 53], outline=(255, 240, 180, 255), width=2)

    # 3D Sapphire/Aqua Crystal Dome
    core_size = (128, 128)
    core_grad = create_radial_gradient(core_size, (110, 220, 255, 255), (15, 45, 90, 255), (cx - 10, cy - 12), 46)
    c_mask = Image.new("L", size, 0)
    c_draw = ImageDraw.Draw(c_mask)
    c_draw.ellipse([cx - 44, cy - 44, cx + 44, cy + 44], fill=255)
    img.paste(core_grad, (0, 0), c_mask)

    # Inner Gold Petal Mount Claws
    for angle in [0, 90, 180, 270]:
        rad = math.radians(angle)
        pr = math.radians(angle + 90)
        tip = (cx + 44 * math.cos(rad), cy + 44 * math.sin(rad))
        in_p = (cx + 34 * math.cos(rad), cy + 34 * math.sin(rad))
        w1 = (in_p[0] + 6 * math.cos(pr), in_p[1] + 6 * math.sin(pr))
        w2 = (in_p[0] - 6 * math.cos(pr), in_p[1] - 6 * math.sin(pr))
        draw.polygon([tip, w1, (cx + 26 * math.cos(rad), cy + 26 * math.sin(rad)), w2], fill=(235, 195, 110, 240), outline=(70, 50, 20, 220))

    # Concentric Crystal Rings
    draw.ellipse([cx - 30, cy - 30, cx + 30, cy + 30], outline=(140, 230, 255, 160), width=1)
    draw.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], outline=(180, 245, 255, 180), width=1)

    # Brilliant Specular Glint (Top-Left)
    glint_pos = (cx - 14, cy - 16)
    draw.ellipse([glint_pos[0] - 10, glint_pos[1] - 7, glint_pos[0] + 10, glint_pos[1] + 7], fill=(255, 255, 255, 220))
    draw.ellipse([glint_pos[0] - 4, glint_pos[1] - 3, glint_pos[0] + 4, glint_pos[1] + 3], fill=(255, 255, 255, 255))
    draw.ellipse([cx + 12, cy + 16, cx + 18, cy + 22], fill=(255, 255, 255, 110))

    img.save(os.path.join(OUTPUT_DIR, "joypad_knob.png"))
    print("-> joypad_knob.png generated")


# ==============================================================================
# 3. Action Buttons: Attack (256x256), Dash (192x192), Guard (192x192)
# ==============================================================================
def generate_action_buttons():
    # --- A. ATTACK BUTTON (256x256) - Heavy Forged Gold Bezel & Crossed Blades ---
    size = (256, 256)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 128, 128

    # Outer Drop Shadow
    for r in range(126, 116, -1):
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, int(50 * (126 - r) / 10.0)))

    # Heavy Forged Gold Bezel
    gold_grad = create_radial_gradient(size, (255, 225, 140, 255), (130, 90, 30, 255), (cx - 15, cy - 20), 120)
    g_mask = Image.new("L", size, 0)
    g_draw = ImageDraw.Draw(g_mask)
    g_draw.ellipse([cx - 116, cy - 116, cx + 116, cy + 116], fill=255)
    g_draw.ellipse([cx - 92, cy - 92, cx + 92, cy + 92], fill=0)
    img.paste(gold_grad, (0, 0), g_mask)

    # Bevel lines & 4 Stud Rivets
    draw.ellipse([cx - 115, cy - 115, cx + 115, cy + 115], outline=(255, 245, 190, 255), width=2)
    draw.ellipse([cx - 93, cy - 93, cx + 93, cy + 93], outline=(60, 40, 15, 255), width=2)
    for angle in [45, 135, 225, 315]:
        rad = math.radians(angle)
        rx, ry = cx + 104 * math.cos(rad), cy + 104 * math.sin(rad)
        draw.ellipse([rx - 5, ry - 5, rx + 5, ry + 5], fill=(255, 230, 150, 255), outline=(60, 40, 15, 255))
        draw.circle((rx - 1, ry - 1), 1.5, fill=(255, 255, 255, 255))

    # Deep Crimson Ruby Core Plate
    ruby_grad = create_radial_gradient(size, (215, 35, 45, 240), (80, 10, 18, 250), (cx, cy), 92)
    r_mask = Image.new("L", size, 0)
    r_draw = ImageDraw.Draw(r_mask)
    r_draw.ellipse([cx - 92, cy - 92, cx + 92, cy + 92], fill=255)
    img.paste(ruby_grad, (0, 0), r_mask)

    # Inner Glass Highlight Arc
    draw.arc([cx - 86, cy - 86, cx + 86, cy + 86], start=190, end=350, fill=(255, 200, 210, 180), width=3)

    # Embossed Crossed Holy Blades (Silver Steel + Gold Guard)
    def draw_sword(ang):
        s_img = Image.new("RGBA", size, (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(s_img)
        # Blade centered vertically from y=48 to y=170
        blade_pts = [(cx, 48), (cx + 8, 58), (cx + 7, 138), (cx - 7, 138), (cx - 8, 58)]
        s_draw.polygon(blade_pts, fill=(240, 245, 255, 255), outline=(130, 145, 165, 255))
        s_draw.line([(cx, 50), (cx, 138)], fill=(160, 180, 205, 255), width=2)
        # Guard
        s_draw.rounded_rectangle([cx - 24, 138, cx + 24, 146], radius=2, fill=(250, 210, 110, 255), outline=(90, 65, 20, 255))
        # Hilt & Pommel
        s_draw.rectangle([cx - 4, 146, cx + 4, 166], fill=(70, 50, 30, 255))
        s_draw.ellipse([cx - 8, 166, cx + 8, 182], fill=(225, 40, 50, 255), outline=(250, 210, 110, 255))
        s_rot = s_img.rotate(ang, center=(cx, cy), resample=Image.Resampling.BICUBIC)
        img.alpha_composite(s_rot)

    draw_sword(-40)
    draw_sword(40)
    img.save(os.path.join(OUTPUT_DIR, "btn_attack.png"))
    print("-> btn_attack.png generated")

    # --- B. DASH BUTTON (192x192) - Emerald/Cyan Rune Bezel & Winged Wind Boots ---
    size_sub = (192, 192)
    img_dash = Image.new("RGBA", size_sub, (0, 0, 0, 0))
    draw_d = ImageDraw.Draw(img_dash)
    dcx, dcy = 96, 96

    # Shadow
    for r in range(94, 86, -1):
        draw_d.ellipse([dcx - r, dcy - r, dcx + r, dcy + r], fill=(0, 0, 0, int(45 * (94 - r) / 8.0)))

    # Cyan/Emerald Bezel
    cyan_bezel = create_radial_gradient(size_sub, (180, 245, 240, 255), (20, 95, 90, 255), (dcx - 10, dcy - 15), 88)
    b_mask = Image.new("L", size_sub, 0)
    b_draw = ImageDraw.Draw(b_mask)
    b_draw.ellipse([dcx - 86, dcy - 86, dcx + 86, dcy + 86], fill=255)
    b_draw.ellipse([dcx - 70, dcy - 70, dcx + 70, dcy + 70], fill=0)
    img_dash.paste(cyan_bezel, (0, 0), b_mask)
    draw_d.ellipse([dcx - 85, dcy - 85, dcx + 85, dcy + 85], outline=(230, 255, 250, 255), width=2)
    draw_d.ellipse([dcx - 71, dcy - 71, dcx + 71, dcy + 71], outline=(10, 50, 45, 255), width=2)

    # Core Plate: Dark Cyan Slate
    core_d = create_radial_gradient(size_sub, (25, 150, 145, 240), (10, 45, 50, 250), (dcx, dcy), 70)
    c_mask = Image.new("L", size_sub, 0)
    c_draw = ImageDraw.Draw(c_mask)
    c_draw.ellipse([dcx - 70, dcy - 70, dcx + 70, dcy + 70], fill=255)
    img_dash.paste(core_d, (0, 0), c_mask)

    # Winged Boot & Wind Trail Symbol
    # Wind streaks
    draw_d.line([(dcx - 45, dcy - 12), (dcx - 15, dcy - 12)], fill=(180, 255, 250, 200), width=3)
    draw_d.line([(dcx - 55, dcy), (dcx - 20, dcy)], fill=(220, 255, 255, 240), width=4)
    draw_d.line([(dcx - 45, dcy + 12), (dcx - 15, dcy + 12)], fill=(180, 255, 250, 200), width=3)

    # Winged Boot Polygon
    boot_pts = [
        (dcx - 8, dcy - 30),
        (dcx + 16, dcy - 30),
        (dcx + 18, dcy + 8),
        (dcx + 42, dcy + 16),
        (dcx + 44, dcy + 26),
        (dcx - 6, dcy + 26),
        (dcx - 6, dcy - 6),
        (dcx - 12, dcy - 12)
    ]
    draw_d.polygon(boot_pts, fill=(245, 250, 255, 255), outline=(50, 90, 110, 255))
    # Golden Wing on Boot
    wing_pts = [
        (dcx - 6, dcy - 10),
        (dcx - 30, dcy - 32),
        (dcx - 14, dcy - 18),
        (dcx - 34, dcy - 20),
        (dcx - 16, dcy - 8),
        (dcx - 30, dcy - 6),
        (dcx - 8, dcy - 2)
    ]
    draw_d.polygon(wing_pts, fill=(255, 225, 120, 255), outline=(110, 80, 25, 255))
    img_dash.save(os.path.join(OUTPUT_DIR, "btn_dash.png"))
    print("-> btn_dash.png generated")

    # --- C. GUARD BUTTON (192x192) - Cobalt Blue & Gold Royal Shield ---
    img_guard = Image.new("RGBA", size_sub, (0, 0, 0, 0))
    draw_g = ImageDraw.Draw(img_guard)

    # Shadow
    for r in range(94, 86, -1):
        draw_g.ellipse([dcx - r, dcy - r, dcx + r, dcy + r], fill=(0, 0, 0, int(45 * (94 - r) / 8.0)))

    # Royal Gold Bezel
    gold_bezel_g = create_radial_gradient(size_sub, (255, 225, 140, 255), (130, 90, 30, 255), (dcx - 10, dcy - 15), 88)
    img_guard.paste(gold_bezel_g, (0, 0), b_mask)
    draw_g.ellipse([dcx - 85, dcy - 85, dcx + 85, dcy + 85], outline=(255, 245, 190, 255), width=2)
    draw_g.ellipse([dcx - 71, dcy - 71, dcx + 71, dcy + 71], outline=(60, 40, 15, 255), width=2)

    # Core Plate: Royal Cobalt Blue
    core_g = create_radial_gradient(size_sub, (35, 95, 205, 240), (12, 28, 65, 250), (dcx, dcy), 70)
    img_guard.paste(core_g, (0, 0), c_mask)

    # Embossed Heraldic Shield Symbol
    shield_pts = [
        (dcx, dcy - 34),
        (dcx + 28, dcy - 26),
        (dcx + 24, dcy + 10),
        (dcx, dcy + 36),
        (dcx - 24, dcy + 10),
        (dcx - 28, dcy - 26)
    ]
    draw_g.polygon(shield_pts, fill=(230, 240, 255, 255), outline=(40, 60, 95, 255))
    # Inner Gold Cross on Shield
    draw_g.line([(dcx, dcy - 28), (dcx, dcy + 30)], fill=(245, 205, 100, 255), width=6)
    draw_g.line([(dcx - 20, dcy - 8), (dcx + 20, dcy - 8)], fill=(245, 205, 100, 255), width=6)
    draw_g.ellipse([dcx - 5, dcy - 13, dcx + 5, dcy - 3], fill=(225, 45, 55, 255), outline=(255, 230, 140, 255))
    img_guard.save(os.path.join(OUTPUT_DIR, "btn_guard.png"))
    print("-> btn_guard.png generated")


# ==============================================================================
# 4. Player Avatar Gothic Shield & Knight Helmet (256x256)
# ==============================================================================
def generate_player_avatar():
    size = (256, 256)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 128, 128

    # Outer Escutcheon Shield Frame
    shield_outer = [
        (cx, 16),
        (cx + 96, 28),
        (cx + 90, 140),
        (cx, 236),
        (cx - 90, 140),
        (cx - 96, 28)
    ]
    # Drop shadow
    for offset in range(8, 0, -2):
        s_poly = [(p[0] + offset, p[1] + offset) for p in shield_outer]
        draw.polygon(s_poly, fill=(0, 0, 0, 40))

    # Forged Brass Outer Rim
    draw.polygon(shield_outer, fill=(130, 95, 40, 255))
    shield_inner = [
        (cx, 26),
        (cx + 84, 36),
        (cx + 78, 134),
        (cx, 222),
        (cx - 78, 134),
        (cx - 84, 36)
    ]
    draw.polygon(shield_inner, fill=(245, 215, 135, 255))

    # Core Slate Background
    shield_core = [
        (cx, 34),
        (cx + 74, 44),
        (cx + 70, 128),
        (cx, 210),
        (cx - 70, 128),
        (cx - 74, 44)
    ]
    draw.polygon(shield_core, fill=(18, 24, 36, 255))

    # Decorative Border Engravings
    draw.line([shield_core[0], shield_core[3]], fill=(35, 48, 70, 200), width=2)

    # Knight Great Helm (Artistic Steel Silhouette)
    helm_pts = [
        (cx - 40, 68), (cx + 40, 68),
        (cx + 46, 118), (cx + 34, 156),
        (cx, 172),
        (cx - 34, 156), (cx - 46, 118)
    ]
    draw.polygon(helm_pts, fill=(90, 105, 125, 255), outline=(180, 200, 225, 255))

    # Brow Plate & Crest
    draw.polygon([(cx - 44, 76), (cx + 44, 76), (cx + 38, 92), (cx - 38, 92)], fill=(125, 145, 170, 255), outline=(220, 235, 255, 255))
    # Visor Slit (Cyan Soul Light)
    draw.rounded_rectangle([cx - 28, 112, cx + 28, 122], radius=3, fill=(10, 15, 25, 255), outline=(60, 80, 105, 255))
    draw.rounded_rectangle([cx - 24, 115, cx + 24, 119], radius=2, fill=(90, 240, 255, 255))
    # Glowing glint on visor
    draw.ellipse([cx - 10, 114, cx + 2, 120], fill=(255, 255, 255, 240))

    # Lower Chin Breathing Holes
    for hx in [-18, -9, 0, 9, 18]:
        draw.circle((cx + hx, 144), 2, fill=(20, 28, 40, 255))

    # Top Crown Ruby Crest
    draw.polygon([(cx, 18), (cx + 12, 34), (cx, 44), (cx - 12, 34)], fill=(225, 40, 50, 255), outline=(255, 220, 120, 255))

    img.save(os.path.join(OUTPUT_DIR, "hud_player_avatar_frame.png"))
    print("-> hud_player_avatar_frame.png generated")


# ==============================================================================
# 5. Faceted Ruby Soul Gems: Full (96x96) & Fractured Empty (96x96)
# ==============================================================================
def generate_soul_gems():
    size = (96, 96)
    cx, cy = 48, 48

    # --- A. FULL GEM (Vibrant 3D Faceted Ruby Crystal) ---
    img_full = Image.new("RGBA", size, (0, 0, 0, 0))
    draw_f = ImageDraw.Draw(img_full)

    # Gold Claw Mount
    mount_pts = [
        (cx, 12), (cx + 36, 32), (cx + 28, 76),
        (cx, 88), (cx - 28, 76), (cx - 36, 32)
    ]
    draw_f.polygon(mount_pts, fill=(130, 95, 35, 255))
    draw_f.polygon(mount_pts, outline=(245, 215, 125, 255), width=2)

    # Diamond Cut Crystal Facets
    gem_pts = [
        (cx, 16), (cx + 32, 34), (cx + 24, 72),
        (cx, 82), (cx - 24, 72), (cx - 32, 34)
    ]
    draw_f.polygon(gem_pts, fill=(210, 30, 45, 255))

    # Facet Polygons for 3D Diamond Sheen
    f_center = (cx, 44)
    # Top Facet
    draw_f.polygon([gem_pts[0], gem_pts[1], f_center], fill=(255, 120, 130, 255))
    # Top Left Facet
    draw_f.polygon([gem_pts[0], gem_pts[5], f_center], fill=(255, 160, 170, 255))
    # Bottom Left Facet
    draw_f.polygon([gem_pts[5], gem_pts[4], f_center], fill=(160, 15, 28, 255))
    # Bottom Center Facet
    draw_f.polygon([gem_pts[4], gem_pts[3], f_center], fill=(120, 10, 20, 255))
    # Bottom Right Facet
    draw_f.polygon([gem_pts[3], gem_pts[2], f_center], fill=(180, 20, 35, 255))
    # Top Right Facet
    draw_f.polygon([gem_pts[2], gem_pts[1], f_center], fill=(235, 60, 75, 255))

    # Specular Gleams
    draw_f.line([(cx - 8, 26), (cx + 8, 38)], fill=(255, 255, 255, 240), width=3)
    draw_f.ellipse([cx - 5, 28, cx + 1, 34], fill=(255, 255, 255, 255))
    img_full.save(os.path.join(OUTPUT_DIR, "hud_soul_gem_full.png"))
    print("-> hud_soul_gem_full.png generated")

    # --- B. EMPTY GEM (Fractured Dark Obsidian Slate) ---
    img_empty = Image.new("RGBA", size, (0, 0, 0, 0))
    draw_e = ImageDraw.Draw(img_empty)
    draw_e.polygon(mount_pts, fill=(55, 45, 30, 220), outline=(110, 95, 70, 220), width=2)
    draw_e.polygon(gem_pts, fill=(24, 30, 42, 240), outline=(50, 60, 78, 255), width=2)

    # Jagged Fractures
    draw_e.line([(cx - 4, 18), (cx + 6, 38), (cx - 8, 54), (cx + 4, 78)], fill=(120, 140, 165, 220), width=2)
    draw_e.line([(cx + 6, 38), (cx + 22, 46)], fill=(90, 110, 130, 180), width=2)
    draw_e.line([(cx - 8, 54), (cx - 20, 62)], fill=(90, 110, 130, 180), width=2)
    img_empty.save(os.path.join(OUTPUT_DIR, "hud_soul_gem_empty.png"))
    print("-> hud_soul_gem_empty.png generated")


# ==============================================================================
# 6. Parchment Scroll Ribbon Banner (512x96)
# ==============================================================================
def generate_parchment_scroll():
    w, h = 512, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Scroll Body Coordinates
    pts = [
        (24, 20), (w - 24, 20),
        (w - 6, 30), (w - 24, 76),
        (24, 76), (6, 30)
    ]
    # Drop shadow
    draw.polygon([(p[0] + 4, p[1] + 4) for p in pts], fill=(0, 0, 0, 60))

    # Forged Gold Trim
    draw.polygon(pts, fill=(150, 115, 55, 255), outline=(245, 215, 130, 255), width=3)

    # Warm Parchment Center
    p_pts = [
        (30, 26), (w - 30, 26),
        (w - 14, 34), (w - 30, 70),
        (30, 70), (14, 34)
    ]
    draw.polygon(p_pts, fill=(28, 34, 46, 245))  # Dark gothic tinted slate for readable text
    # Inner gold border line
    draw.line([(34, 30), (w - 34, 30)], fill=(190, 160, 95, 180), width=1)
    draw.line([(34, 66), (w - 34, 66)], fill=(190, 160, 95, 180), width=1)

    # Left & Right Golden Fleur/Seal Caps
    for cap_x in [24, w - 24]:
        draw.ellipse([cap_x - 14, 48 - 14, cap_x + 14, 48 + 14], fill=(225, 185, 95, 255), outline=(80, 55, 20, 255), width=2)
        draw.circle((cap_x, 48), 6, fill=(215, 35, 45, 255))

    img.save(os.path.join(OUTPUT_DIR, "hud_banner_scroll.png"))
    print("-> hud_banner_scroll.png generated")


# ==============================================================================
# 7. Boss Bar Gothic Wings & Frame (820x110)
# ==============================================================================
def generate_boss_bar_frame():
    w, h = 820, 110
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = w // 2
    bar_y, bar_h = 44, 40
    bar_w = 700
    bar_x = (w - bar_w) // 2

    # A. Left Wing Filigree (from x=bar_x back to x=10)
    def draw_wing(start_x, dir_mult):
        wing_base = [
            (start_x, bar_y + bar_h // 2),
            (start_x, bar_y - 8),
            (start_x + dir_mult * 36, bar_y - 28),
            (start_x + dir_mult * 50, bar_y - 10),
            (start_x + dir_mult * 42, bar_y + 14),
            (start_x + dir_mult * 26, bar_y + bar_h + 12),
            (start_x, bar_y + bar_h + 8)
        ]
        draw.polygon(wing_base, fill=(22, 28, 38, 255), outline=(130, 95, 35, 255), width=2)
        # Gold Feather Struts
        draw.line([wing_base[0], wing_base[2]], fill=(255, 220, 130, 255), width=3)
        draw.line([wing_base[0], wing_base[3]], fill=(240, 200, 110, 255), width=2)
        draw.line([wing_base[0], wing_base[4]], fill=(220, 180, 90, 255), width=2)
        # Ruby Claw Gem
        gem_c = (start_x + dir_mult * 18, bar_y + bar_h // 2)
        g_pts = [
            (gem_c[0], gem_c[1] - 12),
            (gem_c[0] + dir_mult * 9, gem_c[1]),
            (gem_c[0], gem_c[1] + 12),
            (gem_c[0] - dir_mult * 9, gem_c[1])
        ]
        draw.polygon(g_pts, fill=(225, 35, 45, 255), outline=(255, 230, 140, 255), width=2)
        draw.circle((gem_c[0] - dir_mult * 2, gem_c[1] - 3), 2, fill=(255, 255, 255, 255))

    draw_wing(bar_x, -1)
    draw_wing(bar_x + bar_w, 1)

    # B. Central Bar Frame (Hollow window so health fill shows through)
    outer_rect = [bar_x - 3, bar_y - 3, bar_x + bar_w + 3, bar_y + bar_h + 3]
    draw.rounded_rectangle(outer_rect, radius=4, outline=(140, 100, 40, 255), width=3)
    inner_rect = [bar_x - 1, bar_y - 1, bar_x + bar_w + 1, bar_y + bar_h + 1]
    draw.rounded_rectangle(inner_rect, radius=2, outline=(255, 225, 135, 255), width=2)

    # C. Central Royal Crown Crest
    crest_pts = [
        (cx, bar_y - 18),
        (cx + 14, bar_y - 4),
        (cx + 10, bar_y + 4),
        (cx - 10, bar_y + 4),
        (cx - 14, bar_y - 4)
    ]
    draw.polygon(crest_pts, fill=(245, 215, 125, 255), outline=(70, 50, 15, 255), width=2)
    draw.circle((cx, bar_y - 6), 3.5, fill=(225, 35, 45, 255))

    # D. Phase Segment Divider Pins
    # 50% Milestone (cx), 25% Milestone (bar_x + bar_w * 0.25), 75% Milestone
    for pin_x, is_major in [(cx, True), (bar_x + int(bar_w * 0.25), True), (bar_x + int(bar_w * 0.75), False)]:
        col = (255, 230, 140, 255) if is_major else (190, 160, 100, 200)
        # Top pin
        draw.polygon([(pin_x, bar_y - 8), (pin_x + 5, bar_y - 2), (pin_x - 5, bar_y - 2)], fill=col)
        # Bottom pin
        draw.polygon([(pin_x, bar_y + bar_h + 8), (pin_x + 5, bar_y + bar_h + 2), (pin_x - 5, bar_y + bar_h + 2)], fill=col)

    img.save(os.path.join(OUTPUT_DIR, "boss_bar_frame.png"))
    print("-> boss_bar_frame.png generated")


# ==============================================================================
# 8. Boss Bar Fill Textures: Ruby Fill (700x40) & Amber Linger (700x40)
# ==============================================================================
def generate_boss_bar_fills():
    w, h = 700, 40

    # Ruby Crystal Core Fill
    img_ruby = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw_r = ImageDraw.Draw(img_ruby)
    # Background rich red gradient
    for y in range(h):
        t = y / float(h)
        r = int(245 - 60 * t)
        g = int(45 - 25 * t)
        b = int(55 - 20 * t)
        draw_r.line([(0, y), (w, y)], fill=(r, g, b, 255))
    # Top Glass Highlight Rim (30% height)
    draw_r.rectangle([0, 0, w, 12], fill=(255, 255, 255, 60))
    draw_r.line([(0, 2), (w, 2)], fill=(255, 255, 255, 180), width=2)
    # Bottom shading
    draw_r.rectangle([0, h - 8, w, h], fill=(60, 10, 15, 120))
    img_ruby.save(os.path.join(OUTPUT_DIR, "boss_bar_fill_ruby.png"))
    print("-> boss_bar_fill_ruby.png generated")

    # Amber Magma Linger Fill
    img_amber = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw_a = ImageDraw.Draw(img_amber)
    for y in range(h):
        t = y / float(h)
        r = int(255 - 30 * t)
        g = int(210 - 70 * t)
        b = int(100 - 60 * t)
        draw_a.line([(0, y), (w, y)], fill=(r, g, b, 240))
    draw_a.rectangle([0, 0, w, 10], fill=(255, 255, 255, 90))
    img_amber.save(os.path.join(OUTPUT_DIR, "boss_bar_linger_amber.png"))
    print("-> boss_bar_linger_amber.png generated")


# ==============================================================================
# 9. Third Blade Combo Frame (360x100) & Just Parry Burst Banner (640x120)
# ==============================================================================
def generate_combo_and_parry_banners():
    # A. Combo Frame (360x100)
    w, h = 360, 100
    img_c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw_c = ImageDraw.Draw(img_c)
    # Metallic Violet/Gold Slash Plate
    pts = [(16, 8), (w - 6, 8), (w - 24, h - 8), (0, h - 8)]
    draw_c.polygon(pts, fill=(18, 14, 28, 240), outline=(235, 195, 80, 255), width=3)
    # Inner Violet Neon Accent
    draw_c.line([(24, 14), (w - 14, 14)], fill=(210, 80, 255, 200), width=2)
    draw_c.line([(8, h - 14), (w - 30, h - 14)], fill=(210, 80, 255, 200), width=2)
    img_c.save(os.path.join(OUTPUT_DIR, "combo_banner_frame.png"))
    print("-> combo_banner_frame.png generated")

    # B. Just Parry Banner (640x120)
    w2, h2 = 640, 120
    img_p = Image.new("RGBA", (w2, h2), (0, 0, 0, 0))
    draw_p = ImageDraw.Draw(img_p)
    cx, cy = w2 // 2, h2 // 2
    # Gothic Ribbon
    r_pts = [
        (30, 18), (w2 - 30, 18),
        (w2 - 6, cy), (w2 - 30, h2 - 18),
        (30, h2 - 18), (6, cy)
    ]
    draw_p.polygon(r_pts, fill=(22, 18, 12, 245), outline=(255, 220, 110, 255), width=3)
    # Golden Inset Border
    draw_p.polygon([(p[0] + (6 if p[0] < cx else -6), p[1] + (4 if p[1] < cy else -4)) for p in r_pts], outline=(180, 140, 60, 220), width=1)
    # Left & Right Lightning Bolts
    for lx in [50, w2 - 50]:
        bolt = [(lx - 8, cy - 24), (lx + 6, cy - 2), (lx - 2, cy - 2), (lx + 8, cy + 24), (lx - 6, cy + 2), (lx + 2, cy + 2)]
        draw_p.polygon(bolt, fill=(255, 235, 120, 255), outline=(90, 65, 15, 255))
    img_p.save(os.path.join(OUTPUT_DIR, "parry_burst_banner.png"))
    print("-> parry_burst_banner.png generated")


def main():
    print("=== Generating AAA RPG UI Texture Pack ===")
    generate_joypad_base()
    generate_joypad_knob()
    generate_action_buttons()
    generate_player_avatar()
    generate_soul_gems()
    generate_parchment_scroll()
    generate_boss_bar_frame()
    generate_boss_bar_fills()
    generate_combo_and_parry_banners()
    print("=== All UI Textures Generated Successfully ===")


if __name__ == "__main__":
    main()
