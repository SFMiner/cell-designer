# Cell Designer: Power & Growth
## Game Design Document — v0.2 | Agent-ready implementation and sims-site hosting specification

**Audience:** Grade 7 science (Amplify Metabolism unit; students have already studied the basics of cell structures).  
**Engine:** Godot 4.7.x, GDScript, 2D, single-threaded web export for school Chromebooks; GL Compatibility renderer preferred.  
**Format:** Three short, sequential scenarios in one game.  
**Design goal:** Let students *experience* the relationship between cellular respiration, ATP availability, protein production, and, later, photosynthesis and carbohydrate storage. This is a game about managing a living cell, not a drag-and-drop organelle identification exercise.

> **Directive for the building agent:** This document integrates the site-hosting requirements supplied 2026-11-14. **[SITE SPEC]** rules are mandatory; **[IMPLEMENTATION ADVICE]** items are strongly recommended and must be documented if bypassed. Build the complete playable three-level MVP in one pass. Do not block on artwork: use attractive vector-like procedural placeholders with the stable asset filenames specified in the separate asset manifest, so the creator can replace them later with Illustrator artwork. Prioritize a functional, scientifically faithful causal simulation, readable visual feedback, tested victory/failure rules, and a Chromebook-friendly web export. Do not introduce a fourth level or extraneous systems.

---

## 1. Player experience and core rules

The player sees a stylized cutaway of a **single cell**, with its mitochondria and, in Level 3, chloroplasts. The player **clicks/taps a ready organelle to make it divide**. They do **not** drag in organelles, build proteins by hand, move glucose molecules, store starch manually, or control individual metabolic reactions. Supplies enter and products leave automatically.

Mitochondria carry out aerobic cellular respiration, using glucose-derived fuel and oxygen to support ATP production. Carbon dioxide travels toward and exits the cell; water produced by respiration appears briefly, then blends into body/cellular fluids (no water storage minigame). In Levels 2–3, amino acids enter and ribosomes animate protein synthesis. Protein synthesis consumes energy; protein products form a capped construction pool. When ATP becomes scarce, protein synthesis and background cellular activity visibly slow.

In Level 3, chloroplasts use light, carbon dioxide, and water to produce sugars and release oxygen. Excess sugar is **automatically** converted to a finite starch reserve; the reserve is **automatically** broken down when sugar is needed. The student chooses how to divide resources between organelle populations. Both organelle types consume ATP and, when enabled, proteins to grow, have maintenance costs, occupy finite room, and take time to become ready to divide again.

**Only strategic action:** clicking/tapping *ready* mitochondria or chloroplasts to initiate fission. Secondary UI controls: Start (required before motion begins), Pause, Restart, Next Level, Help, Settings, optional Show/Hide ATP Molecules. Keep the top-right site-overlay zone clear of controls. No gathering clicks, recipe assembly, manual storage, or construction placement.

**Success by experimentation, not quizzes.** Short contextual pop-ups introduce new features; no text answer is required to progress.

### Default session length

- Level 1: about 1–3 minutes, tutorial.
- Level 2: about 3–5 minutes, build-and-balance challenge.
- Level 3: about 3–5 minutes, two accelerated day/night cycles.

These are *design targets*, not promises of runtime. Never force a player to wait for a fixed class-period timer; add speed-up (1×/2×) if needed after core testing. **Do not begin simulation or decorative animation until Start is activated.**

---

## 2. Three-level progression

### Level 1 — **Power Up** (tutorial: cellular respiration)

**Start:** animal cell, **one mitochondrion**, flowing glucose and oxygen, enough initial ATP to begin fission. **No protein synthesis and no protein requirement for division** in this tutorial (explicitly a temporary educational simplification). New mitochondria require ATP and maturation time only; space is generous and does not gate play.

**Player's task:** grow the population **1 → 2 → 4 → 8** and demonstrate that the cell can sustain a target ATP production rate. The player may divide individual ready mitochondria in any order; the 1→2→4→8 path is the intended quick route, not a forced script.

**Tutorial beats:**
1. Highlight incoming glucose and oxygen. Animate one mitochondrion producing ATP and releasing CO₂ and H₂O. Text: “Mitochondria use glucose and oxygen during cellular respiration to supply ATP.”
2. Highlight the ready mitochondrion and prompt “Click a mitochondrion to divide it.” The action costs ATP.
3. Daughter mitochondria show a **filling circular loading ring** for 3–5 seconds; when full they may divide.
4. Show increasing ATP production *capacity* as the population grows. When there are 8 mitochondria, automatically initiate a brief **cellular-workload power test**, so the simulator has enough ATP demand to measure actual production rather than artificially consuming glucose when the ATP reserve is already full.
5. Win if **8+ mitochondria** and actual ATP generation **≥14 normalized units/s for 8 consecutive seconds during the power test** without an ATP crisis. Label the meter “ATP/s” with a short note that model units are not molecular counts.

**Opening example text:** “Your cell needs more ATP. Help it increase its ability to carry out cellular respiration.”

**No protein or chloroplast controls.** Glucose and oxygen supplies are fixed and finite-rate, not infinite.

### Level 2 — **Grow and Build** (ATP powers protein synthesis)

**Start:** animal cell, **six mitochondria**, ATP reserve, amino-acid delivery, ribosomes synthesizing proteins. Begin with a small stock of available construction proteins. The cell already has a defined protein synthesis pipeline; the student does not assemble amino acids.

**Player's task:** reach **24 mitochondria (4× the starting population)**, maintain enough ATP for protein synthesis, and pass a short sustained-production check.

**New rules:**
- Mitochondrial fission costs **ATP + construction proteins + time**.
- Ribosomes automatically assemble proteins from incoming amino acids, using ATP-equivalent energy. If ATP is low, synthesis slows; if the protein pool is full, assembly pauses until capacity opens.
- Glucose and oxygen enter at fixed *limited rates*. Once mitochondria can process the available supplies as fast as they arrive, adding more gives diminishing ATP returns, but still costs resources and maintenance.
- Brief automated ion-pump/vesicle/membrane-repair animations also slow when ATP is scarce. They are not separate player tasks.

**Win:** 24+ mitochondria; protein production **≥4 normalized protein units/s for 10 consecutive seconds**, ATP reserve **≥12 units** at the end, and no energy crisis. A brief “sustainability check” begins automatically on reaching the count; it should visibly show ATP production and demand, including an automatic temporary cell-workload demand if required for the respiration meter to register useful output.

**Important design tension:** Do not set resource inputs so low that reaching 24 is self-defeating. The supply ceiling should become visibly important near the target or if the player overbuilds beyond it. The game must not teach “more mitochondria always means more ATP.”

### Level 3 — **Through the Night** (plant cell: photosynthesis and storage)

**Start:** plant cell, **8 mitochondria**, **1 chloroplast**, a **small initial starch reserve**, a small construction-protein reserve, ATP reserve, and automatic protein synthesis. All Level 2 costs apply. The plant cell has a visibly finite organelle-space budget.

**Player's task:** manage mitochondria and chloroplast division so that the cell remains active through **two complete accelerated day/night cycles**, sustains useful protein synthesis, and avoids an extended ATP crisis.

**New rules:**
- Light cycles automatically: **30 s day / 15 s night** at 1×; show a clear sun/moon indicator and phase countdown.
- Chloroplasts photosynthesize only in light; more chloroplasts raise daytime sugar-production capacity, subject to available inputs and space.
- Surplus sugar is converted automatically to starch, up to a finite **starch storage cap**. When immediate sugar supply falls short, starch is broken down automatically to release fuel. Starch is represented as granules associated with plastids, not literal free-floating glucose chains all over the cytoplasm.
- Chloroplast fission, like mitochondrial fission, consumes ATP, construction proteins, space, and 3–5 s maturation time. Use the same loading-ring affordance.
- Both organelle types have ongoing ATP maintenance costs and occupy space. Adding mitochondria can increase respiration capacity but also raises glucose demand and maintenance. Adding chloroplasts can improve daylight sugar supply but is costly and cannot perform photosynthesis in darkness.

**Scripted discoverable event:** **As soon as the first unit/granule of stored starch is broken down**, pause once and show a short pop-up while the starch granules gain a thick temporary outline / pulse (not color alone):

> “Your cell is using stored starch to release sugar. This reserve will run out. Divide chloroplasts to make more sugar while sunlight is available!”

Then resume play. The starch reserve should be small enough, and the initial chloroplast population low enough, that this event normally occurs early in the **first day**, not only after darkness has already made recovery impossible.

**Second contextual event (first storage of surplus sugar):** show a single brief pop-up emphasizing newly growing starch granules: “Extra sugar is being stored as starch. The cell can use it when there is no sunlight.” On first night, optionally a one-line nonblocking banner: “No light: chloroplasts stop making sugar. Stored starch can still fuel respiration.”

**Win:** survive 2 day/night cycles (success at the second dawn), keep ATP above crisis threshold for the required interval, and reach **≥2 protein units/s for a sustained 8 s** at some point during the final cycle. No mandatory exact chloroplast/mitochondrion count; make sustainable balance, not rote counting, the winning strategy.

**Failure:** ATP below the critical threshold for **more than 7 consecutive seconds**, or inability to sustain required activity by the end of the second cycle. Provide a replay action and clear cause (“Stored sugar ran out; ATP production fell”). Do not immediately end the game the moment ATP briefly dips.

---

## 3. Resource model: deterministic, bounded, and simplified

All figures below are **tunable starting values**, not empirical cellular rates or molecule counts. Expose them in `.tres` resources or one small config script with per-level overrides. **The agent must tune and test until all three levels have demonstrable winning paths and meaningful failure paths.** Do not silently alter the pedagogical rules to get the numbers to work.

| Concept | Model value / behavior |
|---|---|
| Time step | Fixed 0.05–0.1 s simulation tick independent of rendering. Rates scale with `dt`; Pause freezes all simulation timers and animations. |
| ATP reserve | Capacity **60 ATP units**; Level 1 start 12, Level 2 start 25, Level 3 start 30. |
| Glucose fuel | One normalized glucose portion; cap **16** immediately available portions. May be supplied externally (L1–2) or made by chloroplasts / released from starch (L3). |
| Oxygen supply | One normalized oxygen *respiration-equivalent portion* pairs with one glucose portion (represents the oxygen needed to use it, **not one O₂ molecule**); cap 16. |
| Mitochondrion | Maximum **2 ATP units/s** if glucose, oxygen, and demand allow; maintenance **0.30 ATP/s** each. |
| Cellular respiration | Each **8 ATP model units** consumes 1 glucose portion plus 1 oxygen-equivalent portion. Actual ATP synthesis is demand-limited when the ATP store is full; do not waste fuel at full ATP. |
| General maintenance | L1 **0.5 ATP/s**; L2/L3 **3 ATP/s**. Background activities draw from this and respond visually to shortage. |
| Mitochondrial division | **5 ATP** and **3–5 s maturation**; **+1 mitochondrial space**. In L2–3, additionally **4 construction-protein units**. In L1, protein cost is disabled. |
| Protein synthesis | L2 target maximum **4 protein units/s**; L3 **2/s**, requiring 1 amino-acid unit and **2.5 ATP units** per protein unit (an ATP-*equivalent* simplification; real translation also uses GTP). Automatically throttles with ATP/amino-acid availability or full protein store. |
| Amino acids | Delivered automatically, capped at 12 immediately available units; supply L2 **4/s**, L3 **2/s**. |
| Construction-protein reserve | Capped at **24 units**. Start L2 **12**, start L3 **12**. Protein stock is for construction/maintenance, not every protein in the real cell. |
| Chloroplast | Daytime sugar production **1.1 glucose portions/s** per chloroplast under adequate light, CO₂, water; maintenance **0.35 ATP/s** each, powered from cell's ATP pool. |
| Chloroplast division | **8 ATP + 5 construction proteins**, adds **2 space units**, daughters mature 3–5 s. |
| Starch storage | L3 max **40 glucose-equivalent portions**; start **12**. Convert surplus glucose to starch automatically; release starch automatically to cover sugar deficit. Storage and release can be rate-limited gently for visuals but must not make the tutorial impossible. |
| Space | L1 roomy (e.g. 16, not shown as challenge); L2 30 (soft cap); L3 hard cap **18 space units**. Mitochondrion = 1; chloroplast = 2. Start L3 uses 10 of 18. |
| Fixed L1 supply | Glucose **2.0 portions/s**, oxygen **2.0 portions/s**. Saturated respiratory production ≈16 ATP/s. |
| Fixed L2 supply | Glucose **5.5 portions/s**, oxygen **5.5 portions/s**. Saturated respiratory production ≈44 ATP/s; around 22 mitochondria the supply ceiling becomes relevant. |
| L3 oxygen | External O₂ diffusion sufficient for the starting population (e.g. **3 oxygen-equivalent portions/s**). Show daytime O₂ released from photosynthesis; extra available O₂ may leave the cell. |
| L3 CO₂, water and light | Environmental CO₂ and water adequate for the first prototype. Respiration produces CO₂ and water; photosynthesis consumes CO₂ and water. Water mixes with fluids; CO₂ can be recycled or leave. Light on/off is the only explicit photosynthesis constraint for v0.1. |

### Per-tick algorithm (authoritative gameplay state, not particles)

1. Add externally delivered glucose, oxygen, amino acids, and available CO₂/water into capped buffers as appropriate.
2. During daylight, chloroplasts make glucose, subject to resource buffers and available storage. Animate O₂ being released. During darkness, chloroplast photosynthesis rate is **zero**, not negative.
3. Move **surplus** glucose into the starch reserve when there is room. On an immediate glucose deficit, **automatically** break down starch to top up the usable glucose buffer. Ensure the order does not spuriously store and immediately retrieve the same portion in a single tick.
4. Calculate potential ATP generation based on mitochondrial count and available glucose/O₂. **Actual production** is limited by available fuel and by ATP storage room plus expected ATP demand this tick. Do not generate ATP from no fuel; do not consume extra fuel when ATP is full.
5. Spend ATP on baseline and organelle maintenance. Protein synthesis uses the remaining ATP and amino acids, contributing to the capped construction pool. If ATP is insufficient, scale protein synthesis continuously rather than abruptly teleporting proteins in or out.
6. A division click is **transactional**: check organelle maturity, ATP, construction proteins (if enabled), and space; then spend exact costs once, replace the parent with two daughters, start each daughter's individual cooldown; if unavailable, leave all resources unchanged and show a clear brief reason.
7. Derive the rate meters, counts, win/fail conditions, and animation pacing from this same state. Never derive game logic from sprite particle counts.

**Important numerical distinction:** These unit conversions are intentionally scaled for fast gameplay. The chemically correct overall respiration relationship is glucose + oxygen → carbon dioxide + water, releasing energy used to make ATP. Do not present `8 ATP` as the actual biochemical ATP yield of one glucose molecule. In science notes, the balanced net equation is `C₆H₁₂O₆ + 6 O₂ → 6 CO₂ + 6 H₂O` (plus energy captured in ATP). The energy carriers ADP and phosphate may be omitted visually in v0.1.

### Resource shortages and priority

- A low ATP reserve causes protein synthesis, ion pumps, cargo movement, membrane repair, and organelle-growth animations to slow progressively; the cell should look less active, not simply show a falling number.
- Maintenance and basic survival demand are funded before optional synthesis; division is attempted only when its full up-front costs are present.
- Reserve levels cannot be negative or exceed their caps. UI bars clamp to capacity.
- Mitochondria always carry out respiration *when substrates and ATP demand allow*, including at night. Chloroplasts do not carry out photosynthesis at night.
- Do not confuse chloroplast-internal ATP made by light reactions with ATP available to the rest of the cell. **Photosynthesis adds sugar** to the cell-level economy; mitochondria support the modeled general-use ATP pool.

### Tuning and soft-lock prevention

- A patient player with sensible division choices must be able to win **all three** levels using only normal input, without cheats.
- Level 3 starting conditions are intentionally unsustainable without expanding chloroplast capacity: one chloroplast makes less sugar per second than the initial eight mitochondria could use at full output, triggering early automatic starch breakdown and the teaching pop-up. Dividing to at least ~3 chloroplasts early should give a reliable path to surviving nights if the player does not overspend on mitochondria.
- Provide a small recovery safeguard if an ATP shortage would otherwise create an irreversible dead end due solely to a numerical tuning oversight: e.g. retain minimal background respiration and enough initial protein for early chloroplast fission. **Do not** replenish glucose/starch invisibly or grant free organelles.
- Display reason for blocked divisions: “Need 5 ATP,” “Need 4 proteins,” “Not ready,” or “Not enough room.” No silent clicks.

---

## 4. Division / readiness interaction

- Clicking a mature organelle begins one brief **elongate → constrict → separate** fission animation.
- The parent becomes two daughters; each daughter displays a **standard circular loading ring**, initially empty and then filling clockwise over a randomized **3–5 s** cooldown (seeded if deterministic tests are running).
- **Ready:** solid full ring, no pulsing necessary, clickable. **Maturing:** incomplete filling ring; not clickable yet. **Dividing:** temporary animated shape/ring transition.
- Immature click: subtle bump/shake and small clock pictogram; no deduction of ATP/proteins. Ready/blocked status may not be signaled by color alone.
- Reduced Motion: keep static discrete-step filling rings and no shaking. Make hit targets larger than the decorative organelle artwork.
- When fission completes, daughters spawn in unoccupied positions near the parent using deterministic packing/repositioning that respects cell boundary. Space failure must be detected *before* deducting resources. Plant chloroplasts should remain inside the stylized cytoplasm, not overlap the wall or vacuole.
- Cooldown affects **ability to divide again**, not ATP production/photosynthesis or maintenance. Daughter organelles continue normal function while the ring fills.

---

## 5. Visual design and feedback

### Main screen layout

- **Central 65–75%:** living cell cutaway. Animal-cell outline in L1–2; plant cell wall/membrane, vacuole and visible plastids in L3. Organelle shapes are large, clickable, deliberately not drawn at molecular scale.
- **Top/status HUD:** goal (“8 mitochondria + ATP power test”; “24 mitochondria + protein production”; “Survive 2 cycles”), compact progress indicator, pause/reset/settings.
- **Side/bottom HUD:** labeled bars and numbers for ATP reserve, available glucose, oxygen, construction proteins (L2–3), starch (L3), and cell space (L3). Show mitochondrial/chloroplast counts and ATP output/demand rates. Hide irrelevant bars in earlier levels.
- **Day/night strip (L3):** sun/moon pictogram, progress sweep and “Day 1/2” / “Night 1/2”. Do not use background color alone to convey light state.
- **Tutorial callouts:** short (1–3 sentences), with pause/resume as required, dismiss with a large button or keyboard. Anchored to actual items without covering the cell. Initial message can be dismissed immediately.

### Background molecular visualization

These are **illustrative count-correlated particles**, not literal molecular concentrations or physical scale. Use quiet 20–35% opacity and slow drift below the interactive organelles. Show/hide or visually emphasize a type by tutorial event.

| Resource/effect | Representation | Behavior |
|---|---|---|
| Glucose | Small hexagonal-ring glyphs | Drift into cytoplasm or out of chloroplast; number tracks current glucose stock approximately. |
| Oxygen | Tiny labeled `O₂` paired-circle glyphs | Enter from cell boundary; move toward mitochondria. |
| Carbon dioxide | Distinct labeled `CO₂` three-circle glyphs | Produced near mitochondria; move out or toward photosynthesis. |
| Water | Tiny `H₂O` bent-triad glyphs | Emerge briefly during respiration, then fade/mix into surrounding fluids. |
| Amino acids | Small, distinct polygon/chain glyphs | Enter cell and approach ribosome animation in L2–3. |
| Proteins | Larger simple folded/squiggle glyphs | Appear at ribosome and join the bounded construction pool visualization; depleted during fission. |
| Starch | Clustered branching icons / granules associated with chloroplasts or plastids | Granules grow with storage, visibly shrink as reserve is consumed; initial breakdown and first storage are highlighted. |
| ATP (experimental) | Tiny distinct 3-part glyphs | Optional low-contrast particles, count tied to ATP reserve; can be disabled independently without affecting game rules. |

**ATP visualization policy:** Implement both variants **now**. Default **ON** for first classroom evaluation. Provide Settings → “Show ATP particles” toggle, while ATP bar and movement slowdown remain present whether particles are visible or not. Later the creator can decide which reads better.

**Accessibility:** differentiate resource glyphs by geometry and labels, not just hue; clear silhouette and grayscale functionality; reduced-motion mode; visible keyboard focus; avoid flashing; use high-contrast HUD text over muted cytoplasm; all actions accessible via mouse, touch, keyboard (Tab to organelles, Enter/Space to divide, Escape closes the innermost overlay and then leaves the game); support Tab/Shift+Tab exit from the embedded host and a larger-text setting. See §8 for mandatory details.

### Tutorial highlighting

When a resource is introduced, temporarily dim unrelated scenery, give the relevant glyphs a bold white/dark outline (choose contrast automatically), and point to the corresponding HUD meter. **Never rely on a color-only flash.** The starch tutorial additionally highlights the actual plastid/starch granule.

### Background ATP-dependent activities

Animate several automatically, without new controls: membrane ion pump pulses, vesicles transporting cargo, slow repair/shape maintenance, ribosomes (L2–3). Their speed should respond to the actual ATP availability factor. These are *representations* of ATP use; costs are included in general maintenance or protein synthesis, not separate hidden failure rules.

---

## 6. Educational accuracy and simplifications

**Keep these statements true in text and animation:**

- Cellular respiration uses glucose-derived fuel and oxygen; carbon dioxide and water result; ATP powers diverse processes.
- Protein synthesis uses amino acids and metabolic energy; ribosomes assemble the proteins. In this model, ATP units stand for the broader energy budget, including processes that in reality use GTP.
- Mitochondria multiply by fission after growth; chloroplasts are plastids that also divide. New organelles need cellular proteins and energy, except in **Level 1's explicitly simplified tutorial**.
- Photosynthesis uses light, carbon dioxide, and water; it produces sugars and oxygen. Chloroplast light reactions produce ATP for their own photosynthetic processes, **not a direct general-purpose ATP payout into the cell's mitochondrial ATP meter**.
- Plant cells also respire day and night. Stored **starch**, a polymer of glucose, can support respiration when light is absent. Most plant starch is stored in plastids, so the art should place granules inside/associated with plastids rather than imply every granule floats freely in cytoplasm.
- Biological structures are not drawn to true relative scale. Displayed particle counts and accelerated 3–5 s fission are teaching/game abstractions; **do not imply real organelles divide in seconds**.

**Avoid:** claiming protein synthesis is the cell's only ATP use; having chloroplasts create ATP for all the cell's needs; showing glucose matter created from sunlight alone; treating water as vanishing from existence; turning ATP particles into authoritative exact molecules; suggesting unlimited substrate throughput or immediate organelle multiplication.

---

## 7. Architecture and delivery requirements

### Recommended Godot project structure

```text
cell-designer/
  project.godot
  README.md
  docs/SCIENCE_MODEL.md
  docs/ASSET_INTEGRATION.md
  scenes/Main.tscn
  scenes/cell_view.tscn
  scenes/hud.tscn
  scenes/tutorial_overlay.tscn
  scripts/game_controller.gd
  scripts/simulation_model.gd     # sole authoritative resource state
  scripts/level_configs.gd        # named per-level constants/resources
  scripts/organelle.gd            # type, fission, cooldown, hit area
  scripts/organelle_layout.gd     # collision-aware auto-placement
  scripts/cell_view.gd
  scripts/molecule_visuals.gd     # cosmetic only, seeded, bounded count
  scripts/hud.gd
  scripts/tutorials.gd
  scripts/settings.gd
  scripts/ui/keyboard_exit.gd   # focus boundary / Escape -> site host
  docs/HOSTING_VERIFICATION.md
  CREDITS.md
  assets/vector/                  # Illustrator SVG drop-in source targets
  assets/placeholder/             # procedural placeholder if no SVG exists
  tests/test_resource_model.gd
  tests/test_fission.gd
  tests/test_progression.gd
  tests/test_web_sanity.gd
  export_presets.cfg
```

Exact filenames may vary if the delivered README accurately documents them. Prefer small modular scripts and data-driven level configs. No C#, paid plugins, cloud backend, accounts, telemetry, or external runtime requests. Web export must run offline from a normal static host once loaded.

### Assets workflow

- Until final Illustrator graphics exist, draw organelles and particles using `draw_*()`/`Polygon2D`/simple local SVGs. **Never block gameplay waiting for art.**
- Art replacement must not alter hitboxes, simulation or resource totals. Use transparent backgrounds and stable anchor/origin coordinates; keep loading rings and meter fills drawn procedurally in Godot (not baked into art).
- Vector asset checklist: **`Cell_Designer_Visual_Assets_v0.1.md`** in same delivery.
- Visual particle populations are capped and pooled; FPS should remain smooth on school Chromebooks. At most ~100 cosmetic particles on screen as a first-pass guideline, configurable.

### Build acceptance / tests

1. Project loads in Godot 4.7.x with no parser errors; exports with **no threads** and runs in real Chrome, both standalone and in a same-origin iframe. Primary iframe target: **1180×500 CSS px**; also test 360 px height, device pixel ratio 1.5 and 200% zoom. No `SCRIPT ERROR` and a `cell-designer: boot ok` console line from `_ready`. The prior 1366×768 figure describes a browser window, **not** the site frame.
2. Controls work for mouse, touch and keyboard. **Tab past last / Shift+Tab before first / Escape with no open overlay** release focus and send `sims:leave-game` to a same-origin parent. Escape with an overlay open closes only that overlay. Pause freezes all resource and organelle maturation timers. Restart resets *all* level state, events and resource buffers. No auto-play before explicit Start.
3. **L1:** starts with exactly 1 mitochondrion, no protein synthesis, uses ATP-only division, reaches 8 via successive clicks, and wins only following the sustained ATP power test.
4. **L2:** starts with exactly 6 mitochondria and real automated protein synthesis; fission fails cleanly without sufficient ATP/protein; a scripted legal path reaches 24 and passes sustainable protein output. Excess mitochondria eventually show diminished incremental ATP production due to substrate delivery limits.
5. **L3:** starts with 8 mitochondria, 1 chloroplast, starch=12/40 and protein=12/24; first starch breakdown triggers exactly one tutorial highlight and popup; first surplus storage triggers its own one-time highlight; no chloroplast creates sugar at night; a legal early chloroplast-investment strategy wins two cycles; doing nothing causes a visible night energy shortage/failure.
6. Resource quantities stay ≥0 and ≤caps; blocked clicks never spend resources; organelles never overlap the cell boundary or become unclickable due to decorative particles; all cooldown rings complete and turn actionable.
7. Carbon dioxide and water product animations appear during active respiration; water fades into fluid without accumulating as gameplay inventory. Glucose, O₂, amino-acid and protein visuals respond to their underlying states.
8. Protein synthesis, ion pumps and background transport visibly slow in controlled ATP-shortage tests. Hiding ATP particles changes **only drawing** and leaves all outcomes identical.
9. Reduced Motion disables pulsing/shaking yet preserves readable cooldown progress and tutorial highlights. HUD labels and click states work in grayscale.
10. Add automated headless tests for resource conservation/bounds, paused ticks, fission cost transactions, per-level win/fail logic, night photosynthesis zero, reserve depletion/replenishment, event-once behavior, and rendering smoke test if feasible.
11. README includes how to run in editor and web, where to replace assets, known approximations, exact test commands, class-setting query parameters, verified/not-yet-verified accessibility and device checks, chosen web export template and version, credits, and site registry handoff details. Keep a plain-text list of any features not completed instead of silently omitting them.

### Suggested scripted balancing test paths

- **L1:** click the first organelle; click each ready daughter until count 8. Auto-trigger power test. Should win without artificial resource injection.
- **L2:** divide whenever resources, maturity, and space allow while protein synthesis runs; reach 24 and hold the objective state. Test an overbuilt sandbox case to verify output saturates against glucose/O₂ delivery.
- **L3 success:** immediately divide the starting chloroplast; when daughters become ready, divide at least one again to reach ~3 chloroplasts early. Preserve the mitochondrial population while starch replenishes in sunlight. Should survive two complete cycles.
- **L3 failure:** never divide a chloroplast. The reserve should be depleted and ATP-dependent activities slow, with a clear crisis before or during the night.

If those tests fail, adjust exposed model rates or caps and record the changes in README; do not fake pass criteria.

---

## 8. sims.mr-miner.com hosting and publication contract

This section incorporates **`Sims_Site_Hosting_Requirements.md` (2026-11-14)** directly into the implementation specification. It is not a request for the building agent to independently interpret a second document. Labels preserve the source's distinction: **[SITE SPEC]** means binding site requirements, and **[IMPLEMENTATION ADVICE]** means a proven recommendation rather than a site rule. If a substantive conflict survives this revision, report it rather than silently substituting a behavior.

### 8.1 Embed, navigation and responsive layout

- **[SITE SPEC]** Ship a **static web export** with `index.html` at the export root and a folder-safe slug `cell-designer` (letters, digits, `_` and `-`). The hosting service will expose it at `/g/cell-designer/`, run it inside a **same-origin iframe** at `/play/<slug>`, and also offer it standalone in a new tab. Both modes must work.
- **[SITE SPEC]** Leave the **top-right** corner available for the host's overlaid Full screen button. **[IMPLEMENTATION ADVICE]** Reserve roughly **200 × 64 CSS px** there. Put Pause, Settings, audio, Help, etc. elsewhere.
- **[IMPLEMENTATION ADVICE]** Design first for an iframe around **1180 × 500 CSS px**; verify at **360 px frame height**, desktop high-DPI / **device pixel ratio 1.5**, and **200% browser zoom**. The cell viewport may shrink or pan while control labels remain readable. The **1366 × 768 browser window** is not a valid proxy for the host frame. Include a larger-text control.
- **[IMPLEMENTATION ADVICE]** Use `stretch/aspect = expand`, not `keep`, so resize signaling and responsive layout work. Set content scaling so UI text stays at least ~**0.85 CSS px per base pixel**. Keep `display/window/dpi/allow_hidpi` enabled; verify responsive reflow when size changes.
- **Site environment (informational):** Server currently sends `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Cache-Control: no-cache`; `.wasm` is served as `application/wasm`. The hosting site generates `.gz` copies, so the builder should **not** add a separate compression step or require new cross-origin-isolation headers. No CSP is presently set.

### 8.2 Engine, browser export and build hygiene

- **[SITE SPEC]** Godot **4.7.x**, **GDScript**, **no threads**: `thread_support=false`. Do not introduce features requiring COOP/COEP cross-origin isolation or a different site configuration.
- **[IMPLEMENTATION ADVICE]** Prefer **GL Compatibility**. Use `scenes/Main.tscn` with capital `M` as the main scene. Retain HiDPI. For lean exports, run `python ..\..\godot-2d-web-template\check_web_template.py <project>` with the correct local relative path, verify the template supports Godot 4.7, select 2D or 2D + GUI, **disable Export With Debug**, and point the export preset to that template. If a lean template is unavailable or incompatible, document the limitation and choose a working web template instead of producing a broken build.
- **[IMPLEMENTATION ADVICE]** The lean **2D-only** template lacks `OptionButton`, `MenuButton`, `RichTextLabel`, dialogs, `RegEx`, and likely `Crypto`. Use simple `Button` cycling where needed. Avoid deprecated `Color8`, `convert`, `inst_to_dict` and `Image.create`; use `Image.create_empty` where appropriate. Avoid emoji text (draw icons), NUL-string sentinels (`"\u0000"`), and other APIs unsupported by the chosen template. **Desktop parser success alone does not prove browser success.**
- **[IMPLEMENTATION ADVICE]** Keep screenshots, private notes, configuration secrets, and development files **outside the Godot project folder**, not merely filtered by `exclude_filter`: names may remain visible in the `.pck`. Explicitly include runtime `.json`, `.csv`, and `.txt` via `include_filter` if the game loads them. Scan the final `.pck` contents/names.
- **[SITE SPEC]** Produce a root-level `index.html` in the export. **Owner's export convention:** `C:\Users\seanm\Nextcloud2\Gamedev\GodotGames\exports\cell-designer\` (use if available). The **game-sim-server session**, not this building agent, will import into the live site.

### 8.3 Mandatory keyboard navigation and returning focus to the host

- **[SITE SPEC]** Everything playable with keyboard; no keyboard trap. Tab through all live controls, including dynamically generated organelles, with Enter/Space to activate. Define a predictable, visible focus order; update it whenever organelles are added, removed, or repositioned. Wire `focus_next`/`focus_previous` **after** laying out or reparenting controls.
- **[SITE SPEC]** Escape closes the **innermost open** tutorial pop-up, Help panel, Settings panel or Pause overlay. A second Escape when no overlay remains **leaves** the game. **Tab past the last** and **Shift+Tab before the first** also leave the game. If the canvas has no focus owner after a mouse click, Tab begins at the first control and Shift+Tab begins at the last.
- **[SITE SPEC]** Implement the outbound action for web export (with a testable wrapper), following the site's actual protocol:

```gdscript
func leave_game() -> void:
    get_viewport().gui_release_focus()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("if (window.parent !== window) window.parent.postMessage({type: 'sims:leave-game'}, location.origin)")
```

- **[SITE SPEC]** Detect Tab and Shift+Tab in `_input`, **not** `_unhandled_input` (GUI can consume focus events). For exact matches, use `event.is_action_pressed("ui_focus_next", false, true)` so Shift+Tab does not masquerade as forward Tab. Make Tab boundary handling and focus release deterministic; prevent duplicate navigation caused by other GUI focus handlers.
- **[SITE SPEC]** Do **not** set `FOCUS_NONE` on actionable controls. All focused controls, including custom organelle hit areas and sliders, need an explicit **visible focus outline**. Escape in real Chrome fullscreen can be intercepted by the browser first; two presses to leave fullscreen and then game are acceptable.
- **Reference implementations, if present locally:** site `docs/game-keyboard-exit.md`, cell-membrane `main.gd` and `tests/keyboard_test.gd`, water-balance `ui/keyboard_nav.gd`. These are implementation pointers, not a dependency on inaccessible folders.

### 8.4 Accessibility, playback and non-visual limitations

- **[SITE SPEC]** Target **WCAG 2.2 AA where possible in a canvas**: body text **4.5:1 contrast**, focus outlines and icons **3:1**, **44 × 44 CSS px** touch targets, and **never color-only** communication. Organelle readiness rings show progress by shape/fill and have a stable complete-ring state. Meters also show labels/numeric or patterned states.
- **[SITE SPEC]** **No auto-play**: the game starts stopped, without audio or decorative motion, until the player activates Start. Simulation motion after Start is permitted. Any music, if later added, is **off by default**; no surprise sound.
- **[IMPLEMENTATION ADVICE]** Pause applies to any continuing animation over five seconds, including **Level 1 power-test** and **Level 3 day/night countdown**. Timers should be extendable/disableable for accessibility. Reduced Motion stops decoration, not the progress information needed to play; consider using browser `prefers-reduced-motion` as the default through `JavaScriptBridge`. Add **text-size** setting because browser zoom alone does not scale canvas typography. **Never flash.**
- **[SITE SPEC, reporting]** Do **not** claim screen-reader accessibility without testing. A plain Godot canvas generally exposes little or no game-state content to screen readers. If feasible, reuse the existing site's optional accessible web shell and announcer (`data-detectives/web/shell.html`, `scripts/ui/announcer.gd`) to mirror significant state updates through live regions; otherwise explicitly mark this limitation in README/site notes. Do not invent a new accessibility framework as part of this MVP.
- **[IMPLEMENTATION ADVICE]** Chrome may freeze a hidden or minimized game's frame updates. Treat this as browser behavior, not a game bug; document it if relevant.

### 8.5 Privacy, state, teacher URL settings

- **[SITE SPEC]** No text entry, accounts, network calls, analytics, external URLs/fonts, cheating/admin modes, secret PINs/passwords, or score/result messages posted to the hosting page. The game is **self-contained**. No debug/cheat/admin functionality in the production web export. A `.pck` can be unpacked; never bundle secrets.
- **[IMPLEMENTATION ADVICE]** Local settings/progress may use Godot `user://` (IndexedDB in browser). Set `application/config/name` to the distinctive **Cell Designer** (or custom user directory) to avoid same-origin game-save collisions. Do not require persistent storage to play.
- **[SITE SPEC, optional URL class settings]** Support these **specific** whitelisted settings so the host can select a starting scenario or ATP visual mode: `level=1|2|3` (choice, default `1`), `particles=on|off` (choice, default `on`). **[IMPLEMENTATION ADVICE]** These two are sufficient for v0.2; do not implement a teacher panel. Parse `window.location.search` through `JavaScriptBridge` **only in web builds** and ignore unknown/out-of-range values. If browser parameters are absent, use defaults. Never interpret the URL as a file path or executable instruction.
- **[SITE SPEC]** Class-setting keys must start with a lowercase letter and contain only lowercase letters/digits (≤24 chars). A `choice` allows 2–20 values using lowercase letters/digits/`_`/`-`; a `flag` is only emitted as `1` when on, and cannot be used for a feature on by default. `particles=on|off` is therefore **a choice**, not a flag. A numeric setting would require a minimum/maximum. Document keys, accepted values and defaults in README. Optional browser query settings must not create uncontrolled simulation advantages or bypass level completion validation.

### 8.6 Required documentation and ownership boundary

- **[SITE SPEC]** Keep `CREDITS.md` from the first third-party asset and record licenses. Artist-made Illustrator assets may be credited as original. The site registry uses these credits.
- **[SITE SPEC]** `README.md` must include: game title; one-sentence description beginning with a **verb**; estimated play duration (**7–13 minutes** for the full three-level sequence, provisional); **actual** Godot version and **actual** export template; supported query settings; how to run/test; art substitution instructions; model approximations; and a factually accurate accessibility matrix covering keyboard exit, screen-reader reporting, autoplay, and devices.
- **[SITE SPEC]** Distinguish **actually tested** in real Chrome vs headless Chromium, automated desktop, and manual device testing. For **phone**, **Chromebook** and **physical keyboard**, say **not yet checked** unless tried. State how Tab and Escape exit were exercised. Do not claim WCAG compliance or full accessibility based solely on code review.
- **[SITE SPEC]** The registry's `level` (grade), `author`, and `license` are **owner-only** fields: **leave them blank for Sean** even though the GDD identifies Grade 7 as the instructional target. Do not register or publish the game.
- **[SITE SPEC]** The game-sim-server session imports the exported build **hidden**, verifies it on the live site, and publishes it **only on Sean's explicit word**.

### 8.7 Non-negotiable pre-handoff verification

Run these tests and place observed outputs/results in README and `docs/HOSTING_VERIFICATION.md` (mark tests **not run** when the environment prevents them; never invent passing results):

1. Verify a Godot 4.7.x editor import and full project tests; check the chosen lean template with `check_web_template.py` if available, then export **with no threads** and **without Export With Debug**. Confirm `index.html` exists at root.
2. Launch the actual web export in **real Chrome**. Require console line **`cell-designer: boot ok`** emitted from `_ready` and **no `SCRIPT ERROR`**. A blank or gray canvas is a failure even without console errors. If real Chrome is unavailable, record that unverified and run the strongest available headless browser smoke test without presenting it as equivalent.
3. Load an iframe test page on the **same origin**, with a listener for `sims:leave-game`; check **1180×500**, **360 px tall**, **device pixel ratio 1.5**, resizing, text readability, and the top-right safe area. Also load standalone in a tab.
4. Keyboard-only walkthrough: Tab into and across every organelle/control, verify new organelles enter focus order, Tab past last exits, Shift+Tab before first exits, Escape dismisses callout then exits on the next press, and focus is restored to host/fullscreen control. Verify custom controls and sliders show focus.
5. Let the page load and sit **60 seconds without any input**: no sound, no decorative animation and no automatic gameplay progression. After Start, check Pause truly freezes animation/state, power test and the day/night clock.
6. Search the `.pck` for names/contents of screenshots, notes, test secrets, private configuration and other files that must not ship; record result. Check no external network or analytics requests.
7. Rerun all three level simulation balance tests and note **automated / headless browser / real browser / by hand** verification level separately. Explicitly record any untested phone, Chromebook, screen reader, or physical keyboard claims.

---

## 9. Explicit non-goals for v0.2


- No organelle drag-and-drop, free placement or building/painting cell structures.
- No editable RNA/DNA, transcription puzzles, genetic mutation, enzymes as player tools, or exact metabolic pathways.
- No manual amino-acid linking, protein folding, glucose polymer building, starch toggles, CO₂ removal clicks, or water inventory.
- No disease states, competitive multiplayer, online accounts, long campaign, score economy, narrative branching, or teacher dashboard in this MVP.
- No additional plant cell mechanics such as turgor, osmosis, stomata control, mineral uptake, or chlorophyll upgrades.

**Core promise:** a lively visual cell in which clicking to divide organelles alters a causal resource economy, and students learn from consequences.

---

## 10. One-shot handoff prompt for Fable

> Build the complete three-level Godot 4.7.x web-ready game described in `Cell_Designer_Respiration_GDD_v0.2.md`. Use GDScript and procedural vector-style placeholder art so missing Illustrator assets do not block execution. Follow the scope, resource interactions, level starts and victories, loading-ring fission interactions, automatic protein/starch handling, molecule toggles, accessibility, and science accuracy notes. Test each level with deterministic scripted playthroughs (including Level 3 success and failure), fix soft locks and parser/runtime issues, and export the web build if tools permit. **Meet all §8 SITE SPEC requirements**, including single-threaded export, same-origin iframe, keyboard host-exit protocol, no auto-play, responsive 1180×500 layout, query settings, privacy, README registry facts, and truthful browser/device verification. Provide an actual browser smoke test whenever the tools permit; do not declare an unperformed test a pass. The site-owner/server session handles import and publishing. Use `Cell_Designer_Visual_Assets_v0.1.md` as the eventual artwork manifest; never couple mechanics to temporary assets. Build and test instead of stopping to ask nonessential questions.
