#!/usr/bin/env python3
"""Generate GlassStore's original app icon (1024x1024 PNG, no Apple assets).

Design: blue->teal gradient base, a white glass shopping-bag glyph with a
specular sweep — original artwork drawn from scratch for this project.
"""
from PIL import Image, ImageDraw
import math

OUT = "/home/z/my-project/download/GlassStore/GlassStore/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png"
S = 2048  # draw at 2x, downscale for antialiasing


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    top, bottom = (10, 100, 245), (0, 197, 195)  # #0A64F5 -> #00C5C3
    for y in range(S):
        d.line([(0, y), (S, y)], fill=lerp(top, bottom, y / S))

    # Soft radial glow upper-left
    glow = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse([ -S * 0.35, -S * 0.45, S * 0.75, S * 0.55 ], fill=70)
    glow = glow.filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(220))
    white = Image.new("RGB", (S, S), (255, 255, 255))
    img = Image.composite(white, img, glow.point(lambda p: p // 3))
    d = ImageDraw.Draw(img)

    # --- bag glyph (layered: shadow, glass fill, outline) ---
    bx0, by0 = 660, 980
    bx1, by1 = 1388, 1620
    rr = 140

    # drop shadow
    d.rounded_rectangle([bx0 + 26, by0 + 40, bx1 + 26, by1 + 40], radius=rr, fill=(6, 60, 120, 90))

    # glass fill: white at 18% over the gradient
    overlay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rounded_rectangle([bx0, by0, bx1, by1], radius=rr, fill=(255, 255, 255, 46))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    d = ImageDraw.Draw(img)

    # outline
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=rr, outline=(255, 255, 255), width=26)

    # handles: two arcs meeting the bag mouth
    hx0, hx1 = 850, 1198
    d.arc([hx0, by0 - 300, hx1, by0 + 190], start=185, end=355, fill=(255, 255, 255), width=30)

    # specular sweep inside the bag (glass highlight)
    spec = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(spec)
    sd.polygon([(bx0 + 40, by1 - 60), (bx0 + 330, by0 + 40), (bx0 + 470, by0 + 40), (bx0 + 180, by1 - 60)], fill=60)
    sweep = Image.new("RGB", (S, S), (255, 255, 255))
    img = Image.composite(sweep, img, spec.point(lambda p: p * 3 // 4))
    d = ImageDraw.Draw(img)

    # three "app dots" inside the bag — a storefront in miniature
    cy = (by0 + by1) // 2 + 10
    for i, dx in enumerate((-190, 0, 190)):
        r = 62
        cx = (bx0 + bx1) // 2 + dx
        alpha = 255 if i == 1 else 205
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, alpha))

    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(OUT, "PNG")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
