# Project State — Sili-Tubig: Task Avenue

State of the project as of **2026-09-26**. Latest commit: `3faf041 Edit the gameplay by
making tubig ask for teammates help and being untagged`. On top of that commit are the
**uncommitted** leaderboard and name-tag changes: `data/leaderboard.gd` (new),
`scenes/maze_game.gd`, `player.gd`, `player.tscn`, `title_screen.gd`, `title_screen.tscn`.

Everything below comes from the actual files in this folder: `.gd`, `.tscn`,
`project.godot`, `README.md` and `assets/`. Anything I could not confirm from the files is
marked **[CHECK]**.

---

## 1. Game summary

**Title:** Sili-Tubig: Task Avenue (`config/name` in `project.godot`)

**Concept:** a LAN multiplayer chase game in a maze that looks like a Philippine city,
based on the Filipino street game *sili-tubig*. **Sili** players chase and **Tubig**
players run. The Tubig team must also pick up "?" scrolls and correctly answer
multiple-choice questions about Filipino culture (`data/questions.gd`, 32 questions).
Tubigs can answer at the same time and can pass a question to a teammate.

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
  1-player game with no Sili. The message "Test mode: no Sili" is shown, and the round is
  not added to the leaderboard.

### Round time (`maze_game.gd _round_seconds()`)

Tubigs can answer questions at the same time, so the round gets shorter the more Tubigs
there are:

| Tubigs | Round time |
|---|---|
| 1 | 3:00 (`round_time` = 180) |
| 2 | 2:40 |
| 3 | 2:20 |
| 4 | 2:00 |

That is 20 s less per extra Tubig (`less_time_per_extra_tubig`), never below 1:30
(`min_round_time`). The start message shows it, e.g. "(2:00 for 4 Tubigs)".

### Win / lose rules (`scenes/maze_game.gd`)

| Result | When |
|---|---|
| **TUBIG TEAM WINS!** | `questions_to_win` = **10** correct answers |
| **SILI WINS!** | every Tubig is frozen at the same time |
| **TIME'S UP — SILI WINS!** | the round time runs out |
| **THE SILI LEFT — TUBIG WINS!** | every Sili disconnects mid-round |
| **ALL TUBIG LEFT — SILI WINS!** | every Tubig disconnects mid-round |

Each device shows "You win!" or "You lose!" for its own role, the stats (correct
answers, scrolls opened, time left) and "You earned +N points".

### Questions (`maze_game.gd`, `quiz_panel.gd`)

- **Scrolls:** 3 on the map (`scrolls_on_map`). A free Tubig (not caught, not answering)
  picks one up within **24 px**. After each question a new scroll appears at least
  5 tiles away from every Tubig.
- **Several at once:** any free Tubig can open a scroll even while teammates are
  answering, so several questions can be open at the same time. Each has its own
  answerer and timer.
- **Answering:** questions are drawn at random with no repeats until all 32 are used,
  and the 4 choices are shuffled. Only the answerer sees the question window.
  - The answerer has **15 s** (`answer_time`). The timer waits while the game is paused.
  - While answering, that Tubig **can't move and can't be tagged**, and "ANSWERING..." is
    shown next to their name. Everyone else keeps playing and the round clock keeps
    running.
- **Only one Tubig in the game:** the whole chase stops (round state `QUESTION`) and the
  clock stops. The Sili sees "Tubig is answering, cannot be tagged"
  (`answering_notice.tscn`).
- **Result:**
  - A big **TAMA! / MALI! / TIME'S UP!** popup (`answer_popup.tscn`) shows the correct
    answer, a fact and the score for **3.5 s** (`feedback_time`).
  - It appears on the answerer's screen only. With one Tubig, it appears on everyone's.
  - Other players get a short line, e.g. "Ben: TAMA! (3 / 10)".
  - After the popup, the answerer gets **1 s** of protection (`grace_after_question`).

### Asking a teammate for help

- The answerer can press **ASK A TEAMMATE FOR HELP** (or **H**) once per question. It is
  not available when there is only one Tubig.
- **Only one Tubig can ask at a time.** While someone is asking, every other answerer's
  button is disabled with "<name> is already asking for help...". It comes back when that
  request ends: someone said YES, or the question was answered or timed out.
- Every **free** teammate (not caught, not answering) gets an alert in the bottom-right
  corner: "<name> needs help with the question! Do you want to help?", with
  **YES (Y) / NO (N)** (`help_alert.tscn`). The game does not stop.
- The **first YES** gets the question with a fresh 15 s timer. The asker's window
  closes, the asker is free to run again (with 1 s protection), and all other alerts
  close. Later YESes are ignored.
- If nobody says YES, the asker must answer before the timer runs out.

### Tag, rescue, movement

- **Tag:** a Sili within **24 px** of a Tubig freezes it (`tag_distance`), unless that
  Tubig is answering or protected.
- **Rescue:** a free teammate within **26 px** of a frozen Tubig frees it, but only after
  it has been frozen for **1 s** (`min_frozen_time`). The rescued Tubig gets **1.5 s** of
  immunity and **×1.3** speed.
- **Speed:** Tubig 140 px/s with sprint ×1.6. Sili 150 px/s with sprint ×1.35.
  Stamina lasts 3 s of sprinting and refills at 0.5 per second.
- **Warnings (Tubig only):** "!! SILI NEARBY !!" within **170 px** and
  "RUN! SILI IS RIGHT THERE!" within **90 px**, with a pulsing red screen edge.
- **Name tags:** each player's **name is shown above their head**, with no role word.
  Your own name is yellow.

### Leaderboard (`data/leaderboard.gd`, title screen "TOP PLAYERS")

- **Opening it:** the **LEADERBOARD** button on the title screen opens it as a centered
  pop-up over a dark backdrop. Close it with ✕, Esc, or a click outside. The rankings
  reload every time it opens.

- **Points per round:** win **3**, correct answer **1** (the helper gets it if the
  question was passed), tag **1**, rescue **1**.
- **Saving:** each device saves every LAN round it plays to `user://leaderboard.cfg`, for
  all players in that round. Players are matched by name.
- **Ranking:** points, then wins, then fewer games. The top 20 are shown with
  gold/silver/bronze for ranks 1–3, and your own name in yellow.

### Controls

**Keyboard.** The input actions are created in code in `autoloads/game_state.gd`; the
other keys are read directly.

| Key | Action |
|---|---|
| W A S D / arrow keys | move |
| Shift / Space | sprint (uses stamina) |
| 1, 2, 3, 4 | answer a question |
| H | ask a teammate for help |
| Y / N | accept / refuse a help request |
| Esc | in a round: pause / resume for everyone (host only; others see "Only the host can pause.") |
| Esc | closes How to Play, Leaderboard, Host and Join windows |
| Enter in the IP box | connect |

**Buttons and fields**

| Screen | Buttons / fields |
|---|---|
| Title | PLAYER NAME field (saved to `user://player_settings.cfg`), HOST GAME, JOIN GAME, HOW TO PLAY, LEADERBOARD, QUIT |
| Leaderboard window | ✕ (or Esc / click outside) |
| How to Play | scrollable rules, GOT IT! |
| Host window | ✕, CANCEL, START GAME (disabled until 2+ players) |
| Join window | JOIN on each game found (disabled when full), IP field + CONNECT, ✕, CANCEL |
| Question window | 4 answer buttons, ASK A TEAMMATE FOR HELP |
| Help alert | YES (Y), NO (N) |
| End of round | Play Again / "Play Again (next Sili)" (host only), Main Menu / Leave |

---

## 2. Scenes / screens

| Scene | What it shows | Main nodes |
|---|---|---|
| `title_screen.tscn` (main scene) | City background, logo, name field, menu; opens How to Play, Leaderboard, Host and Join | `Background`, `Dim`, `Menu` (`TitleLogo`, `PlayerNameRow`, `HostButton`, `JoinButton`, `HowToButton`, `LeaderboardButton`, `QuitButton`, `ErrorLabel`), `LeaderboardDim`, `Leaderboard` pop-up (`Header` with `Title` + `CloseButton`, `Scoring`, `HeaderRow`, `Scroll/Rows/RowTemplate`, `Empty`), `HowToDim`, `HowToPanel` (`Header`, `Divider`, `Scroll/Rules` RichTextLabel, `CloseButton`), `HostModal`, `JoinModal` |
| `host_modal.tscn` | "HOST A GAME" sari-sari store window: IP on a chalkboard, 6 player slots, status, START GAME | `Center/Store/Top` (`Roof`, `Title`, `CloseButton`), `Body/VBox/HostCard`, `PlayersCard` (`Slots/SlotTemplate`), `Counter` (`Status`, buttons) |
| `join_modal.tscn` | "JOIN A GAME" store window: games nearby, type-an-IP, slots after connecting | `FindCard` (`FoundList/GameTemplate`), `IpCard` (`IpEdit`, `ConnectButton`), `PlayersCard`, `Counter` |
| `maze_game.tscn` | The round | `Map` (city_map), `Camera`, `Scrolls`, `Actors`, `RoundTimer`, `AnimationPlayer`, `HUD` (CanvasLayer: `Minimap`, `TopBar`, `WarningLabel`, `WarningGlow`, `MessageLabel`, `PauseLabel`, `QuizPanel`, `AnswerPopup`, `AnsweringNotice`, `HelpAlert`, `EndPanel`). The `HUD` is **hidden in the editor** so it doesn't cover the map; the game shows it at start. |
| `city_map.tscn` | City and maze painted with tiles | `Surroundings`, `Maze` (TileMapLayers), `Props` (jeepneys, tricycles, posts), `Starts` (`TubigStart1–4`, `SiliStart1–2`) |
| `player.tscn` | One character | `Body` (Sprite2D), `NameLabel` (above the head), `AlertLabel` ("!" above the name), `CollisionShape2D` |
| `question_scroll.tscn` | The "?" pickup | `Icon` (Sprite2D) |
| `quiz_panel.tscn` | Question window | `Panel/Margin/VBox` (`HeaderLabel`, `TimeLabel`, `QuestionLabel`, `Choices/Choice1–4`, `HelpButton`, `FeedbackLabel`) |
| `answer_popup.tscn` | TAMA! / MALI! / TIME'S UP! popup | `Center/Panel/Margin/VBox` (`BigWord`, `Who`, `Answer`, `Fact`, `Score`) |
| `help_alert.tscn` | Bottom-right help request | `Panel/Margin/VBox` (`Title`, `Message`, `Buttons/YesButton`, `NoButton`) |
| `answering_notice.tscn` | "Tubig is answering, cannot be tagged" (Sili, one-Tubig games) | `Center/Panel/Margin/Label` |
| `how_to_play.tscn` | Old standalone How to Play panel | **Not used** |
| `lobby.tscn` | Old lobby screen | **Not used**; its script was deleted |
| `lobby_modal.tscn` | Old combined Host/Join window | **Not used and broken** (see §9) |

---

## 3. Scripts and responsibilities

| Script | Responsibility |
|---|---|
| `autoloads/game_state.gd` | Round state (`READY, PLAYING, QUESTION, PAUSED, ENDED`), scene paths, player name (saved in `user://player_settings.cfg`), keyboard input actions. |
| `autoloads/network.gd` | LAN networking with ENet: host/join/leave, player list and names, role assignment and rotation, "everyone loaded" handshake, LAN discovery (joiner asks, host answers). |
| `data/questions.gd` | Question bank: 32 entries with question, 4 choices, answer and a fact. |
| `data/leaderboard.gd` | Leaderboard: points formula, saving round results to `user://leaderboard.cfg`, sorted rankings. |
| `scenes/maze_game.gd` | The round and all rules: reads the maze from the TileMap, camera and vignette, spawning, round time, scrolls, several questions at once, help requests (one at a time), tag/rescue, warnings, timer, pause, per-player stats, win/lose, leaderboard results, Play Again. The host decides; all devices display. |
| `scenes/player.gd` | One character: movement, sprint/stamina, position sync, walking animation, name tag above the head, answering / caught / rescued / immunity states. |
| `scenes/minimap.gd` | Whole maze in the corner ("MAPA"), your dot, camera-view box. |
| `scenes/quiz_panel.gd` | Question window: 15 s countdown (waits while paused), answer by click or 1–4, help button and its locked / unavailable states. |
| `scenes/answer_popup.gd` | Result popup; words and colors editable in the Inspector. |
| `scenes/help_alert.gd` | Help request alert with YES/NO and Y/N keys; text editable in the Inspector. |
| `scenes/answering_notice.gd` | The Sili's "Tubig is answering" notice; text editable in the Inspector. |
| `scenes/question_scroll.gd` | Scroll sprite scaling and pulse. |
| `scenes/title_screen.gd` | Title menu, name field, How to Play, and the Leaderboard pop-up (open, close, refill). |
| `scenes/store_modal.gd` | Shared base of the Host/Join windows: player slots, counts, status, close. |
| `scenes/host_modal.gd` / `join_modal.gd` | Host window (IP, START) and Join window (games list, connect). |
| `scenes/png_button.gd` | PNG buttons: fit, hover glow, press shrink, grey when disabled. |
| `scenes/ui_button_style.gd` | Code-drawn button styles (end-of-round, answer, help and help-alert buttons). |

---

## 4. What works now vs. what is incomplete

### Works — tested with real game copies over LAN (see "Test runs")

- Title screen, How to Play (scrolls), TOP PLAYERS leaderboard, Host/Join windows.
- LAN discovery: several joiners on one PC; a host with two network adapters is listed
  once, with the right IP; joining by the list's JOIN button.
- Rounds with 2, 3, 4 and 6 players:
  - roles and round time
  - scroll pickup, several questions at once, the answerer can't be tagged
  - help requests: one at a time, only free teammates alerted, first YES wins, late YES ignored
  - TAMA!/MALI! popup, tag, rescue, Sili win
  - pause (question timer waits), Play Again with the Sili role rotating
- One-Tubig games: the whole chase stops, the Sili notice shows, and the clock pauses.
- Leaderboard points (win / correct / tag) and "You earned +N points".
- Screen shapes 2400×1080, 1024×768 and 1920×1080: screen filled and HUD placed
  correctly.

### Not re-tested **[CHECK]**

- The full 3-minute timeout, a player or host leaving mid-round, 7th player refused,
  rescue points on the leaderboard, discovery across separate real devices or hotspots,
  mouse clicks on real hardware, Android or exported builds.

### Incomplete / placeholder

- **Art:** placeholder, generated by script (§6). There is one walking strip flipped
  left/right, with no up/down animations.
- **No sound or music.**
- **No touch controls or Android build.**
- **No stamina bar** (`get_stamina_ratio()` is unused).
- **No fog of war:** only the close camera and a vignette.
- **One maze only.**
- **No reconnect.**
- **Leaderboard is per device:** players are matched by name only, and it can't be reset
  from the game (delete `user://leaderboard.cfg`).
- **Old files:** `how_to_play.tscn`, `lobby.tscn` and `lobby_modal.tscn` are unused.
  `README.md` is partly out of date.

---

## 5. Networking model

- **Transport:** Godot high-level multiplayer (`ENetMultiplayerPeer`). Game port **7777**,
  discovery port **7778** (UDP). The host plays as peer 1 and allows 5 clients.
- **Discovery** (`network.gd`; the joiner asks, the host answers):
  - The joiner broadcasts `SILITUBIG_FIND` every 1 s from **its own random port**, to
    `255.255.255.255` and every local network's `x.y.z.255`.
  - The host listens on 7778 and answers each FIND directly with
    `SILITUBIG_TASKAVENUE|<host id>|<players>|<host name>`.
  - Games are grouped by **host id**, so a host with several network adapters is listed
    once. The IP on the same network as the joiner is used. Games not heard from for 4 s
    are removed.
  - Why this way: several joiners work on one PC, and the joiner's firewall lets the
    answers in because they are replies.
  - The host's IP list puts real Wi-Fi/LAN addresses first and virtual adapters
    (192.168.56.x, 172.16–31.x) last.
- **Joining:** the client sends its name. The host syncs players and names to everyone,
  and refuses joins after the start or when 6 are in.
- **Start:** the host calls `start_game()`, every device loads the maze and reports
  ready, and the host spawns everyone once all have reported.
- **The host decides** (`_host_*` functions, `@rpc("authority")`):
  - roles and round time
  - spawns and scrolls
  - opening questions (`_open_question` with a question id)
  - answers (`_question_result`)
  - help requests: `_help_lock` makes one request at a time, `_help_asked` alerts
    teammates, `_question_passed` hands over the question
  - tags and rescues, the timer (`_sync_time`), pause
  - win/lose and the per-player results for the leaderboard (`_end_round`)
- **Each device sends:**
  - its own position about 30 times per second (`_net_position`)
  - its answer (`_submit_answer(qid, choice)`)
  - its help request (`_request_help`) and help offer (`_offer_help`)
  - its name, and "my scene is ready"
- **Disconnects:** if the host leaves, clients return to the title screen. If a player
  leaves, the host removes them, times out their open question, and may end the round.

---

## 6. Assets

**Source:** all PNGs except the two marked **[CHECK]** were generated for this project
by Python/Pillow scripts during development sessions with Claude (Anthropic). The TileSet
was built with a Godot script. No third-party asset packs are included. `README.md`
mentions the group project's credits (EsriEsra, LimeZu, Crusenho, Yūki — CC BY-SA 4.0),
but none of those files are in this folder.

| File(s) | Size (px) | Used by | Source / license |
|---|---|---|---|
| `backgrounds/title_city.png` | 1199×633 | title background | **[CHECK]** replaced in commit `8ee0cc3`; source and license unknown |
| `ui/title_logo.png` | 421×180 | title logo | **[CHECK]** replaced in commit `8ee0cc3`; source and license unknown |
| `characters/tubig_kid.png`, `sili_kid.png` | 96×24 (4 frames) | `player.gd` | generated |
| `props/jeepney.png`, `tricycle.png`, `electric_post.png` | small | `city_map.tscn` | generated |
| `walls/*.png` (12 tiles) + `walls/city_tileset.tres` | 40×40 | maze TileSet | generated |
| `ui/scroll.png` | 24×24 | scroll | generated |
| `ui/button_*.png` (11 buttons, incl. `button_leaderboard.png` 720×96) | various | title, Host/Join windows | generated |
| `ui/panel.png`, `ui/card.png` | 64×64, 48×48 | How to Play and leaderboard frame; cards/slots | generated |
| `ui/host_store/*`, `ui/join_store/*` | 1280×236, 128×64, 128×76, 48×48 | store windows | generated |
| `ui/store_templates/*` | same sizes | drawing guides (not used in game) | generated |

**Fonts:**
- There are no font files. Text uses Godot's default font; RichTextLabel bold and italic
  use the default theme's variants.
- Words inside the generated PNGs were drawn with Windows **Arial Black / Arial Bold**
  **[CHECK]** whether the course needs this listed.

---

## 7. Project settings (`project.godot`)

| Setting | Value |
|---|---|
| Engine | `config/features = "4.7", "Forward Plus"`. Tested with Godot 4.7.2-stable. `README.md` still says 4.3 **[CHECK]** |
| Main scene | `res://scenes/title_screen.tscn` |
| Viewport | 960 × 640 (window override 1280 × 720) |
| Stretch | mode `canvas_items`, aspect **`expand`**: the game fills any screen shape, and the HUD is anchored to the edges |
| Orientation | `window/handheld/orientation=4` (sensor landscape) |
| Default texture filter | Nearest (pixel art). The title screen uses Linear |
| Autoloads | `GameState`, `Network` |
| Export presets | **none** |
| Physics layers (in code) | walls 1, Tubig 2, Sili 4; players collide with walls only |

---

## 8. Changes compared to a basic maze chase with placeholder shapes

| Area | Now |
|---|---|
| Viewpoint | `Camera2D` zoom 2.5 following your own player; limits 3 tiles past the maze |
| Fog | none; a radial vignette darkens the screen edges |
| Minimap | "MAPA": whole maze, your dot, camera-view box |
| Maze | painted TileMapLayer (`city_map.tscn`); walls are tiles with collision; draggable start markers |
| City look | roads, GI roofs, house/store fronts, trees, outer city, jeepney/tricycle/post props |
| Characters | PNG kids (blue Tubig, red Sili), 4-frame walk, tints; grey when caught; blink when immune; **name above the head** (own name yellow) |
| Title screen | PNG background, logo and buttons; scrollable formatted How to Play; **LEADERBOARD button → TOP PLAYERS pop-up** |
| Lobby | Host / Join pop-up windows drawn as a sari-sari store |
| Questions | several at once; the answerer is frozen and untaggable; pass to one teammate; one help request at a time; result popup |
| Round time | shorter with more Tubigs |
| Screens | fills any screen shape; HUD anchored; sensor landscape |
| Editing | HUD and pop-ups hidden in the editor; templates for slots/rows/games; texts and colors in the Inspector; replaceable PNGs; drawing templates |

---

## 9. Known bugs, Output errors and fragile parts

1. **`scenes/lobby_modal.tscn` fails to load.** It points to the deleted
   `lobby_modal.gd` and to old `assets/ui/store_*.png` / `chalkboard.png`, so Godot prints
   `File not found` / `Parse Error` when it imports or loads it. Nothing uses it; it
   comes back when the editor re-saves an open tab. **Fix:** close its tab without saving,
   delete it, and commit. `lobby.tscn` and `how_to_play.tscn` are also unused.
2. **No runtime errors or warnings** were printed in any of the test runs listed below.
3. **Likely editor warnings [CHECK]** (the analyzer shows them in the editor only): `var
   name` in `network.gd` hides `Node.name`; parameters named `position` in
   `maze_game.gd` / `quiz_panel.gd`; integer divisions in `maze_game.gd`.
4. **Leaderboard on one PC:** several game copies on one PC share one leaderboard file.
   If they save at the same moment, one save can be lost (seen in testing: 2 games
   recorded instead of 3). Separate devices each have their own file.
5. **Leaderboard identity:** players are matched by name only. Two people with the same
   name share one row, and renaming starts a new row.
6. **Only the answerer sees the question**; teammates see the result line. How to Play
   describes this correctly; `README.md` does not.
7. **README out of date:** Godot 4.3, "placeholder shapes", "no player names", "no real
   sprites", "everyone sees the question", old lobby.
8. **Fragile parts:**
   - The map needs **4 `TubigStart`** and **2 `SiliStart`** markers on road tiles.
   - `TILE = 40` must match the TileSet.
   - Name-tag scale 0.4 is tied to camera zoom 2.5.
   - Minimap colors are fixed in `minimap.gd`.
9. **Not tested on real devices:** discovery across devices or hotspots, Android, exports.
   The host PC's firewall must allow Godot (ports 7777/7778) for others to join.

---

## 10. Bugs fixed during development sessions

| # | What happened | Cause | Fix | Result after fix |
|---|---|---|---|---|
| 1 | Other players were invisible | An earlier "perspective" change hid everyone except you | Removed; a close-up camera limits the view instead | Nearby players visible |
| 2 | The whole maze was on screen | No camera | `Camera2D` zoom 2.5 following the local player | About 10×6 tiles visible |
| 3 | Name labels blurry at zoom | Small font scaled up 2.5× | 15 px font at scale 0.4 | Sharp text |
| 4 | Minimap used hard-coded origin/tile | Copied numbers | Real values passed in | Dot and camera box line up |
| 5 | Maze not editable visually | Text array drawn in code | TileMapLayer + TileSet | 345 cells, 0 collision mismatches |
| 6 | Logo banner overlapped text | Banner too narrow | Wider banner | Clear |
| 7 | PNG button press unreliable | `is_pressed()` read inside signals | Separate down/up handlers | Shrinks on press **[CHECK: real mouse]** |
| 8 | START looked clickable below 2 players | No disabled look | Grey when disabled | Greyed until 2 players |
| 9 | Join list had stale counts | Refreshed only for new IPs | Refresh on count change | Counts update |
| 10 | Host/Join window ran off screen | Manual resize | `CenterContainer` | Fits |
| 11 | Host window too tall | Large spacing | Tighter layout | Fits 640 px |
| 12 | Host/Join window invisible in the editor | Root hidden; rows built only in code | Visible scene root; editable templates | Editable |
| 13 | Old lobby scenes keep returning | Editor re-saves open tabs | Deleted | **Not solved** (§9 #1) |
| 14 | Sign text overflowed | Font too big | Smaller font, wider sign | Fits |
| 15 | Parameter names hid built-ins | Naming | Renamed | No conflict |
| 16 | TAMA/MALI hard to read | Small line at the bottom of the question window, 2 s | `answer_popup.tscn`, 3.5 s | Readable popup |
| 17 | Game didn't fit other screens | Aspect `keep` + fixed HUD positions | Aspect `expand`, anchored HUD | Tested at 20:9, 4:3, 16:9 |
| 18 | Same host listed twice | Host PC has two adapters (Wi-Fi + VirtualBox); each IP listed | Host id in answers; one entry per id; best IP chosen | Listed once, real IP |
| 19 | Second joiner on the same PC saw no games | All joiners bound the same port 7778; the second failed silently | Joiner asks from a random port; host answers directly | 3 joiners on one PC all see the game |
| 20 | Host window could show a virtual IP | Adapter order | Real LAN IPs sorted first | Shows 192.168.0.x |
| 21 | Pop-ups covered the map while editing | HUD CanvasLayer and pop-ups visible in the editor | HUD and pop-ups hidden in the scene; shown by code | Map visible when editing |
| 22 | How to Play too tall for the screen | Long text in a fixed 500 px panel | ScrollContainer + formatted RichTextLabel | Whole text reachable by scrolling |
| 23 | Two HELP presses at the same instant | Second asker could be stuck on "Asking..." | Host rejects the second one; its button shows "already asking" | No stuck button |
| 24 | Name tags floated too high | Offset too large after moving them above the head | Lowered to sit just above the sprite | Checked in screenshot |

**Fixed before these sessions** (from `README.md`, not re-checked): the Sili could not
tag (collision circles too big); Esc could pause but not resume; instant rescue
(now 1 s minimum); portrait orientation (now sensor landscape, see §7).

---

## Test runs

All tests used Godot 4.7.2-stable copies of the real game on one Windows 11 PC over
127.0.0.1, driven by temporary scripts (deleted afterwards). Screenshots were taken from
the game's own viewport.

| Date | Test | Result |
|---|---|---|
| 09-24 | Load every scene | All used scenes load; `lobby_modal.tscn` fails (§9) |
| 09-24 | 3-player round: join, pause, question, tag, rescue, Sili win, Play Again | All correct on all devices; Sili rotated |
| 09-24 | Wall collisions | 345 cells, 0 mismatches |
| 09-26 | Result popup, solo | TAMA! (green) / MALI! (red) with answer, fact, score |
| 09-26 | Screen sizes 2400×1080, 1024×768, 1920×1080 | Screen filled, HUD placed correctly |
| 09-26 | 2 players (1 Tubig) question | Chase stops, Sili sees notice, clock held at 178, no help button |
| 09-26 | 6 players help flow | Answerer untaggable; B's NO closes only B's alert; C's YES wins; D's late YES ignored; popup only on the answerer |
| 09-26 | Discovery: host + 3 joiners on one PC, host with 2 adapters | Each joiner lists the host once, with IP 192.168.0.104 |
| 09-26 | 4 players joining by the list's JOIN button | All reach the maze |
| 09-26 | 6 players, two questions at once + help | Two open questions, pass to C, both scored (2/10) |
| 09-26 | 6 players, help lock | B's button "Host is already asking..." (disabled) until C accepted; then B asked and D helped |
| 09-26 | Round time | 4 Tubigs → 2:00; 1 Tubig → 3:00 |
| 09-26 | How to Play at 960×640 | 700×525 panel; rules 1056 px tall, scroll to the bottom |
| 09-26 | Leaderboard round (3 players) | +1 for a correct answer, +5 for the Sili (win + 2 tags), +0 for the other Tubig; TOP PLAYERS shows the ranking; test data deleted afterwards |
| 09-26 | Name tags | Name above the head, own name yellow |
| 09-26 | Leaderboard pop-up (sample data, deleted afterwards) | Opens centered with 4 ranked rows; closes with Esc, click outside and ✕ |

**Not tested:** see §4 "Not re-tested".
