"""Makes the second icon state for every Stream Deck key that shows OBS state.
   python make_states.py <icons_dir> <retail|forever>
   Reads the normal icons (state 0) and writes, next to them:
     mic_off / desktop_off            muted  (red slash, red "MUTED")
     cam_off / sponsors_off / alerts_off   hidden (red slash, "HIDDEN")
     scene_*_active                   the scene that is on screen (accent frame + "ACTIVE" tag)
     record_on                        recording (red)
     live_on                          streaming (red, "LIVE")
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "Archivo-ExtraBold.ttf")
RED, RED_D = (240, 72, 72), (150, 28, 34)
ACC = {"retail": ((232, 120, 90), (240, 176, 92)), "forever": ((217, 164, 65), (246, 217, 143))}
S = 144
LABEL = (92, 127)          # rows the label sits in


def font(px): return ImageFont.truetype(FONT, px)


def spaced(d, text, y, px, fill, track=0.12):
    f = font(px); tr = px * track
    w = sum(d.textlength(c, font=f) for c in text) + tr * (len(text) - 1)
    x = (S - w) / 2
    for c in text:
        d.text((x, y), c, font=f, fill=fill, anchor="lm"); x += d.textlength(c, font=f) + tr


def erase_label(im):
    """Paint the label rows with the key's own background (sampled at the edges of each row)."""
    px = im.load()
    for y in range(*LABEL):
        a, b = px[5, y], px[S - 6, y]
        c = tuple((a[i] + b[i]) // 2 + 2 for i in range(3))
        for x in range(4, S - 4): px[x, y] = c


def grey(im, k=0.45):
    g = im.convert("L").convert("RGB")
    return Image.blend(im, g, 0.85).point(lambda v: int(v * k))


def grad(c0, c1, w, h, diag=True):
    g = Image.new("RGB", (w, h)); p = g.load()
    for y in range(h):
        for x in range(w):
            t = ((x / w) + (y / h)) / 2 if diag else x / w
            p[x, y] = tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3))
    return g


def frame(im, c0, c1, width):
    mask = Image.new("L", (S, S), 0); d = ImageDraw.Draw(mask)
    d.rectangle((0, 0, S - 1, S - 1), fill=255); d.rectangle((width, width, S - 1 - width, S - 1 - width), fill=0)
    glow = mask.filter(ImageFilter.GaussianBlur(5))
    g = grad(c0, c1, S, S)
    im = Image.composite(g, im, ImageChops.multiply(glow, Image.new("L", (S, S), 110)))
    return Image.composite(g, im, mask)


def muted(src, word):
    im = grey(src)
    erase_label(im)
    d = ImageDraw.Draw(im)
    d.line((40, 26, 104, 86), fill=(12, 14, 20), width=15)       # cut the glyph...
    d.line((40, 26, 104, 86), fill=RED, width=7)                  # ...with a red slash
    d.rectangle((50, 0, 94, 4), fill=RED)                         # top bar turns red
    spaced(d, word, 109, 17, RED)
    return frame(im, RED_D, RED, 2)


def active(src, ed):
    c0, c1 = ACC[ed]
    tint = Image.new("RGB", (S, S), c0)
    glow = Image.new("L", (S, S), 0); ImageDraw.Draw(glow).ellipse((-10, -30, S + 10, 110), fill=70)
    im = Image.composite(tint, src, glow.filter(ImageFilter.GaussianBlur(28)))
    im = Image.blend(src, im, 1.0)
    im = frame(im, c0, c1, 5)
    d = ImageDraw.Draw(im)                                        # "ACTIVE" tag where the little bar was
    tag = grad(c0, c1, 70, 18, diag=False); m = Image.new("L", (70, 18), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 69, 17), radius=9, fill=255)
    im.paste(tag, (37, 5), m)
    d = ImageDraw.Draw(im)
    spaced(d, "ACTIVE", 14, 11, (10, 12, 17), 0.14)
    return im


def recording(src):
    im = src.copy(); px = im.load()
    for y in range(8, LABEL[0]):                                  # the accent glyph turns red
        for x in range(S):
            r, g, b = px[x, y]
            if r > 90 and r > b + 40:
                k = r / 240; px[x, y] = (min(255, int(RED[0] * k * 1.05)), int(RED[1] * k), int(RED[2] * k))
    red_bg = Image.new("RGB", (S, S), (70, 12, 16))
    glow = Image.new("L", (S, S), 0); ImageDraw.Draw(glow).ellipse((-20, -20, S + 20, S + 10), fill=120)
    im = Image.composite(red_bg, im, glow.filter(ImageFilter.GaussianBlur(30)))
    erase_label(im)
    d = ImageDraw.Draw(im); d.rectangle((50, 0, 94, 4), fill=RED)
    spaced(d, "REC", 109, 17, (255, 236, 236))
    d.ellipse((S - 22, 10, S - 10, 22), fill=RED)
    return frame(im, RED_D, RED, 4)


def live(src):
    # glyph mask: the dark strokes on the light key
    L = src.convert("L"); m = L.point(lambda v: 255 if v < 110 else 0)
    m = m.crop((0, 0, S, LABEL[0])).filter(ImageFilter.GaussianBlur(0.6))
    im = grad((232, 60, 60), (160, 22, 30), S, S)
    glyphs = Image.new("RGB", (S, LABEL[0]), (255, 255, 255))
    im.paste(glyphs, (0, 0), m)
    d = ImageDraw.Draw(im)
    spaced(d, "LIVE", 109, 19, (255, 255, 255), 0.16)
    d.ellipse((S - 22, 10, S - 10, 22), fill=(255, 255, 255))
    return im


def run(dirp, ed):
    o = lambda n: Image.open(os.path.join(dirp, n + ".png")).convert("RGB")
    out = {}
    for n in ("mic", "desktop"): out[n + "_off"] = muted(o(n), "MUTED")
    for n in ("cam", "sponsors", "alerts"): out[n + "_off"] = muted(o(n), "HIDDEN")
    for n in ("scene_starting", "scene_ingame", "scene_brb", "scene_ending", "scene_outro"): out[n + "_active"] = active(o(n), ed)
    out["record_on"] = recording(o("record")); out["live_on"] = live(o("live"))
    for k, im in out.items(): im.save(os.path.join(dirp, k + ".png"))
    return out


if __name__ == "__main__":
    run(sys.argv[1], sys.argv[2])
