"""Pixel-art UI in the style of the city tileset (buttons, window frames,
store windows). Everything is drawn on a small grid and scaled up with
nearest-neighbour so it matches the game's pixel art. Button text uses a
hand-made 5x7 pixel font (no font files needed).

usage: python make_ui.py <project dir>
"""
import sys

from PIL import Image

ROOT = sys.argv[1]
UI = f"{ROOT}/assets/ui"

# ---------------------------------------------------------------- palette
OUT = (33, 26, 20)          # tileset outline
HI = (213, 204, 205)        # roof highlight
PARAPET = (177, 173, 170)
EDGE = (47, 43, 42)
SLATE = (36, 38, 50)        # window fill (dark, so text stays readable)
SLATE_HI = (58, 60, 76)
CARD = (52, 54, 70)
GOLD = (236, 178, 52)
GOLD_HI = (255, 222, 120)
GOLD_LO = (176, 118, 30)
BLUE = (72, 168, 236)       # Tubig
RED = (214, 52, 42)         # Sili
GREEN = (88, 170, 80)
WOOD = (150, 96, 54)
WOOD_LO = (110, 68, 38)
WOOD_HI = (184, 128, 78)
GRAY = (112, 116, 128)
AWN_RED = (202, 69, 60)
AWN_WHITE = (235, 232, 241)
AWN_LINE = (57, 0, 0)
BRICK = (129, 80, 65)
BRICK_LO = (103, 59, 45)
PLASTER = (215, 210, 206)
DARK_TEXT = (40, 28, 24)
WHITE = (250, 248, 240)

# ---------------------------------------------------------------- font
FONT = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
    "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    "-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
    ".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
    ":": [".....", "..#..", ".....", ".....", ".....", "..#..", "....."],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "'": ["..#..", "..#..", ".....", ".....", ".....", ".....", "....."],
}


def text_width(text):
    w = 0
    for ch in text:
        w += 3 if ch == " " else 6
    return w - 1


def draw_text(px, x, y, text, color, shadow=None):
    for ch in text:
        if ch == " ":
            x += 3
            continue
        rows = FONT[ch.upper()]
        for dy, row in enumerate(rows):
            for dx, c in enumerate(row):
                if c == "#":
                    if shadow:
                        put(px, x + dx, y + dy + 1, shadow)
        for dy, row in enumerate(rows):
            for dx, c in enumerate(row):
                if c == "#":
                    put(px, x + dx, y + dy, color)
        x += 6


def put(px, x, y, c):
    try:
        px[x, y] = c + (255,) if len(c) == 3 else c
    except IndexError:
        pass


def rect(px, x0, y0, x1, y1, c):
    for y in range(y0, y1):
        for x in range(x0, x1):
            put(px, x, y, c)


def scaled(im, s, size=None):
    big = im.resize((im.width * s, im.height * s), Image.NEAREST)
    if size and big.size != size:
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        canvas.alpha_composite(big, ((size[0] - big.width) // 2, (size[1] - big.height) // 2))
        return canvas
    return big


# ---------------------------------------------------------------- buttons
def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def button(text, fill, size, text_color=WHITE, icon=None):
    """A chunky button: dark outline, light top edge, thick bottom shadow."""
    W, H = size
    tw = text_width(text) if text else 12
    s = 8 if icon else max(3, min(8, W // (tw + 10), H // 14))
    w, h = W // s, H // s
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    rect(px, 1, 1, w - 1, h - 1, fill)
    rect(px, 1, h - 4, w - 1, h - 1, shade(fill, 0.62))        # bottom shadow (3D)
    rect(px, 2, 1, w - 2, 2, shade(fill, 1.35))                # top highlight
    rect(px, 1, 2, 2, h - 4, shade(fill, 1.15))
    for x in range(1, w - 1):                                  # outline with cut corners
        put(px, x, 0, OUT)
        put(px, x, h - 1, OUT)
    for y in range(1, h - 1):
        put(px, 0, y, OUT)
        put(px, w - 1, y, OUT)
    for cx, cy in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        put(px, cx, cy, OUT)
    if text:
        tx = (w - tw) // 2
        ty = (h - 3 - 7 + 1) // 2
        draw_text(px, tx, ty, text, text_color, shadow=shade(fill, 0.5) if text_color == WHITE else None)
    if icon:
        icon(px, w, h)
    return scaled(im, s, size)


def icon_x(px, w, h):
    cx, cy = w // 2, (h - 3) // 2
    for i in range(-3, 4):
        for dx in (0, 1):
            put(px, cx + i + dx - 1, cy + i, WHITE)
            put(px, cx - i + dx - 1, cy + i, WHITE)


def icon_gear(px, w, h):
    import math
    cx, cy = (w - 1) / 2, (h - 4) / 2
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy)
            a = math.atan2(y - cy, x - cx)
            tooth = (math.cos(a * 8) > 0.3)
            if 1.5 < d <= 3.2 or (3.2 < d <= 4.4 and tooth):
                put(px, x, y, WHITE)


BUTTONS = {
    # file: (text, color, size, text color)
    "button_play": ("PLAY", GOLD, (540, 108), DARK_TEXT),
    "button_solo": ("SOLO VS BOT", BLUE, (540, 108), WHITE),
    "button_host": ("HOST GAME", GREEN, (540, 108), WHITE),
    "button_join": ("JOIN GAME", GREEN, (540, 108), WHITE),
    "button_how_to_play": ("HOW TO PLAY", WOOD, (540, 108), WHITE),
    "button_leaderboard": ("LEADERBOARD", WOOD, (540, 108), WHITE),
    "button_credits": ("CREDITS", WOOD, (540, 108), WHITE),
    "button_quit": ("QUIT", RED, (540, 108), WHITE),
    "button_got_it": ("GOT IT!", GOLD, (400, 96), DARK_TEXT),
    "button_cancel": ("CANCEL", GRAY, (420, 112), WHITE),
    "button_connect": ("CONNECT", GOLD, (340, 100), DARK_TEXT),
    "button_start": ("START GAME", GOLD, (500, 112), DARK_TEXT),
    "button_join_small": ("JOIN", GREEN, (240, 92), WHITE),
}


def make_buttons():
    for name, (text, color, size, tc) in BUTTONS.items():
        button(text, color, size, tc).save(f"{UI}/{name}.png")
    button("", RED, (96, 96), icon=icon_x).save(f"{UI}/button_close.png")
    button("", SLATE_HI, (96, 96), icon=icon_gear).save(f"{UI}/button_settings.png")


# ---------------------------------------------------------------- frames
def frame(size, fill, layers):
    """A 9-slice frame: `layers` are the border colors from outside in."""
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    px = im.load()
    w, h = size
    rect(px, 0, 0, w, h, fill)
    for i, c in enumerate(layers):
        for x in range(i, w - i):
            put(px, x, i, c)
            put(px, x, h - 1 - i, c)
        for y in range(i, h - i):
            put(px, i, y, c)
            put(px, w - 1 - i, y, c)
    # cut the outer corners so the window isn't a hard rectangle
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        px[cx, cy] = (0, 0, 0, 0)
    return im


def make_frames():
    # windows: like the game's rooftops (outline, light edge, parapet, dark lip)
    panel = frame((16, 16), SLATE, [OUT, HI, PARAPET, PARAPET, EDGE])
    scaled(panel, 4).save(f"{UI}/panel.png")
    card = frame((12, 12), CARD, [(24, 22, 30), SLATE_HI, CARD])
    scaled(card, 4).save(f"{UI}/card.png")
    board = frame((12, 12), (38, 74, 54), [OUT, WOOD_HI, WOOD])
    scaled(board, 4).save(f"{UI}/host_store/chalkboard.png")


# ---------------------------------------------------------------- stores
def store_top(awning, awning_dark):
    """Shop front header, 320x59 at 1x (shown 640x118 in game)."""
    w, h = 320, 59
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    # rooftop parapet like the tileset buildings
    rect(px, 0, 0, w, 2, OUT)
    rect(px, 0, 2, w, 3, HI)
    rect(px, 0, 3, w, 7, PARAPET)
    rect(px, 0, 7, w, 8, EDGE)
    # brick wall band (the title sign sits on it)
    rect(px, 0, 8, w, 32, BRICK)
    for y in range(8, 32):
        for x in range(w):
            row = (y - 8) // 4
            if (y - 8) % 4 == 3 or (x + (row % 2) * 4) % 8 == 0:
                put(px, x, y, BRICK_LO)
    # title sign board in the middle (the Label is drawn on top)
    rect(px, 74, 3, 246, 31, OUT)
    rect(px, 75, 4, 245, 30, GOLD_LO)
    rect(px, 76, 5, 244, 29, GOLD)
    rect(px, 76, 5, 244, 6, GOLD_HI)
    for x, y in ((78, 7), (241, 7), (78, 26), (241, 26)):
        put(px, x, y, EDGE)
    # "BAWAL ANG UTANG" sign on the left, a classic sari-sari store joke
    rect(px, 4, 11, 70, 22, OUT)
    rect(px, 5, 12, 69, 21, WHITE)
    small = "BAWAL ANG UTANG"
    draw_small(px, 8, 14, small, AWN_RED)
    # awning: stripes 8 px wide with a scalloped bottom edge
    for y in range(32, 52):
        for x in range(w):
            c = awning if (x // 8) % 2 == 0 else AWN_WHITE
            if y < 34:
                c = shade(c, 0.8)
            put(px, x, y, c)
    for x in range(w):
        put(px, x, 32, AWN_LINE)
        k = x % 8
        depth = [2, 4, 5, 6, 6, 5, 4, 2][k]
        c = awning if (x // 8) % 2 == 0 else AWN_WHITE
        for y in range(52, 52 + depth):
            put(px, x, y, c if y < 51 + depth else awning_dark)
        put(px, x, 52 + depth, AWN_LINE)
    return im


SMALL = {
    "A": ["###", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
    "G": ["###", "#..", "#.#", "#.#", "###"], "L": ["#..", "#..", "#..", "#..", "###"],
    "N": ["#.#", "###", "###", "#.#", "#.#"], "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"], "W": ["#.#", "#.#", "###", "###", "#.#"],
}


def draw_small(px, x, y, text, color):
    for ch in text:
        if ch == " ":
            x += 2
            continue
        for dy, row in enumerate(SMALL[ch]):
            for dx, c in enumerate(row):
                if c == "#":
                    put(px, x + dx, y + dy, color)
        x += 4


def store_body(shelf_colors):
    """Shop interior, 32x16 at 1x; the middle stretches, the sides repeat."""
    w, h = 32, 16
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    rect(px, 0, 0, w, h, PLASTER)
    for side in (0, w - 9):
        rect(px, side, 0, side + 9, h, BRICK)
        rect(px, side + (8 if side == 0 else 0), 0, side + (9 if side == 0 else 1), h, OUT)
        put_shelf(px, side + 1, 2, shelf_colors[0])
        put_shelf(px, side + 1, 9, shelf_colors[1])
    rect(px, 0, 0, 1, h, OUT)
    rect(px, w - 1, 0, w, h, OUT)
    return im


def put_shelf(px, x, y, color):
    rect(px, x, y + 5, x + 7, y + 6, WOOD_LO)           # shelf plank
    for i in range(3):                                    # little goods (bottles / packs)
        rect(px, x + i * 2 + 1, y + 1, x + i * 2 + 2, y + 5, color if i != 1 else WHITE)


def store_counter():
    """Wooden counter, 32x19 at 1x."""
    w, h = 32, 19
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    rect(px, 0, 0, w, 4, WOOD_HI)
    rect(px, 0, 3, w, 4, WOOD_LO)
    rect(px, 0, 4, w, h, WOOD)
    for x in range(0, w, 6):
        rect(px, x, 4, x + 1, h, WOOD_LO)
    rect(px, 0, h - 2, w, h, WOOD_LO)
    rect(px, 0, 0, w, 1, OUT)
    rect(px, 0, h - 1, w, h, OUT)
    rect(px, 0, 0, 1, h, OUT)
    rect(px, w - 1, 0, w, h, OUT)
    return im


def make_stores():
    for folder, awn, shelves in (("host_store", AWN_RED, [RED, GOLD]), ("join_store", BLUE, [BLUE, GREEN])):
        dark = shade(awn, 0.6)
        scaled(store_top(awn, dark), 4).save(f"{UI}/{folder}/store_top.png")
        scaled(store_body(shelves), 4).save(f"{UI}/{folder}/store_body.png")
        scaled(store_counter(), 4).save(f"{UI}/{folder}/store_counter.png")


make_buttons()
make_frames()
make_stores()
print("ui saved")


def icon_pause(px, w, h):
    cy = (h - 3) // 2
    for y in range(cy - 3, cy + 4):
        for x in (w // 2 - 3, w // 2 - 2, w // 2 + 1, w // 2 + 2):
            put(px, x, y, WHITE)


button("", SLATE_HI, (96, 96), icon=icon_pause).save(f"{UI}/button_pause.png")
print("pause icon saved")
