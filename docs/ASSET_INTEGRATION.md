# Replacing the placeholder art

Placeholder art is drawn in code by `scripts/placeholder_art.gd` (cells, organelles, molecule glyphs, icons).
Nothing waits for artwork.

**In use now:** `mitochondrion_body.svg` and `chloroplast_body.svg`, supplied on 2026-11-14 while the build was
running. Both imported cleanly in Godot 4.7.2 (CSS classes, gradients and paths all rendered) and were checked in
Chrome. **No other swap has been tried.**

## How it works

For each asset name below, the game looks for `res://assets/vector/<name>.svg`, then `<name>.png`. If one exists it
is drawn in place of the placeholder: centred on the same point, scaled to fit the same space, with the same rotation.
If none exists the placeholder is drawn. Nothing else needs to change. The two organelles also accept the shorter
names `mitochondrion.svg` and `chloroplast.svg`.

**Set the import scale.** Godot turns an SVG into a bitmap at its artboard size, so a 90 px artboard is blurry on a
sharp screen. In the Import dock set **SVG > Scale** to 4 and turn **Mipmaps > Generate** on, then Reimport. (For the
two files above this is already set in their `.import` files; deleting an `.import` file resets it to 1.)

An art swap cannot change:

- **Hit areas.** An organelle's clickable area is its button rectangle (at least 44 CSS px), set by the layout.
- **Loading rings, focus rings, highlights, meter fills.** Always drawn in code, around the art.
- **The simulation.** `simulation_model.gd` never looks at art or particles.

Export: SVG and PNG are Godot resources, so they are picked up by the "all resources" export without touching the
preset. After adding art, re-export and check it in a browser.

## Names and boxes

Keep the artwork centred in its artboard with a transparent background. Do not draw loading rings or shadows.

| File name (in `assets/vector/`) | Replaces | Fitted to | Notes |
|---|---|---|---|
| `mitochondrion_body` | mitochondrion | the whole artboard inside a circle of radius 0.43 x the slot spacing (just inside the loading ring) | Any angle works; the game also turns each one a little. Crop the artboard tightly: empty margin makes the organelle smaller. |
| `chloroplast_body` | chloroplast | the same circle | Starch granules are drawn on top, below the centre line. |
| `animal_cell_outline` | animal cell (Levels 1, 2) | the whole 1000 x 560 cell box | The cytoplasm must cover an ellipse centred in the box with radii 486 x 266 (of 1000 x 560), because organelles are placed inside that ellipse. |
| `plant_cell_outline` | plant cell wall, membrane and cytoplasm (Level 3) | the whole 1000 x 560 box | Cytoplasm must cover the rectangle from (34, 30) to (966, 530). |
| `plant_vacuole` | central vacuole | a 410 x 176 box centred in the cell | Organelles are kept out of an ellipse of that size, so the art should fill it and not much more. |
| `ribosome` | ribosome | about 27 x 27 cell units | The growing protein chain is drawn in code beside it. |
| `mol_glucose`, `mol_oxygen`, `mol_carbon_dioxide`, `mol_water`, `mol_amino_acid`, `mol_protein`, `mol_atp` | molecule glyphs (cytoplasm, status panel icons, Help legend) | a small square, about 12 to 22 px on screen | Drawn at about 34% opacity in the cytoplasm. Keep them distinct by **shape**. The O2 / CO2 / H2O text labels are added in code. |
| `starch_granule_small` | starch granules inside chloroplasts, and the starch icon | a small square | The game scales it with the reserve. |
| `ion_pump`, `transport_vesicle`, `membrane_repair_patch` | background activity | about 24 to 44 cell units | The moving ion and the pump's timing stay in code. |
| `sun_icon`, `moon_icon` | day / night pictograms | about 20 px | |

From the asset checklist but **not wired yet** (no lookup exists; add one in `placeholder_art.gd` if wanted):
`protein_chain` (the emerging chain at the ribosome is drawn in code), `starch_granule_large` (the small one is
scaled), `plant_thylakoid_detail`, `resource_delivery_arrow`, and extra variants of `mol_amino_acid` / `mol_protein`.

## Limits to know about

- The night tint is applied to the placeholder cytoplasm in code. A replacement cell outline is drawn as supplied,
  so it will **not** darken at night; the sun / moon pictograms and the word "Day" / "Night" still show the phase.
- Tutorial dimming multiplies the art's opacity, so it works with replacement art.
- The constricting "neck" of the fission animation is drawn only for placeholders. With replacement art the two
  daughters slide apart without it.
- **Contrast is the art's job.** The current mitochondrion is yellow on cream cytoplasm (about 1:1 for the fill).
  A darker outline in the artwork, around 3:1 or better against `#f5e6c7` (animal) and `#e0f0c7` (plant), would fix it.
- Organelle art is sized from the slot spacing, which differs by level (128, 100 and 108 cell units in Levels 1, 2 and 3), so the
  same file is drawn at different sizes. Keep interior detail readable at about 45 px wide.
- Private source files (`.ai`) do not belong in this folder: an "all resources" export can ship stray files or their names.

## Checklist after dropping art in

1. Run the editor scan and the four test suites (README, "Tests"). They do not depend on art.
2. Run the game at 1180 x 500 and at 1180 x 360; check rings, focus rings and starch granules still read.
3. Re-export, then look at it in Chrome (README, "Export and browser check").
4. Add the artist and licence to `CREDITS.md`.
