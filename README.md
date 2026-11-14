# Cell Designer: Power & Growth

Divide mitochondria and chloroplasts to keep a living cell supplied with ATP, protein and sugar across three short levels.

Built from `Cell_Designer_Respiration_GDD_v0.2.md` (in this folder) on 2026-11-14. Grade 7 science, Amplify
Metabolism unit. The only strategic action is clicking a ready organelle to make it divide; supplies, protein
synthesis and starch storage run on their own.

| | |
|---|---|
| Title | Cell Designer: Power & Growth |
| Folder / slug | `cell-designer` |
| Engine | Godot **4.7.2.stable.official** (`ed1daf0bf`), GDScript, GL Compatibility renderer |
| Web export template | Godot's **standard** 4.7.2 `web_nothreads_release.zip` (no threads, no extensions, "Export With Debug" off). Not a lean template: see "Export". |
| Export | `..\exports\cell-designer\index.html` (wasm 39,514,754 B, pck 177,560 B) |
| Estimated play time | About 5 to 10 minutes for all three levels. **Not measured with players.** The GDD's provisional figure is 7 to 13. The scripted fastest paths take about 17 s, 25 s and 90 s of level time, before any reading. |
| Sound | None. The project has no audio files or audio players. |
| Network | None. No accounts, text entry, analytics, external URLs or fonts. |

## Feature checklist

- [x] Level 1 "Power Up": 1 mitochondrion, ATP-only division, grow to 8, automatic power test (14 ATP/s for 8 s)
- [x] Level 2 "Grow and Build": 6 mitochondria, automatic protein synthesis, division costs ATP + proteins, grow to 24,
      sustainability check (4 proteins/s for 10 s, 12 ATP at the end), supply ceiling at 44 ATP/s
- [x] Level 3 "Through the Night": plant cell, 8 mitochondria + 1 chloroplast, 30 s day / 15 s night, automatic starch
      storage and breakdown, hard space cap 18, two cycles to win, failure with a stated cause
- [x] One authoritative resource model on a fixed 0.05 s tick (`scripts/simulation_model.gd`)
- [x] Transactional division with clear refusals: "Not ready", "Need 5 ATP", "Need 4 proteins", "Not enough room"
- [x] Maturation ring (3 to 5 s, per daughter), elongate / constrict / separate animation, clock pictogram on an early click
- [x] Slot-based placement: organelles never overlap each other, the boundary or the vacuole
- [x] Cosmetic molecule layer (glucose, oxygen, carbon dioxide, water, amino acids, proteins, ATP), capped at 100, own RNG
- [x] "Show ATP particles" setting, default on; changes drawing only
- [x] Background ATP-dependent activity (ion pumps, vesicles, membrane repair, ribosomes) that slows when ATP is short
- [x] Tutorial call-outs that pause the level and highlight glyphs, organelles and meters by outline, not colour
- [x] Scripted Level 3 events: first starch breakdown, first starch storage, first-night banner (each once)
- [x] Start (required before anything moves), Pause, Restart, Next level, Help (3 pages), Settings, speed 1x / 2x / 0.5x
- [x] Reduced Motion (default taken from the browser's `prefers-reduced-motion`), three text sizes
- [x] Responsive layout: 1180 x 500 base, UI never below 0.85 CSS px per base px, top-right corner kept clear
- [x] Keyboard: Tab ring over buttons and organelles, Enter / Space, Escape closes then leaves, `sims:leave-game`
- [x] Class settings from the page address: `level`, `particles`
- [x] HTML shell with live regions and an announcer (reused pattern from data-detectives)
- [x] Headless tests (216 checks), balance report, browser check script, axe check of the shell
- [x] Web export, single-threaded, `index.html` at the root
- [x] Sean's `mitochondrion_body.svg` and `chloroplast_body.svg` in use (added to `assets/vector/` during the build)
- [ ] The rest of the Illustrator artwork (still placeholders drawn in code; names in `docs/ASSET_INTEGRATION.md`)
- [ ] Hand testing on a phone, a Chromebook, with a physical keyboard, and with a screen reader
- [ ] Import to the sims site (done by the game-sim-server session, not this build)

## Run it

Commands are for PowerShell 7, from this folder.

```powershell
$godot = "C:\Users\seanm\Nextcloud2\Gamedev\Godot_v4.7.2-stable_win64_console.exe"

# Open in the editor (then press F5)
& $godot --path . --editor

# Play it directly in a window the size of the site frame
& $godot --path . --resolution 1180x500
```

### Tests

```powershell
# Once, and after adding scripts: register class names and import assets. Expect no SCRIPT ERROR / Parse Error.
& $godot --headless --path . --editor --quit-after 200

& $godot --headless --path . --script tests/test_resource_model.gd   # 48 checks
& $godot --headless --path . --script tests/test_fission.gd          # 40 checks
& $godot --headless --path . --script tests/test_progression.gd      # 36 checks
& $godot --headless --path . --script tests/test_web_sanity.gd       # 92 checks

# Not pass/fail: how each scripted strategy plays out over 30 seeds (for tuning)
& $godot --headless --path . --script tests/balance_report.gd
```

Each test prints `<name>: N/N passed (expected N checks) -> PASS` and exits 0, or lists the failures and exits 1.
A run that stops early cannot pass, because the number of checks is compared with the expected total.

`tests/shot.gd` is a developer tool that plays a level with a scripted policy and saves a screenshot. It needs a
real renderer, so run it without `--headless`. Save screenshots **outside** this folder (see "Export").

### Export and browser check

```powershell
& $godot --headless --path . --export-release "Web" ..\exports\cell-designer\index.html

# Stage a throwaway web root OUTSIDE the project: the export as game\, plus the iframe harness
$root = "$env:TEMP\cell-designer-web"
New-Item -ItemType Directory -Force "$root\game" | Out-Null
Copy-Item ..\exports\cell-designer\* "$root\game\" -Force
Copy-Item tests\web\harness.html "$root\" -Force

# In a second terminal (check the port is free first; 8791 was taken on 2026-11-14, 8823 was free)
python -m http.server 8823 --bind 127.0.0.1 --directory $root

# Back in the first terminal
$env:NODE_PATH = "C:\Users\seanm\Nextcloud2\Website\game-sim-server\node_modules"
$env:PORT = "8823"
node tests\web\web_check.js "$env:TEMP\cell-designer-shots"          # installed Chrome, headless
node tests\web\web_check.js "$env:TEMP\cell-designer-shots" headed   # a visible Chrome window
node tests\web\axe_check.js                                          # axe-core on the HTML shell
```

`web_check.js` takes about three minutes because it waits 60 s without input. `$env:QUICK = "1"` shortens that wait to 6 s.

**Export notes**

- **Template.** `check_web_template.py` reports "2D template OK", but the lean templates in `godot-2d-web-template\` are
  built from Godot **4.5** source and a template must match the engine exactly. This build therefore uses Godot's
  standard 4.7.2 web template. The cost is download size: the wasm is 39.5 MB against about 22 MB for a lean 2D
  template. The game uses only basic controls (`Button`, `Label`, `PanelContainer`, `ScrollContainer`, flow and box
  containers) and no deprecated calls, so it should work on a lean 4.7 template once one is built. That is **not tested**.
- The preset excludes `tests/*`, `web/*`, `docs/*`, `*.md` and `*.txt`. The `.pck` was scanned after export: it holds only
  `project.binary`, `icon.svg`, `scenes/Main.tscn`, the two SVGs in `assets/vector/` and the 15 scripts under `scripts/`
  (see `docs/HOSTING_VERIFICATION.md`).
- Keep screenshots, notes and anything private **out of this folder**. Godot imports stray images, and an excluded
  file's name can still ship in the `.pck`.
- `web/shell.html` is the custom HTML shell (loading message, canvas label, hidden live regions). `web/` has a
  `.gdignore`, so the editor does not import it.

## Class settings (page address)

Read from `window.location.search` in web builds only. Anything unknown or out of range is ignored and the default is used.
The text is only compared with fixed strings; it is never used as a path or run.

| Key | Type | Values | Default | Effect |
|---|---|---|---|---|
| `level` | choice | `1`, `2`, `3` | `1` | Level the game opens on |
| `particles` | choice | `on`, `off` | `on` | Cosmetic ATP glyphs in the cytoplasm. The ATP bar and the slowdown stay either way. |

Example: `index.html?level=3&particles=off`. Neither setting changes the rules, and every level still has to be won
by its own check. The Settings panel can also change the level (it restarts) and the ATP particles.

## Registry facts for the sims site

- **Title:** Cell Designer: Power & Growth
- **Description:** Divide mitochondria and chloroplasts to keep a living cell supplied with ATP, protein and sugar across three short levels.
- **Estimated minutes:** 5 to 10, provisional and not measured with players (GDD figure: 7 to 13).
- **Godot version / template:** 4.7.2.stable.official, standard `web_nothreads_release` template, no threads.
- **Class settings:** `level` (choice 1|2|3, default 1), `particles` (choice on|off, default on).
- **Credits:** see `CREDITS.md`. No third-party assets.
- **`level` (grade), `author`, `license`:** left blank for Sean.
- **Not imported, not published.** The export is in `..\exports\cell-designer\`.

### Accessibility notes, at the strength of what was checked

| Item | Status | How it was checked |
|---|---|---|
| Keyboard: every control | Works | Tab / Shift+Tab reach the five top buttons, every organelle (in reading order, updated as organelles divide) and every overlay button; Enter and Space activate. Headless Godot test with real key events, and installed Chrome driven by Playwright (headless and a visible window). **Not tried by hand on a physical keyboard.** |
| Keyboard exit | Works in the test harness | Tab past the last control, Shift+Tab before the first, and Escape with nothing open each released focus and sent one `sims:leave-game`; focus landed on the harness's Full screen button. Escape with a call-out or Pause open closed only that. Checked in Chrome through Playwright against `tests/web/harness.html`, a same-origin stand-in that copies the play page's listener. **Not checked on the real site.** |
| Full-screen Escape | Not checked | In real Chrome full screen the browser takes the first Escape; that was not exercised. |
| Visible focus | Present | Buttons get a 4 px yellow outline; organelles get a yellow ring over a dark ring. Seen in browser screenshots. Contrast figures in `docs/HOSTING_VERIFICATION.md` are computed from the colour constants, not measured on a screen. |
| Organelle contrast | **Below 3:1 with the new mitochondrion art** | The supplied mitochondrion is yellow (`#fce421`) on cream cytoplasm: about 1.0:1 for the fill and 1.9 to 2.7:1 for its orange membrane. The chloroplast art is 1.7:1 (fill) and 2.7:1 (line). Each organelle still sits inside a dark loading ring (13:1), which is what marks its position and readiness. Computed from the SVG colours, not measured. |
| No auto-play | Confirmed | The exported game was left 60 s without input in Chrome: the frame was pixel-identical before and after, and the level had not started (headless and visible window). The project contains no audio. |
| Pause | Confirmed | With Pause open, the frame was pixel-identical over 4 s in Chrome, and the model, timers and particles were unchanged over 600 frames in the headless test. Covers the Level 1 power test and the Level 3 day/night clock, which run on the same clock. |
| Timers | Partly | Pause, and a 0.5x speed that doubles every timer. There is no option to turn the Level 3 day/night clock off. |
| Reduced motion | Present | Stops drift, pulses, the fission slide and the "not ready" shake; rings fill in 8 steps. Default follows the browser's `prefers-reduced-motion`. Outcome proven identical with it on (headless test). The browser default was not exercised. |
| Text size | Present | Normal / Large / Extra large (1.0 / 1.2 / 1.4) scales the whole UI. Layout checked by test at five frame sizes and at Extra large in a 360 px frame. |
| Colour | By design | Molecules differ by shape and carry O2 / CO2 / H2O labels; readiness is a complete ring versus a partial arc; every meter has a label and numbers; the ATP crisis state adds the word CRISIS and hatching; day and night have a sun or moon and a word. **Not viewed in grayscale or with a colour-blindness simulator.** |
| Touch targets | 44 CSS px minimum | Organelle hit areas and buttons are at least 44 CSS px (test). In frames under about 700 px wide with 20+ organelles the hit areas of neighbours can overlap. **Touch itself was not tested**; only mouse clicks. |
| Screen reader | **Not tested** | The game is a canvas. The shell adds a canvas label and two hidden live regions; the game writes level starts, call-out text, blocked-division reasons, organelle focus descriptions, day/night changes and results to them. axe-core found 0 violations in the shell. Nobody has listened to it with a screen reader, so no claim is made about what is actually announced. |
| Phone | **Not yet checked** | Only an emulated 380 x 640 frame in desktop Chrome. It boots and starts; the layout is cramped. |
| Chromebook | **Not yet checked** | |
| Physical keyboard, by hand | **Not yet checked** | Key events were sent by Playwright and by the Godot test. |
| 200% browser zoom | Emulated only | A 590 x 250 frame at device pixel ratio 2 (the CSS size the frame has at 200%). Real browser zoom was not used. |
| Device pixel ratio 1.5 | Checked | Chrome through Playwright, `deviceScaleFactor: 1.5`; text is sharp in the screenshot. |
| WCAG conformance | **No claim** | |

A game in a hidden tab or a fully covered or minimised window stops, because Chrome stops sending animation frames.
That is browser behaviour, not a fault in the game.

## Where things are

```text
project.godot, export_presets.cfg, icon.svg
scenes/Main.tscn                 one node; everything else is built in code
scripts/game_controller.gd       root: UI, fixed-tick loop, events -> tutorials, cards, layout
scripts/simulation_model.gd      sole authoritative resource state (no nodes, no drawing)
scripts/level_configs.gd         every per-level number
scripts/organelle_layout.gd      slots inside the cell; "is there room?"
scripts/organelle.gd             one organelle button: art, ring, fission animation, focus outline
scripts/cell_view.gd             cell cutaway, background activity, hosts organelles and molecules
scripts/molecule_visuals.gd      cosmetic particles (own RNG, capped)
scripts/placeholder_art.gd       all placeholder drawing + the art-replacement lookup
scripts/hud.gd                   status panel: goal, meters, rates, day/night strip
scripts/tutorials.gd             all player-facing teaching text and its triggers
scripts/settings.gd              settings, saved file, page-address parsing
scripts/ui/keyboard_exit.gd      Tab ring, Escape, sims:leave-game
scripts/ui/overlay_panel.gd      Start / tutorial / Pause / Help / Settings / result cards
scripts/ui/announcer.gd          live-region messages for assistive technology
scripts/ui/ui_theme.gd           theme built in code
assets/vector/                   drop Illustrator SVGs here (empty for now)
web/shell.html                   custom HTML shell for the export
tests/                           headless tests, balance report, screenshot tool, tests/web/ browser checks
docs/SCIENCE_MODEL.md            the model, its simplifications, tuning record
docs/ASSET_INTEGRATION.md        how to replace placeholder art
docs/HOSTING_VERIFICATION.md     what was run on 2026-11-14 and what it showed
CREDITS.md
```

Differences from the GDD's suggested structure: there are no `cell_view.tscn`, `hud.tscn` or `tutorial_overlay.tscn`
scenes (those parts are scripts built in code), no `assets/placeholder/` folder (placeholders are drawn by
`placeholder_art.gd`), and the level numbers are one config script rather than `.tres` files.

## Replacing the art

Drop a file with the right name into `assets/vector/` and it is used instead of the placeholder; nothing else changes.
Names, sizes and limits are in `docs/ASSET_INTEGRATION.md`.

Two files are in use already: `mitochondrion_body.svg` and `chloroplast_body.svg`. They appeared in `assets/vector/`
while the build was running (first as `mitochondrion.svg` / `chloroplast.svg`, then renamed), so they were wired in,
given an SVG import scale of 4 with mipmaps, and the tests, export and browser checks were run again with them.

## Model approximations (short version)

Full detail and the tuning record are in `docs/SCIENCE_MODEL.md`.

- ATP, glucose, oxygen, protein and starch numbers are **model units**, not molecule counts. "8 ATP per glucose
  portion" is a game scale, not the real yield.
- ATP units stand for the cell's whole energy budget (real translation also uses GTP).
- Chloroplasts add **sugar and oxygen**, never ATP, to the cell-level pools. Mitochondria supply the ATP meter, day and night.
- Division in 3 to 5 seconds, particle sizes and organelle sizes are game abstractions. The Help panel says so.
- Level 1 has no protein cost for division: a stated teaching simplification.

## Departures from the GDD, and things you should decide

1. **A full protein pool does not pause the ribosomes.** The GDD says assembly pauses when the construction pool is
   full, and also that Level 2 is won by 4 proteins/s for 10 s and Level 3 by 2 proteins/s for 8 s. With a full pool
   those two rules cannot both hold: a player with nothing left to build could never win. In this build the pool
   still caps at 24, and proteins made beyond it go to "the rest of the cell" (growth and repair). The switch is
   `protein_overflow_to_cell` in `level_configs.gd`; the literal rule is one line away and is covered by a test.
2. **Level 2 has no failure you can reach by playing.** When ATP runs short, protein synthesis slows first (as the GDD
   asks), so the reserve never stays under the crisis line for 7 s. A player who does nothing is stuck, not failed.
   The 7-second rule itself is tested with the fuel supply cut off.
3. **Level 3 can be won with 2 chloroplasts**, not only with 3, using the GDD's numbers unchanged. One division at
   the start and then waiting is enough. If you want the choice to bite harder, the levers are `chloro_rate`,
   `starch_start` or the mitochondria count, but that is a design change, so the GDD values were left alone.
4. **Levels 1 and 2 are quicker than the GDD's targets.** The fastest scripted paths take about 17 s and 25 s of level
   time. With reading and hesitation I would guess 1 to 2 minutes each; that guess has not been tested with students.
5. **The lean web template was not used** (it is built for Godot 4.5). The download is about 17 MB larger than it could be.
6. **A level switch was added to Settings** ("Level: N (changing it restarts)"), so a returning student or a teacher
   without the address setting does not have to replay Level 1. It skips nothing inside a level.
7. **No option turns the day/night clock off.** Pause and 0.5x speed are the only timing aids.
8. **The new mitochondrion art has almost no contrast with the animal cytoplasm** (yellow on cream, about 1:1; see
   the accessibility table). Either the art needs a darker membrane line, or the cytoplasm colour should change. The
   placeholder colours were not changed to suit it, because that is an art-direction call.

## Not completed or not verified

- Only the mitochondrion and chloroplast have real artwork. Cells, vacuole, ribosomes, molecules, pumps, vesicles and
  icons are still placeholder drawing in code, and none of their swaps has been tried.
- The fission "neck" between dividing organelles is not drawn when replacement art is in use (it would be in the
  placeholder's colour); the daughters simply slide apart.
- Not tested: real sims site, phone, Chromebook, physical keyboard by hand, touch input, screen reader, real 200% zoom,
  full-screen Escape, grayscale viewing, a lean 4.7 web template.
- The status panel scrolls in very small frames with large text, and that scroll area cannot be moved from the keyboard.
- In phone-sized portrait frames the top buttons wrap to three rows and the cell is small.
- Play time and difficulty have not been tried with students.
- The editor scan prints `ERROR: Max client limits reached` on most runs on this machine (not all). It is an engine
  message, not a script error (no `SCRIPT ERROR` or parse error is reported); its cause was not investigated. My
  guess is other Godot editors open at the same time.
