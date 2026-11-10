"""Game icon from the title logo (assets/ui/title_logo.png, by Stefane Cerezo).

The logo is wide, icons are square: the whole logo sits on a dark rounded
square with a gold frame, like the game's windows.

  assets/icon/icon.png              512x512  window / taskbar / project icon
  assets/icon/icon.ico              16-256   Windows .exe icon
  assets/icon/android_192.png       192x192  Android launcher icon
  assets/icon/android_fg_432.png    432x432  Android adaptive icon, front layer
  assets/icon/android_bg_432.png    432x432  Android adaptive icon, back layer

usage: python make_icon.py <project dir>
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = sys.argv[1]
OUT = f"{ROOT}/assets/icon"
os.makedirs(OUT, exist_ok=True)
LOGO = Image.open(f"{ROOT}/assets/ui/title_logo.png").convert("RGBA")

BG = (30, 32, 44, 255)
BG_GLOW = (52, 56, 78, 255)
GOLD = (236, 178, 52, 255)
OUTLINE = (33, 26, 20, 255)


def logo_fit(width):
    h = round(LOGO.height * width / LOGO.width)
    return LOGO.resize((width, h), Image.LANCZOS)


def background(size, rounded=True):
    """Dark square with a soft lighter centre (and a frame if rounded)."""
    big = size * 4   # draw large, then shrink for smooth edges
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = big // 5 if rounded else 0
    if rounded:
        d.rounded_rectangle((0, 0, big - 1, big - 1), r, fill=OUTLINE)
        d.rounded_rectangle((big // 40, big // 40, big - 1 - big // 40, big - 1 - big // 40), r, fill=GOLD)
        inset = big // 18
        d.rounded_rectangle((inset, inset, big - 1 - inset, big - 1 - inset), r - inset // 2, fill=BG)
    else:
        d.rectangle((0, 0, big, big), fill=BG)
    # soft glow behind the logo
    glow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(12):
        a = int(12 + i * 8)
        pad = big // 8 + i * big // 80
        gd.ellipse((pad, pad + big // 12, big - pad, big - pad - big // 12), fill=BG_GLOW[:3] + (a,))
    mask = im.split()[3] if rounded else None
    im.alpha_composite(glow)
    if mask:
        im.putalpha(mask)
    return im.resize((size, size), Image.LANCZOS)


def icon(size):
    im = background(size)
    logo = logo_fit(int(size * 0.86))
    im.alpha_composite(logo, ((size - logo.width) // 2, (size - logo.height) // 2))
    return im


def small_icon(size):
    """For 16-48 px the wordmark can't be read: use the two mascots instead
    (the chili "S" and the water drop from the logo)."""
    work = 256
    im = background(work)
    chili = LOGO.crop((0, 0, 128, 150))
    drop = LOGO.crop((338, 45, 421, 140))
    c = chili.resize((int(128 * 1.35), int(150 * 1.35)), Image.LANCZOS)
    d = drop.resize((int(83 * 1.25), int(95 * 1.25)), Image.LANCZOS)
    im.alpha_composite(c, (18, 22))
    im.alpha_composite(d, (work - d.width - 16, work - d.height - 26))
    return im.resize((size, size), Image.LANCZOS)


big = icon(512)
big.save(f"{OUT}/icon.png")
icon(192).save(f"{OUT}/android_192.png")
small_icon(64).save(f"{OUT}/icon_small.png")
ico_frames = [small_icon(n) for n in (16, 24, 32, 48)] + [icon(n) for n in (64, 128, 256)]
ico_frames[-1].save(f"{OUT}/icon.ico", sizes=[f.size for f in ico_frames], append_images=ico_frames[:-1])

# Android adaptive icon: the launcher crops to a circle / squircle, so the
# logo stays inside the middle 2/3 (the "safe zone") of the 432 px layer
fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
logo = logo_fit(280)
fg.alpha_composite(logo, ((432 - logo.width) // 2, (432 - logo.height) // 2))
fg.save(f"{OUT}/android_fg_432.png")
background(432, rounded=False).save(f"{OUT}/android_bg_432.png")
print("icons saved in", OUT)
