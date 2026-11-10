# Test Plan, Traceability, Defects and Acceptance (AS3 Milestone)

## 1. Build and environment

| Item | Value |
|---|---|
| Build | 1.1.0 (Android version code 2), commit: *record `git log -1 --format=%h` here* |
| Development PC | Windows 11 Home, NVIDIA GeForce MX250, Godot 4.7.2-stable |
| Target devices | *fill in: phone model, Android version, screen size* (at least one physical phone + one emulator or second phone) |
| Network | Phone hotspot or home Wi-Fi, UDP ports 7777 (game) and 7778 (discovery) allowed |

**Acceptance criteria (release candidate):** all critical paths below pass on a phone; no open
defect that loses data, blocks finishing a round, shows another player's data, or crashes repeatedly.

## 2. Requirements-to-test traceability matrix

| Req | Requirement | Test cases |
|---|---|---|
| R1 | Title screen, How to Play, Credits, version shown | TC-01, TC-02 |
| R2 | Solo vs Bot: 4 rounds, win → next, lose → retry, best round saved | TC-03, TC-04 |
| R3 | LAN host / join, 2–6 players, 7th refused | TC-05, TC-06 |
| R4 | Movement on keyboard and touch (joystick, RUN, USE) | TC-07, TC-08 |
| R5 | Scroll questions, help request, Tubig win | TC-09, TC-10 |
| R6 | Tag → freeze; all frozen or time up → Sili wins | TC-11, TC-12 |
| R7 | Buhos-Tubig rescue quiz | TC-13 |
| R8 | Huling Hirit self-thaw | TC-14 |
| R9 | Power-up stations: random spots inside the maze, used with E / USE; shield, turbo, gate | TC-15, TC-16, TC-17, TC-18, TC-19 |
| R10 | Bot behaviour by difficulty | TC-20 |
| R11 | Pause (Esc / button), settings saved, pause on app background | TC-21, TC-22, TC-23 |
| R12 | Player data: name rules, leaderboard, tamper check, reset | DT-01 … DT-10 (`DATA_AND_SECURITY.md`) |
| R13 | Error handling: host leaves, wrong IP, player leaves; Leave button rules | TC-24, TC-25, TC-27, TC-28 |
| R14 | Performance: steady 60 FPS on the target phone | TC-26 (`PERFORMANCE.md`) |

## 3. Test cases and results

Automated scripts are in `tools/tests/` (run with `godot --headless --path . --script tools/tests/<file>`).
"Executed (AI)" means Claude ran the script on the development PC on 2026-11-10 while developing;
these results are real but are **not** phone tests. Repeat them yourself and add your phone results.

| ID | Steps | Expected | Actual | Status |
|---|---|---|---|---|
| TC-01 | Open the game; press HOW TO PLAY, CREDITS; close with ✕/Esc | Windows open and close; version "v1.1.0" bottom left | Screenshots 1280×720 (`tools/tests/shot_ui.gd`): all windows render | Executed (AI): Pass |
| TC-02 | Change player name to an invalid value | Error message, name not saved | DT-01…04 | Executed (AI): Pass |
| TC-03 | Solo Round 4: Tubig stands still | Bots tag; 2 Huling Hirit tries; then "SILI WINS…", button "Retry Round 4" | As expected (`sim_solo.gd`, SIM_ROUND=4) | Executed (AI): Pass |
| TC-04 | Win a solo round | "Next Round" button; best round saved and shown in PLAY window | End panel "Next Round" seen in screenshot test; best-round display not yet checked by hand | Partly executed |
| TC-05 | Host + 2 joiners on one PC (multiple instances) | All see each other; START works | Tested in v1.0 (PROJECT_STATE test runs) | Re-test on phones |
| TC-06 | 7th player joins | Refused | Not re-tested since v1.0 | Not run |
| TC-07 | Keyboard: WASD, Shift, E | Moves, sprints, uses station | E opens station quiz (`sim_e.gd`) | Executed (AI): Pass |
| TC-08 | Phone: joystick, RUN, USE button next to a cooler | USE appears only near a station; tap opens quiz | `use_available` true next to a cooler (`sim_e.gd`); real touch not tested | Phone test needed |
| TC-09 | Pick up a scroll, answer correctly | Count goes up; popup TAMA! | Tested in v1.0 | Re-test |
| TC-10 | 2 Tubigs: ask for help, teammate says YES | Question moves to helper | Tested in v1.0 | Re-test |
| TC-11 | Sili touches Tubig | Ice block, "SAVE name!" | Seen in screenshot test | Executed (AI): Pass |
| TC-12 | All Tubigs frozen (team game) | "SILI WINS! ALL TUBIG FROZEN" | Tested in v1.0 | Re-test |
| TC-13 | 3 players: Ana frozen, I touch her and answer correctly | Ana freed, my rescues +1 | As expected (`sim_team.gd`) | Executed (AI): Pass |
| TC-14 | Solo: get tagged, answer 2 hard questions | Thawed, 2 s safety | As expected (`sim_solo.gd`) | Executed (AI): Pass |
| TC-15 | Start 2 rounds; list station cells | All inside the maze (≥2 cells from edge), on road, not under a scroll, different each round | As expected, 2 runs (`sim_e.gd`) | Executed (AI): Pass |
| TC-16 | Walk over a cooler without pressing E | No question | No question | Executed (AI): Pass |
| TC-17 | Press E on a cooler, answer correctly | Yelo Shield ~10 s; cooler rests 20 s | Shield 8.9 s left, rest 19 s when checked | Executed (AI): Pass |
| TC-18 | Bot tags a shielded Tubig | Tag blocked, Sili extinguished 5 s | Stun 4.9 s | Executed (AI): Pass |
| TC-19 | Press E next to a Kalamansi gate, answer correctly | Moved to the other side | Cell (20,6) as expected | Executed (AI): Pass |
| TC-20 | Rounds 3–4 bots | Bots use peppers, retry after a wrong bugtong, tag | Seen in real-time runs | Executed (AI): Pass |
| TC-21 | Pause button / Esc as host | Everyone paused, timers stop | Not run yet | Not run |
| TC-22 | Change settings, restart the app | Settings kept | Not run yet (v1.0 tested audio) | Not run |
| TC-23 | Phone: go to home screen mid-round | Round paused on return | Not run | Phone test needed |
| TC-24 | Host closes the game mid-round | Clients return to title with "The host left the game." | Tested in an earlier version | Re-test |
| TC-25 | Join with a wrong IP | "Could not connect…" message | Not re-tested | Not run |
| TC-27 | Solo: tap LEAVE twice | 1st tap: "Tap LEAVE again…"; 2nd tap: title screen | As expected (`test_leave.gd`, ROLE=solo) | Executed (AI): Pass |
| TC-28 | LAN, 2 instances on one PC: client taps LEAVE mid-round; host leaves mid-round | Client button locked with message; host warned that the game ends for everyone; client sees "GAME OVER — THE HOST LEFT" with Main Menu | As expected (`test_leave.gd`, ROLE=host + ROLE=client, real time) | Executed (AI): Pass |
| TC-26 | 60 s Solo Round 4 performance scenario | ≥ 55 FPS average on the phone | PC: 59–60 FPS (see `PERFORMANCE.md`) | Phone test needed |

## 4. Defect log

| ID | Severity | Found | Steps to reproduce | Expected | Actual (before fix) | Fix | Status |
|---|---|---|---|---|---|---|---|
| D-01 | High | 2026-11-10, `sim_solo.gd` | Solo Round 4, get tagged, thaw | Bots wait a few steps away | All 3 bots stood on the frozen Tubig and tagged again as soon as the 2 s safety ended | Bots keep a "lurk distance" from untaggable Tubig (`bot_sili.gd`) | Fixed, re-run passed |
| D-02 | Medium | 2026-11-10, `sim_e.gd` | Start a round after stations were moved inside the maze | 2+ Kalamansi gates | Only 1 gate (spacing rule too strict) | Gate spacing 3 cells from stations, 5 between gates | Fixed, 2 gates |
| D-03 | Medium | 2026-11-10, screenshot | Open the title screen | Sharp pixel buttons | Buttons blurred (title forced smooth filtering) | Title uses nearest filtering; logo stays smooth | Fixed |
| D-04 | Medium | 2026-11-10, review | Export APK and get tagged on a phone | Phone vibrates | Android needs the VIBRATE permission, which was off | `permissions/vibrate=true` in `export_presets.cfg` | Fixed; verify on phone |
| D-05 | Low | 2026-11-10, review | Edit `leaderboard.cfg` by hand | Edit is detected | Edited numbers were trusted | Checksum + reset (DT-08) | Fixed |

Earlier defects and fixes (v1.0): see `PROJECT_STATE.md` §10 (29 entries).

## 5. Acceptance summary (to complete)

| Passed | Failed | Blocked | Not run |
|---|---|---|---|
| *count after your phone tests* | | | |

*Ready for optimization?* Write your decision and the evidence for it here.
