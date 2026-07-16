#!/usr/bin/env python3
"""Compose a preview mockup of how the icons appear in real contexts."""
from PIL import Image, ImageDraw, ImageFont, ImageOps
import os

P = os.path.join(os.path.dirname(__file__), "..", "public")
def load(n): return Image.open(os.path.join(P, n)).convert("RGBA")

def font(sz, bold=True):
    for c in (["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"] if bold else
              ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]):
        if os.path.exists(c): return ImageFont.truetype(c, sz)
    return ImageFont.load_default()

BG = (238, 238, 234)
W, H = 1240, 1000
canvas = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(canvas)
d.text((40, 30), "Dutch 5K — new app icon preview", font=font(40), fill=(17, 17, 17))

def rounded(img, rad):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.size[0]-1, img.size[1]-1], rad, fill=255)
    out = img.copy(); out.putalpha(m); return out

def circle(img):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).ellipse([0, 0, img.size[0]-1, img.size[1]-1], fill=255)
    out = img.copy(); out.putalpha(m); return out

# --- Row 1: home-screen tiles ---
y = 120
def label(x, ty, t): d.text((x, ty), t, font=font(24, False), fill=(90, 90, 90))

# iOS (rounded square, uses apple-touch-icon)
ios = load("apple-touch-icon.png").resize((180, 180))
ios = rounded(ios, 40)
canvas.paste(ios, (60, y), ios)
label(60, y + 190, "iOS home screen")
d.text((60, y + 218), "Dutch 5K", font=font(22), fill=(30, 30, 30))

# Android (circular mask, uses maskable icon)
andr = load("icon-maskable-512.png").resize((180, 180))
andr = circle(andr)
canvas.paste(andr, (330, y), andr)
label(330, y + 190, "Android home screen")
d.text((330, y + 218), "Dutch 5K", font=font(22), fill=(30, 30, 30))

# Browser tab mock
tab = Image.new("RGB", (360, 92), (255, 255, 255))
td = ImageDraw.Draw(tab)
td.rounded_rectangle([0, 0, 359, 91], 12, fill=(255, 255, 255), outline=(200, 200, 200), width=2)
fav = load("favicon-32.png").resize((40, 40))
tab.paste(fav, (22, 26), fav)
td.text((78, 34), "Dutch 5K — Vocab Trainer", font=font(20), fill=(40, 40, 40))
canvas.paste(tab, (620, y + 44))
label(620, y + 150, "Browser tab")

# --- Row 2: link-share card ---
y2 = 460
d.text((60, y2 - 46), "Link-share preview (WhatsApp / iMessage / Slack …)", font=font(26), fill=(17, 17, 17))
og = load("og-image.png")
cardw = 1000
cardh = int(og.size[1] * cardw / og.size[0])
og2 = og.resize((cardw, cardh))
# chat-bubble frame
frame = Image.new("RGB", (cardw + 4, cardh + 96), (255, 255, 255))
fd = ImageDraw.Draw(frame)
frame.paste(og2.convert("RGB"), (2, 2))
fd.rectangle([2, 2, cardw + 1, cardh + 1], outline=(220, 220, 220), width=2)
fd.text((22, cardh + 22), "dutch5k  ·  Vocab Trainer for Dutch B1", font=font(22, False), fill=(120, 120, 120))
canvas.paste(rounded(frame.convert("RGBA"), 16), (60, y2), rounded(frame.convert("RGBA"), 16))

out = os.path.join(os.path.dirname(__file__), "icon_preview.png")
canvas.save(out)
print(out)
