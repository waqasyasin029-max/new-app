"""Draws the Kharcha Notice launcher icon (orange square, white paper plane).
Usage: python3 tool/make_icon.py android/app/src/main/res
"""
import os
import sys

from PIL import Image, ImageDraw

res = sys.argv[1]
S = 1024
sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

# Diagonal gradient, orange like the app.
a, b = (245, 138, 75), (238, 111, 43)
grad = Image.new("RGB", (S, S))
px = grad.load()
for y in range(S):
    for x in range(S):
        k = (x + y) / (2.0 * S)
        px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))

icon = grad.convert("RGBA")
d = ImageDraw.Draw(icon)
# Paper plane.
d.polygon([(200, 540), (840, 220), (650, 830), (520, 620)], fill=(255, 255, 255, 255))
d.polygon([(520, 620), (840, 220), (560, 560)], fill=(238, 111, 43, 90))

mask = Image.new("L", (S * 4, S * 4), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, S * 4 - 1, S * 4 - 1), radius=int(S * 4 * 0.225), fill=255)
mask = mask.resize((S, S), Image.LANCZOS)
icon.putalpha(mask)

for dens, size in sizes.items():
    path = f"{res}/mipmap-{dens}/ic_launcher.png"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    icon.resize((size, size), Image.LANCZOS).save(path)
print("icon written")
