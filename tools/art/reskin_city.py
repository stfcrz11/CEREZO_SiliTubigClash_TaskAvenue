"""Re-skins the painted city map with the Simple 32x32 City Tileset (Acxa Rmz).

Reads the old map (scenes/city_map.tscn, 40x40 tiles from city_tileset.tres),
works out what every cell is (road / line / crossing / roof / front / trees),
and picks a matching 32x32 piece for it: roads get curbs next to buildings,
roofs get parapet edges, fronts become shop and apartment facades, tree lots
become hedges on grass. Every piece used goes into assets/walls/city_atlas.png,
and a new TileSet (one atlas, 32x32 tiles, wall tiles with collision) replaces
city_tileset.tres. The map layers are scaled 1.25x so one cell is still
40x40 world pixels: no gameplay number changes.

usage: python reskin_city.py <project dir> <tileset png>
"""
import base64
import hashlib
import math
import re
import struct
import sys

from PIL import Image

PROJECT = sys.argv[1]
SRC = Image.open(sys.argv[2]).convert("RGBA")
T = 32

ROAD_KINDS = {"road", "road_lines_h", "road_lines_v", "road_crossing"}
WALL_KINDS = {"roof_red", "roof_blue", "roof_green", "roof_gray", "house_front", "house_front_pink",
              "store_front", "tree_lot"}
FRONT_KINDS = {"house_front", "house_front_pink", "store_front"}

# ------------------------------------------------------------------ colors
ASPHALT = (75, 78, 85)
ASPHALT_DARK = (68, 71, 78)
DASH = (211, 183, 110)
STRIPE = (226, 229, 233)
CURB_LIGHT = (148, 149, 151)
CURB_MID = (103, 107, 118)
CURB_DARK = (43, 46, 53)
R_OUT = (33, 26, 20)
R_HI = (213, 204, 205)
R_PARAPET = (177, 173, 170)
R_EDGE = (47, 43, 42)
R_FILL = (118, 109, 110)
R_SEAM = (90, 84, 84)


def h(*parts) -> int:
    return int(hashlib.md5(repr(parts).encode()).hexdigest()[:8], 16)


def crop(tx, ty, w=1, hgt=1, dx=0, dy=0):
    return SRC.crop((tx * T + dx, ty * T + dy, (tx + w) * T + dx, (ty + hgt) * T + dy))


# ------------------------------------------------------------- read map
def read_tileset_names():
    text = open(f"{PROJECT}/assets/walls/city_tileset.tres", encoding="utf-8").read()
    names = dict(re.findall(r'\[sub_resource type="TileSetAtlasSource" id="([^"]+)"\]\s*resource_name = "([^"]+)"', text))
    out = {}
    for sid, ref in re.findall(r'sources/(\d+) = SubResource\("([^"]+)"\)', text):
        out[int(sid)] = names[ref]
    return out


def decode_layer(b64):
    data = base64.b64decode(b64)
    cells = {}
    for i in range(2, len(data), 12):
        x, y, src, ax, ay, alt = struct.unpack("<hhHHHH", data[i:i + 12])
        cells[(x, y)] = src
    return cells


def encode_layer(cells):
    out = bytearray(struct.pack("<H", 0))
    for (x, y), (ax, ay) in sorted(cells.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        out += struct.pack("<hhHHHH", x, y, 0, ax, ay, 0)
    return base64.b64encode(bytes(out)).decode()


# --------------------------------------------------------------- pieces
def road_tile(kind, walls8, cell):
    """kind: plain / dash_h / dash_v / cross_h / cross_v; walls8: N,E,S,W,NE,SE,SW,NW wall flags."""
    im = Image.new("RGBA", (T, T), ASPHALT + (255,))
    px = im.load()
    # a little texture so long roads don't look flat
    r = h("speck", cell)
    for i in range(6):
        x, y = (r >> (i * 5)) % T, (r >> (i * 3 + 2)) % T
        px[x, y] = ASPHALT_DARK + (255,)
    if kind == "dash_h":
        for x in range(T):
            if (x // 5) % 2 == 0:
                px[x, 15] = DASH + (255,)
                px[x, 16] = DASH + (255,)
    elif kind == "dash_v":
        for y in range(T):
            if (y // 5) % 2 == 0:
                px[15, y] = DASH + (255,)
                px[16, y] = DASH + (255,)
    elif kind in ("cross_h", "cross_v"):
        for a in range(T):
            for b in range(4, T - 4):
                if a % 7 < 4:
                    if kind == "cross_v":
                        px[a, b] = STRIPE + (255,)
                    else:
                        px[b, a] = STRIPE + (255,)
    # curbs where the road meets a building
    n, e, s, w, ne, se, sw, nw = walls8
    profile = [CURB_LIGHT, CURB_LIGHT, CURB_LIGHT, CURB_MID, CURB_DARK]
    for y in range(T):
        for x in range(T):
            d = 99
            if n: d = min(d, y)
            if s: d = min(d, T - 1 - y)
            if w: d = min(d, x)
            if e: d = min(d, T - 1 - x)
            if ne and not n and not e: d = min(d, max(y, T - 1 - x))
            if se and not s and not e: d = min(d, max(T - 1 - y, T - 1 - x))
            if sw and not s and not w: d = min(d, max(T - 1 - y, x))
            if nw and not n and not w: d = min(d, max(y, x))
            if d < len(profile):
                px[x, y] = profile[d] + (255,)
    return im


def roof_tile(open8, deco, cell):
    """open8: N,E,S,W,NE,SE,SW,NW = that side is NOT part of the same building."""
    im = Image.new("RGBA", (T, T), R_FILL + (255,))
    px = im.load()
    profile = [R_OUT, R_HI, R_PARAPET, R_PARAPET, R_PARAPET, R_EDGE]
    n, e, s, w, ne, se, sw, nw = open8
    for y in range(T):
        for x in range(T):
            d = 99
            if n: d = min(d, y)
            if s: d = min(d, T - 1 - y)
            if w: d = min(d, x)
            if e: d = min(d, T - 1 - x)
            if ne and not n and not e: d = min(d, max(y, T - 1 - x))
            if se and not s and not e: d = min(d, max(T - 1 - y, T - 1 - x))
            if sw and not s and not w: d = min(d, max(T - 1 - y, x))
            if nw and not n and not w: d = min(d, max(y, x))
            if d < len(profile):
                px[x, y] = profile[d] + (255,)
    # roof panel seams
    r = h("seam", cell)
    if not deco:
        sx = 8 + r % 16
        sy = 8 + (r >> 4) % 16
        for y in range(T):
            if px[sx, y][:3] == R_FILL:
                px[sx, y] = R_SEAM + (255,)
        for x in range(T):
            if px[x, sy][:3] == R_FILL and ((r >> 9) & 1):
                px[x, sy] = R_SEAM + (255,)
    else:
        # an aircon unit taken from the tileset roof
        unit = SRC.crop((15 * T + 8, 8 * T + 11, 15 * T + 27, 8 * T + 29))
        ox = 6 + r % 6
        oy = 6 + (r >> 3) % 5
        im.alpha_composite(unit, (ox, oy))
    return im


FACADES = [
    # (tile x, tile y, y offset inside the 3-wide building)  -> a 96x32 strip
    (15, 9, 18),   # bakery with red awnings
    (18, 9, 18),   # noodle shop
    (21, 9, 18),   # purple shop
    (15, 6, 30),   # beige apartment, ground floor with door
    (18, 6, 30),   # purple apartment, glass doors
    (21, 6, 30),   # brick house with door
]


def facade_strip(i):
    tx, ty, oy = FACADES[i]
    return SRC.crop((tx * T, ty * T + oy, (tx + 3) * T, ty * T + oy + T))


def facade_tile(style, offset, start, end):
    strip = facade_strip(style)
    im = strip.crop((offset, 0, offset + T, T))
    if start and offset != 0:
        im.paste(strip.crop((0, 0, 3, T)), (0, 0))
    if end and offset != 64:
        im.paste(strip.crop((93, 0, 96, T)), (T - 3, 0))
    return im


GRASS = None


def hedge_tile(mask4):
    """mask4 = connections to other tree cells: N,E,S,W."""
    base = crop(16, 1).copy()
    n, e, s, w = mask4
    table = {
        (0, 0, 0, 0): (7, 3), (0, 1, 0, 0): (4, 3), (0, 1, 0, 1): (5, 3), (0, 0, 0, 1): (6, 3),
        (0, 0, 1, 0): (4, 4), (1, 0, 1, 0): (4, 5), (1, 0, 0, 0): (4, 6),
        (0, 1, 1, 0): (5, 4), (0, 0, 1, 1): (7, 4), (1, 1, 0, 0): (5, 6), (1, 0, 0, 1): (7, 6),
        (0, 1, 1, 1): (6, 4), (1, 1, 0, 1): (6, 6), (1, 1, 1, 0): (5, 5), (1, 0, 1, 1): (7, 5),
        (1, 1, 1, 1): (5, 3),
    }
    tx, ty = table[(n, e, s, w)]
    base.alpha_composite(crop(tx, ty))
    return base


def gate_tile():
    """Kalamansi gate: road with a big kalamansi slice blocking the gap."""
    im = road_tile("plain", (0, 0, 0, 0, 0, 0, 0, 0), ("gate",))
    px = im.load()
    cx = cy = 15.5
    for y in range(T):
        for x in range(T):
            d = math.hypot(x - cx, y - cy)
            ang = math.atan2(y - cy, x - cx)
            if d <= 14.5:
                if d > 13.2:
                    c = (34, 74, 22)        # outline
                elif d > 11.2:
                    c = (78, 150, 40)       # green peel
                elif d > 10.2:
                    c = (236, 240, 190)     # pith
                else:
                    seg = (ang / (2 * math.pi) * 8) % 1.0
                    if seg < 0.12 or seg > 0.88 or d < 1.6:
                        c = (236, 240, 190)
                    else:
                        c = (176, 214, 72) if d > 4 else (200, 228, 100)
                px[x, y] = c + (255,)
    return im


# ------------------------------------------------------------ main
def main():
    names = read_tileset_names()
    scene_path = f"{PROJECT}/scenes/city_map.tscn"
    scene = open(scene_path, encoding="utf-8").read()
    layers = re.findall(r'(\[node name="(\w+)" type="TileMapLayer"[^\[]*?)tile_map_data = PackedByteArray\("([^"]*)"\)', scene)
    layer_cells = {}
    for _, lname, b64 in layers:
        layer_cells[lname] = {k: names[v] for k, v in decode_layer(b64).items()}
    kind = dict(layer_cells.get("Surroundings", {}))
    kind.update(layer_cells["Maze"])

    def is_wall(c):
        return kind.get(c) in WALL_KINDS

    def is_road(c):
        return kind.get(c) in ROAD_KINDS

    def is_building(c):
        k = kind.get(c)
        return k in WALL_KINDS and k != "tree_lot"

    def is_tree(c):
        return kind.get(c) == "tree_lot"

    dirs8 = [(0, -1), (1, 0), (0, 1), (-1, 0), (1, -1), (1, 1), (-1, 1), (-1, -1)]

    # facade runs: contiguous front cells in a row pick one shop/apartment style
    run_info = {}
    for (x, y), k in kind.items():
        if k in FRONT_KINDS and kind.get((x - 1, y)) not in FRONT_KINDS:
            run = []
            cx = x
            while kind.get((cx, y)) in FRONT_KINDS:
                run.append((cx, y))
                cx += 1
            style = h("style", x, y) % len(FACADES)
            if k == "store_front":
                style = h("store", x, y) % 3
            elif k in ("house_front", "house_front_pink"):
                style = 3 + h("house", x, y) % 3
            for i, c in enumerate(run):
                L = len(run)
                if L == 1:
                    off = 32
                elif i == 0:
                    off = 0
                elif i == L - 1:
                    off = 64
                elif i == L // 2:
                    off = 32
                else:
                    off = 2 if i % 2 else 62
                run_info[c] = (style, off, i == 0, i == L - 1)

    pieces = {}      # key -> image
    cell_key = {}

    def use(key, maker):
        if key not in pieces:
            pieces[key] = maker()
        return key

    for c, k in kind.items():
        x, y = c
        nb = [(x + dx, y + dy) for dx, dy in dirs8]
        if k in ROAD_KINDS:
            walls8 = tuple(1 if is_wall(p) else 0 for p in nb)
            sub = {"road": "plain", "road_lines_h": "dash_h", "road_lines_v": "dash_v"}.get(k)
            if k == "road_crossing":
                horiz = is_road(nb[1]) and is_road(nb[3])
                sub = "cross_v" if horiz else "cross_h"
            speck = h("speckvar", c) % 3
            key = ("road", sub, walls8, speck)
            cell_key[c] = use(key, lambda sub=sub, walls8=walls8, speck=speck: road_tile(sub, walls8, ("v", speck)))
        elif k in FRONT_KINDS:
            style, off, start, end = run_info[c]
            key = ("front", style, off, start, end)
            cell_key[c] = use(key, lambda a=(style, off, start, end): facade_tile(*a))
        elif k == "tree_lot":
            mask4 = tuple(1 if is_tree(p) else 0 for p in nb[:4])
            key = ("hedge", mask4)
            cell_key[c] = use(key, lambda m=mask4: hedge_tile(m))
        else:
            # roof: open on any side that isn't the same building; a front
            # cell below shows the roof's front edge
            open8 = []
            for i, p in enumerate(nb):
                same = is_building(p) and kind.get(p) not in FRONT_KINDS
                if i == 2 and kind.get(p) in FRONT_KINDS:
                    same = False
                if i in (5, 6) and kind.get(p) in FRONT_KINDS:
                    same = False
                open8.append(0 if same else 1)
            open8 = tuple(open8)
            enclosed = sum(open8[:4]) <= 1
            deco = enclosed and h("ac", c) % 5 == 0
            variant = h("roofvar", c) % 2 if not deco else 0
            key = ("roof", open8, deco, variant)
            cell_key[c] = use(key, lambda o=open8, d=deco, v=variant: roof_tile(o, d, ("rv", v, o)))

    # the Kalamansi gate is placed by the game at runtime
    use(("gate",), gate_tile)

    keys = sorted(pieces, key=repr)
    cols = 16
    rows = math.ceil(len(keys) / cols)
    atlas = Image.new("RGBA", (cols * T, rows * T), (0, 0, 0, 0))
    coord = {}
    for i, key in enumerate(keys):
        cx, cy = i % cols, i // cols
        atlas.paste(pieces[key], (cx * T, cy * T))
        coord[key] = (cx, cy)
    atlas.save(f"{PROJECT}/assets/walls/city_atlas.png")
    print("pieces:", len(keys), "atlas", atlas.size)

    # ------------------------------------------------ TileSet resource
    lines = ['[gd_resource type="TileSet" load_steps=3 format=3 uid="uid://dmq77akb2x7qb"]', "",
             '[ext_resource type="Texture2D" path="res://assets/walls/city_atlas.png" id="1_atlas"]', "",
             '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_city"]',
             'resource_name = "simple_city"',
             'texture = ExtResource("1_atlas")',
             "texture_region_size = Vector2i(32, 32)"]
    for key in keys:
        cx, cy = coord[key]
        lines.append(f"{cx}:{cy}/0 = 0")
        kind_name = key[0]
        lines.append(f'{cx}:{cy}/0/custom_data_0 = "{kind_name}"')
        if kind_name in ("roof", "front", "hedge", "gate"):
            lines.append(f"{cx}:{cy}/0/physics_layer_0/polygon_0/points = PackedVector2Array(-16, -16, 16, -16, 16, 16, -16, 16)")
    lines += ["", "[resource]", "tile_size = Vector2i(32, 32)",
              "physics_layer_0/collision_layer = 1", "physics_layer_0/collision_mask = 0",
              'custom_data_layer_0/name = "kind"', "custom_data_layer_0/type = 4",
              'sources/0 = SubResource("TileSetAtlasSource_city")', ""]
    open(f"{PROJECT}/assets/walls/city_tileset.tres", "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    gx, gy = coord[("gate",)]
    print("gate atlas coords:", gx, gy)

    # --------------------------------------------------- map scene
    for block, lname, b64 in layers:
        cells = {c: coord[cell_key[c]] for c in layer_cells[lname]
                 if c in cell_key and (lname == "Maze" or c not in layer_cells["Maze"])}
        new_block = block
        if "scale = " not in block:
            new_block = block + "scale = Vector2(1.25, 1.25)\n"
        scene = scene.replace(block + 'tile_map_data = PackedByteArray("' + b64 + '")',
                              new_block + 'tile_map_data = PackedByteArray("' + encode_layer(cells) + '")')
    open(scene_path, "w", encoding="utf-8", newline="\n").write(scene)
    print("map rewritten")


main()
