# Sili-Tubig: Task Avenue

Individual prototype for PEBSIT 004 LAB (MAD2) Preliminary Examination.
Adopted, with the instructor's permission, from the group project
**Sili-Tubig Clash** (F.I.R.E.S DEV, ULS CODE & CONQUER Cagayan Valley
entry), where I served as tester and support developer.

**Student:** Stefane B. Cerezo, BSIT 4A
**Naming convention:** PEBSIT004_Prelim_Cerezo_TaskAvenue
**Category:** Board Games or Brain Games (trivia chase)

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
  "Stef answered correctly". Questions come at random from a bank of 32.
- A Sili touching a Tubig freezes it. A teammate touching a frozen Tubig
  rescues it (after 1 s) and gives 1.5 s of safety plus a speed burst.
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
  questions.gd        32 Filipino-culture questions (edit to add more)
  leaderboard.gd      Points and rankings, saved on this device
scenes/
  title_screen.*      Menu, How to Play, Leaderboard pop-up
  host_modal.*        "Host a game" window (sari-sari store): IP, player slots, Start
  join_modal.*        "Join a game" window: games found nearby, type-the-IP
  store_modal.gd      Shared parts of both windows (slots, status, close)
  png_button.gd       Buttons made from PNG pictures (hover glow, press)
  city_map.tscn       The maze, painted with tiles (edit it in the editor)
  maze_game.*         The round: camera, scrolls, questions, help requests,
                      tags, rescues, timer, win/lose (host decides)
  player.*            One character (walk animation, name above the head)
  minimap.gd          The MAPA in the corner (your dot, scroll dots)
  question_scroll.*   The "?" pickup
  quiz_panel.*        4-choice question window with the help button
  answer_popup.*      TAMA! / MALI! result popup
  help_alert.*        "<name> needs help" YES/NO alert
  answering_notice.*  "Tubig is answering" notice for the Sili
  settings_panel.*    Settings window (audio on/off + volume, controls)
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
   - **SOLO VS BOT** — you are the Tubig and a computer Sili chases you
	 (`scenes/bot_sili.gd`). Solo rounds don't go on the leaderboard.
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
| Answer | Click / tap a choice, or keys 1–4 |
| Ask a teammate for help | H (or the button) |
| Accept / refuse a help request | Y / N (or the buttons) |
| Pause / Resume | Esc (host only; pauses everyone) |
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
- Sili tag → freeze; teammate rescue with 1 s minimum freeze, immunity and
  speed burst; Sili-nearby warning
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
- Most art is simple starter art made for this project; no Filipino voice
  callouts yet
- Walking animation is side-view only (no up/down animation)
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

- **Title background:** "Sunset in the city background" by **inbevel13**,
  downloaded from Freepik under the **Freepik Premium license**: free to use
  in personal and commercial projects and to modify; it may not be
  sub-licensed, resold, rented, or included in an online/offline archive or
  database (Freepik Terms of Use, sections 7 and 8:
  http://www.freepik.com/terms_of_use). The personal license certificate is
  available from the Freepik profile (https://profile.freepik.com/my_downloads).
  Credit: image by inbevel13 on Freepik.
- **Maze tiles, characters, props, scroll, buttons and store windows** were
  made for this project with Python scripts.
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
- Up/down walking animations and final art (tiles, characters, props)
- Reconnect support
- Filipino voice callouts from the group game; key rebinding
- More mazes and questions (e.g. Cagayan Valley culture)
