"""Title-screen background: a pixel city street built from the same tile
pieces as the maze (Simple 32x32 City Tileset by Acxa Rmz).

usage: python make_title_bg.py <project dir> <tileset png>
"""
import sys

import reskin_city as rc
from PIL import Image

rc.SRC = Image.open(sys.argv[2]).convert("RGBA")
OUT = f"{sys.argv[1]}/assets/backgrounds/title_city_pixel.png"

# 30 x 20 cells of 32 px = 960 x 640 (the game's base screen size).
# R roof, F shop front, H house front, T hedge, r road, h road with a
# dashed line, v road with a dashed line (vertical), c crosswalk
LAYOUT = [
    "RRRRRRRRRRRRRRvRRRRRRRRRRRRRRR",
    "RRRRRRRRRRRRRRvRRRRRRRRRRRRRRR",
    "RRRRRRRRRRRRRRvRRRRRRRRRRRRRRR",
    "RRRRRTRRRRRRRRvRRRRRRRRRTRRRRR",
    "FFFFFTHHHHHHHHvHHHHHHFFFTFFFFF",
    "hhhhhhhhhhhhcrrrchhhhhhhhhhhhh",
    "RRRRvRRRRRRRRRvRRRRRRRRvRRRRRR",
    "RRRRvRRRRRTTRRvRRTTRRRRvRRRRRR",
    "RRRRvRRRRRRRRRvRRRRRRRRvRRRRRR",
    "RRRRvRRRRRRRRRvRRRRRRRRvRRRRRR",
    "HHHHvFFFFFFHHHvHHHFFFFFvHHHHHH",
    "hhhhrhhhhhhhcrrrchhhhhhrhhhhhh",
    "RRRRRRRRRRRRRRvRRRRRRRRRRRRRRR",
    "RRTTRRRRRRRRRRvRRRRRRRRRRTTRRR",
    "RRRRRRRRRRRRRRvRRRRRRRRRRRRRRR",
    "FFFFFFHHHHHHHHvHHHHHHHFFFFFFFF",
    "rrrrrrrrrrrrcrrrcrrrrrrrrrrrrr",
    "hhhhhhhhhhhhcrrrchhhhhhhhhhhhh",
    "rrrrrrrrrrrrcrrrcrrrrrrrrrrrrr",
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]
NAMES = {"R": "roof_gray", "F": "store_front", "H": "house_front", "T": "tree_lot",
         "r": "road", "h": "road_lines_h", "v": "road_lines_v", "c": "road_crossing"}

kind = {}
for y, row in enumerate(LAYOUT):
    assert len(row) == 30, (y, len(row))
    for x, ch in enumerate(row):
        kind[(x, y)] = NAMES[ch]
pieces, cell_key = rc.skin(kind)
img = Image.new("RGBA", (30 * 32, 20 * 32))
for (x, y), key in cell_key.items():
    img.paste(pieces[key], (x * 32, y * 32))
img.save(OUT)
print("saved", OUT)
