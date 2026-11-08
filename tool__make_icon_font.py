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
    "calendar": "calendar-03", "barChart": "custom:barChart", "barChartFill": "custom:barChartFill",
    "homeFill": "custom:homeFill", "receiptFill": "custom:receiptFill", "walletFill": "custom:walletFill",
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

# Hand-made icons (24 grid): the filled "selected" versions for the nav bar, plus our bar chart.
# An element with data-cut="1" is cut out of what has been drawn so far.
HOME_D = "M3 11.99v2.51c0 3.3 0 4.95 1.025 5.975S6.7 21.5 10 21.5h4c3.3 0 4.95 0 5.975-1.025S21 17.8 21 14.5v-2.51c0-1.682 0-2.522-.356-3.25s-1.02-1.244-2.346-2.276l-2-1.555C14.233 3.303 13.2 2.5 12 2.5s-2.233.803-4.298 2.409l-2 1.555C4.375 7.496 3.712 8.012 3.356 8.74S3 10.308 3 11.99"
RECEIPT_D = "M4 18.646V8.054c0-2.854 0-4.28.879-5.167C5.757 2 7.172 2 10 2h4c2.828 0 4.243 0 5.121.887C20 3.773 20 5.2 20 8.054v10.592c0 1.511 0 2.267-.462 2.565c-.755.486-1.922-.534-2.509-.904c-.485-.306-.727-.458-.997-.467c-.29-.01-.537.137-1.061.467l-1.911 1.205c-.516.325-.773.488-1.06.488s-.544-.163-1.06-.488l-1.91-1.205c-.486-.306-.728-.458-.997-.467c-.291-.01-.538.137-1.062.467c-.587.37-1.754 1.39-2.51.904C4 20.913 4 20.158 4 18.646"
FLAP_D = "M14 3H5a2 2 0 1 0 0 4h13c0-.93 0-1.395-.102-1.776a3 3 0 0 0-2.121-2.122C15.395 3 14.93 3 14 3"
ST = 'stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"'
BARS = '<rect x="4" y="12" width="4" height="9" rx="1.5"/><rect x="10" y="4" width="4" height="17" rx="1.5"/><rect x="16" y="8" width="4" height="13" rx="1.5"/>'
EXTRA = {
    "homeFill": f'<path fill="currentColor" {ST} d="{HOME_D}"/><path data-cut="1" fill="currentColor" d="M10 23V17.5a2 2 0 0 1 4 0V23z"/>',
    "receiptFill": f'<path fill="currentColor" {ST} d="{RECEIPT_D}"/><path data-cut="1" fill="none" {ST} d="M8 11h3M8 7h6"/>',
    "walletFill": f'<path fill="currentColor" {ST} d="{FLAP_D}"/><rect fill="currentColor" {ST} x="3" y="7" width="18" height="14" rx="4"/><path data-cut="1" fill="none" stroke="currentColor" stroke-width="1" d="M5 7h13"/><rect data-cut="1" fill="currentColor" x="15.5" y="11.5" width="7" height="4.5" rx="2.25"/>',
    "barChartFill": f'<g fill="currentColor" {ST}>{BARS}</g>',
    "barChart": f'<g fill="none" {ST}>{BARS}</g>',
}

src, out = sys.argv[1], sys.argv[2]
data = json.load(open(src))["icons"]
for _k, _b in EXTRA.items():
    data["custom:" + _k] = {"body": _b}
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
        cut = el.get("data-cut") == "1"
        piece = pathops.Path()
        if fill != "none":
            q = pathops.Path(p)
            if attrs.get("fill-rule") == "evenodd":
                q.fillType = pathops.FillType.EVEN_ODD
            q.simplify(fix_winding=True)
            piece = union(piece, q)
        if stroke != "none":
            q = pathops.Path(p)
            w = float(attrs.get("stroke-width", STROKE_DEFAULT)) * K * SCALE
            q.stroke(w, CAPS[attrs.get("stroke-linecap", "butt")], JOINS[attrs.get("stroke-linejoin", "miter")], 4)
            q.convertConicsToQuads(0.1)
            q.simplify(fix_winding=True)
            piece = union(piece, q)
        if cut:
            if list(result.segments) and list(piece.segments):
                result = pathops.op(result, piece, pathops.PathOp.DIFFERENCE)
        else:
            result = union(result, piece)

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
