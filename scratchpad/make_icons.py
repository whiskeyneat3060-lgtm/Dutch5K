#!/usr/bin/env python3
"""Generate Mondrian-style app icons + share image for Dutch 5K.
On-brand: white paper, thick black rules, red/blue/yellow blocks (see CLAUDE.md)."""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "public")

INK   = (17, 17, 17)     # #111
PAPER = (255, 255, 255)
RED   = (221, 1, 0)      # #DD0100
BLUE  = (34, 80, 149)    # #225095
YELLOW= (250, 201, 1)    # #FAC901

# Mondrian composition in relative (0..1) coords: coloured blocks over a white
# ground, then thick black rules drawn on top of the seams + outer frame.
BLOCKS = [
    (0.00, 0.00, 0.58, 0.60, RED),      # big red, top-left
    (0.00, 0.60, 0.32, 1.00, BLUE),     # blue, bottom-left cell
    (0.76, 0.60, 1.00, 1.00, YELLOW),   # yellow, bottom-right cell
]
# Connected grid: a full cross + two dividers in the bottom row, so every rule
# meets another one (proper Mondrian, no floating segments).
VLINES = [(0.58, 0.00, 1.00), (0.32, 0.60, 1.00), (0.76, 0.60, 1.00)]
HLINES = [(0.60, 0.00, 1.00)]


def draw_logo(size, line_frac=0.05, border=True):
    img = Image.new("RGB", (size, size), PAPER)
    d = ImageDraw.Draw(img)
    lw = max(2, round(size * line_frac))

    def px(v): return round(v * size)

    for x0, y0, x1, y1, col in BLOCKS:
        d.rectangle([px(x0), px(y0), px(x1), px(y1)], fill=col)

    for pos, a, b in VLINES:
        d.rectangle([px(pos) - lw // 2, px(a), px(pos) + lw - lw // 2, px(b)], fill=INK)
    for pos, a, b in HLINES:
        d.rectangle([px(a), px(pos) - lw // 2, px(b), px(pos) + lw - lw // 2], fill=INK)

    if border:
        d.rectangle([0, 0, size - 1, size - 1], outline=INK, width=lw)
    return img


def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p)
    print("wrote", os.path.relpath(p))


# Standard icons (with frame, tight)
save(draw_logo(512), "icon-512.png")
save(draw_logo(192), "icon-192.png")
save(draw_logo(180), "apple-touch-icon.png")
save(draw_logo(32), "favicon-32.png")

# Maskable icon: safe zone — shrink logo to ~72% centred on white so Android's
# circular/rounded mask never clips the composition.
def maskable(size=512, scale=0.72):
    bg = Image.new("RGB", (size, size), PAPER)
    inner = round(size * scale)
    logo = draw_logo(inner)
    off = (size - inner) // 2
    bg.paste(logo, (off, off))
    return bg

save(maskable(), "icon-maskable-512.png")

# favicon.ico (multi-size)
ico = draw_logo(64, line_frac=0.1)
ico.save(os.path.join(OUT, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)])
print("wrote", "favicon.ico")

# ---- Share image (Open Graph / Twitter) 1200x630 ----
def share():
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    logo_size = 400
    lx, ly = 80, (H - logo_size) // 2
    img.paste(draw_logo(logo_size), (lx, ly))
    # thick black divider rule
    dx = lx + logo_size + 60
    d.rectangle([dx, 120, dx + 9, H - 120], fill=INK)

    def font(sz):
        for cand in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                     "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
            if os.path.exists(cand):
                return ImageFont.truetype(cand, sz)
        return ImageFont.load_default()

    tx = dx + 55
    lines = [("Dutch 5K", 84, INK), ("Vocab Trainer", 46, RED),
             ("5,000 words · flashcards · offline", 27, (90, 90, 90))]
    # vertically centre the text block
    gaps = [28, 26]
    heights = [d.textbbox((0, 0), t, font=font(s))[3] for t, s, _ in lines]
    total = sum(heights) + sum(gaps)
    y = (H - total) // 2
    for i, (t, s, col) in enumerate(lines):
        d.text((tx, y), t, font=font(s), fill=col)
        y += heights[i] + (gaps[i] if i < len(gaps) else 0)
    return img

save(share(), "og-image.png")
print("done")
