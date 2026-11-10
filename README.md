# Sili-Tubig: Task Avenue

Individual prototype for PEBSIT 004 LAB (MAD2) Preliminary Examination.
Adopted, with the instructor's permission, from the group project
**Sili-Tubig Clash** (F.I.R.E.S DEV, ULS CODE & CONQUER Cagayan Valley
entry), where I served as tester and support developer.

**Student:** Stefane B. Cerezo, BSIT 4A
**Naming convention:** PEBSIT004_Prelim_Cerezo_TaskAvenue
**Category:** Board Games or Brain Games (trivia chase)

| Project information | |
|---|---|
| Game title | Sili-Tubig: Task Avenue |
| Version | **1.1.0** (Android version code 2) — `application/config/version` in `project.godot` |
| Theme | Board Games or Brain Games (trivia chase), built on the Filipino street game *sili-tubig* — see `docs/THEME_AND_DESIGN.md` |
| Platform | Android phones (landscape, touch controls); Windows for development and LAN testing |
| Engine | Godot 4.7.2-stable, GDScript |
| Repository | https://github.com/stfcrz11/CEREZO_SiliTubigClash_TaskAvenue |
| Current commit | run `git log -1 --format=%h` and record it here for each weekly submission |
| Install | Android: copy `build/SiliTubig_TaskAvenue.apk` to the phone and open it (allow "install unknown apps"). PC: open the folder in Godot 4.7 and press F5 |
| Known limitations | see "Incomplete / not attempted" and "Known issues" below |

Course documents (MOBILE DEV 002, Weeks 13-18) are in [`docs/`](docs/): theme and
design, data and security, test plan, performance, usability test kit,
responsible development (AI and asset disclosure), user guide, release checklist.

## Concept

A LAN multiplayer chase game based on the Filipino street game sili-tubig,
played in a maze that looks like a Philippine city (roads, sari-sari stores,
jeepneys). **Sili** players chase, **Tubig** players run — and the Tubig team
has a task: "?" scrolls in the maze hold multiple-choice questions about
Filipino culture (mythology, epics, traditions, dances, games).

- **2–6 players**, each on their own device (same Wi-Fi or hotspot).
- **Roles:** 2–4 players → 1 Sili, 5–6 players → 2 Silis, everyone else is
  Tubig. The Sili role rotates every round (Play Again).
- **Tubig team wins** by answering **10 questions correctly** before time
  runs out. Round time: **3:00 for 1 Tubig, 20 s less for each extra Tubig**
  (Tubigs can answer at the same time), never below 1:30.
- **Sili wins** by freezing **all** Tubigs at the same time (catching one is
  not enough, teammates can save them), or when time runs out. The top bar
  shows **Frozen: X / Y**.
- **Scrolls:** Tubigs see the scrolls as **yellow dots on their minimap**;
  the Sili doesn't, but can guess where they are going.
- **Answering:** walking into a scroll opens a question for that Tubig only
  (15 s). While answering, that Tubig **can't move and can't be tagged**; the
  others keep playing, and several Tubigs can answer at the same time.
  If there is only one Tubig, the whole chase stops and the Sili sees
  "Tubig is answering, cannot be tagged".
- **Asking for help:** the answerer can press **ASK A TEAMMATE FOR HELP (H)**
  once. Only one Tubig can ask at a time. Free teammates get a YES/NO alert;
  the **first YES** gets the question with a fresh timer, and the asker is
  free to run.
- **Result:** the player who answered gets a big **TAMA! / MALI! / TIME'S UP!**
  popup with the answer and a fun fact; everyone else sees a short line like
  "Stef answered correctly". Questions come at random from 49 general
  questions, 16 hard ones (self-thaw) and 14 bugtong riddles (peppers).
- A Sili touching a Tubig freezes it (an ice block). **Buhos-Tubig:** a
  teammate who touches a frozen Tubig must answer 1 question to splash them
  free (1.5 s of safety plus a speed burst). **Huling Hirit:** a Tubig with no
  one to save them can thaw themselves with 2 hard questions in a row.
- **Power-up stations**, in new random spots inside the maze every round
  (press **E** / tap **USE**): Halo-Halo coolers give a Tubig a Yelo Shield,
  Bicol Express peppers give a Sili Extra Anghang (bugtong riddles), and
  Kalamansi gates let anyone squeeze through a shortcut.
- **Solo vs Bot:** 4 rounds from Easy (1 bot) to Labuyo (3 bots).
- Tubigs get a warning when a Sili is close: "!! SILI NEARBY !!", then
  "RUN! SILI IS RIGHT THERE!", with a flashing red screen edge.
- **Leaderboard:** points per round (win 3, correct answer 1, tag 1,
  rescue 1) are saved on each device and shown in **TOP PLAYERS**.

Intended users: students and barkada groups who want short party rounds and
a fun way to learn Filipino culture.

## Development environment

- Godot Engine **4.7** (tested with 4.7.2-stable), GDScript only, no
  third-party plugins
- Godot high-level multiplayer (ENetMultiplayerPeer + RPCs); own UDP LAN
  discovery
- PNG art in `assets/` (see "Authorized assets" and `assets/README.md`);
  the maze is a TileMap in `scenes/city_map.tscn`

## Project structure

```
autoloads/
  game_state.gd       Round state, scene paths, keyboard controls, player name
  network.gd          Host / join, LAN discovery, player list, roles
  sound.gd            Music and sound effects (assets/audio/)
data/
  questions.gd        Question lists: 49 general (culture, food, places),
                      16 hard (self-thaw), 14 bugtong riddles (peppers)
  leaderboard.gd      Points and rankings, saved on this device
scenes/
  title_screen.*      Menu, How to Play, Leaderboard pop-up
  host_modal.*        "Host a game" window (sari-sari store): IP, player slots, Start
  join_modal.*        "Join a game" window: games found nearby, type-the-IP
  store_modal.gd      Shared parts of both windows (slots, status, close)
  png_button.gd       Buttons made from PNG pictures (hover glow, press)
  city_map.tscn       The maze, painted with tiles (edit it in the editor)
  maze_game.*         The round: camera, scrolls, quizzes (scroll, rescue,
                      self-thaw, cooler, pepper, gate), help requests,
                      tags, effects, timer, win/lose, solo rounds (host decides)
  bot_sili.gd         Computer Sili for SOLO VS BOT (easy/medium/hard/labuyo)
  player.*            One character (5-direction animations, effects, trails)
  minimap.gd          The MAPA in the corner (your dot, scroll dots)
  question_scroll.*   The "?" pickup
  quiz_panel.*        4-choice question window with the help button
  answer_popup.*      TAMA! / MALI! result popup
  help_alert.*        "<name> needs help" YES/NO alert
  answering_notice.*  "Tubig is answering" notice for the Sili
  settings_panel.*    Settings window (audio on/off + volume, controls)
tools/art/           Python scripts that made the character sheets, city
                     atlas and station props (not used by the game)
```

**Networking model:** the host is the only one who decides roles, round
time, scrolls, questions, answers, help requests, tags, rescues, the timer
and the result, and sends each decision to all devices by RPC. Every device
moves only its own character and sends its position ~30 times per second.
To find games, joiners broadcast a "who is hosting?" message and the host
answers directly.

## Setup and run

1. Open Godot 4.7 and import this folder.
2. Type your name on the title screen, then press Run (F5) and **PLAY**. The
   PLAY window has three choices:
   - **SOLO VS BOT** — you are the Tubig in 4 rounds, easy to difficult:
	 Round 1 Easy (1 bot), 2 Medium (1 bot), 3 Hard (2 bots), 4 Labuyo
	 (3 bots). Win to go to the next round, lose to retry. Solo rounds don't
	 go on the leaderboard.
   - **HOST GAME** — host a LAN game on one PC.
   - **JOIN GAME** — on other devices on the same network, press **JOIN** next
	 to the game in the list (or type the IP shown in the host's window).
3. Host presses **START GAME** (needs at least 2 players).

To test on one PC: Debug → Customize Run Instances → Enable Multiple
Instances → 2 or more, then Run. Host in one window, join from the others.

**Tips:**
- Venue/school Wi-Fi often blocks device-to-device traffic. Use the host's
  phone or laptop hotspot instead.
- Allow Godot (or the exported game) through Windows Firewall on the host PC,
  otherwise others can't join.

## Controls

| Action | Key |
|---|---|
| Move | W A S D or arrow keys |
| Sprint | Shift or Space (drains stamina) |
| Use a power-up station | E (phone: USE button, appears next to a station) |
| Answer | Click / tap a choice, or keys 1–4 |
| Ask a teammate for help | H (or the button) |
| Accept / refuse a help request | Y / N (or the buttons) |
| Pause / Resume | Esc or the pause button, top right (host only; pauses everyone). The game also pauses when the phone app goes to the background |
| Close a window | Esc |
| Settings (audio, controls) | Gear button, top right |
| **Phone:** move | Drag on the right half of the screen (joystick) |
| **Phone:** sprint | Hold the RUN button (bottom left) |
| **Phone:** back / close / pause | Android Back button (same as Esc) |

## Completed features

- Title screen with sunset city background, How to Play (scrollable) and a
  Leaderboard pop-up
- Host/Join windows drawn as a sari-sari store; automatic LAN discovery
  (each host listed once, even with several network adapters) and
  type-the-IP fallback; 2-player minimum, 6-player maximum (7th refused)
- Role assignment (1 or 2 Silis by player count) and rotation each round
- City maze painted with a TileMap; close-up camera following your own
  player; minimap with your position and (for Tubigs) the scrolls
- Movement, sprint/stamina and walking animation synced across devices;
  player names above their heads
- Question scrolls: several Tubigs can answer at once, the answerer is safe,
  one help request at a time, first YES takes the question
- Result popup with the correct answer and a fact; 10 correct = win
- Sili tag → freeze (ice block); **Buhos-Tubig** rescue: touch a frozen
  teammate and answer 1 question; **Huling Hirit** self-thaw: 2 hard
  questions in a row when no teammate can help (2 per round in solo);
  Sili-nearby warning
- Quiz stations, in new random spots inside the maze every round (press **E**,
  or tap **USE** on a phone): **Halo-Halo coolers** (Yelo Shield 10 s;
  a Sili who tags a shielded Tubig is extinguished 5 s), **Bicol Express
  peppers** (Sili solves a bugtong: faster + wider tag reach 6 s),
  **Kalamansi gates** (answer to squeeze through a shortcut; wrong = slowed
  3 s). Stations show on the MAPA and rest after use
- SOLO VS BOT: 4 rounds with 1-3 bots. Bot AI adapted from the group
  project's BotBrain: sight with buildings blocking view, memory of the
  last sighting, human-like tag reaction delay, leading a running Tubig,
  unstick logic, waiting a few steps away from a frozen Tubig; team bots
  share sightings and split into chaser / flanker / scroll guard; bots use
  peppers
- City re-skinned with the Simple 32x32 City Tileset; new Sili / Tubig
  characters from Eris Esra's 16x32 template (idle, walk, run and answering
  animations in 5 directions); red ember / blue water trails
- Round time based on the number of Tubigs; win/lose screen with "You
  win/lose" and points earned; leaderboard saved per device
- Host pause for everyone; Play Again (next Sili); Leave
- Player leaving mid-round is handled (round ends if no Sili / no Tubig left)
- Fits any screen shape (wide phones, 4:3, 16:9)
- Sound: title music, button clicks, game start, a loop while you answer,
  correct/wrong, help alert, Sili-nearby warning, game over, win/lose
- Settings (gear button, top right of the title screen and the game): music
  and sound effects on/off + volume, controls list; saved on the device
- Android touch controls: joystick (right half) and RUN button (left), turned on
  automatically on touch screens (switch in Settings)

## Tested (Godot 4.7.2, several game instances on one PC over ENet)

- 2, 3, 4 and 6 players joined (by the list's JOIN button and by IP); roles
  1/1, 1/2, 1/3 and 2/4
- Question, answer, score, result popup, several questions at once, help
  request (NO, first YES, late YES ignored, one request at a time), tag,
  rescue, pause, Sili win, Play Again rotation, round time by Tubig count,
  leaderboard points, scroll dots on the minimap — all matched on every
  instance
- Screen sizes 2400×1080, 1024×768 and 1920×1080
- Still to test: separate physical devices on a hotspot, 7th player refused
  and players leaving (tested in an earlier version), Android export

## Incomplete / not attempted (honestly declared)

- No reconnect if a player drops
- No Filipino voice callouts yet
- Bots only play Sili (no bot Tubig teammates)
- One maze only
- Leaderboard is saved per device and matches players by name

## Known issues

- If the host leaves, the round ends for everyone (the host runs the rules)
- Automatic discovery can be blocked on some networks — use the IP box
- Several copies of the game on one PC share one leaderboard file

## Fixed during development

- Sili could never tag: collision circles (12 + 13 = 25 px) stopped the
  bodies before the 20 px tag distance. Tubig and Sili now use different
  collision layers (both hit walls) and tag by distance.
- Esc could pause but not resume (`get_tree().paused` froze the node that
  listens for Esc). Pause now uses the round state, sent to all devices.
- A teammate standing next to a tagged Tubig rescued them instantly.
  A caught Tubig must now stay frozen 1 s before a rescue counts.
- The same host was listed twice (PC with Wi-Fi + VirtualBox adapters), and
  a second joiner on the same PC saw no games (port already in use).
  Discovery now works by "ask and answer" with a host id.
- The Tama/Mali result was too small to read → big result popup.
- The game had black bars on other screen shapes → it now fills any screen.
- How to Play did not fit the screen → scrollable window.
- Import errors from an old, deleted lobby scene and leftover cache files →
  removed.

See `PROJECT_STATE.md` for the full list (cause, fix and result of each).

## Build status

Attempted export target: **Android (debug APK)** — `build/SiliTubig_TaskAvenue.apk`
Result (success / documented error): **Success** (2026-09-27, Godot 4.7.2).
- Rebuilt 2026-09-27 with audio, settings and touch controls: 66 MB,
  package `com.cerezo.silitubig.taskavenue`, version 1.0, min Android 7.0
  (API 24), ARM 32/64-bit, signed with the debug key (verified with apksigner)
- Permissions: Internet, network/Wi-Fi state, Wi-Fi multicast (for LAN play)
- First attempt failed with "ETC2/ASTC texture compression is required for
  Android export"; fixed by enabling Import ETC2 ASTC in Project Settings.
- Playable on a phone: on-screen joystick + RUN button, tap for answers and
  buttons, Back button = Esc. Not yet installed on a real phone (touch was
  tested with simulated touches on PC). No custom app icon yet (Godot's
  default icon).

## Authorized assets

- **Title background (until v1.0; no longer in the game):** "Sunset in the city background" by **inbevel13**,
  downloaded from Freepik under the **Freepik Premium license**: free to use
  in personal and commercial projects and to modify; it may not be
  sub-licensed, resold, rented, or included in an online/offline archive or
  database (Freepik Terms of Use, sections 7 and 8:
  http://www.freepik.com/terms_of_use). The personal license certificate is
  available from the Freepik profile (https://profile.freepik.com/my_downloads).
  Credit: image by inbevel13 on Freepik.
- **City tiles:** "Simple 32x32 City Tileset" by **Acxa Rmz**
  (https://acxaonpixelia.itch.io/simple-32x32-city-tileset). The maze tiles in
  `assets/walls/city_atlas.png` are cut and combined from it (curbs, roof
  edges, shop/apartment fronts, hedges) by `tools/art/reskin_city.py`.
- **Characters:** **Eris Esra's character template v4.1** (16x32). The Sili
  and Tubig outfits in `assets/characters/*_sheet.png` were painted onto the
  template by `tools/art/make_characters.py`.
- **Props, scroll, buttons and store windows** (jeepney, tricycle, post,
  Halo-Halo coolers, Bicol Express pepper, ice block) were made for this
  project with Python scripts (`tools/art/make_props.py` for the new ones).
- **Audio** (`assets/audio/`, 11 MP3 files: title music, answering loop,
  button click, game start, correct, wrong, help alert, Sili nearby,
  game over, win, lose): [add source / author / license].
- **Fonts:** Godot's default font in the game. Text inside the generated
  button pictures uses the Windows fonts Arial Rounded MT Bold and Arial
  Black.
- **Questions** are original, written for this game.
- If art from the group project is added later, carry forward the
  attribution in the group repo's `CREDITS.md` (EsriEsra, LimeZu, Crusenho,
  Yūki — CC BY-SA 4.0).

## Development assistance

Claude (Anthropic) was used to help design and write the maze, LAN
networking, question, help-request and leaderboard scripts, generate the
starter art, test the game with multiple instances, and draft
documentation.

## Next development steps

- Custom app icon; test on real phones
- Reconnect support
- Filipino voice callouts from the group game; key rebinding
- More mazes and questions (e.g. Cagayan Valley culture)
