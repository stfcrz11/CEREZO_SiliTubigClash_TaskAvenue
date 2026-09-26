# Project State — Sili-Tubig: Task Avenue

State of the project as of **2026-09-24**. Latest commit: `673d4a1 Add new bg`. Everything
below comes from the actual files in this folder: `.gd`, `.tscn`, `project.godot`,
`README.md` and `assets/`. Anything I could not confirm from the files is marked **[CHECK]**.

---

## 1. Game summary

**Title:** Sili-Tubig: Task Avenue (`config/name` in `project.godot`)

**Concept:** a LAN multiplayer chase game in a maze that looks like a Philippine city,
based on the Filipino street game *sili-tubig*. **Sili** players chase and **Tubig**
players run. The Tubig team must also pick up "?" scrolls and correctly answer
multiple-choice questions about Filipino culture (`data/questions.gd`, 32 questions).

### Roles and player counts (`autoloads/network.gd`)

| Players | Sili | Tubig |
|---|---|---|
| 2–4 | 1 | the rest |
| 5–6 | 2 | the rest |

- Minimum **2** players (`MIN_PLAYERS`), maximum **6** (`MAX_PLAYERS`). A 7th player who
  joins is disconnected by the host.
- **Role rotation:** the first Sili is random (`round_number = randi() % MAX_PLAYERS`).
  After that the role moves down the player list every round (`assign_roles()`).
- **Solo test mode:** if `maze_game.tscn` is run directly, `Network.play_solo()` makes a
  1-player game with no Sili. The message "Test mode: no Sili" is shown.

### Win / lose rules (`scenes/maze_game.gd`)

| Result | When |
|---|---|
| **TUBIG TEAM WINS!** | `questions_to_win` = **10** correct answers |
| **SILI WINS!** | every Tubig is frozen at the same time |
| **TIME'S UP — SILI WINS!** | `round_time` = **180 s** runs out |
| **THE SILI LEFT — TUBIG WINS!** | every Sili disconnects mid-round |
| **ALL TUBIG LEFT — SILI WINS!** | every Tubig disconnects mid-round |

Each device shows "You win!" or "You lose!" for its own role, plus the stats: correct
answers, scrolls opened and time left.

### Rules in detail (values from the exported variables)

- **Scrolls:** 3 on the map (`scrolls_on_map`). A Tubig picks one up within **24 px**.
  After each question a new scroll appears at least 5 tiles away from every Tubig.
- **Questions:**
  - Drawn at random with no repeats until all 32 are used. The 4 choices are shuffled.
  - The picker has **15 s** (`quiz_panel.gd answer_time`). A wrong answer or timeout
    shows "Mali!" plus the correct answer and a fact.
  - All movement stops while a question is open (round state `QUESTION`).
  - After the question, every unfrozen Tubig gets **1 s** of protection (`grace_after_question`).
- **Tag:** a Sili within **24 px** of a Tubig freezes it (`tag_distance`).
- **Rescue:** an unfrozen teammate within **26 px** of a frozen Tubig frees it, but only
  after it has been frozen for **1 s** (`min_frozen_time`). The rescued Tubig gets
  **1.5 s** of immunity and **×1.3** speed (`player.gd`).
- **Speed:** Tubig 140 px/s with sprint ×1.6. Sili 150 px/s with sprint ×1.35.
  Stamina lasts 3 s of sprinting and refills at 0.5 per second.
- **Warnings (Tubig only):** "!! SILI NEARBY !!" within **170 px**, and
  "RUN! SILI IS RIGHT THERE!" within **90 px**, with a pulsing red screen edge and a "!"
  over your own character.

### Controls

**Keyboard.** The input actions are created in code in `autoloads/game_state.gd`;
`project.godot` has no `[input]` section.

| Key | Action |
|---|---|
| W A S D / arrow keys | move (`move_up/down/left/right`) |
| Shift / Space | sprint (`sprint`, uses stamina) |
| 1, 2, 3, 4 | answer a question (only the picker) |
| Esc (`ui_cancel`) | in a round: pause / resume for everyone (host only; others see "Only the host can pause.") |
| Esc | closes the How to Play, Host and Join windows |
| Enter in the IP box | connect (same as CONNECT) |

**Buttons and fields**

| Screen | Buttons / fields |
|---|---|
| Title | PLAYER NAME field (saved to `user://player_settings.cfg`), HOST GAME, JOIN GAME, HOW TO PLAY, QUIT |
| How to Play window | GOT IT! |
| Host window | ✕ (close), CANCEL, START GAME (disabled until 2+ players) |
| Join window | JOIN on each game found (disabled when full), IP field + CONNECT, ✕, CANCEL |
| Question window | the 4 answer buttons (click or tap) |
| End of round | Play Again / "Play Again (next Sili)" (host only), Main Menu / Leave |

---

## 2. Scenes / screens

| Scene | What it shows | Main nodes |
|---|---|---|
| `scenes/title_screen.tscn` (main scene) | City background, logo, name field, 4 menu buttons; opens How to Play, Host and Join | `Background` (TextureRect), `Dim`, `Menu` (`TitleLogo`, `PlayerNameRow/PlayerNameInput`, `HostButton`, `JoinButton`, `HowToButton`, `QuitButton`, `ErrorLabel`), `HowToDim`, `HowToPanel` (rules + `CloseButton`), `HostModal`, `JoinModal` (instances) |
| `scenes/host_modal.tscn` | "HOST A GAME" window drawn as a sari-sari store: IP on a chalkboard, 6 player slots, status, START GAME | `Dim`, `Center/Store/Top` (`Roof`, `Title`, `CloseButton`), `Body/VBox/HostCard` (`IpLabel`, `Hint`), `PlayersCard` (`Count`, `SiliChip`, `TubigChip`, `Slots/SlotTemplate`), `Counter` (`Status`, `CancelButton`, `StartButton`) |
| `scenes/join_modal.tscn` | "JOIN A GAME" store window: games found nearby, type-an-IP, then player slots after connecting | same frame; `FindCard` (`Searching`, `FoundList/GameTemplate`), `IpCard` (`IpEdit`, `ConnectButton`), `PlayersCard`, `Counter` (`Status`, `CancelButton`) |
| `scenes/maze_game.tscn` | The round | `Map` (instance of city_map), `Camera` (Camera2D), `Scrolls`, `Actors`, `RoundTimer`, `HUD` (CanvasLayer: `Minimap`, `TopBar` with Score/Timer/Mode labels, `WarningLabel`, `WarningGlow` (4 red edges), `MessageLabel`, `PauseLabel`, `QuizPanel`, `EndPanel` with `PlayAgainButton`/`MenuButton`). A `Vignette` is added by code. |
| `scenes/city_map.tscn` | The city and maze, painted with tiles | `Surroundings` (TileMapLayer, decoration outside the maze), `Maze` (TileMapLayer, the playable 23×15 maze), `Props` (Sprite2D jeepneys, tricycles, electric posts), `Starts` (Marker2D `TubigStart1–4`, `SiliStart1–2`) |
| `scenes/player.tscn` | One character | `Player` (CharacterBody2D), `Body` (Sprite2D), `NameLabel`, `AlertLabel`, `CollisionShape2D` (circle, r = 11) |
| `scenes/question_scroll.tscn` | The "?" pickup | `QuestionScroll` (Node2D), `Icon` (Sprite2D) |
| `scenes/quiz_panel.tscn` | Question window | `Dim`, `Panel/Margin/VBox` (`HeaderLabel`, `TimeLabel`, `QuestionLabel`, `Choices/Choice1–4`, `FeedbackLabel`) |
| `scenes/how_to_play.tscn` | Old standalone How to Play panel | **Not used by any scene or script.** The title screen has its own `HowToPanel`. |
| `scenes/lobby.tscn` | Old lobby screen (replaced by the Host/Join windows) | **Not used.** Its script `lobby.gd` was deleted. |
| `scenes/lobby_modal.tscn` | Old combined Host/Join window | **Not used, and broken:** it points to the deleted `lobby_modal.gd` and to `assets/ui/store_*.png` / `chalkboard.png`, which moved to `host_store/` and `join_store/`. Loading it gives errors (see §9). |

---

## 3. Scripts and responsibilities

| Script | Responsibility |
|---|---|
| `autoloads/game_state.gd` | Global round state (`READY, PLAYING, QUESTION, PAUSED, ENDED`), scene paths, player name (saved/loaded from `user://player_settings.cfg`), creates the keyboard input actions. |
| `autoloads/network.gd` | LAN networking with ENet: host/join/leave, player list and names, role assignment and rotation, "everyone loaded" handshake, UDP discovery beacon and listener. |
| `data/questions.gd` | Question bank: 32 entries, each with question, 4 choices, answer index and a short fact. |
| `scenes/maze_game.gd` | The round and all game rules: reads the maze from the TileMap, camera and vignette, spawning, scrolls, questions, tag/rescue, warnings, timer, pause, win/lose, Play Again. The host decides; all devices display. |
| `scenes/player.gd` | One Tubig/Sili: movement, sprint/stamina, sends its position 30×/s, smooths other players' movement, sprite-strip walking animation with left/right flip, caught/rescued/immunity visuals. |
| `scenes/minimap.gd` | Draws the whole maze in the HUD corner ("MAPA"), your position dot (blue for Tubig, red for Sili) and a white box showing what the camera sees. Other players are not shown. |
| `scenes/quiz_panel.gd` | Question window: shows the question to the picker, 15 s countdown, answer by click or keys 1–4, shows the host's verdict and the fact. |
| `scenes/question_scroll.gd` | Scroll visual: scales `scroll.png` to 24 px and pulses it. |
| `scenes/title_screen.gd` | Title menu: name field, opens Host/Join windows and How to Play, Quit, shows the last network error. |
| `scenes/store_modal.gd` | Shared base for both store windows: player slots (copied from `SlotTemplate`), SILI/TUBIG counts, status line, close with ✕ / CANCEL / Esc. |
| `scenes/host_modal.gd` | Host window: starts hosting, shows the IP, turns START GAME on at 2+ players, starts the game. |
| `scenes/join_modal.gd` | Join window: starts discovery, lists games (copied from `GameTemplate`), connects by list or typed IP, shows slots after connecting. |
| `scenes/png_button.gd` | TextureButton made from one PNG: fits the picture, glows on hover, shrinks when pressed, greys out when disabled. |
| `scenes/ui_button_style.gd` | Code-drawn (StyleBoxFlat) button styles, still used by the end-of-round buttons and the 4 answer buttons. |

---

## 4. What works now vs. what is incomplete

### Works — tested this session (see "Test run" at the end)

- Title screen, PNG buttons, How to Play window.
- Host window: IP shown, player slots update live, START GAME disabled below 2 players.
- Join window: connect by typed IP (127.0.0.1); the game list and FULL/disabled JOIN
  render correctly (tested with sample data).
- 3-player LAN round: roles (1 Sili / 2 Tubig), 3 scrolls, question pickup, correct answer
  counted on all devices, tag, rescue, Sili win, correct "You win/You lose" per device,
  the timer counts down.
- Host pause/resume with Esc reaches every device.
- Play Again: a new round starts and the Sili role moves to the next player.
- Camera: zoom 2.5, active on every device, follows that device's own player.
- Tile collisions: all 345 maze cells match the painted map (0 mismatches).
- Solo mode (maze scene run directly) runs with no errors.

### Works according to the code or README, not re-tested this session **[CHECK]**

- Wrong answer / answer timeout, the time-up loss, a player leaving mid-round, 7th player
  refused, automatic LAN discovery between separate devices (the game list was only
  tested with sample data here), the warning banners on screen.

### Incomplete / placeholder

- **Art is placeholder**, generated by script (see §6). The walking animation is one
  4-frame strip flipped left/right; there are no up/down animations. Being caught is
  only a grey tint, not an animation.
- **No sound or music.**
- **No touch controls:** there is no on-screen joystick, so phones/Android cannot move.
  No Android build was made.
- **No stamina bar:** `get_stamina_ratio()` exists but nothing uses it.
- **No fog of war:** only the close camera plus a dark vignette at the screen edges.
- **One maze only** (`city_map.tscn`).
- **No reconnect:** if the host leaves, everyone returns to the title screen.
- **Other players don't see the question** (see §9): only the picker's device shows the
  question window.
- `random_floor_cell()` in `maze_game.gd` is never used.
- `README.md` is partly out of date (see §9).

---

## 5. Networking model

- **Transport:** Godot high-level multiplayer with `ENetMultiplayerPeer`.
  - Game port **7777** (`GAME_PORT`); discovery port **7778** (UDP).
  - The host creates the server with room for 5 clients (`MAX_PLAYERS - 1`) and also
    plays as peer 1.
- **Host:** HOST GAME → `Network.host_game()`.
  - The host broadcasts a UDP beacon every 1 s: `SILITUBIG_TASKAVENUE|<players>|<host name>`.
  - It is sent to `255.255.255.255` and to each local network's `x.y.z.255`.
- **Join:** JOIN GAME → `start_listening()` on port 7778.
  - Games heard in the last 4 s are listed as "<name>'s game  n/6".
  - The player can press JOIN, or type an IP and press CONNECT (`join_game(ip)`).
- **Joining:**
  - On connect, the client sends its name to the host (`_register_player_name`).
  - The host sends the player list and names to everyone (`_sync_players`, `_sync_player_names`).
  - A player who connects after the game started, or when 6 are already in, is disconnected.
- **Start:**
  - The host calls `start_game()`, and every device loads `maze_game.tscn`.
  - Each device calls `report_ready()`. The host spawns everyone only after all devices
    have reported (`everyone_ready()`).
- **The host decides** (functions named `_host_*`, sent with `@rpc("authority")`):
  - roles and spawn positions (`_spawn_all`)
  - scroll spawns
  - which question and choice order (`_open_question`)
  - whether the answer is right (`_question_result`)
  - tags and rescues
  - the timer (`_sync_time`, every 1 s)
  - pause, win/lose and Play Again
- **Each device sends:**
  - its own position about 30 times per second (`_net_position`, unreliable ordered)
  - its answer, only if it is the picker (`_submit_answer`, to the host)
  - its name, and "my scene is ready"
- **Movement:** each player is the multiplayer authority of its own character. Other
  characters glide toward the last position received.
- **Disconnects:** if the host leaves, clients return to the title screen with "The host
  left the game." If a player leaves, the host removes them and may end the round (§1).

---

## 6. Assets

**Source:** all PNGs below except the two marked **[CHECK]** were **generated for this
project** by Python/Pillow scripts during the development sessions with Claude
(Anthropic). The TileSet was built with a Godot script. No third-party asset packs are in
the project. `README.md` mentions the group project's credits (EsriEsra, LimeZu, Crusenho,
Yūki — CC BY-SA 4.0), but none of those files are in this folder.

| File(s) | Size (px) | Used by | Source / license |
|---|---|---|---|
| `backgrounds/title_city.png` | 1199×633 | title `Background` | **[CHECK]** replaced in commit `8ee0cc3`; source and license unknown |
| `ui/title_logo.png` | 421×180 | title `TitleLogo` | **[CHECK]** replaced in commit `8ee0cc3`; source and license unknown |
| `characters/tubig_kid.png`, `sili_kid.png` | 96×24 (4 frames of 24×24) | `player.gd` | generated (restored to the originals from commit `75fff8b`) |
| `props/jeepney.png`, `tricycle.png`, `electric_post.png` | 38×20, 16×22, 16×12 | `city_map.tscn` Props | generated |
| `walls/road.png`, `road_lines_h.png`, `road_lines_v.png`, `road_crossing.png` | 40×40 each | TileSet (walkable) | generated |
| `walls/roof_red/blue/green/gray.png`, `house_front.png`, `house_front_pink.png`, `store_front.png`, `tree_lot.png` | 40×40 each | TileSet (walls, with collision) | generated |
| `walls/city_tileset.tres` | tile size 40×40, 12 sources, physics layer 0 | `city_map.tscn` | generated by a Godot script |
| `ui/scroll.png` | 24×24 | `question_scroll.tscn` | generated |
| `ui/button_host/join/how_to_play/quit/got_it.png` | 720×112, 720×96, 400×96 | title screen | generated |
| `ui/button_start/cancel/connect/join_small/close.png` | various | Host/Join windows | generated |
| `ui/panel.png`, `ui/card.png` | 64×64, 48×48 | How to Play frame; cards and slots | generated |
| `ui/host_store/store_top/body/counter.png`, `chalkboard.png` | 1280×236, 128×64, 128×76, 48×48 | `host_modal.tscn` | generated |
| `ui/join_store/store_top/body/counter.png` | same sizes | `join_modal.tscn` | generated |
| `ui/store_templates/*` (4 templates + `HOW_TO_DRAW_THE_STORE.png`) | same sizes / 1100×1160 | not used in game; drawing guides | generated |

**Fonts:**
- No font files are in the project. All in-game text uses Godot's default font
  (`ThemeDB.fallback_font`).
- The words inside the generated button, logo and sign PNGs were drawn with Windows
  **Arial Black / Arial Bold** when the PNGs were made. **[CHECK]** whether the course
  needs this listed under font licensing.

---

## 7. Project settings (`project.godot`)

| Setting | Value |
|---|---|
| Engine | `config/features = "4.7", "Forward Plus"`. Tested with **Godot 4.7.2-stable**. `README.md` still says 4.3 **[CHECK]** |
| Renderer | Forward Plus |
| Main scene | `res://scenes/title_screen.tscn` |
| Viewport | 960 × 640 |
| Window size override | 1280 × 720 |
| Stretch mode | `canvas_items` (aspect not set, so Godot's default `keep`) |
| Orientation | **not set** in `project.godot`, so Godot's default (landscape) is used. `README.md` says `window/handheld/orientation` was changed to landscape, but the key is not in the file **[CHECK]** |
| Default texture filter | `0` = Nearest (crisp pixel art). The title screen sets its own filter to Linear |
| Autoloads | `GameState` = `autoloads/game_state.gd`, `Network` = `autoloads/network.gd` |
| Input map | none in the file; actions are created in `game_state.gd` |
| Export presets | **none** (`export_presets.cfg` does not exist) |
| Physics layers (in code) | walls = layer 1 (TileSet physics layer), Tubig = layer 2, Sili = layer 4; both players collide with walls only (mask 1) |

---

## 8. Changes compared to a basic maze chase with placeholder shapes

| Area | Before | Now |
|---|---|---|
| Viewpoint | whole maze on screen, no camera | `Camera2D` zoom 2.5 follows only your own player (about 10×6 of 23×15 tiles visible), with smoothing and limits 3 tiles past the maze |
| Fog / darkness | none | **no real fog**; a radial vignette darkens the screen edges (`_add_vignette`) |
| Minimap | none | "MAPA" in the HUD: whole maze, your dot, white box of the camera view |
| Maze | text array (`MAZE` const) drawn as brown `ColorRect`s | painted `TileMapLayer` (`city_map.tscn`) from a 12-tile TileSet. Walls = tiles with collision. The game reads the map at start, so editing the map in the editor changes the game |
| City look | green floor, brown walls | roads with lane lines and crossings, GI roofs, house/store fronts, tree lots, outer city blocks (`Surroundings`), jeepney/tricycle/electric-post props |
| Start spots | `P`/`S` letters in the text maze | draggable `Marker2D` nodes (`TubigStart1–4`, `SiliStart1–2`) |
| Characters | coloured squares | PNG kids (blue Tubig, red Sili) with a 4-frame walk, left/right flip, per-teammate tint, grey when caught, blinking when immune; Sili drawn 15% bigger |
| Name labels | large text | 15 px text at scale 0.4 so it stays sharp at zoom 2.5 |
| Other players | earlier "perspective" attempt hid all other players | visible again; the close camera limits what you see |
| Scroll | yellow square with "?" | `scroll.png` sprite, any size scaled to 24 px, pulsing |
| Title screen | text title, standard buttons | city background PNG, logo PNG, PNG buttons (hover glow / press), How to Play with frame and dark backdrop |
| Lobby | separate `lobby.tscn` screen | two pop-up windows on the title screen (`host_modal.tscn`, `join_modal.tscn`) drawn as a sari-sari store, with hanging snack sachets, a chalkboard IP, a wooden counter, player slots with HOST/YOU badges and SILI/TUBIG counts |
| Discovery list | IP only | host's name + player count ("Stef's game 2/6"), refreshes when the count changes |
| Theme | code-drawn buttons | mostly PNG-based UI. There is no Godot `Theme` resource; the end-of-round and answer buttons still use `ui_button_style.gd` |
| Customizing | code only | texts and colors in the Inspector (Host/Join windows), editable templates, replaceable PNGs, drawing templates in `assets/ui/store_templates/`, guide in `assets/README.md` |

---

## 9. Known bugs, Output errors and fragile parts

### Errors / warnings

1. **`scenes/lobby_modal.tscn` fails to load.** Output shows:
   - `Attempt to open script 'res://scenes/lobby_modal.gd' ... 'File not found'`
   - `Resource file not found: res://assets/ui/store_top.png` (and `store_body`,
     `store_counter`, `chalkboard`)
   - `Parse Error: [ext_resource] referenced non-existent resource`

   Nothing uses this file. It keeps coming back because the Godot editor had it open and
   saves it again. **Fix:** close its tab in Godot without saving, delete it, and commit.
2. **`scenes/lobby.tscn`** is also unused. Its script `lobby.gd` was deleted.
   **`scenes/how_to_play.tscn`** is an unused duplicate of the title screen's How to Play
   panel.
3. In the three-player test runs, **no runtime errors or warnings** were printed by the
   game (host and both joiners).
4. **Likely editor warnings [CHECK]** (the GDScript analyzer shows these in the editor,
   not in a headless run):
   - `var name` in `network.gd _register_player_name()` hides `Node.name`.
   - Parameters called `position` in `maze_game.gd` and `quiz_panel.gd` hide
     `Node2D.position` / `Control.position`.
   - Integer division warnings in `maze_game.gd` (`maze[0].length() / 2`,
     `total_seconds / 60`).
5. In one earlier run the host printed `ERROR: Unable to send packet` from the discovery
   beacon. It seems to happen when a broadcast address is not reachable, and the game
   kept working **[CHECK]**.
6. `Could not host (port 7777 busy?)` appears if another copy of the game is already
   hosting on the same PC.

### Behaviour that differs from the documentation

7. **Only the picker sees the question.** `quiz_panel.show_question()` sets
   `visible = answerer_is_me`. `README.md` and the How to Play text say every screen
   shows the question, and teammates are told "help them!", but other devices only see
   the frozen game. **[CHECK]** whether this is intended.
8. **README out of date:**
   - It says Godot 4.3, "Placeholder shapes / no external assets", "no player names
     (P1–P6 only)" and "No real sprites".
   - It says the orientation setting was fixed, but the key is not in `project.godot`.
   - A comment in `network.gd` says slots are "0..3 => P1..P4", but there are 6 slots.

### Fragile parts

9. **Start markers:** `_spawn_all` uses `tubig_starts[tubigs.size()]`. The map needs at
   least **4 `TubigStart`** and **2 `SiliStart`** markers on road tiles, or a 6-player
   game crashes with an index error.
10. **Tile size:** `TILE = 40` in `maze_game.gd` must match the TileSet (40×40). Tile PNGs
    must be exactly 40×40.
11. **Maze painting:** unpainted cells inside the maze count as road but show nothing. A
    new tile is a wall only if it has a collision shape on physics layer 0.
12. **Label scale:** `player.tscn` name/alert labels use scale 0.4, which is 1 ÷ camera
    zoom 2.5. If `camera_zoom` changes, the labels become blurry or the wrong size.
13. **Rescue order:** in the same physics frame, tags are checked before rescues. A
    rescuer who arrives while the Sili is still next to the frozen player is tagged
    first. This was seen during testing and is probably fine as a rule **[CHECK]**.
14. **Minimap colors** are fixed in `minimap.gd` and do not follow the tile art.
15. **Uncommitted change:** `scenes/maze_game.tscn` has changes from an editor re-save
    (IDs and `layout_mode`, no gameplay change).
16. **Not tested on real devices:** Wi-Fi/hotspot discovery between separate devices,
    Android, and exported builds.

---

## 10. Bugs fixed during our sessions

| # | What happened | Cause | Fix | Result after fix |
|---|---|---|---|---|
| 1 | The "perspective" change hid every other player, so a Tubig could not see the Sili chasing it | `body_rect.visible = is_local()` in `player.gd` hid all characters except your own | Removed those lines; a close-up `Camera2D` now limits the view | Players near you are visible; far ones are off-screen. Checked in screenshots |
| 2 | The whole maze was still on screen | No camera existed | Added `Camera` (zoom 2.5, smoothing, limits) following only the local player | About 10×6 tiles visible; test shows `camera zoom=(2.5,2.5) current=true` on every device |
| 3 | Name labels were blurry at the new zoom | A 6 px font was drawn small and enlarged 2.5× by the camera | Font 15 px with label scale 0.4 (net 1:1 on screen) | Sharp text (screenshot) |
| 4 | Minimap used hard-coded `Vector2(20,40)` and `40` | Values copied instead of passed in | `set_maze(layout, origin, tile)` gets the real origin and tile size | Minimap position dot and camera box line up (screenshot) |
| 5 | Maze could not be edited visually | Maze was a text array drawn in code | TileMapLayer + TileSet; game reads walls from tile collision | Collision check: 345 cells, **0 mismatches** |
| 6 | Title logo: the banner stripes overlapped "TASK AVENUE" | Banner too narrow | Widened the banner and moved the stripes | Text clear (preview image) |
| 7 | PNG button press effect unreliable | `is_pressed()` read inside the `button_down` / `button_up` signals | Separate handlers for down/up | Button shrinks on press and restores on release [CHECK: not clicked with a real mouse] |
| 8 | START GAME looked clickable with fewer than 2 players | PNG buttons had no disabled look | `png_button.gd` greys out disabled buttons | START greyed until 2 players (screenshot) |
| 9 | Join list showed old player counts | `hosts_found_changed` fired only for new IPs | Also fire when a host's player count changes | List updates counts |
| 10 | Host/Join window ran off the bottom of the screen | Manual `reset_size()` + position did not shrink the panel | Put the panel in a `CenterContainer` | Window centered and sized to its content (screenshots) |
| 11 | Host window too tall for the 640 px screen | Large margins, fonts and slots | Smaller spacing, font sizes and slot height | Fits on screen |
| 12 | Host/Join window invisible when opened in the editor | Root node saved with `visible = false`; slots and game rows existed only at runtime | Root visible in its own scene (hidden by the title screen instance); added `SlotTemplate` / `GameTemplate` nodes that the code copies | Window and one slot/row visible and editable in the editor; 2-player test shows slots "Stef[HOST][YOU]", "Ana" |
| 13 | Old lobby scene kept returning | The open editor re-saved deleted scenes | Deleted `lobby.tscn` / `lobby_modal.tscn` | **Not solved:** they are back in the repo (see §9, #1–2) |
| 14 | "BAWAL ANG UTANG" text overflowed its sign | Font too large for the sign | Wider sign, smaller font | Fits (preview image) |
| 15 | Parameter names `seed` and `show` hid built-in names | Naming | Renamed to `variant` / `open` | No conflict |

**Fixed before these sessions** (from `README.md`, not re-checked here): the Sili could
never tag (collision circles blocked the 20 px tag distance); Esc could pause but not
resume; a teammate next to a caught Tubig rescued it instantly (now 1 s minimum); the
handheld orientation was portrait (see §7 **[CHECK]**).

---

## Test run (2026-09-24, Godot 4.7.2-stable, Windows 11)

I ran the tests with headless Godot copies of the real game on one PC over 127.0.0.1.
A temporary script clicked through the game; it has been deleted. Screenshots were taken
with Godot's movie writer.

| Test | Result |
|---|---|
| Load and create every scene | All used scenes load. `lobby_modal.tscn` **fails** (missing files, §9) |
| Import project (`--import`) | No errors |
| Solo: run `maze_game.tscn` directly for 5 s | No errors or warnings |
| Host opens window | IP shown (`192.168.0.103`), START disabled with 1 player |
| 2 joiners connect by IP | Both show "Connected! Waiting for host..."; host shows 3 players, "Ready!", START enabled |
| START GAME | All 3 load the maze. Roles 1 Sili / 2 Tubig, 3 scrolls, maze 23×15, time 180 |
| Wall collisions | 345 cells, 0 mismatches |
| Host presses Esc twice | PAUSED then PLAYING on all 3 devices; pause label shown/hidden on host |
| Tubig walks onto scroll | QUESTION on all 3 devices; question window visible **only** on the picker |
| Picker answers correctly | `correct_answers = 1` on all devices; play resumes after 2 s |
| Sili tags Tubig A | A frozen |
| Tubig B touches A after > 1 s | A rescued |
| Sili tags A, then B | all Tubig frozen → **"SILI WINS!"** on all 3; "You win!" for the Sili, "You lose!" for the Tubigs; time left 2:54 (timer ran) |
| Host presses Play Again | Round 2 starts on all 3; the Sili role moved to the next player |
| Host/Join windows, join list with sample data | Render correctly; a full game shows "FULL" and a greyed JOIN |

**Not tested:** wrong answer, answer timeout, full 3-minute timeout, player or host
leaving mid-round, 7th player refused, discovery across real devices or hotspots, mouse
clicks on real hardware, Android or any export.
