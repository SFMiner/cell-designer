# Science model

What the simulation does, what it simplifies, and which numbers were chosen during the build.
The code is `scripts/simulation_model.gd`; every number is in `scripts/level_configs.gd`.

## What stays true

- Cellular respiration uses glucose and oxygen; carbon dioxide and water result; the energy released is captured in
  ATP, which powers many processes. Overall: `C6H12O6 + 6 O2 -> 6 CO2 + 6 H2O` (plus energy captured in ATP).
- Mitochondria respire whenever fuel, oxygen and demand allow, **day and night**.
- Ribosomes build proteins from amino acids using metabolic energy. Protein synthesis is not the cell's only ATP
  use: baseline maintenance and organelle upkeep are paid first, and ion pumps, vesicles and membrane repair are shown.
- Mitochondria and chloroplasts multiply by division, and new organelles cost energy and (from Level 2) protein.
- Photosynthesis needs light, and makes sugar and oxygen. Chloroplasts do **not** pay ATP into the cell's ATP
  meter; they add sugar, which mitochondria then use. The model never creates sugar it has nowhere to put.
- Extra sugar is stored as starch, in granules drawn **inside the chloroplasts** (plastids), and broken down again
  when sugar runs short. Starch supports respiration in the dark.
- Water from respiration appears briefly and fades into the surrounding fluid. It is not an inventory.

## Simplifications (deliberate)

| Simplification | Why |
|---|---|
| All quantities are model units. One "glucose portion" and one "oxygen portion" yield 8 ATP units. | Fast, readable numbers. The real yield is very different; the Help panel and the status panel say the numbers are not molecule counts. |
| An "oxygen portion" is the oxygen needed for one glucose portion, not one O2 molecule. | Keeps glucose and oxygen one-for-one on screen. |
| ATP units stand for the whole energy budget. | Real translation also uses GTP. |
| ADP and phosphate are not shown. | Left out of v0.2 by the GDD. |
| Division and maturation take 3 to 5 seconds. | Real organelles take far longer. The Help panel says so. |
| Level 1 division costs ATP only. | Tutorial simplification, stated on the Level 1 Start card. |
| Carbon dioxide and water for photosynthesis are always available; light is the only switch. | GDD: environmental CO2 and water are adequate in the first prototype. |
| Nothing is drawn to scale; particle numbers only roughly follow the stocks. | Particles are illustration, never game state. |
| No nucleus or other organelles are drawn. | Not in the asset list; only the organelles the player manages are shown. |

## The tick (fixed 0.05 s)

1. Outside supplies of glucose, oxygen and amino acids arrive into capped buffers.
2. In daylight, each chloroplast makes 1.1 glucose portions per second, limited by the room in the glucose buffer plus
   what starch can take this tick. Photosynthesis also adds the same number of oxygen portions; what the oxygen
   buffer cannot hold leaves the cell. At night the rate is exactly zero.
3. Starch: glucose above 6 portions is stored (up to 6 per second, cap 40); glucose below 2 portions is topped up
   from starch (up to 4 per second). The gap between 2 and 6 means one tick never stores and releases together.
4. Respiration: ATP made = the least of (mitochondria x 2 per second), (fuel: the smaller of glucose and oxygen, x 8)
   and (room in the ATP store + this tick's demand). So no ATP comes from no fuel, and no fuel is burned at full ATP
   beyond demand.
5. Spending: baseline, organelle upkeep and any automatic workload are paid first. Protein synthesis then uses what
   is left, scaled smoothly by `ATP reserve / 10` (capped at 1), by amino acids, and by its maximum rate.
6. Division is a single transaction: ready? enough ATP? enough protein? room? Then the exact cost is spent and the
   parent is replaced by two daughters, or nothing changes and the reason is shown.
7. Meters, checks, win and fail are read from this same state. `activity` (0 to 1) drives the speed of the
   background animations.

## Numbers taken straight from the GDD

ATP cap 60 (start 12 / 25 / 30). Glucose and oxygen caps 16. Mitochondrion 2 ATP/s, upkeep 0.30. 8 ATP per portion.
Baseline upkeep 0.5 (L1), 3 (L2, L3). Mitochondrial division 5 ATP, plus 4 proteins in L2 and L3, 1 space.
Protein synthesis up to 4/s (L2) and 2/s (L3) at 1 amino acid and 2.5 ATP each. Amino acids cap 12, supply 4/s and 2/s.
Protein pool cap 24, start 12. Chloroplast 1.1 portions/s, upkeep 0.35; division 8 ATP + 5 proteins, 2 space.
Starch cap 40, start 12. Space 16 / 30 / 18 (10 used at the start of L3). Supplies: L1 2.0 and 2.0; L2 5.5 and 5.5;
L3 oxygen 3.0. Day 30 s, night 15 s, 2 cycles. Maturation 3 to 5 s. Crisis failure after more than 7 s.
Targets: 8 mitochondria + 14 ATP/s for 8 s; 24 mitochondria + 4 proteins/s for 10 s with 12 ATP; 2 proteins/s for 8 s
in the final cycle.

## Tuning record: numbers the GDD left open, chosen in this build

| Setting | Value | Reason |
|---|---|---|
| ATP "low" line (activity starts to slow) | 10 | Gives a visible slowdown before the crisis line. |
| ATP crisis line | 3 | "Critical threshold" was not given a number. |
| Starting glucose / oxygen, L1 and L2 | 8 / 8 | Half-full buffers. |
| Starting glucose, L3 | 2.2 | With 1 chloroplast the cell uses sugar faster than it makes it, so starch breakdown, and its call-out, begin about 0.3 s into the first day, before the player can act. At 5.0 a fast player divided first and the call-out arrived at night, where its advice ("while sunlight is available") made no sense. |
| Starting amino acids, L2 and L3 | 6 | Half-full buffer. |
| Starch thresholds | store above 6, release below 2 | See step 3. |
| Starch rates | store 6/s, release 4/s | Faster than 5 chloroplasts can make sugar, and as fast as 16 mitochondria can use it, so the rates are never the hidden limit. |
| Power-test workload, L1 | 12.5 ATP/s | With 8 mitochondria total demand is 15.4 of the 16 ATP/s the supply allows: above the 14 target, below the ceiling. |
| Sustainability-check workload, L2 | 20 ATP/s | With 24 mitochondria total demand is 40.2 of the 44 ATP/s ceiling, so the ceiling is close and visible. |
| Space, L1 and L2 | hard caps at 16 and 30 | The GDD calls L2's 30 a "soft cap"; here division simply stops there ("Not enough room"). |
| Rate tolerance | 0.05 | "At least 4 per second" is met at 3.95, to absorb rounding in the 1-second average. |
| Rate meters | averaged over 1 s | Stable read-outs and checks. |
| Photosynthesis oxygen | 1 oxygen portion per glucose portion | Matches the equation's proportions. |
| Protein overflow | on | See README, "Departures from the GDD", item 1. |

No GDD number was changed. No recovery safeguard was added: none of the scripted paths found a dead end caused by
the numbers, and nothing is ever replenished invisibly.

## What the scripted runs show (30 seeds each; the seed only changes maturation times)

From `tests/balance_report.gd` on 2026-11-14:

| Strategy | Result |
|---|---|
| L1: divide every ready mitochondrion up to 8 | wins 30/30, at 16.2 to 18.1 s; lowest ATP 7.1 |
| L1: overbuild to 16 | wins 30/30, at 17.0 to 22.6 s; one brief dip under the crisis line |
| L1: do nothing | no win, no failure |
| L2: divide whenever possible up to 24 | wins 30/30 at 25.2 s; supply-limit lesson at 13.2 s; check starts 15.2 s |
| L2: do nothing | no win, no failure; ATP settles near 7 with synthesis throttled |
| L3: never divide a chloroplast | fails 30/30 at 44.7 s, "stored sugar ran out"; crisis from 37.7 s (first night) |
| L3: 2 chloroplasts | wins 30/30 at 90 s |
| L3: 3, 4 or 5 chloroplasts | wins 30/30 at 90 s |
| L3: mitochondria only, up to 16 | fails 30/30 at 33.9 s |
| L3: 3 chloroplasts, then fill with mitochondria | wins 30/30 |
| L3: mitochondria to 12 first, then chloroplasts | wins 30/30; lowest ATP 15.5 |

Read these as "the model behaves this way under these scripts", not as a measure of how hard students will find it.
