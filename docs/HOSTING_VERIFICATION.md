# Hosting verification (GDD section 8.7)

Run on 2026-11-14 on Sean's desktop (Windows 11), against the export in
`..\exports\cell-designer\`. Each result says **how** it was checked. Where something was not run, it says so.

Levels of evidence used below:

- **Automated (Godot, headless):** the `tests/*.gd` suites. No browser, no rendering.
- **Chrome, headless:** installed Google Chrome 157.0.8103.39 driven by Playwright, software GL (SwiftShader).
- **Chrome, visible window:** the same Chrome, same script, in a normal window with the real GPU. Still driven by
  Playwright, so key presses and clicks are synthetic.
- **By hand:** a person using the game. **Nothing in this document was checked by hand.**

The export served to the browser was byte-identical to the one in `..\exports\cell-designer\` (`cmp` on `index.pck`).
Build identifiers (first 16 hex digits of SHA-256): `index.pck` d1a9317610b356b4, `index.wasm` fc74679e3b97f768.

Two SVGs (`mitochondrion_body.svg`, `chloroplast_body.svg`) were added to `assets/vector/` by Sean while the build
was running. Everything in this document was **run again on the final export that includes them**; the results
were the same as on the earlier placeholder-only exports.

## 1. Editor import, tests, template, export

| Check | Result |
|---|---|
| `Godot --headless --path . --editor --quit-after 200` with Godot 4.7.2.stable.official.ed1daf0bf | No `SCRIPT ERROR`, `Parse Error` or `not found`. One engine line, `ERROR: Max client limits reached`, appears on most runs; it is not a script error and its cause was not investigated. |
| `tests/test_resource_model.gd` | 48/48 passed |
| `tests/test_fission.gd` | 40/40 passed |
| `tests/test_progression.gd` | 36/36 passed |
| `tests/test_web_sanity.gd` | 92/92 passed |
| `check_web_template.py .` | "VERDICT: 2D template OK", 0 hits for 3D, advanced GUI and deprecated API. **But** the lean templates are built for Godot 4.5 and cannot be used with 4.7.2, so the verdict only says the code would suit a lean template. |
| Template actually used | Godot's standard 4.7.2 `web_nothreads_release.zip` |
| Export command | `--export-release "Web"` (so "Export With Debug" is off), `variant/thread_support=false`, `variant/extensions_support=false` |
| `index.html` at the export root | Yes. Files: `index.html` 4,760 B, `index.js` 279,815 B, `index.pck` 177,560 B, `index.wasm` 39,514,754 B, two audio worklet scripts (engine files; the game has no audio), three icons/splash PNGs. |
| A lean 4.7 template | **Not tested** (none exists here). |

## 2. Real Chrome: boot line and console

| Check | Chrome, headless | Chrome, visible window |
|---|---|---|
| Console shows `cell-designer: boot ok` (printed from `_ready`) | Yes, standalone and in the iframe | Yes, both |
| `SCRIPT ERROR`, page errors, `USER ERROR` in the console | 0 | 0 |
| Canvas is not blank | Screenshots show the Start card over the cell | Same |

## 3. Same-origin iframe and standalone

`tests/web/harness.html` is a stand-in for the play page: a same-origin `<iframe>`, a Full screen button, and a copy
of the page's listener for `sims:leave-game` (same origin, same frame, right message type). **It is not the real site.**

| Check | Result | Evidence |
|---|---|---|
| Standalone tab at 1180 x 500 | Boots, plays | Chrome headless and visible |
| Iframe 1180 x 500 | Boots, plays, keyboard walk-through passes (section 4) | Chrome headless and visible |
| Iframe 1180 x 360 | Boots and starts from the keyboard; status panel switches to its compact form and fits without scrolling; cell fully visible | Chrome headless and visible; screenshot read by the building agent |
| Device pixel ratio 1.5 (1180 x 500 frame) | Boots and starts; text and outlines are sharp in the 1770 px wide screenshot | Chrome headless and visible (`deviceScaleFactor: 1.5`) |
| 200% zoom | **Emulated only**: a 590 x 250 frame at device pixel ratio 2. Boots and starts; text stays at 0.85 CSS px per base px; the cell is small and call-outs cover part of the status panel. | Chrome headless and visible. Real browser zoom was **not used**. |
| Phone-like 380 x 640 frame | **Emulated only.** Boots and starts; the top buttons wrap to three rows and the cell is small. | Chrome headless and visible. No real phone. |
| Resizing while running | The frame width was cut by 20% mid-level in each variant; the layout followed in the next screenshot. A stale call-out pointer line found this way was fixed and re-checked. | Chrome headless and visible |
| Top-right safe area (200 x 64 CSS px) | No button, organelle or card is placed there, at five frame sizes and with extra-large text | Automated (Godot, headless): `test_web_sanity.gd` layout checks. Also seen in the browser screenshots. |
| Text readability | UI scale never drops below 0.85 CSS px per base px (15 px base text is at least about 12.75 CSS px) | Automated (scale function) + screenshots. **Not judged by a person on a Chromebook.** |
| Class settings | `?level=3&particles=off` opened Level 3 with ATP particles off; `?level=9&particles=maybe&debug=1` fell back to Level 1, particles on | Chrome headless and visible (console line `level N ready (ATP particles on/off)`), plus 8 parsing checks in Godot |
| Real sims site | **Not tested.** Not imported, not published. | |

## 4. Keyboard-only walk-through (iframe, 1180 x 500)

All of these passed in Chrome headless and in the visible window, with keys sent by Playwright. **Not done by hand
on a physical keyboard.**

1. Click an empty spot of the canvas, press Tab: focus lands on Start. Enter starts Level 1.
2. First call-out appears. Escape closes it; no leave message. The level resumes and the second call-out arrives.
3. Escape closes that one too; still no leave message.
4. Six Tabs walk Pause, Speed, Restart, Help, Settings and reach the mitochondrion. Enter divides it (the
   maturation-ring call-out appears, which only happens after a division).
5. Escape closes the call-out; focus returns to a daughter mitochondrion, so the new organelles are in the ring.
6. Tab past the last organelle: exactly one `sims:leave-game`; the page's focus is on the Full screen button.
7. Tab back in, Shift+Tab before the first control: one more leave message; focus on the Full screen button.
8. Escape with nothing open: one more leave message; focus on the Full screen button.

Also covered by the Godot test with real key events: Tab with nothing focused goes to the first control and Shift+Tab
to the last; a modal overlay limits Tab to its own buttons; Help opened over the Start card closes on Escape and
returns focus to the Help button; Escape on the Start card and on a result card leaves; a blocked division spends
nothing and announces its reason.

Focus visibility: the yellow outline on buttons and the yellow-over-dark ring on a focused organelle are visible in
the browser screenshots. Contrast ratios computed from the colour constants (not measured on screen): body text on
panels 15.3:1 and 11.0:1 (dim text); button text 10.5:1; button border on the page 8.7:1; focus yellow on its dark
under-ring 11.8:1; ring ink on cytoplasm 13.1:1 (day) and 6.6:1 (night); organelle outlines on cytoplasm 11.6:1
and 8.9:1. Organelle fill colours alone are 3.4:1 and 2.1:1, which is why every organelle has a dark outline.
Those organelle figures are for the **placeholders**. With the supplied artwork now in use, computed from the SVG
colours: mitochondrion fill 1.0:1 and membrane 1.9 to 2.7:1 on animal cytoplasm; chloroplast fill 1.7:1 and line
2.7:1 on plant cytoplasm. Both are under 3:1; the dark loading ring around each organelle is unchanged.

There are no sliders in the game.

**Not checked:** real Chrome full screen (where the browser takes the first Escape), the real play page's handling
of the message, other browsers.

## 5. Sixty seconds without input; Pause

| Check | Result | Evidence |
|---|---|---|
| Load, wait 60 s, touch nothing | Screenshot at 1.5 s and at 61.5 s are **pixel-identical**; no `started level` line in the console | Chrome headless and visible |
| Same, in the engine | Over 3600 frames the model time stays 0, no particle moves, pump / vesicle / repair phases stay 0, nothing takes focus | Automated (Godot, headless) |
| Sound | The project has no audio files and no `AudioStreamPlayer` (test). Audio output was **not listened to**. | Automated + code |
| After Start, Pause freezes everything | With Pause open, two screenshots 4 s apart are pixel-identical; after Escape the picture changes again | Chrome headless and visible |
| Pause freezes the model | Model snapshot, maturation timers, particles and animation phases unchanged over 600 frames | Automated (Godot, headless) |
| Level 1 power test and Level 3 day/night clock stop while paused | They are fields of the same model, which is not ticked while any overlay is open (the test above). They were **not** paused individually in a browser. | Automated, by construction |
| Tutorial call-outs pause the level | Model unchanged over 300 frames with a call-out open | Automated (Godot, headless) |

## 6. What is in the `.pck`; network

Scanned `index.pck` (177,560 B) as bytes after the final export.

- `res://` paths present: `project.binary`, `icon.svg`, `scenes/Main.tscn`, `assets/vector/mitochondrion_body.svg`,
  `assets/vector/chloroplast_body.svg` (each with its imported texture), and the 15 scripts under `scripts/`
  (source remaps and compiled `.gdc`). 41 distinct paths in all.
- Count of each of these strings: `tests` 0, `shot.gd` 0, `GDD` 0, `Hosting` 0, `Visual_Assets` 0, `Handoff` 0,
  `README` 0, `CREDITS` 0, `shell.html` 0, `harness` 0, `Users` 0, the Windows user name 0, `password` 0, `secret` 0,
  `cheat` 0, `https://` 0. The only `http://` is the XML namespace inside `icon.svg`.
- No screenshots, notes or private files are in the project folder's export. Screenshots from this build were saved
  in a temp folder outside the project.
- Network: in the standalone run Chrome made 6 requests: `index.html`, `index.js`, `index.wasm`, `index.pck`,
  `index.icon.png` (all on the game's own origin) and one in-page `blob:` URL. **0 requests to any other origin.**
  (Chrome headless and visible.) The game code contains no `HTTPRequest`, no URLs, no analytics.
- `index.html` references only `index.icon.png`, `index.apple-touch-icon.png` and `index.js`.
- An unrelated installer (`HuionTabletInstall_20.0.1.123.exe`) appeared in the project folder during the build. It was
  not created by this build, is not a Godot resource, is not in the `.pck` (string count 0) and was left untouched and
  uncommitted. It should be moved out of the project folder.

## 7. Three-level balance, by level of evidence

| Level | Automated (Godot, headless) | Chrome, headless / visible | By hand |
|---|---|---|---|
| 1 | Scripted path wins on 30/30 seeds; win only after 8 s of power test; 7 mitochondria never win; timer restarts if output drops. Full win, result card and "Next level" also driven through the real scene. | Start, two call-outs, a keyboard division and a mouse division. The level was **not** played to a win in the browser. | Not done |
| 2 | Scripted path wins on 30/30 seeds; 23 never wins; ATP floor enforced; supply ceiling 44 ATP/s holds for 22, 26 and 30 mitochondria; crisis failure rule tested with fuel cut off | Boots at DPR 1.5 and starts; first call-out seen. Not played further. | Not done |
| 3 | Early chloroplast strategy wins on 30/30 seeds at the second dawn; doing nothing fails on 30/30 (stored sugar ran out); mitochondria-only fails; each scripted event fires exactly once; photosynthesis is exactly 0 at night; fail card shows the cause in the real scene | Opens from `?level=3`; boots and starts at 1180 x 360 and in the phone-like frame; first call-out seen. Not played to the end. | Not done |

## Not verified (say "not yet checked" in the registry)

- Phone, Chromebook, physical keyboard by hand, touch input.
- Any screen reader. The shell's live regions and canvas label exist and axe-core reports 0 violations for the
  shell (`tests/web/axe_check.js`: loading 0, running 0; 14 rules passed each), but axe cannot see inside the canvas
  and nobody has listened to the announcements.
- Real 200% browser zoom, real full-screen Escape, the real site, other browsers (Vivaldi, Firefox, Safari, Edge).
- A complete playthrough of any level in a browser, and any play by a student.
- Grayscale or colour-blindness viewing.
- The browser's `prefers-reduced-motion` default (the code path exists; it was not exercised).
- Saved settings in the browser (`user://` on IndexedDB): the code saves text size, ATP particles and reduced
  motion; a reload was not checked.
