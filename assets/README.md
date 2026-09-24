# Assets — how to change the game's look

Every picture in the game is a PNG in this folder. The ones here now are
simple starter pictures. To change one, **replace the PNG with your own
using the same file name**, then go back to Godot (it re-imports by itself).

| What | File | Size to use |
|---|---|---|
| Tubig kid (blue team) | `characters/tubig_kid.png` | Square frames side by side, e.g. 4 frames of 24x24 = 96x24. One single image also works. |
| Sili kid (red team) | `characters/sili_kid.png` | Same as above |
| "?" scroll | `ui/scroll.png` | Any size (it is scaled to fit) |
| Title screen background | `backgrounds/title_city.png` | 960x640 is best (it is stretched to cover the screen) |
| Game title (logo) | `ui/title_logo.png` | Any size, wide shape (now 900x300); fitted into the top of the menu |
| Host / Join window buttons | `ui/button_start.png`, `button_cancel.png`, `button_connect.png`, `button_join_small.png`, `button_close.png` | Any size; text drawn into the picture |
| Window frame and cards | `ui/panel.png` (64x64), `ui/card.png` (48x48) | Keep the same size. Godot stretches only the middle, so draw the border within the outer ~14-20 px |
| Title screen buttons | `ui/button_host.png`, `button_join.png`, `button_how_to_play.png`, `button_quit.png`, `button_got_it.png` | Any size, wide shape (now 720x112). Draw the button text INTO the picture |
| Maze tiles (roads, roofs, houses, stores, trees) | `walls/*.png` | **Exactly 40x40** |
| Props (jeepney, tricycle, electric post) | `props/*.png` | Any size |

Characters: the walking frames play while the kid moves and flip for
left/right. You can also pick different PNGs without renaming anything:
open `scenes/player.tscn`, click **Player**, and drag PNGs into
**Tubig Texture** / **Sili Texture** in the Inspector. **Body Size** sets
how tall the kid is.

Buttons: they glow when the mouse is over them and shrink a little when
clicked. To use your own pictures for those states, open
`scenes/title_screen.tscn`, click the button, and drag PNGs into
**Texture Hover** / **Texture Pressed** in the Inspector.

## Editing the maze (in the editor, no code)

Open `scenes/city_map.tscn`. It has four parts:

- **Maze**: the playable maze. Click it, open the **TileMap** tab at the
  bottom, pick a tile and paint. Tiles with a collision shape (roofs,
  house fronts, store fronts, tree lot) are **walls**. Road tiles are
  walkable. The game reads this layer when a round starts, including the
  minimap.
- **Surroundings**: the city outside the maze. Only for looks.
- **Props**: jeepneys, tricycles and posts. Drag a PNG from the FileSystem
  panel into the scene to add one and move it with the mouse. Props are
  only for looks: they do not block anyone.
- **Starts**: where players begin. Drag `TubigStart1`–`4` and
  `SiliStart1`–`2`, and keep each one on a road tile.

Keep the Maze closed all around with wall tiles. Don't leave empty
(unpainted) cells inside it: they count as road but show nothing.

## Adding a NEW tile (e.g. a basketball court or a church)

1. Make or download the picture and save it as a 40x40 PNG in `walls/`.
2. Double-click `walls/city_tileset.tres`, then open the **TileSet** tab at
   the bottom.
3. Drag the PNG into the left list and answer **Yes** when it asks to
   create tiles.
4. If it should be a **wall**: in the TileSet tab click **Paint** →
   **Physics Layer 0**. In the shape editor that appears, click the
   "reset to default tile shape" button (or draw a square over the whole
   tile), then click your tile to give it that collision shape.
5. It now appears in the TileMap tab of the Maze layer, ready to paint.

## Free asset sources

Always check the license, and list what you use in the README's
"Authorized assets" section (name, author, link, license).

- **Kenney** — https://kenney.nl/assets. CC0 (free, no credit needed).
  Try "Roguelike Modern City", "RPG Urban Pack", "Toon Characters".
- **OpenGameArt** — https://opengameart.org. Search "top down city" or
  "top down character". Licenses vary (CC0, CC-BY: give credit).
- **itch.io free assets** — https://itch.io/game-assets/free/tag-top-down.
  Read each pack's page for its license.
- **LimeZu** (Modern Interiors/Exteriors) — https://limezu.itch.io.
  Already credited in the group project.
- **Draw your own** — Piskel (https://www.piskelapp.com, free, in the
  browser) or LibreSprite. Your own art needs no credit.

Many packs use 16x16 or 32x32 tiles. Resize them to 40x40 before you use
them as maze tiles: in Piskel use Resize, or in https://www.photopea.com use
Image → Image Size with "Nearest Neighbor" so pixel art stays sharp.
