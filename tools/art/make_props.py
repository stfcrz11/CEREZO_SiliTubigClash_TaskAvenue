"""Small pixel-art props for the quiz stations (drawn by code, 24x24 frames).

  cooler_stalls.png  4 frames: Halo-Halo, Mais Con Yelo, Sago't Gulaman, Buko Pandan
  bicol_pepper.png   Bicol Express pepper checkpoint (chili on a bilao tray)
  ice_block.png      translucent ice block drawn over a frozen Tubig

usage: python make_props.py <output dir>
"""
import math
import sys

from PIL import Image

OUT = sys.argv[1]
OUTLINE = (40, 32, 36, 255)


def new(w=24, h=24):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(px, x, y, c):
    w, h = px_size[0], px_size[1]
    if 0 <= x < w and 0 <= y < h:
        px[x, y] = c if len(c) == 4 else c + (255,)


px_size = (24, 24)

DRINKS = [
    # name, bottom layer, middle layer, topping colors
    ("halo_halo", (118, 62, 150), (196, 72, 84), [(250, 200, 70), (150, 80, 180), (230, 60, 70)]),
    ("mais_con_yelo", (226, 178, 52), (246, 226, 150), [(250, 210, 60), (255, 240, 170)]),
    ("sago_gulaman", (124, 70, 34), (176, 106, 48), [(40, 30, 30), (200, 60, 60)]),
    ("buko_pandan", (88, 170, 80), (226, 240, 210), [(120, 200, 100), (250, 250, 240)]),
]


def cooler_frame(bottom, middle, toppings):
    im = new()
    px = im.load()
    # wooden cart table
    for x in range(2, 22):
        for y in range(17, 20):
            put(px, x, y, (150, 96, 54) if y < 19 else (110, 68, 38))
        put(px, x, 16, OUTLINE)
        put(px, x, 20, OUTLINE)
    for y in range(16, 21):
        put(px, 1, y, OUTLINE)
        put(px, 22, y, OUTLINE)
    for x in (4, 19):
        for y in range(21, 24):
            put(px, x, y, (90, 56, 32))
    # glass (wider at the top)
    for y in range(5, 16):
        half = 4 + (15 - y) // 5
        for x in range(12 - half, 12 + half):
            if y >= 12:
                c = bottom
            elif y >= 9:
                c = middle
            else:
                c = (236, 246, 252)   # crushed ice
            put(px, x, y, c)
        put(px, 12 - half - 1, y, OUTLINE)
        put(px, 12 + half, y, OUTLINE)
    for x in range(8, 16):
        put(px, x, 16, OUTLINE)
    # glass shine
    for y in range(7, 14):
        put(px, 9, y, (255, 255, 255, 170))
    # dome of shaved ice with toppings
    for y in range(1, 6):
        for x in range(6, 18):
            if (x - 11.5) ** 2 / 36 + (y - 5.5) ** 2 / 20 <= 1:
                put(px, x, y, (246, 250, 255))
    for x in range(6, 18):
        for y in range(0, 6):
            if px[x, y][3] and (y == 0 or px[x, y - 1][3] == 0):
                put(px, x, y - 1, OUTLINE)
    for i, (x, y) in enumerate([(9, 3), (13, 2), (11, 4), (15, 4), (8, 5)]):
        put(px, x, y, toppings[i % len(toppings)])
    # spoon
    for i in range(5):
        put(px, 15 + i // 2, 4 - i, (170, 176, 190))
    return im


def coolers():
    sheet = new(24 * len(DRINKS), 24)
    for i, (_, b, m, t) in enumerate(DRINKS):
        sheet.paste(cooler_frame(b, m, t), (i * 24, 0))
    sheet.save(f"{OUT}/cooler_stalls.png")


def pepper():
    im = new()
    px = im.load()
    # bilao (round woven tray)
    for y in range(24):
        for x in range(24):
            d = (x - 11.5) ** 2 / 121 + (y - 15) ** 2 / 49
            if d <= 1:
                woven = (x + y) % 3 == 0
                put(px, x, y, (196, 150, 82) if not woven else (168, 122, 62))
                if d > 0.8:
                    put(px, x, y, (120, 80, 40))
    # chili: a fat curved pepper
    for t in range(0, 60):
        a = t / 59
        cx = 6 + a * 12
        cy = 13 - math.sin(a * math.pi) * 4 + a * 3
        r = 3.2 * (1 - a * 0.75)
        for y in range(24):
            for x in range(24):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    put(px, x, y, (214, 40, 36))
    # outline + shine
    base = im.copy().load()
    for y in range(24):
        for x in range(24):
            if base[x, y][:3] == (214, 40, 36):
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 24 and 0 <= ny < 24 and base[nx, ny][:3] != (214, 40, 36):
                        put(px, nx, ny, (110, 16, 20))
    for x, y in ((6, 10), (7, 9), (8, 9), (9, 9)):
        put(px, x, y, (255, 150, 130))
    # green stem
    for x, y in ((4, 11), (3, 10), (3, 9), (4, 8), (2, 10), (2, 9)):
        put(px, x, y, (70, 150, 50))
    im.save(f"{OUT}/bicol_pepper.png")


def ice_block():
    global px_size
    px_size = (22, 30)
    im = new(22, 30)
    px = im.load()
    for y in range(30):
        for x in range(22):
            edge = x in (0, 21) or y in (0, 29)
            if edge:
                c = (210, 245, 255, 235)
            elif x in (1, 20) or y in (1, 28):
                c = (150, 210, 245, 170)
            else:
                c = (120, 190, 240, 105)
            put(px, x, y, c)
    for i in range(9):   # shine streaks
        put(px, 3 + i // 3, 3 + i, (255, 255, 255, 200))
        put(px, 15 + i // 4, 18 + i // 2, (255, 255, 255, 150))
    im.save(f"{OUT}/ice_block.png")
    px_size = (24, 24)


coolers()
pepper()
ice_block()
print("props saved")
