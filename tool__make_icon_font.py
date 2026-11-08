"""Builds the app icon font (Iconify / Hugeicons) and lib/core/app_icons.dart.

Needs: pip install fonttools skia-pathops ; npm i @iconify-json/hugeicons
Usage: python3 tool/make_icon_font.py <path to node_modules/@iconify-json/hugeicons/icons.json> <out dir>
Writes <out>/kicons.ttf and <out>/app_icons.dart (copy them to assets/fonts/ and lib/core/).
"""
import json, re, sys
import xml.etree.ElementTree as ET
import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path

# Dart name -> Hugeicons name (Iconify set "hugeicons", stroke rounded)
ICONS = {
    "chevronRight": "arrow-right-01", "chevronLeft": "arrow-left-01",
    "wallet": "wallet-01", "factCheck": "task-done-01", "delete": "delete-02",
    "check": "tick-02", "add": "add-01", "swapHoriz": "arrow-data-transfer-horizontal",
    "receipt": "invoice-01", "payments": "cash-01", "close": "cancel-01",
    "calendar": "calendar-03", "barChart": "chart-bar-line",
    "sparkle": "sparkles", "addCircle": "add-circle",
    "refresh": "refresh", "bellRinging": "bell-ring",
    "lock": "square-lock-02", "home": "home-01", "edit": "pencil-edit-02",
    "editNote": "note-edit", "atm": "atm-01", "clock": "clock-01",
    "wifiOff": "wifi-off-01", "trendUp": "chart-up", "trendDown": "chart-down",
    "translate": "translate", "timer": "timer-02", "systemUpdate": "download-01",
    "arrowDownLeft": "arrow-down-left-01", "slideshow": "presentation-01",
    "shoppingBag": "shopping-bag-01", "settings": "settings-02", "send": "sent",
    "search": "search-01", "savings": "piggy-bank", "restaurant": "restaurant-01",
    "person": "user", "bellAdd": "bell-plus", "arrowUpRight": "arrow-up-right-01",
    "movie": "film-01", "medical": "first-aid-kit", "grocery": "shopping-cart-01",
    "insights": "chart-line-data-01", "info": "information-circle", "healthSafety": "shield-01",
    "coffee": "coffee-01", "car": "car-01", "dinner": "rice-bowl-01",
    "dateRange": "calendar-02", "clear": "cancel-circle", "category": "dashboard-square-01",
    "brightness": "contrast", "batterySaver": "battery-charging-01",
    "badge": "id-card", "backspace": "arrow-left-02",
    "arrowForward": "arrow-right-02", "alarm": "alarm-clock", "bank": "bank",
}

src, out = sys.argv[1], sys.argv[2]
data = json.load(open(src))["icons"]
S = 1024          # font units per em
K = S / 24.0      # icons are drawn on a 24 grid
SCALE = 0.84      # glyph size inside the em box (smaller = smaller icons everywhere)
OFF = S * (1 - SCALE) / 2
STROKE_DEFAULT = 1.5
CAPS = {"butt": pathops.LineCap.BUTT_CAP, "round": pathops.LineCap.ROUND_CAP, "square": pathops.LineCap.SQUARE_CAP}
JOINS = {"miter": pathops.LineJoin.MITER_JOIN, "round": pathops.LineJoin.ROUND_JOIN, "bevel": pathops.LineJoin.BEVEL_JOIN}


def shape_d(el):
    tag = el.tag.split("}")[-1]
    g = lambda k, d=0.0: float(el.get(k, d))
    if tag == "path":
        return el.get("d")
    if tag == "circle":
        cx, cy, r = g("cx"), g("cy"), g("r")
        return f"M{cx - r} {cy}a{r} {r} 0 1 0 {2 * r} 0a{r} {r} 0 1 0 {-2 * r} 0z"
    if tag == "ellipse":
        cx, cy, rx, ry = g("cx"), g("cy"), g("rx"), g("ry")
        return f"M{cx - rx} {cy}a{rx} {ry} 0 1 0 {2 * rx} 0a{rx} {ry} 0 1 0 {-2 * rx} 0z"
    if tag == "line":
        return f"M{g('x1')} {g('y1')}L{g('x2')} {g('y2')}"
    if tag in ("polyline", "polygon"):
        pts = el.get("points").replace(",", " ").split()
        d = "M" + " L".join(f"{pts[i]} {pts[i + 1]}" for i in range(0, len(pts), 2))
        return d + ("z" if tag == "polygon" else "")
    if tag == "rect":
        x, y, w, h = g("x"), g("y"), g("width"), g("height")
        r = min(g("rx", g("ry", 0)), w / 2, h / 2)
        if r <= 0:
            return f"M{x} {y}h{w}v{h}h{-w}z"
        return (f"M{x + r} {y}h{w - 2 * r}a{r} {r} 0 0 1 {r} {r}v{h - 2 * r}a{r} {r} 0 0 1 {-r} {r}"
                f"h{-(w - 2 * r)}a{r} {r} 0 0 1 {-r} {-r}v{-(h - 2 * r)}a{r} {r} 0 0 1 {r} {-r}z")
    return None


def union(a, b):
    if not list(a.segments):
        return b
    return pathops.op(a, b, pathops.PathOp.UNION)


def build_path(body):
    root = ET.fromstring("<svg xmlns='http://www.w3.org/2000/svg'>" + body + "</svg>")
    result = pathops.Path()

    def walk(el, inh):
        nonlocal result
        attrs = dict(inh)
        attrs.update({k: v for k, v in el.attrib.items() if k in (
            "fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "fill-rule", "opacity")})
        tag = el.tag.split("}")[-1]
        if tag in ("g", "svg"):
            for c in el:
                walk(c, attrs)
            return
        d = shape_d(el)
        if not d:
            return
        if float(attrs.get("opacity", 1)) < 0.5:
            return  # skip faint duotone layers
        p = pathops.Path()
        parse_path(d, TransformPen(p.getPen(), (K * SCALE, 0, 0, -K * SCALE, OFF, S * SCALE + OFF)))
        fill = attrs.get("fill", "currentColor")
        stroke = attrs.get("stroke", "none")
        if fill != "none":
            q = pathops.Path(p)
            if attrs.get("fill-rule") == "evenodd":
                q.fillType = pathops.FillType.EVEN_ODD
            q.simplify(fix_winding=True)
            result = union(result, q)
        if stroke != "none":
            q = pathops.Path(p)
            w = float(attrs.get("stroke-width", STROKE_DEFAULT)) * K * SCALE
            q.stroke(w, CAPS[attrs.get("stroke-linecap", "butt")], JOINS[attrs.get("stroke-linejoin", "miter")], 4)
            q.convertConicsToQuads(0.1)
            q.simplify(fix_winding=True)
            result = union(result, q)

    walk(root, {})
    result.simplify(fix_winding=True)
    return result


glyphs = {".notdef": TTGlyphPen(None).glyph()}
order = [".notdef"]
cmap = {}
lsb = {".notdef": 0}
code = 0xE000
for dart, ph in ICONS.items():
    p = build_path(data[ph]["body"])
    tt = TTGlyphPen(None)
    p.draw(Cu2QuPen(tt, 2.0, reverse_direction=True))
    name = "i_" + dart
    glyphs[name] = tt.glyph()
    bx = p.bounds
    lsb[name] = int(round(bx[0])) if bx else 0
    order.append(name)
    cmap[code] = name
    code += 1

fb = FontBuilder(S, isTTF=True)
fb.setupGlyphOrder(order)
fb.setupCharacterMap(cmap)
fb.setupGlyf(glyphs)
glyf = fb.font["glyf"]
for n in order:
    glyf[n].recalcBounds(glyf)
    lsb[n] = getattr(glyf[n], "xMin", 0)
fb.setupHorizontalMetrics({n: (S, lsb[n]) for n in order})
fb.setupHorizontalHeader(ascent=S, descent=0)
fb.setupNameTable({"familyName": "KIcons", "styleName": "Regular"})
fb.setupOS2(sTypoAscender=S, sTypoDescender=0, usWinAscent=S, usWinDescent=0)
fb.setupPost()
fb.save(f"{out}/kicons.ttf")

lines = [
    "import 'package:flutter/widgets.dart';",
    "",
    "/// App icons (Iconify, Hugeicons stroke-rounded set). Generated by tool/make_icon_font.py.",
    "/// One outline icon family for the whole app.",
    "class AppIcons {",
    "  AppIcons._();",
    "  static const _f = 'KIcons';",
]
for (dart, ph), c in zip(ICONS.items(), cmap):
    lines.append(f"  static const {dart} = IconData(0x{c:x}, fontFamily: _f); // hugeicons:{ph}")
lines.append("}")
open(f"{out}/app_icons.dart", "w").write("\n".join(lines) + "\n")
print(len(ICONS), "icons")
