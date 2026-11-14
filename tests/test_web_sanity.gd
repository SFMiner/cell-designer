extends "res://tests/test_base.gd"
## Scene-level checks on the real Main scene, headless: no auto-play, Start, Pause, Restart, the
## keyboard ring and host exit, tutorial pop-ups, settings that only change drawing, class-setting
## parsing and responsive layout. Frames are stepped by calling the controller's _process directly,
## so "60 seconds" here is 3600 simulated frames, not wall-clock time. The browser checks in
## tests/web/ cover the real export.
## Run:  Godot --headless --path . --script tests/test_web_sanity.gd

const EXPECTED: int = 92
const FRAME: float = 1.0 / 60.0

var main: Control = null


func _init() -> void:
	test_name = "test_web_sanity"
	_run.call_deferred()


func _run() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.settings.persist = false
	main.settings.show_atp_particles = true
	main.settings.reduced_motion = false
	main.settings.text_size = 0
	# The headless window does not start at the project's size; set the 1180x500 frame explicitly.
	root.size = Vector2i(1180, 500)
	await process_frame
	main.load_level(1, 3)
	await process_frame

	_query_parsing()
	_scaling()
	_no_autoplay()
	_keyboard_before_start()
	_start_and_tutorials()
	_pause_and_escape()
	_organelles_and_ring()
	_restart()
	_drawing_only_settings()
	_shortage_slows_visuals()
	await _layouts()
	_results_and_levels()
	finish(EXPECTED)


func frames(n: int) -> void:
	for i: int in range(n):
		main._process(FRAME)


## Steps frames, dismissing tutorial pop-ups, until `seconds` of level time have passed.
func play(seconds: float) -> void:
	var target: float = main.model.time + seconds
	var guard: int = 0
	while main.model.time < target and guard < 100000 and not main.model.is_finished():
		guard += 1
		if not main.overlays.is_empty() and main.overlays[-1].kind == "tutorial":
			main.close_topmost_overlay()
		main._process(FRAME)


func key(code: Key, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.shift_pressed = shift
		ev.pressed = down
		root.push_input(ev)


func focused() -> Control:
	return root.gui_get_focus_owner()


func particle_digest() -> String:
	var parts: Array[String] = []
	for p: MoleculeVisuals.Particle in main.cell_view.molecules.particles:
		parts.append("%s:%.3f:%.3f:%.2f" % [p.kind, p.pos.x, p.pos.y, p.alpha])
	return ",".join(parts)


func _query_parsing() -> void:
	check(GameSettings.parse_query("?level=2&particles=off") == {"level": 2, "particles": false}, "query: level=2&particles=off")
	check(GameSettings.parse_query("") == {} and GameSettings.parse_query("?") == {}, "query: empty -> defaults")
	check(GameSettings.parse_query("?level=4") == {} and GameSettings.parse_query("?level=0") == {} and GameSettings.parse_query("?level=2x") == {}, "query: out-of-range level ignored")
	check(GameSettings.parse_query("?particles=1") == {} and GameSettings.parse_query("?particles=ON") == {}, "query: unknown particles value ignored")
	check(GameSettings.parse_query("?debug=1&cheat=on&level=3&atp=999") == {"level": 3}, "query: unknown keys ignored")
	check(GameSettings.parse_query("?level=../../etc&particles=<script>") == {}, "query: odd text is ignored, never used")
	var s: GameSettings = GameSettings.new()
	s.apply_query(GameSettings.parse_query("?particles=on&level=3"))
	check(s.start_level == 3 and s.show_atp_particles, "query: applied to settings")
	s.apply_query({})
	check(s.start_level == 3, "query: absent keys leave settings alone")


func _scaling() -> void:
	check(is_equal_approx(main.view_scale(Vector2(1180, 500), 1.0, 1.0), 1.0), "scale: 1180x500 frame -> 1.0")
	check(is_equal_approx(main.view_scale(Vector2(1180, 360), 1.0, 1.0), 0.85), "scale: 360 px tall frame keeps UI at 0.85, not 0.72")
	check(is_equal_approx(main.view_scale(Vector2(1770, 750), 1.5, 1.0), 1.5), "scale: device pixel ratio 1.5 -> 1.5 physical px per base px")
	check(is_equal_approx(main.view_scale(Vector2(1180, 500), 1.0, 1.4), 1.4), "scale: extra-large text enlarges the UI 1.4x")
	check(is_equal_approx(main.view_scale(Vector2(590, 250), 1.0, 1.0), 0.85), "scale: 200% zoom (half the CSS px) still 0.85")
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand" and bool(ProjectSettings.get_setting("display/window/dpi/allow_hidpi")), "project: stretch aspect expand, hidpi on")


func _no_autoplay() -> void:
	check(not main.started and not main.is_running(), "boot: the game starts stopped")
	check(main.overlays.size() == 1 and main.overlays[0].kind == "start", "boot: the Start card is showing")
	var before: String = particle_digest()
	var snap: String = str(main.model.snapshot())
	main.set_process(true)
	for i: int in range(5):
		main._process(FRAME)
	main.set_process(false)
	frames(3600)
	check(is_equal_approx(main.model.time, 0.0) and str(main.model.snapshot()) == snap, "60 s without input: the model does not advance")
	check(particle_digest() == before, "60 s without input: no particle moves")
	var cv: CellView = main.cell_view
	check(is_equal_approx(cv._pump_phase, 0.0) and is_equal_approx(cv._vesicle_phase, 0.0) and is_equal_approx(cv._repair_phase, 0.0), "60 s without input: pumps, vesicles and repair are still")
	check(focused() == null, "boot: the game does not grab focus by itself")
	var has_audio: bool = false
	for n: Node in main.find_children("*", "AudioStreamPlayer", true, false):
		has_audio = true
	check(not has_audio, "there is no audio player in the game")


func _keyboard_before_start() -> void:
	var kb: KeyboardExit = main.keyboard
	key(KEY_TAB)
	check(focused() is Button and (focused() as Button).text == "Start", "Tab with nothing focused lands on Start")
	root.gui_release_focus()
	key(KEY_TAB, true)
	check(focused() == main.settings_button, "Shift+Tab with nothing focused lands on the last control (Settings)")
	var leaves: int = kb.leave_count
	key(KEY_TAB)
	check(kb.leave_count == leaves + 1 and focused() == null, "Tab past the last control leaves the game and releases focus")
	key(KEY_TAB)
	key(KEY_TAB, true)
	check(kb.leave_count == leaves + 2 and focused() == null, "Shift+Tab before the first control leaves the game")
	key(KEY_ESCAPE)
	check(kb.leave_count == leaves + 3 and not main.overlays.is_empty(), "Escape on the Start card leaves the game (the card is not a closable overlay)")
	# Help opens over the Start card; Escape closes only Help.
	main.help_button.grab_focus()
	key(KEY_ENTER)
	check(main.overlays.size() == 2 and main.overlays[-1].kind == "help", "Enter on Help opens Help")
	var ring: Array[Control] = kb.current_ring()
	check(ring.size() == 2 and focused() == ring[0], "a modal overlay limits Tab to its own buttons and takes focus")
	leaves = kb.leave_count
	key(KEY_ESCAPE)
	check(main.overlays.size() == 1 and kb.leave_count == leaves and focused() == main.help_button, "Escape closes Help only, and focus returns to the Help button")
	check(is_equal_approx(main.model.time, 0.0), "none of that started the level")


func _start_and_tutorials() -> void:
	root.gui_release_focus()
	key(KEY_TAB)
	key(KEY_SPACE)
	check(main.started and main.overlays.is_empty(), "Space on Start begins the level")
	frames(30)
	check(main.model.time > 0.3, "after Start the model advances")
	frames(120)
	check(not main.overlays.is_empty() and main.overlays[-1].kind == "tutorial", "the first tutorial call-out appears")
	var t0: float = main.model.time
	var snap: String = str(main.model.snapshot())
	frames(300)
	check(is_equal_approx(main.model.time, t0) and str(main.model.snapshot()) == snap, "a tutorial call-out pauses the level")
	check(main.hud.highlight.has("glucose") and main.cell_view.emphasis.get("glyphs", []).has("oxygen"), "the call-out highlights glucose and oxygen (meters and glyphs)")
	check(main.announcer.last_text().contains("cellular respiration"), "the call-out text is sent to the announcer")
	var leaves: int = main.keyboard.leave_count
	key(KEY_ESCAPE)
	check(main.overlays.is_empty() and main.keyboard.leave_count == leaves, "Escape dismisses the call-out without leaving")
	check(main.hud.highlight.is_empty() and main.cell_view.emphasis.is_empty(), "highlights clear when the call-out closes")
	key(KEY_ESCAPE)
	check(main.keyboard.leave_count == leaves + 1, "the next Escape leaves the game")
	# A just-opened call-out ignores presses for a moment, so mashing Enter cannot skip it unread.
	var waited: int = 0
	while main.overlays.is_empty() and waited < 600:
		waited += 1
		main._process(FRAME)
	var open_now: bool = not main.overlays.is_empty() and main.overlays[-1].kind == "tutorial"
	if open_now:
		main.overlays[-1].buttons[0].pressed.emit()
	check(open_now and not main.overlays.is_empty(), "a new call-out is not dismissed by an immediate press")
	main.overlays[-1].arm_delay = 0.0
	main.overlays[-1].buttons[0].pressed.emit()
	check(main.overlays.is_empty(), "once armed, 'Got it' dismisses it")


func _pause_and_escape() -> void:
	play(0.5)
	main.pause_button.grab_focus()
	key(KEY_ENTER)
	check(main.overlays.size() == 1 and main.overlays[-1].kind == "pause", "Pause opens the pause overlay")
	var t0: float = main.model.time
	var snap: String = str(main.model.snapshot())
	var digest: String = particle_digest()
	var pump: float = main.cell_view._pump_phase
	frames(600)
	check(is_equal_approx(main.model.time, t0) and str(main.model.snapshot()) == snap, "Pause freezes the model (resources and maturation timers)")
	check(particle_digest() == digest and is_equal_approx(main.cell_view._pump_phase, pump), "Pause freezes particles and background animation")
	var leaves: int = main.keyboard.leave_count
	key(KEY_ESCAPE)
	check(main.overlays.is_empty() and main.keyboard.leave_count == leaves, "Escape closes Pause without leaving")
	frames(10)
	check(main.model.time > t0, "the level resumes after Pause closes")
	main.cycle_speed()
	var t1: float = main.model.time
	frames(60)
	var gained: float = main.model.time - t1
	check(absf(gained - 2.0) < 0.11, "2x speed runs two seconds of level per second (%.2f)" % gained)
	main.cycle_speed()
	main.cycle_speed()


func _organelles_and_ring() -> void:
	main.load_level(1, 3)
	main.press_start()
	var kb: KeyboardExit = main.keyboard
	var ring: Array[Control] = kb.current_ring()
	check(ring.size() == 6 and ring[0] == main.pause_button and ring[5] is OrganelleButton, "ring: 5 top buttons then the organelle")
	var org_button: OrganelleButton = ring[5]
	org_button.grab_focus()
	check(main.announcer.last_text().contains("ready to divide"), "focusing an organelle announces its state")
	var atp0: float = main.model.atp
	key(KEY_ENTER)
	check(main.model.count("mito") == 2 and is_equal_approx(atp0 - main.model.atp, 5.0), "Enter on a ready mitochondrion divides it for 5 ATP")
	check(not main.overlays.is_empty() and main.overlays[-1].kind == "tutorial" and focused() == main.overlays[-1].buttons[0],
		"the first division opens the maturation-ring call-out and focuses its button")
	main._close_top()
	ring = kb.current_ring()
	check(ring.size() == 7 and ring[5] is OrganelleButton and ring[6] is OrganelleButton, "ring: both daughters are in the Tab order at once")
	check(focused() is OrganelleButton and focused() != org_button, "focus moves to the daughter in the parent's place")
	atp0 = main.model.atp
	key(KEY_SPACE)
	check(main.model.count("mito") == 2 and is_equal_approx(main.model.atp, atp0), "Space on a maturing organelle spends nothing")
	check(main.announcer.last_text() == "Not ready" and bool(main.announcer.history[-1]["assertive"]), "the blocked reason 'Not ready' is announced")
	var ob: OrganelleButton = focused()
	check(ob.clock_time > 0.0, "the not-ready clock pictogram is shown")
	# Tab from the last organelle leaves; Shift+Tab from the first control leaves.
	ring[6].grab_focus()
	var leaves: int = kb.leave_count
	key(KEY_TAB)
	check(kb.leave_count == leaves + 1, "Tab past the last organelle leaves the game")
	main.pause_button.grab_focus()
	key(KEY_TAB, true)
	check(kb.leave_count == leaves + 2, "Shift+Tab before the first button leaves the game")
	# Tab walks the whole ring in order.
	root.gui_release_focus()
	var walked: int = 0
	var in_order: bool = true
	for i: int in range(ring.size()):
		key(KEY_TAB)
		in_order = in_order and focused() == ring[i]
		walked += 1
	check(in_order and walked == 7, "Tab visits every control in ring order")
	# Mouse click on an organelle.
	play(5.2)
	var target: OrganelleButton = kb.current_ring()[5]
	var before: int = main.model.count("mito")
	target.pressed.emit()
	check(main.model.count("mito") == before + 1, "pressing (click or tap) a ready organelle divides it")
	# Hit targets and bounds.
	var small: int = 0
	var outside: int = 0
	var view_rect: Rect2 = Rect2(Vector2.ZERO, main.cell_view.size)
	for c: Control in main.cell_view.ordered_buttons():
		if c.size.x < 44.0 - 0.01 or c.size.y < 44.0 - 0.01:
			small += 1
		if not view_rect.encloses(Rect2(c.position, c.size)):
			outside += 1
		if c.focus_mode == Control.FOCUS_NONE:
			small += 1
	check(small == 0 and outside == 0, "organelle hit areas are at least 44 px, focusable, and inside the cell view (%d small, %d outside, view %s)" % [small, outside, str(view_rect)])
	check(main.cell_view.molecules.mouse_filter == Control.MOUSE_FILTER_IGNORE and main.cell_view.molecules.get_index() < target.get_index(), "particles ignore the mouse and sit under the organelles")


func _restart() -> void:
	play(3.0)
	main.restart_button.pressed.emit()
	var m: SimulationModel = main.model
	check(not main.started and is_equal_approx(m.time, 0.0) and m.count("mito") == 1 and is_equal_approx(m.atp, 12.0), "Restart resets the level state and stops it")
	check(main.overlays.size() == 1 and main.overlays[0].kind == "start", "Restart shows the Start card again")
	check(main.cell_view.buttons.size() == 1 and main._shown_beats.is_empty() and main._pending_beats.is_empty(), "Restart clears organelle views and tutorial events")
	main.press_start()
	frames(150)
	check(not main.overlays.is_empty() and main.overlays[-1].kind == "tutorial", "tutorials play again after Restart")
	main.close_topmost_overlay()


## Drives one level deterministically (fixed ticks, same presses) and returns the final snapshot.
func _scripted_run(show_atp: bool, reduced: bool) -> String:
	main.settings.show_atp_particles = show_atp
	main.settings.reduced_motion = reduced
	main.load_level(2, 11)
	main.press_start()
	for i: int in range(500):
		for o: SimulationModel.Org in main.model.organelles.duplicate():
			if main.model.division_block(o.id) == "":
				main._on_organelle_pressed(o.id)
		main.model.tick(TICK)
		main._handle_events()
		main.cell_view.advance(TICK)
		while not main.overlays.is_empty():
			main._close_top()
		if main.model.is_finished():
			break
	return str(main.model.snapshot())


func _drawing_only_settings() -> void:
	var with_atp: String = _scripted_run(true, false)
	var atp_drawn: int = 0
	for p: MoleculeVisuals.Particle in main.cell_view.molecules.particles:
		if p.kind == "atp":
			atp_drawn += 1
	var without_atp: String = _scripted_run(false, false)
	check(with_atp == without_atp, "hiding ATP particles leaves the outcome identical")
	check(atp_drawn > 0 and not main.cell_view.molecules.show_atp, "ATP particles existed when shown and are switched off when hidden")
	var reduced: String = _scripted_run(true, true)
	check(with_atp == reduced, "Reduced Motion leaves the outcome identical")
	var cv: CellView = main.cell_view
	check(is_equal_approx(cv._pump_phase, 0.0) and is_equal_approx(cv._vesicle_phase, 0.0), "Reduced Motion stops decorative pump and vesicle motion")
	var all_static: bool = true
	for id: Variant in cv.buttons.keys():
		var b: OrganelleButton = cv.buttons[id]
		all_static = all_static and is_equal_approx(b.birth, 1.0) and b.reduced_motion and is_equal_approx(b.pulse, 0.0)
	check(all_static, "Reduced Motion: no fission slide or pulse; rings still report progress in steps")
	check(main.cell_view.molecules.particles.size() <= MoleculeVisuals.MAX_TOTAL, "particle count stays within its cap (%d)" % main.cell_view.molecules.particles.size())
	main.settings.reduced_motion = false
	main.settings.show_atp_particles = true


func _shortage_slows_visuals() -> void:
	main.load_level(2, 11)
	main.press_start()
	var cv: CellView = main.cell_view
	main.model.tick(TICK)
	main._handle_events()
	main.model.activity = 1.0
	main.model.protein_rate = 4.0
	var p0: float = cv._pump_phase
	var r0: float = cv._ribosome_phase
	var v0: float = cv._vesicle_phase
	cv.advance(1.0)
	var fast_pump: float = cv._pump_phase - p0
	var fast_ribo: float = cv._ribosome_phase - r0
	var fast_ves: float = cv._vesicle_phase - v0
	main.model.activity = 0.2
	main.model.protein_rate = 0.8
	p0 = cv._pump_phase
	r0 = cv._ribosome_phase
	v0 = cv._vesicle_phase
	cv.advance(1.0)
	check(cv._pump_phase - p0 < fast_pump * 0.3 and cv._vesicle_phase - v0 < fast_ves * 0.3, "ion pumps and vesicles slow when ATP is short")
	check(cv._ribosome_phase - r0 < fast_ribo * 0.3 and fast_ribo > 0.0, "ribosome animation follows the protein synthesis rate")
	while not main.overlays.is_empty():
		main._close_top()


func _layout_problems() -> Array[String]:
	var problems: Array[String] = []
	var view: Vector2 = main.get_viewport_rect().size
	var reserved: Rect2 = Rect2(view.x - main._reserved.x, 0.0, main._reserved.x, main._reserved.y)
	for b: Button in main.top_buttons:
		var r: Rect2 = Rect2(b.position, b.size)
		if r.intersects(reserved):
			problems.append("top button '%s' in the reserved corner" % b.text)
		if r.end.x > view.x + 0.5 or r.end.y > view.y + 0.5:
			problems.append("top button '%s' off-screen" % b.text)
		if b.size.y < main._touch - 0.5:
			problems.append("top button '%s' shorter than a touch target" % b.text)
	var cell: Rect2 = Rect2(main.cell_view.position, main.cell_view.size)
	if cell.intersects(reserved):
		problems.append("cell view overlaps the reserved corner")
	if cell.end.x > view.x + 0.5 or cell.end.y > view.y + 0.5 or cell.size.x < 100.0 or cell.size.y < 60.0:
		problems.append("cell view does not fit: %s in %s" % [str(cell), str(view)])
	for c: Control in main.cell_view.ordered_buttons():
		if c.size.x < main.cell_view.min_hit - 0.5:
			problems.append("organelle hit area under 44 CSS px")
			break
	for o: OverlayPanel in main.overlays:
		var pr: Rect2 = Rect2(o.position + o.panel.position, o.panel.size * o.panel.scale)
		if pr.intersects(reserved):
			problems.append("overlay '%s' in the reserved corner" % o.kind)
		if pr.position.x < -0.5 or pr.position.y < -0.5 or pr.end.x > view.x + 0.5 or pr.end.y > view.y + 0.5:
			problems.append("overlay '%s' off-screen: %s in %s" % [o.kind, str(pr), str(view)])
	return problems


func _layouts() -> void:
	var sizes: Array[Vector2i] = [Vector2i(1180, 500), Vector2i(1180, 360), Vector2i(640, 360), Vector2i(420, 720), Vector2i(1920, 1080)]
	for level: int in [1, 3]:
		main.load_level(level, 3)
		for sz: Vector2i in sizes:
			root.size = sz
			await process_frame
			main.apply_layout()
			main._process(FRAME)
			main._process(FRAME)
			var problems: Array[String] = _layout_problems()
			check(problems.is_empty(), "layout L%d at %dx%d: %s" % [level, sz.x, sz.y, str(problems)])
	# Extra-large text at the smallest frame still fits (cards shrink rather than run off-screen).
	main.settings.text_size = 2
	root.size = Vector2i(1180, 360)
	await process_frame
	main.apply_layout()
	main._process(FRAME)
	main._process(FRAME)
	var p2: Array[String] = _layout_problems()
	check(p2.is_empty(), "layout with extra-large text at 1180x360: %s" % str(p2))
	main.settings.text_size = 0
	root.size = Vector2i(1180, 500)
	await process_frame
	main.apply_layout()


func _results_and_levels() -> void:
	# Win card -> Next level -> stopped Level 2.
	main.load_level(1, 3)
	main.press_start()
	var guard: int = 0
	while not main.model.is_finished() and guard < 40000:
		guard += 1
		while not main.overlays.is_empty():
			main._close_top()
		for o: SimulationModel.Org in main.model.organelles.duplicate():
			if main.model.count("mito") < 8 and main.model.division_block(o.id) == "":
				main._on_organelle_pressed(o.id)
		main._process(FRAME)
	check(main.model.won and not main.overlays.is_empty() and main.overlays[-1].kind == "result", "winning Level 1 shows the result card")
	var leaves: int = main.keyboard.leave_count
	key(KEY_ESCAPE)
	check(main.keyboard.leave_count == leaves + 1 and main.overlays.size() == 1, "Escape on the result card leaves the game")
	main.overlays[-1].arm_delay = 0.0
	main.overlays[-1].buttons[0].pressed.emit()
	check(main.level == 2 and not main.started and main.model.count("mito") == 6, "Next level loads Level 2, stopped")
	frames(120)
	check(is_equal_approx(main.model.time, 0.0), "the next level also waits for Start")
	# Fail card.
	main.load_level(3, 3)
	main.press_start()
	guard = 0
	while not main.model.is_finished() and guard < 40000:
		guard += 1
		while not main.overlays.is_empty():
			main._close_top()
		main._process(FRAME)
	check(main.model.failed and main.overlays[-1].kind == "result" and main.overlays[-1].body_label.text.contains("Stored sugar ran out"), "failing Level 3 shows the cause on the result card")
	check(main._shown_beats.has("l3_starch_breakdown") and not main._shown_beats.has("l3_starch_store"), "L3 idle: the starch-breakdown call-out was shown, the storage one was not")
	check(main.pause_button.disabled, "Pause is disabled once the level is over")
