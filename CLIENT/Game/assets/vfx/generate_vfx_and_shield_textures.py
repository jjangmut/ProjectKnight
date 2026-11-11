"""
ProjectKnight V3-022: High-Resolution Combat VFX & Shield Prop Texture Generator
Generates runtime game textures for:
1. vfx_slash_arc_amber.png (Warm Golden-Amber Sword Slash Arc)
2. vfx_energy_barrier_runic.png (Luminous Hexagonal & Runic Aegis Barrier)
3. vfx_hit_spark_burst.png (Radial Starlight & Ember Hit Sparks)
4. vfx_enemy_slash_crescent.png (Crimson-Orange Jagged Enemy Slash)
5. vfx_boss_fissure_magma.png (Molten Ground Fissure & Volcanic Rock)
6. vfx_shockwave_ring.png (Concentric Pressure Shockwave)
7. heavy_shield_albedo.png (Forged Steel & Gilded Rim Knight Greatshield)
8. heavy_shield_normal.png (Tangent-Space Normal Map for Rivets & Crest)
9. heavy_shield_metallic_roughness.png (PBR Metallic/Roughness Map)
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

VFX_DIR = os.path.dirname(os.path.abspath(__file__))
PROPS_DIR = os.path.normpath(os.path.join(VFX_DIR, "..", "props"))
os.makedirs(VFX_DIR, exist_ok=True)
os.makedirs(PROPS_DIR, exist_ok=True)


def clamp(val, low=0.0, high=1.0):
    return max(low, min(high, val))


# ==============================================================================
# 1. Player Slash Arc Motion Trail (512 x 256)
# ==============================================================================
def generate_slash_arc_amber():
    w, h = 512, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pixels = img.load()

    for y in range(h):
        v = y / float(h - 1)  # 0.0 (inner) to 1.0 (outer cutting blade)
        for x in range(w):
            u = x / float(w - 1)  # 0.0 (tail) to 1.0 (cutting tip)

            # Intensity profile along U (motion streak):
            # Slow acceleration from tail, rising to searing tip
            if u < 0.15:
                u_profile = (u / 0.15) ** 1.8
            elif u <= 0.85:
                u_profile = 0.70 + 0.30 * ((u - 0.15) / 0.70)
            else:
                # Leading edge razor tip: sharp peak at 0.95, razor taper to 1.0
                u_profile = 1.0 - ((u - 0.85) / 0.15) ** 2.0
                u_profile = max(0.0, u_profile)

            # Cross-section profile along V (blade width):
            # Sharp cutting edge at v=0.92, glowing core at v=0.75, soft trail at v=0.0
            blade_core = math.exp(-((v - 0.78) ** 2) / 0.035)
            blade_edge = math.exp(-((v - 0.92) ** 2) / 0.008)
            blade_body = clamp(1.0 - (1.0 - v) ** 1.5)

            intensity = u_profile * (blade_core * 0.70 + blade_edge * 0.45 + blade_body * 0.25)
            intensity = clamp(intensity)

            # High-frequency motion streaks along U
            streak = 0.90 + 0.10 * math.sin(u * 48.0 + v * 6.0)

            # Color Gradient:
            # Searing solar yellow core -> rich warm golden amber -> deep fiery orange edge
            r = int(clamp(255 * (0.90 + 0.10 * intensity)) * streak)
            g = int(clamp(140 + 105 * (intensity ** 1.2)) * streak)
            b = int(clamp(15 + 65 * (intensity ** 3.0)) * streak)
            a = int(clamp(255 * intensity * (u ** 0.5) * (1.0 - (1.0 - v) ** 3.0)))

            pixels[x, y] = (r, g, b, a)

    # Gentle horizontal motion blur
    img = img.filter(ImageFilter.GaussianBlur(radius=1.2))
    out_path = os.path.join(VFX_DIR, "vfx_slash_arc_amber.png")
    img.save(out_path, "PNG")
    print(f"Generated: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# 2. Luminous Hexagonal & Runic Aegis Barrier (512 x 512)
# ==============================================================================
def generate_energy_barrier_runic():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w / 2.0, h / 2.0
    radius = 230.0

    # Draw outer runic shield rim
    rim_color = (40, 195, 255, 240)
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], outline=rim_color, width=6)
    draw.ellipse([cx - radius + 12, cy - radius + 12, cx + radius - 12, cy + radius - 12], outline=(30, 160, 240, 180), width=3)

    # Outer Runic Notches & Compass Sigils
    for deg in range(0, 360, 15):
        rad = math.radians(deg)
        r0 = radius - 10
        r1 = radius + (4 if deg % 45 == 0 else -2)
        x0 = cx + r0 * math.cos(rad)
        y0 = cy + r0 * math.sin(rad)
        x1 = cx + r1 * math.cos(rad)
        y1 = cy + r1 * math.sin(rad)
        w_line = 3 if deg % 45 == 0 else 1
        draw.line([x0, y0, x1, y1], fill=(120, 225, 255, 230), width=w_line)

    # Inner Hexagonal Grid (Honeycomb)
    hex_size = 28.0
    for q in range(-7, 8):
        for r in range(-7, 8):
            hx = cx + hex_size * (math.sqrt(3) * q + math.sqrt(3) / 2.0 * r)
            hy = cy + hex_size * (3.0 / 2.0 * r)
            d_center = math.hypot(hx - cx, hy - cy)
            if d_center < radius - 20:
                hex_pts = []
                for a in range(6):
                    ang = math.radians(60 * a + 30)
                    hex_pts.append((hx + (hex_size - 3) * math.cos(ang), hy + (hex_size - 3) * math.sin(ang)))
                # Fade hex alpha towards edge
                alpha_hex = int(190 * (1.0 - (d_center / radius) ** 1.4))
                draw.polygon(hex_pts, outline=(40, 180, 255, alpha_hex), width=2)

    # Central Aegis Starburst Emblem
    star_r = 55.0
    for a in range(8):
        ang0 = math.radians(45 * a)
        ang1 = math.radians(45 * a + 22.5)
        p0 = (cx + star_r * math.cos(ang0), cy + star_r * math.sin(ang0))
        p1 = (cx + (star_r * 0.4) * math.cos(ang1), cy + (star_r * 0.4) * math.sin(ang1))
        draw.line([(cx, cy), p0], fill=(160, 240, 255, 250), width=3)
        draw.line([(cx, cy), p1], fill=(70, 200, 255, 200), width=2)

    # Soft ethereal radial glow
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    g_pix = glow.load()
    for y in range(h):
        for x in range(w):
            dist = math.hypot(x - cx, y - cy)
            if dist < radius:
                t = dist / radius
                val = (1.0 - t) ** 1.6
                a = int(85 * val)
                g_pix[x, y] = (20, 140, 230, a)

    final = Image.alpha_composite(glow, img)
    final = final.filter(ImageFilter.GaussianBlur(radius=0.8))

    out_path = os.path.join(VFX_DIR, "vfx_energy_barrier_runic.png")
    final.save(out_path, "PNG")
    print(f"Generated: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# 3. Radial Hit Spark Burst & Embers (256 x 256)
# ==============================================================================
def generate_hit_spark_burst():
    w, h = 256, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w / 2.0, h / 2.0

    # 16 Radiating Starlight Spikes
    angles = [0, 22, 45, 68, 90, 112, 135, 158, 180, 202, 225, 248, 270, 292, 315, 338]
    lengths = [115, 65, 120, 55, 110, 60, 122, 58, 114, 62, 118, 54, 112, 64, 120, 56]

    for deg, leng in zip(angles, lengths):
        rad = math.radians(deg)
        x_tip = cx + leng * math.cos(rad)
        y_tip = cy + leng * math.sin(rad)

        # Needle triangle
        perp_rad = rad + math.pi / 2.0
        w_base = 4.5 if leng > 90 else 2.5
        x_b0 = cx + w_base * math.cos(perp_rad)
        y_b0 = cy + w_base * math.sin(perp_rad)
        x_b1 = cx - w_base * math.cos(perp_rad)
        y_b1 = cy - w_base * math.sin(perp_rad)

        color = (255, 215, 80, 240) if deg % 45 == 0 else (255, 150, 40, 200)
        draw.polygon([(x_b0, y_b0), (x_tip, y_tip), (x_b1, y_b1)], fill=color)

    # Central Searing Core
    draw.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=(255, 245, 180, 255))
    draw.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(255, 255, 230, 255))

    img = img.filter(ImageFilter.GaussianBlur(radius=0.7))
    out_path = os.path.join(VFX_DIR, "vfx_hit_spark_burst.png")
    img.save(out_path, "PNG")
    print(f"Generated: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# 4. Crimson-Orange Enemy Slash Crescent (512 x 256)
# ==============================================================================
def generate_enemy_slash_crescent():
    w, h = 512, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pixels = img.load()

    for y in range(h):
        v = y / float(h - 1)
        for x in range(w):
            u = x / float(w - 1)

            u_profile = (u ** 1.4) if u < 0.85 else max(0.0, 1.0 - ((u - 0.85) / 0.15) ** 2)
            crescent_shape = math.exp(-((v - (0.65 + 0.20 * math.sin(u * math.pi))) ** 2) / 0.04)
            intensity = clamp(u_profile * crescent_shape)

            r = int(clamp(245 * (0.85 + 0.15 * intensity)))
            g = int(clamp(45 + 130 * (intensity ** 1.8)))
            b = int(clamp(15 + 40 * (intensity ** 3.0)))
            a = int(clamp(235 * intensity * (u ** 0.6)))

            pixels[x, y] = (r, g, b, a)

    img = img.filter(ImageFilter.GaussianBlur(radius=1.0))
    out_path = os.path.join(VFX_DIR, "vfx_enemy_slash_crescent.png")
    img.save(out_path, "PNG")
    print(f"Generated: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# 5. Molten Magma Ground Fissure Texture (512 x 256)
# ==============================================================================
def generate_boss_fissure_magma():
    w, h = 512, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Jagged subterranean fracture path
    center_y = h / 2.0
    points = []
    num_pts = 32
    for i in range(num_pts):
        x = i * (w / float(num_pts - 1))
        offset = math.sin(i * 1.8) * 22.0 + math.cos(i * 3.4) * 14.0
        points.append((x, center_y + offset))

    # Wide charred rock halo
    draw.line(points, fill=(45, 20, 15, 220), width=38)
    draw.line(points, fill=(160, 45, 15, 240), width=22)
    # Molten lava core
    draw.line(points, fill=(255, 130, 25, 255), width=10)
    draw.line(points, fill=(255, 220, 110, 255), width=4)

    # Lateral volcanic crack branches
    for idx in range(3, num_pts - 3, 4):
        bx, by = points[idx]
        b_len = 35.0
        angle = math.radians(45 if idx % 2 == 0 else -45)
        bx1 = bx + b_len * math.cos(angle)
        by1 = by + b_len * math.sin(angle)
        draw.line([(bx, by), (bx1, by1)], fill=(240, 80, 20, 210), width=5)
        draw.line([(bx, by), (bx1, by1)], fill=(255, 180, 60, 240), width=2)

    img = img.filter(ImageFilter.GaussianBlur(radius=1.5))
    out_path = os.path.join(VFX_DIR, "vfx_boss_fissure_magma.png")
    img.save(out_path, "PNG")
    print(f"Generated: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# 6. Concentric Pressure Shockwave Ring (512 x 512)
# ==============================================================================
def generate_shockwave_ring():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pixels = img.load()
    cx, cy = w / 2.0, h / 2.0
    radius = 220.0

    for y in range(h):
        for x in range(w):
            dist = math.hypot(x - cx, y - cy)
            t = dist / radius
            if 0.55 <= t <= 1.0:
                # Triple ripple rings
                ripple = math.sin((t - 0.55) / 0.45 * math.pi * 3.0)
                alpha_curve = math.sin((t - 0.55) / 0.45 * math.pi)
                val = clamp(alpha_curve * (0.60 + 0.40 * ripple))
                r = int(240 * val)
                g = int(90 * val)
                b = int(35 * val)
                a = int(210 * val)
                pixels[x, y] = (r, g, b, a)

    img = img.filter(ImageFilter.GaussianBlur(radius=1.2))
    out_path = os.path.join(VFX_DIR, "vfx_shockwave_ring.png")
    img.save(out_path, "PNG")
    print(f"Generated: {out_path} ({os.path.getsize(out_path)} bytes)")


# ==============================================================================
# 7, 8, 9. Heavy Knight Greatshield PBR Textures (512 x 512)
# Heater / Tower Shield with Gilded Rim, Iron Base, Rivets, & Heraldic Lion Crest
# ==============================================================================
def generate_heavy_shield_textures():
    w, h = 512, 512

    albedo = Image.new("RGBA", (w, h), (42, 46, 56, 255))
    normal = Image.new("RGBA", (w, h), (128, 128, 255, 255))
    metal_rough = Image.new("RGBA", (w, h), (0, 95, 215, 255))  # G=roughness, B=metallic

    alb_draw = ImageDraw.Draw(albedo)
    mr_draw = ImageDraw.Draw(metal_rough)

    cx, cy = w / 2.0, h / 2.0

    # Shield Heater Contour (top arc, vertical body, tapered point at bottom)
    # UV mapping: entire shield surface occupies x in [32, 480], y in [24, 488]
    x_min, x_max = 40.0, 472.0
    y_min, y_max = 30.0, 482.0
    rim_w = 28.0

    def get_shield_polygon(inset=0.0):
        l = x_min + inset
        r = x_max - inset
        t = y_min + inset
        b = y_max - inset
        mid_y = t + (b - t) * 0.58
        bot_tip = (cx, b)

        pts = [
            (l + 25, t),
            (r - 25, t),
            (r, t + 25),
            (r, mid_y),
            (cx + (r - cx) * 0.45, b - (b - mid_y) * 0.35),
            bot_tip,
            (cx - (cx - l) * 0.45, b - (b - mid_y) * 0.35),
            (l, mid_y),
            (l, t + 25),
        ]
        return pts

    outer_poly = get_shield_polygon(inset=0.0)
    inner_poly = get_shield_polygon(inset=rim_w)

    # 1. Outer Heavy Gilded Steel Rim
    gold_rim_col = (205, 155, 55, 255)
    alb_draw.polygon(outer_poly, fill=gold_rim_col)
    mr_draw.polygon(outer_poly, fill=(0, 45, 245, 255))  # Rim: Very metallic, smooth roughness

    # Rim bevel shading
    bevel_poly = get_shield_polygon(inset=6.0)
    alb_draw.polygon(bevel_poly, fill=(235, 185, 80, 255))

    # 2. Inner Shield Face (Dark Forged Blue-Steel Plate)
    steel_face_col = (48, 54, 68, 255)
    alb_draw.polygon(inner_poly, fill=steel_face_col)
    mr_draw.polygon(inner_poly, fill=(0, 110, 210, 255))  # Steel: Metallic 210, Roughness 110

    # Vertical centerline highlight ridge
    alb_draw.line([(cx, y_min + rim_w), (cx, y_max - rim_w)], fill=(62, 70, 88, 255), width=6)
    alb_draw.line([(cx, y_min + rim_w), (cx, y_max - rim_w)], fill=(85, 96, 120, 255), width=2)

    # 3. Steel Studs / Rivets along the Rim
    rivet_pts = []
    # Top edge rivets
    for x in range(int(x_min + 55), int(x_max - 50), 38):
        rivet_pts.append((x, y_min + rim_w * 0.5))
    # Right & Left vertical edge rivets
    for y in range(int(y_min + 55), int(y_min + (y_max - y_min) * 0.60), 45):
        rivet_pts.append((x_min + rim_w * 0.5, y))
        rivet_pts.append((x_max - rim_w * 0.5, y))
    # Bottom tapered rivets
    rivet_pts.append((x_min + 55, y_max - 110))
    rivet_pts.append((x_max - 55, y_max - 110))
    rivet_pts.append((cx - 35, y_max - 45))
    rivet_pts.append((cx + 35, y_max - 45))
    rivet_pts.append((cx, y_max - 18))

    for rx, ry in rivet_pts:
        # Rivet highlight & drop shadow
        alb_draw.ellipse([rx - 6, ry - 6, rx + 6, ry + 6], fill=(28, 30, 36, 255))
        alb_draw.ellipse([rx - 5, ry - 5, rx + 5, ry + 5], fill=(240, 200, 110, 255))
        alb_draw.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(255, 240, 180, 255))

    # 4. Central Gilded Heraldic Boss & Cross Crest
    crest_cy = cy - 25.0
    # Heraldic Cross
    bar_w = 26.0
    bar_h = 160.0
    alb_draw.rectangle([cx - bar_w / 2.0, crest_cy - bar_h / 2.0, cx + bar_w / 2.0, crest_cy + bar_h / 2.0], fill=(215, 165, 60, 255))
    alb_draw.rectangle([cx - bar_h / 2.6, crest_cy - bar_w / 2.0, cx + bar_h / 2.6, crest_cy + bar_w / 2.0], fill=(215, 165, 60, 255))

    # Cross high-specular bevel
    alb_draw.line([(cx, crest_cy - bar_h / 2.0), (cx, crest_cy + bar_h / 2.0)], fill=(255, 220, 110, 255), width=3)
    alb_draw.line([(cx - bar_h / 2.6, crest_cy), (cx + bar_h / 2.6, crest_cy)], fill=(255, 220, 110, 255), width=3)

    # Central Round Boss / Shield Gem
    boss_r = 32.0
    alb_draw.ellipse([cx - boss_r, crest_cy - boss_r, cx + boss_r, crest_cy + boss_r], fill=(35, 38, 48, 255))
    alb_draw.ellipse([cx - boss_r + 4, crest_cy - boss_r + 4, cx + boss_r - 4, crest_cy + boss_r - 4], fill=(235, 180, 65, 255))
    alb_draw.ellipse([cx - boss_r + 8, crest_cy - boss_r + 8, cx + boss_r - 8, crest_cy + boss_r - 8], fill=(60, 120, 220, 255))
    alb_draw.ellipse([cx - 8, crest_cy - 8, cx + 8, crest_cy + 8], fill=(130, 190, 255, 255))

    # Crest metallic map
    mr_draw.rectangle([cx - bar_w / 2.0, crest_cy - bar_h / 2.0, cx + bar_w / 2.0, crest_cy + bar_h / 2.0], fill=(0, 50, 240, 255))
    mr_draw.rectangle([cx - bar_h / 2.6, crest_cy - bar_w / 2.0, cx + bar_h / 2.6, crest_cy + bar_w / 2.0], fill=(0, 50, 240, 255))
    mr_draw.ellipse([cx - boss_r, crest_cy - boss_r, cx + boss_r, crest_cy + boss_r], fill=(0, 35, 250, 255))

    # 5. Generate Tangent-Space Normal Map (Sobel filter over height)
    # Construct heightmap from brightness
    heightmap = Image.new("L", (w, h), 128)
    h_draw = ImageDraw.Draw(heightmap)
    h_draw.polygon(outer_poly, fill=165)
    h_draw.polygon(bevel_poly, fill=185)
    h_draw.polygon(inner_poly, fill=140)
    h_draw.line([(cx, y_min + rim_w), (cx, y_max - rim_w)], fill=165, width=6)
    for rx, ry in rivet_pts:
        h_draw.ellipse([rx - 6, ry - 6, rx + 6, ry + 6], fill=220)
    h_draw.rectangle([cx - bar_w / 2.0, crest_cy - bar_h / 2.0, cx + bar_w / 2.0, crest_cy + bar_h / 2.0], fill=200)
    h_draw.rectangle([cx - bar_h / 2.6, crest_cy - bar_w / 2.0, cx + bar_h / 2.6, crest_cy + bar_w / 2.0], fill=200)
    h_draw.ellipse([cx - boss_r, crest_cy - boss_r, cx + boss_r, crest_cy + boss_r], fill=230)

    heightmap = heightmap.filter(ImageFilter.GaussianBlur(radius=1.5))
    h_pix = heightmap.load()
    norm_pix = normal.load()

    strength = 3.5
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            # Sobel operator
            dx = (int(h_pix[x + 1, y - 1]) + 2 * int(h_pix[x + 1, y]) + int(h_pix[x + 1, y + 1])) - \
                 (int(h_pix[x - 1, y - 1]) + 2 * int(h_pix[x - 1, y]) + int(h_pix[x - 1, y + 1]))
            dy = (int(h_pix[x - 1, y + 1]) + 2 * int(h_pix[x, y + 1]) + int(h_pix[x + 1, y + 1])) - \
                 (int(h_pix[x - 1, y - 1]) + 2 * int(h_pix[x, y - 1]) + int(h_pix[x + 1, y - 1]))

            nx = -dx * strength / 255.0
            ny = -dy * strength / 255.0
            nz = 1.0

            leng = math.sqrt(nx * nx + ny * ny + nz * nz)
            nx /= leng
            ny /= leng
            nz /= leng

            r_norm = int((nx * 0.5 + 0.5) * 255)
            g_norm = int((ny * 0.5 + 0.5) * 255)
            b_norm = int((nz * 0.5 + 0.5) * 255)
            norm_pix[x, y] = (r_norm, g_norm, b_norm, 255)

    # Save PBR files
    p_alb = os.path.join(PROPS_DIR, "heavy_shield_albedo.png")
    p_norm = os.path.join(PROPS_DIR, "heavy_shield_normal.png")
    p_mr = os.path.join(PROPS_DIR, "heavy_shield_metallic_roughness.png")

    albedo.save(p_alb, "PNG")
    normal.save(p_norm, "PNG")
    metal_rough.save(p_mr, "PNG")

    print(f"Generated: {p_alb} ({os.path.getsize(p_alb)} bytes)")
    print(f"Generated: {p_norm} ({os.path.getsize(p_norm)} bytes)")
    print(f"Generated: {p_mr} ({os.path.getsize(p_mr)} bytes)")


if __name__ == "__main__":
    print("Generating ProjectKnight V3-022 Combat VFX & Shield Prop Textures...")
    generate_slash_arc_amber()
    generate_energy_barrier_runic()
    generate_hit_spark_burst()
    generate_enemy_slash_crescent()
    generate_boss_fissure_magma()
    generate_shockwave_ring()
    generate_heavy_shield_textures()
    print("All textures successfully created!")
