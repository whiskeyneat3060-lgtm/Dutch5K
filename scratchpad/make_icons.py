#!/usr/bin/env python3
"""Generate app icons + share image for Dutch 5K from the circular badge art
(black ring, red/white/blue tulip-book, "DUTCH / VOCAB TRAINER / 5000 WORDS").
Used ONLY for the browser tab / home-screen icon / link-share card — never
inside the app UI. We crop the circular badge and composite it onto white so
every tile is a clean white square with the ringed badge centred."""
from PIL import Image, ImageDraw, ImageFont
import os, io, base64

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "public")
SRC = "/root/.claude/uploads/2acb7ccb-aa59-5ad0-a9d9-445b4cf4cc16/8a538840-1784217318076.png"

# Detected: black ring centred at (511,284), outer radius ~207.
CX, CY, R = 511, 284, 210
WHITE = (255, 255, 255)

src = Image.open(SRC).convert("RGB")

def badge_disk(out=1024):
    """Circular crop of the badge (transparent outside the ring), anti-aliased."""
    box = src.crop((CX - R, CY - R, CX + R, CY + R)).resize((out, out), Image.LANCZOS)
    m = Image.new("L", (out * 4, out * 4), 0)
    ImageDraw.Draw(m).ellipse([0, 0, out * 4 - 1, out * 4 - 1], fill=255)
    m = m.resize((out, out), Image.LANCZOS)
    disk = Image.new("RGBA", (out, out), (0, 0, 0, 0))
    disk.paste(box, (0, 0), m)
    return disk

DISK = badge_disk(1024)

def icon(size, scale=0.94):
    img = Image.new("RGB", (size, size), WHITE)
    inner = round(size * scale)
    d = DISK.resize((inner, inner), Image.LANCZOS)
    off = (size - inner) // 2
    img.paste(d, (off, off), d)
    return img

def save(img, name):
    img.save(os.path.join(OUT, name)); print("wrote", name)

save(icon(512), "icon-512.png")
save(icon(192), "icon-192.png")
save(icon(180), "apple-touch-icon.png")
save(icon(32), "favicon-32.png")
# maskable: shrink to ~78% so Android's circular mask never clips the ring/text
save(icon(512, 0.78), "icon-maskable-512.png")

ico = icon(64, 0.96)
ico.save(os.path.join(OUT, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)])
print("wrote favicon.ico")

# ---- Share card 1200x630: badge left, tagline right ----
def font(sz):
    for c in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(c): return ImageFont.truetype(c, sz)
    return ImageFont.load_default()

def share():
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), WHITE)
    d = ImageDraw.Draw(img)
    bs = 460
    img.paste(DISK.resize((bs, bs), Image.LANCZOS), (60, (H - bs) // 2), DISK.resize((bs, bs), Image.LANCZOS))
    tx = 580
    maxw = W - tx - 60
    INK = (20, 20, 20)
    RED = (196, 30, 40)
    spec = [("Learn Dutch,", 68, INK), ("5,000 words at a time", 46, RED),
            ("flashcards · examples · offline", 29, (110, 110, 110))]

    def fit(t, sz):
        while sz > 10 and d.textlength(t, font=font(sz)) > maxw:
            sz -= 2
        return font(sz)
    fonts = [fit(t, s) for t, s, _ in spec]
    gaps = [16, 30]
    hs = [d.textbbox((0, 0), t, font=fn)[3] for (t, _, _), fn in zip(spec, fonts)]
    y = (H - sum(hs) - sum(gaps)) // 2
    for i, ((t, _, col), fn) in enumerate(zip(spec, fonts)):
        d.text((tx, y), t, font=fn, fill=col)
        y += hs[i] + (gaps[i] if i < len(gaps) else 0)
    return img

save(share(), "og-image.png")

# vector favicon: embed the disk PNG as a data URI
buf = io.BytesIO(); icon(180, 0.96).save(buf, "PNG")
b64 = base64.b64encode(buf.getvalue()).decode()
with open(os.path.join(OUT, "favicon.svg"), "w") as f:
    f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 180">'
            '<image width="180" height="180" href="data:image/png;base64,%s"/></svg>' % b64)
print("wrote favicon.svg")
print("done")
