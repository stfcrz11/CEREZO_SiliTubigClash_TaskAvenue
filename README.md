# Sili-Tubig: Task Avenue

Individual prototype for PEBSIT 004 LAB (MAD2) Preliminary Examination.
Adopted, with the instructor's permission, from the group project
**Sili-Tubig Clash** (F.I.R.E.S DEV, ULS CODE & CONQUER Cagayan Valley
entry), where I served as tester and support developer.

**Student:** Stefane B. Cerezo, BSIT 4A
**Naming convention:** PEBSIT004_Prelim_Cerezo_TaskAvenue
**Category:** Board Games or Brain Games (trivia chase)

## Concept

A LAN multiplayer maze game based on the Filipino street game sili-tubig.
**Sili** players chase, **Tubig** players run — and the Tubig team has a
task: "?" scrolls in the maze hold multiple-choice questions about
Filipino culture (mythology, epics, traditions, dances, games).

- **2–6 players**, each on their own device (same Wi-Fi or hotspot).
- **Roles:** 2–4 players → 1 Sili, 5–6 players → 2 Silis, everyone else is
  Tubig. The Sili role rotates every round (Play Again).
- **Tubig team wins** by answering **10 questions correctly** before the
  3-minute timer ends.
- **Sili wins** by freezing every Tubig, or when time runs out.
- Touching a scroll freezes the round and shows the question on every
  screen; only the Tubig who picked it answers (15 s). Wrong answer = find
  another scroll. Questions come at random from a bank of 32.
- A Sili touching a Tubig freezes it. A teammate touching a frozen Tubig
  rescues it (after it has been frozen for 1 s) and gives 1.5 s of safety
  plus a speed burst (rescue rule from the group game).
- Tubigs get a warning when a Sili is close: "!! SILI NEARBY !!", then
  "RUN! SILI IS RIGHT THERE!", with a flashing red screen edge.

Intended users: students and barkada groups who want 3-minute party
rounds and a fun way to learn Filipino culture.

## Development environment

- Godot Engine 4.3, GDScript only, no third-party plugins
- Godot high-level multiplayer (ENetMultiplayerPeer + RPCs)
- Placeholder `ColorRect` shapes — no external assets needed

## Project structure

```
autoloads/
  game_state.gd       Round state, scene paths, keyboard controls
  network.gd          Host / join, LAN discovery, player list, roles
data/
  questions.gd        32 Filipino-culture questions (edit to add more)
scenes/
  title_screen.*      Host Game / Join Game / How to Play / Quit
  lobby.*             Host view (IP, players, Start) and Join view
  maze_game.*         The round: maze, scrolls, questions, tags, rescues,
                      timer, win/lose (host decides, all devices show)
  player.*            One character; role = "tubig" or "sili"
  question_scroll.*   The "?" pickup
  quiz_panel.*        4-choice question window
```

**Networking model:** the host is the only one who decides roles,
pickups, questions, answers, tags, rescues, the timer and the result, and
sends each decision to all devices by RPC. Every device moves only its
own character and sends its position ~30 times per second.

## Setup and run

1. Open Godot 4.3 and import this folder.
2. Press Run (F5) on one PC → **Host Game**.
3. On other devices on the same network → **Join Game** → pick the game
   from the list (or type the host IP shown on the host's lobby).
4. Host presses **Start** (needs at least 2 players).

To test on one PC: Debug → Customize Run Instances → Enable Multiple
Instances → 2 or more, then Run. Host in one window, join `127.0.0.1` in
the other.

**Tip:** venue/school Wi-Fi often blocks device-to-device traffic. Use the
host's phone or laptop hotspot instead.

## Controls

| Action | Key |
|---|---|
| Move | W A S D or arrow keys |
| Sprint | Shift or Space (drains stamina) |
| Answer | Click / tap a choice, or keys 1–4 |
| Pause / Resume | Esc (host only; pauses everyone) |

## Completed features

- Title, How to Play, LAN Host/Join lobby with automatic discovery and
  type-the-IP fallback; 2-player minimum, 6-player maximum (7th refused)
- Role assignment (1 or 2 Silis by player count) and rotation each round
- Maze built from a text layout (walls block everyone)
- Movement + sprint/stamina synced across devices
- Question scrolls, random questions, 15 s answer limit, only the picker
  can answer, fact shown after each answer, 10 correct = win
- Sili tag → freeze; teammate rescue with 1 s minimum freeze, immunity and
  speed burst
- Sili-nearby warning (banner, red edge, "!" over the Tubig)
- 3-minute timer; win/lose screen with per-player "You win / You lose"
- Host pause for everyone; Play Again (next Sili); Leave
- Player leaving mid-round is handled (round ends if no Sili / no Tubig left)

## Tested (Godot 4.3, several game instances on one PC over ENet)

- 2, 3, 4 and 6 players joined; roles 1/1, 1/2, 1/3 and 2/4; 7th refused
- Movement, question, answer, score, tag, rescue timing, pause, 10-answer
  win, timer loss, Play Again rotation, player leaving — all matched on
  every instance
- Still to test: separate physical devices on a hotspot, Android export

## Incomplete / not attempted (honestly declared)

- No on-screen touch joystick (movement needs a keyboard)
- No reconnect if a player drops; no player names (P1–P6 only)
- No real sprites, audio or Filipino voice callouts yet
- One maze only

## Known issues

- If the host leaves, the round ends for everyone (host runs the rules)
- Automatic discovery can be blocked on some networks — use the IP box
- Sili start spots are in the maze corners; one is a short dead end

## Fixed during development

- Sili could never tag: collision circles (12 + 13 = 25 px) stopped the
  bodies before the 20 px tag distance. Tubig and Sili now use different
  collision layers (both hit walls) and tag by distance.
- Esc could pause but not resume (`get_tree().paused` froze the node that
  listens for Esc). Pause now uses the round state, sent to all devices.
- A teammate standing next to a tagged Tubig rescued them instantly.
  A caught Tubig must now stay frozen 1 s before a rescue counts.
- `window/handheld/orientation` was portrait for a landscape game; set to
  landscape.

## Build status

Attempted export target: ______________________
Result (success / documented error): ______________________

## Authorized assets

No imported binary assets (placeholder shapes and Godot's default theme
and font). Questions are original, written for this game. If art from the
group project is added later, carry forward the attribution in the group
repo's `CREDITS.md` (EsriEsra, LimeZu, Crusenho, Yūki — CC BY-SA 4.0).

## Development assistance

Claude (Anthropic) was used to help design and write the maze, LAN
networking and question scripts, test them, and draft documentation.

## Next development steps

- On-screen joystick for Android
- Player names/colors in the lobby; reconnect support
- Sprites, item icons, Filipino voice callouts from the group game
- More mazes and questions (e.g. Cagayan Valley culture)
