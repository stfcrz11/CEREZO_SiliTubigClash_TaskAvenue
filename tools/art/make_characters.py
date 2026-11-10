"""Paints Sili / Tubig outfits onto Eris Esra's 16x32 character template.

Output sheet (32x32 cells, 6 columns):
  rows 0-4   Idle     (4 frames)  directions: down, down-right, right, up-right, up
  rows 5-9   Walk     (4 frames)
  rows 10-14 Run      (6 frames)
  rows 15-19 Interact (4 frames)  used while answering a question
Left-facing directions are the right-facing rows flipped in the game.
"""
import sys
from PIL import Image

SRC = sys.argv[1]      # folder with the template sheets
OUT = sys.argv[2]      # output folder

CELL = 32
COLS = 6
ANIMS = [("Idle", 4), ("Walk", 4), ("Run", 6), ("Interact", 4)]

OUTLINE = (47, 37, 34)
SHADOW = (185, 179, 161)
LIGHT = (250, 243, 232)
MID = (231, 213, 198)
BLUSH = (209, 157, 167)

SKIN = {"l": (238, 192, 150), "s": (196, 142, 106), "m": (222, 170, 128)}
HAIR = {"l": (64, 46, 40), "s": (38, 28, 26), "m": (52, 38, 34)}

ROLES = {
    "sili": {
        "shirt": {"l": (222, 54, 42), "s": (150, 28, 30), "m": (190, 40, 36)},
        "stripe": (255, 196, 64),
        "shorts": {"l": (62, 58, 72), "s": (38, 36, 48), "m": (50, 47, 60)},
        "shoes": {"l": (96, 64, 48), "s": (58, 40, 32), "m": (76, 52, 40)},
    },
    "tubig": {
        "shirt": {"l": (72, 168, 236), "s": (36, 104, 176), "m": (54, 136, 206)},
        "stripe": (236, 250, 255),
        "shorts": {"l": (40, 64, 120), "s": (24, 40, 82), "m": (32, 52, 100)},
        "shoes": {"l": (230, 230, 236), "s": (150, 154, 168), "m": (190, 192, 204)},
    },
}


def shade(c, pal):
    if c == LIGHT:
        return pal["l"]
    if c == SHADOW:
        return pal["s"]
    if c == MID:
        return pal["m"]
    return None


def opaque_rows(im):
    rows = {}
    for y in range(CELL):
        xs = [x for x in range(CELL) if im.getpixel((x, y))[3] > 0]
        if xs:
            rows[y] = (min(xs), max(xs), len(xs))
    return rows


def paint_cell(cell, direction, role):
    pal = ROLES[role]
    im = cell.copy()
    rows = opaque_rows(im)
    if not rows:
        return im
    top = min(rows)
    bottom = max(rows)
    # the neck is the narrowest row between head and body
    cands = [y for y in range(top + 9, top + 14) if y in rows]
    neck = min(cands, key=lambda y: (rows[y][2], -y))
    hl, hr = min(rows[y][0] for y in range(top, neck)), max(rows[y][1] for y in range(top, neck))
    cx = (hl + hr) // 2
    hip_row = neck + 9
    hip = rows.get(hip_row, (cx - 3, cx + 3, 0))

    px = im.load()
    for y in range(CELL):
        for x in range(CELL):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            c = (r, g, b)
            if c == OUTLINE:
                continue
            region = "skin"
            if y < neck:
                if is_hair(x, y, top, neck, hl, hr, cx, direction):
                    region = "hair"
            elif y == neck:
                region = "skin"
            elif y <= neck + 8:
                region = "shirt"
                if y >= neck + 7 and (x < hip[0] or x > hip[1]):
                    region = "skin"   # hands
            elif y <= neck + 10:
                region = "shorts"
            elif y < bottom and y < neck + 13:
                region = "skin"
            else:
                region = "shoes"
            if c == BLUSH:
                if region == "skin":
                    px[x, y] = (226, 132, 120, a)
                else:
                    px[x, y] = HAIR["l"] + (a,)
                continue
            p = {"skin": SKIN, "hair": HAIR}.get(region) or pal[region]
            new = shade(c, p)
            if new:
                px[x, y] = new + (a,)
    # chest stripe (Sili: flame-yellow, Tubig: white wave) on light shirt pixels
    sy = neck + 4
    for x in range(CELL):
        r, g, b, a = px[x, sy]
        if a and (r, g, b) == pal["shirt"]["l"]:
            wave = role == "sili" or (x % 4 in (0, 1))
            px[x, sy] = pal["stripe"] + (a,) if wave else px[x, sy]
            if role == "tubig" and x % 4 in (2, 3):
                px[x, sy - 1] = pal["stripe"] + (a,) if px[x, sy - 1][:3] == pal["shirt"]["l"] else px[x, sy - 1]
    draw_accessory(px, role, top, cx, direction)
    return im


def is_hair(x, y, top, neck, hl, hr, cx, d):
    rel = y - top
    if rel <= 3:
        return True
    if d == 0:      # facing down
        if rel == 4:
            return True
        if rel == 5:
            return not (cx - 2 <= x <= cx + 2)          # fringe
        return rel <= 7 and (x <= hl + 1 or x >= hr - 1)  # sideburns
    if d in (1, 2):  # facing down-right / right: back of the head is on the left
        if rel == 4:
            return True
        limit = cx - 1 if d == 2 else cx - 2
        return rel <= (neck - top) - 3 and x <= limit - (1 if rel >= 7 else 0) and not (d == 2 and rel in (6, 7, 8) and x in (cx - 2, cx - 1))
    if d == 3:      # up-right: only the face edge on the right shows skin
        return not (x >= hr - 2 and rel >= 5) and rel <= (neck - top) - 2
    return rel <= (neck - top) - 2   # facing up: all hair


def put(px, x, y, c):
    if 0 <= x < CELL and 0 <= y < CELL:
        px[x, y] = c + (255,)


def draw_accessory(px, role, top, cx, d):
    if role == "sili":
        # green chili stem sprouting from the head
        g, dg = (88, 176, 64), (34, 82, 34)
        sx = cx + (0 if d in (0, 4) else -1)
        for (x, y, c) in [(sx, top - 1, g), (sx, top - 2, g), (sx + 1, top - 3, g), (sx + 2, top - 3, g),
                          (sx - 1, top - 1, dg), (sx + 1, top - 1, dg), (sx - 1, top - 2, dg), (sx + 1, top - 2, dg),
                          (sx, top - 3, dg), (sx + 1, top - 4, dg), (sx + 2, top - 4, dg), (sx + 3, top - 3, dg), (sx, top - 4, dg)]:
            put(px, x, y, c)
    else:
        # little water droplet on top of the head
        o, l, w = (24, 70, 140), (96, 190, 250), (230, 248, 255)
        sx = cx + (0 if d in (0, 4) else -1)
        shape = [
            (0, -5, o),
            (-1, -4, o), (0, -4, l), (1, -4, o),
            (-2, -3, o), (-1, -3, w), (0, -3, l), (1, -3, l), (2, -3, o),
            (-2, -2, o), (-1, -2, l), (0, -2, l), (1, -2, l), (2, -2, o),
            (-1, -1, o), (0, -1, o), (1, -1, o),
        ]
        for dx, dy, c in shape:
            put(px, sx + dx, top + dy, c)


def main():
    for role in ROLES:
        rows_total = sum(5 for _ in ANIMS)
        sheet = Image.new("RGBA", (COLS * CELL, rows_total * CELL), (0, 0, 0, 0))
        row0 = 0
        for anim, frames in ANIMS:
            src = Image.open(f"{SRC}/16x32 {anim}-Sheet.png").convert("RGBA")
            assert src.width == frames * CELL, (anim, src.size)
            for d in range(5):
                for f in range(frames):
                    cell = src.crop((f * CELL, d * CELL, (f + 1) * CELL, (d + 1) * CELL))
                    sheet.paste(paint_cell(cell, d, role), (f * CELL, (row0 + d) * CELL))
            row0 += 5
        sheet.save(f"{OUT}/{role}_sheet.png")
        print("saved", role, sheet.size)


main()
