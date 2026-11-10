# Performance and Resource Analysis (SA6 · AS3)

## 1. Test scenario (repeatable)

| Item | Value |
|---|---|
| Scenario | Solo vs Bot **Round 4** (3 bots), Tubig stands still at the start (kept protected so the round doesn't end), 60 s |
| Script | `tools/tests/perf.gd`: one sample per second, prints the averages |
| Command | `godot --path . --resolution 1280x720 --script tools/tests/perf.gd` |
| Metrics | FPS (avg, min), process time, physics time, static memory, video memory, draw calls, node count, scene load time |
| On the phone | Settings → **Show FPS** shows FPS, frame time, memory, draw calls and nodes in the game. Godot's remote debugger (Debug → Deploy with Remote Debug) gives the Profiler and Monitors tabs |

## 2. Baseline measured on the development PC

Measured 2026-11-10 by Claude (AI assistant) during development. Windows 11, NVIDIA GeForce
MX250, Godot 4.7.2, window 1280×720, build 1.1.0 (uncommitted working copy).
**This is not the phone. Measure the phone yourself for the SA6 report.**

| Run | Avg FPS | Min FPS | Process (ms) | Physics (ms) | Static mem (MB) | Video mem (MB) | Draw calls | Nodes |
|---|---|---|---|---|---|---|---|---|
| vsync on (normal) | 60.0 | 59 | 17.45 | 1.37 | 65.8 | 42.0 | 25 | 250 |
| vsync off (`--disable-vsync`) | 474.5 | 26 (first second, loading) | 4.77 | 1.13 | 65.8 | 42.0 | 25 | 250 |

Scene load (title → maze): **523 ms**. APK size (v1.0 build): 58–66 MB.

### Finding: the ~17 ms "process" time is waiting, not work
With vsync on, the process time stayed at 17–19 ms even with the minimap, bots, HUD or trails
switched off one at a time:

| Switched off | Avg FPS | Process (ms) | Draw calls |
|---|---|---|---|
| nothing | 60.0 | 17.45 | 25 |
| minimap | 59.9 | 17.77 | 14 |
| bots | 59.1 | 18.43 | 28 |
| HUD | 60.2 | 19.18 | 11 |
| trails | 59.2 | 17.97 | 38 |

With vsync off the game ran at ~475 FPS, so the frame budget is mostly free: the 17 ms is the
frame waiting for the screen refresh. On this PC there is no CPU bottleneck in the round.

## 3. Candidate bottlenecks to check on the phone

These are risks to measure first. They are **not** confirmed on the phone yet:

1. **APK size (58–66 MB):** the audio is MP3 (8.6 MB) and the Android export includes both
   ARM 32 and 64-bit libraries. Try ARM64 only, or compress the long music loop.
2. **Minimap redraw every frame:** it draws the whole maze (≈345 rectangles) every frame
   (`scenes/minimap.gd`). On the PC, hiding it removed 11 draw calls. Candidate change:
   draw the maze once into a texture, and redraw only the dots.
3. **Fill rate on high-resolution phones:** the vignette TextureRect covers the whole screen.
4. **Trails:** 14 particles per player × up to 6 players; check the phone FPS with trails
   on and off.

## 4. Before / after table (fill in on the phone)

| Change (one at a time, separate commits) | Commit | Avg FPS before | After | Memory before | After | Trade-off |
|---|---|---|---|---|---|---|
| | | | | | | |
