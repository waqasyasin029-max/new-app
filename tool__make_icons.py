"""Generates all Android launcher/notification icons from one logo PNG.
Usage: python3 tool/make_icons.py tool/icon_source.png android/app/src/main/res
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

src, res = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")

# 1) Crop to the rounded square (the logo sits on a black canvas) and round its corners.
lum = im.convert("L").point(lambda v: 255 if v > 22 else 0)
box = lum.getbbox() or (0, 0, im.width, im.height)
side = max(box[2] - box[0], box[3] - box[1])
cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
left, top = max(0, cx - side // 2), max(0, cy - side // 2)
crop = im.crop((left, top, left + side, top + side)).resize((1024, 1024), Image.LANCZOS)
mask = Image.new("L", (4096, 4096), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 4095, 4095), radius=int(4096 * 0.225), fill=255)
mask = mask.resize((1024, 1024), Image.LANCZOS)
logo = crop.convert("RGBA")
logo.putalpha(mask)

# 2) Background colour for the adaptive icon = dark colour sampled from the logo.
patch = crop.crop((250, 880, 330, 960)).resize((1, 1), Image.BOX).getpixel((0, 0))
bg_hex = "#%02X%02X%02X" % patch


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
notif = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}

for d, px in legacy.items():
    save(logo.resize((px, px), Image.LANCZOS), f"{res}/mipmap-{d}/ic_launcher.png")

# Adaptive icon: a full-bleed diagonal gradient (same colours as the logo) behind the
# logo's inside, shrunk and feathered so it melts into the gradient. The phone's
# mask (circle, squircle...) then cuts it, like the round-square legacy icon.
def _avg(box):
    return tuple(
        sum(v) / len(v) for v in zip(*[crop.getpixel((x, y)) for x in range(box[0], box[2], 4) for y in range(box[1], box[3], 4)])
    )


ca, cb = _avg((100, 100, 130, 130)), _avg((894, 894, 924, 924))
ta, tb = 115 / 1024.0, 909 / 1024.0


def gradient(px):
    g = Image.new("RGB", (px, px))
    pix = g.load()
    for y in range(px):
        for x in range(px):
            u = ((x + y) / 2.0) / px
            k = (u - ta) / (tb - ta)
            pix[x, y] = tuple(int(max(0, min(255, ca[i] + (cb[i] - ca[i]) * k))) for i in range(3))
    return g


inner = crop.crop((70, 70, 954, 954)).convert("RGBA")
fade = Image.new("L", inner.size, 0)
ImageDraw.Draw(fade).rectangle((60, 60, inner.width - 60, inner.height - 60), fill=255)
inner.putalpha(fade.filter(ImageFilter.GaussianBlur(34)))
for d, px in adaptive.items():
    save(gradient(px), f"{res}/mipmap-{d}/ic_launcher_background.png")
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    side = int(px * 0.66)
    canvas.alpha_composite(inner.resize((side, side), Image.LANCZOS), ((px - side) // 2, (px - side) // 2))
    save(canvas, f"{res}/mipmap-{d}/ic_launcher_foreground.png")

os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
with open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w") as f:
    f.write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
os.makedirs(f"{res}/values", exist_ok=True)
with open(f"{res}/values/ic_launcher_background.xml", "w") as f:
    f.write(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">{bg_hex}</color>\n</resources>\n'
    )

# 3) Notification small icon: white wallet silhouette on transparent.
S = 384
g = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(g)
d.rounded_rectangle((S * 0.12, S * 0.30, S * 0.88, S * 0.84), radius=S * 0.12, fill=255)
d.rounded_rectangle((S * 0.20, S * 0.18, S * 0.72, S * 0.34), radius=S * 0.05, fill=255)
d.rounded_rectangle((S * 0.60, S * 0.47, S * 0.92, S * 0.67), radius=S * 0.10, fill=0)
d.ellipse((S * 0.68, S * 0.52, S * 0.78, S * 0.62), fill=255)
for dens, px in notif.items():
    a = g.resize((px, px), Image.LANCZOS)
    icon = Image.new("RGBA", (px, px), (255, 255, 255, 0))
    icon.putalpha(a)
    save(icon, f"{res}/drawable-{dens}/ic_notification.png")
save(logo.resize((192, 192), Image.LANCZOS), f"{res}/drawable-xxhdpi/ic_notification_large.png")
os.makedirs(f"{res}/raw", exist_ok=True)
with open(f"{res}/raw/keep.xml", "w") as f:
    f.write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources xmlns:tools="http://schemas.android.com/tools"\n'
        '    tools:keep="@drawable/ic_notification,@drawable/ic_notification_large,@mipmap/ic_launcher,@mipmap/ic_launcher_foreground,@mipmap/ic_launcher_background" />\n'
    )
print("icons generated, adaptive background", bg_hex)
