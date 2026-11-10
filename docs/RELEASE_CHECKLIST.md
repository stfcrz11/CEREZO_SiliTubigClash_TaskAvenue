# Release Readiness Checklist and Evidence Index (PT7 · PA2)

## 1. Minimum game requirements (module) — status in v1.1.0

| Requirement | Where | Status |
|---|---|---|
| Title / start screen and instructions | Title screen, HOW TO PLAY | Done |
| Complete core loop with a clear goal | Maze round, scrolls, win/lose | Done |
| Mobile input + immediate feedback | Joystick, RUN, USE; sound, text popups, vibration | Done (vibration: verify on phone) |
| Win / loss / progression | Team win/lose, 4 solo rounds, best round saved | Done |
| Pause or settings + restart / retry | Pause button / Esc, Settings, Play Again / Retry / Next Round | Done |
| Credits and acknowledgements | CREDITS button in game, `CREDITS.md`, README | Done — **audio sources still to add** |
| Player-data / service component | Local profile, leaderboard with tamper check, reset | Done |
| Error handling, stable installable build | Connection errors, damaged saves, backgrounding | **Rebuild APK for 1.1.0 and install from clean** |

## 2. Release steps (to do)

- [ ] Fill in the audio sources in `CREDITS.md` and `docs/RESPONSIBLE_DEVELOPMENT.md`
- [ ] Copy the tileset's and template's license terms into `docs/RESPONSIBLE_DEVELOPMENT.md`
- [ ] Export the Android APK (Project → Export → Android) as `build/SiliTubig_TaskAvenue.apk`
- [ ] Uninstall the old app, install the new APK, run TC-01…TC-26 on the phone
- [ ] Record the commit ID in README; tag the release: `git tag v1.1.0` then `git push origin v1.1.0`
- [ ] Fill the acceptance summary in `TEST_PLAN.md` and the phone table in `PERFORMANCE.md`

## 3. Evidence index

| Evidence | File / location |
|---|---|
| Theme-to-Mechanics Justification, player analysis, loop diagram | `docs/THEME_AND_DESIGN.md` |
| Data inventory, data-flow diagram, security controls, data tests | `docs/DATA_AND_SECURITY.md` |
| Traceability matrix, test cases, defect log | `docs/TEST_PLAN.md` |
| Performance baseline and method | `docs/PERFORMANCE.md`, `tools/tests/perf.gd` |
| Usability protocol and findings | `docs/USABILITY_TEST_KIT.md` (fill in with your testers) |
| AI and asset disclosure | `docs/RESPONSIBLE_DEVELOPMENT.md`, `CREDITS.md` |
| User guide | `docs/USER_GUIDE.md` |
| Automated tests | `tools/tests/` |
| Weekly reflections | *your own PDFs: Lastname_Firstname_Week##_Reflection.pdf* |
| Commits | https://github.com/stfcrz11/CEREZO_SiliTubigClash_TaskAvenue/commits |
