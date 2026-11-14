extends Control
## Root of the game (scenes/Main.tscn). Builds the UI in code, owns the level's SimulationModel,
## steps it on a fixed tick, and turns model events into tutorials, banners and result cards.
##
## Nothing moves until the player presses Start: the model is not ticked and no view is advanced.
## While any overlay is open (tutorial, Pause, Help, Settings) the level is frozen in the same way.

# === CONSTANTS ===
const BASE_SIZE: Vector2 = Vector2(1180.0, 500.0)
## UI never drops below this many CSS px per base px, so 14-15 px text stays readable.
const MIN_UI_SCALE: float = 0.85
const MIN_VIEW_WIDTH: float = 400.0
const HUD_WIDTH: float = 276.0
## Top-right corner kept clear for the host page's Full screen button, in CSS px.
const RESERVED_CSS: Vector2 = Vector2(200.0, 64.0)
const TOUCH_CSS: float = 44.0
const MAX_STEPS_PER_FRAME: int = 12
const BACKGROUND: Color = Color(0.06, 0.09, 0.13, 1)

# === PUBLIC VARIABLES ===
var settings: GameSettings = GameSettings.new()
var model: SimulationModel = null
var level: int = 1
var started: bool = false
var speed_index: int = 0
var overlays: Array[OverlayPanel] = []
var cell_view: CellView = null
var hud: Hud = null
var keyboard: KeyboardExit = null
var announcer: Announcer = null
var top_buttons: Array[Button] = []
var pause_button: Button = null
var speed_button: Button = null
var restart_button: Button = null
var help_button: Button = null
var settings_button: Button = null

# === PRIVATE VARIABLES ===
var _background: ColorRect = null
var _hud_scroll: ScrollContainer = null
var _acc: float = 0.0
var _shown_beats: Dictionary = {}
var _pending_beats: Array[Dictionary] = []
var _divided_once: bool = false
var _css_scale: float = 1.0
var _touch: float = 44.0
var _top_height: float = 64.0
var _reserved: Vector2 = RESERVED_CSS
var _applying_layout: bool = false
var _help_page: int = 0


# === LIFECYCLE METHODS ===
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.load_saved()
	settings.read_browser()
	theme = UiTheme.build()
	_build_ui()
	get_tree().root.size_changed.connect(apply_layout)
	load_level(settings.start_level)
	print("cell-designer: boot ok")


func _process(delta: float) -> void:
	if not overlays.is_empty():
		_place_overlays()
	if is_running():
		var speed: float = GameSettings.SPEEDS[speed_index]
		_acc += delta * speed
		var steps: int = 0
		while _acc >= LevelConfigs.TICK and steps < MAX_STEPS_PER_FRAME:
			model.tick(LevelConfigs.TICK)
			_acc -= LevelConfigs.TICK
			steps += 1
			_handle_events()
			_check_beats()
			if not is_running():
				break
		if steps >= MAX_STEPS_PER_FRAME:
			_acc = 0.0
		cell_view.advance(delta * speed)
		hud.queue_redraw()
	elif not overlays.is_empty() and overlays[-1].kind == "tutorial":
		cell_view.advance_highlight(delta)


# === PUBLIC METHODS ===
## True while the level is actually running (started, nothing open, not finished).
func is_running() -> bool:
	return started and overlays.is_empty() and model != null and not model.is_finished()


## Loads a level in its stopped state and shows its Start card. `rng_seed` < 0 picks a random seed.
func load_level(p_level: int, rng_seed: int = -1) -> void:
	level = clampi(p_level, 1, LevelConfigs.LEVEL_COUNT)
	for o: OverlayPanel in overlays:
		o.queue_free()
	overlays.clear()
	model = SimulationModel.new()
	model.setup(level, rng_seed if rng_seed >= 0 else int(randi() & 0x7fffffff))
	started = false
	_acc = 0.0
	_shown_beats.clear()
	_pending_beats.clear()
	_divided_once = false
	cell_view.settings = settings
	cell_view.set_model(model)
	hud.model = model
	hud.set_highlight([])
	apply_layout()
	_update_top_buttons()
	_show_start_card()
	announcer.say("Level %d: %s. %s" % [level, str(model.cfg["name"]), Tutorials.OPENING[level - 1]])
	print("cell-designer: level %d ready (ATP particles %s)" % [level, "on" if settings.show_atp_particles else "off"])


## The player pressed Start: the level begins to run.
func press_start() -> void:
	if started:
		return
	_close_overlays_of_kind("start")
	started = true
	_update_top_buttons()
	print("cell-designer: started level %d" % level)
	announcer.say("Level started.")


func toggle_pause() -> void:
	if not started or model.is_finished():
		return
	if _top_kind() == "pause":
		_close_top()
		return
	if not overlays.is_empty():
		return
	var o: OverlayPanel = _new_overlay("pause", true, true, 0.5)
	o.preferred_width = 360.0
	o.set_text("Paused", "Everything in the cell is frozen, including timers.")
	o.add_button("Resume", _close_top)
	o.add_button("Restart level", restart_level)
	_push_overlay(o)
	announcer.say("Paused.")


func cycle_speed() -> void:
	speed_index = (speed_index + 1) % GameSettings.SPEEDS.size()
	_update_top_buttons()
	announcer.say("Speed " + GameSettings.SPEED_NAMES[speed_index])


func restart_level() -> void:
	load_level(level)


## Recomputes the content scale and positions every part of the UI for the current window.
func apply_layout() -> void:
	if _applying_layout or cell_view == null:
		return
	_applying_layout = true
	var win: Window = get_window()
	var window_size: Vector2 = Vector2(win.size)
	var dpr: float = _device_pixel_ratio()
	if window_size.x >= 1.0 and window_size.y >= 1.0:
		var s: float = view_scale(window_size, dpr, settings.text_scale())
		win.content_scale_size = Vector2i((window_size / s).floor())
		_css_scale = s / dpr
	var view: Vector2 = get_viewport_rect().size
	_touch = maxf(36.0, TOUCH_CSS / _css_scale)
	_reserved = RESERVED_CSS / _css_scale
	cell_view.min_hit = TOUCH_CSS / _css_scale

	# Top bar buttons flow left to right and wrap; the top-right corner stays empty.
	var x: float = 6.0
	var y: float = 6.0
	for b: Button in top_buttons:
		b.custom_minimum_size = Vector2(_touch, _touch)
		var sz: Vector2 = b.get_combined_minimum_size()
		var limit: float = view.x - 6.0
		if y < _reserved.y:
			limit = view.x - _reserved.x - 6.0
		if x + sz.x > limit and x > 6.0:
			x = 6.0
			y += _touch + 6.0
		b.position = Vector2(x, y)
		b.size = sz
		x += sz.x + 6.0
	_top_height = maxf(y + _touch + 6.0, _reserved.y)

	_background.position = Vector2.ZERO
	_background.size = view
	var below: float = maxf(view.y - _top_height, 40.0)
	# Use whichever arrangement shows the cell bigger: status panel beside it, or above it.
	hud.compact = false
	var cs: Vector2 = OrganelleLayout.CELL_SIZE
	var beside: float = 0.0
	if view.x - HUD_WIDTH >= 180.0:
		beside = minf((view.x - HUD_WIDTH) / cs.x, below / cs.y)
	var above_h: float = minf(hud.content_height(view.x - 12.0), below * 0.42)
	var above: float = minf(view.x / cs.x, (below - above_h) / cs.y)
	if beside >= above:
		_hud_scroll.position = Vector2(0.0, _top_height)
		_hud_scroll.size = Vector2(HUD_WIDTH, below)
		cell_view.position = Vector2(HUD_WIDTH, _top_height)
		cell_view.size = Vector2(view.x - HUD_WIDTH, below)
	else:
		# Narrow frame: status panel above the cell, scrolling if it has to.
		var hud_h: float = minf(hud.content_height(view.x - 12.0), below * 0.42)
		_hud_scroll.position = Vector2(0.0, _top_height)
		_hud_scroll.size = Vector2(view.x, hud_h)
		cell_view.position = Vector2(0.0, _top_height + hud_h)
		cell_view.size = Vector2(view.x, maxf(below - hud_h, 40.0))
	var hud_w: float = _hud_scroll.size.x
	var need: float = hud.content_height(hud_w)
	if need > _hud_scroll.size.y + 0.5:
		hud.compact = true
		need = hud.content_height(hud_w)
	if need > _hud_scroll.size.y + 0.5:
		hud_w -= 12.0
		need = hud.content_height(hud_w)
	hud.custom_minimum_size = Vector2(hud_w, need)
	hud.queue_redraw()
	cell_view.layout_cell()
	_place_overlays()
	_applying_layout = false


## Screen px per base px for a window of `window` physical px on a display with `dpr` physical px
## per CSS px. `text_scale` is the player's text-size setting; it enlarges the whole UI.
static func view_scale(window: Vector2, dpr: float, text_scale: float) -> float:
	var fit: float = minf(window.x / BASE_SIZE.x, window.y / BASE_SIZE.y)
	var s: float = maxf(fit, MIN_UI_SCALE * dpr) * text_scale
	return maxf(minf(s, window.x / MIN_VIEW_WIDTH), 0.1)


## The controls Tab walks through right now, in order (see KeyboardExit).
func focus_ring() -> Array:
	var ring: Array = []
	if not overlays.is_empty():
		var top: OverlayPanel = overlays[-1]
		for b: Button in top.buttons:
			ring.append(b)
		if top.modal:
			return ring
		for b: Button in top_buttons:
			ring.append(b)
		return ring
	for b: Button in top_buttons:
		ring.append(b)
	for c: Control in cell_view.ordered_buttons():
		ring.append(c)
	return ring


## Closes the innermost closable overlay. Returns false when there is nothing to close.
func close_topmost_overlay() -> bool:
	if overlays.is_empty():
		return false
	var top: OverlayPanel = overlays[-1]
	if not top.escape_closes:
		return false
	_close_top()
	return true


func is_modal_open() -> bool:
	return not overlays.is_empty() and overlays[-1].modal


# === PRIVATE METHODS ===
func _device_pixel_ratio() -> float:
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		if v is float or v is int:
			return clampf(float(v), 0.5, 6.0)
	return maxf(DisplayServer.screen_get_scale(), 0.5)


func _build_ui() -> void:
	_background = ColorRect.new()
	_background.color = BACKGROUND
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	cell_view = CellView.new()
	cell_view.name = "CellView"
	cell_view.settings = settings
	cell_view.organelle_pressed.connect(_on_organelle_pressed)
	cell_view.organelle_focused.connect(_on_organelle_focused)
	add_child(cell_view)

	_hud_scroll = ScrollContainer.new()
	_hud_scroll.name = "HudScroll"
	_hud_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_hud_scroll)
	hud = Hud.new()
	hud.name = "Hud"
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_scroll.add_child(hud)

	pause_button = _top_button("Pause", toggle_pause)
	speed_button = _top_button("Speed: 1x", cycle_speed)
	restart_button = _top_button("Restart", restart_level)
	help_button = _top_button("Help", _open_help)
	settings_button = _top_button("Settings", _open_settings)

	announcer = Announcer.new()
	announcer.name = "Announcer"
	add_child(announcer)
	keyboard = KeyboardExit.new()
	keyboard.name = "KeyboardExit"
	keyboard.ring_provider = focus_ring
	keyboard.close_topmost = close_topmost_overlay
	keyboard.modal_active = is_modal_open
	keyboard.left_game.connect(_on_left_game)
	add_child(keyboard)


func _top_button(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_press)
	add_child(b)
	top_buttons.append(b)
	return b


func _update_top_buttons() -> void:
	pause_button.disabled = not started or (model != null and model.is_finished())
	speed_button.text = "Speed: " + GameSettings.SPEED_NAMES[speed_index]
	if cell_view != null and not _applying_layout:
		apply_layout()


func _on_left_game() -> void:
	print("cell-designer: leave-game")


# --- Overlays ---
func _new_overlay(kind: String, modal: bool, escape_closes: bool, dim: float) -> OverlayPanel:
	var o: OverlayPanel = OverlayPanel.new()
	o.kind = kind
	o.modal = modal
	o.escape_closes = escape_closes
	o.dim = dim
	o.name = "Overlay_" + kind
	return o


func _push_overlay(o: OverlayPanel, take_focus: bool = true) -> void:
	o.previous_focus = get_viewport().gui_get_focus_owner()
	o.closed.connect(_on_overlay_closed.bind(o))
	add_child(o)
	overlays.append(o)
	for b: Button in o.buttons:
		b.custom_minimum_size = Vector2(_touch, _touch)
	_place_overlays()
	if take_focus and not o.buttons.is_empty():
		o.buttons[0].grab_focus()
	elif o.modal:
		get_viewport().gui_release_focus()


func _on_overlay_closed(o: OverlayPanel) -> void:
	_remove_overlay(o)


func _close_top() -> void:
	if overlays.is_empty():
		return
	_remove_overlay(overlays[-1])


func _close_overlays_of_kind(kind: String) -> void:
	for o: OverlayPanel in overlays.duplicate():
		if o.kind == kind:
			_remove_overlay(o)


func _remove_overlay(o: OverlayPanel) -> void:
	if not overlays.has(o):
		return
	overlays.erase(o)
	var back: Control = o.previous_focus
	var had_focus: bool = false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and o.is_ancestor_of(focused):
		had_focus = true
	if o.kind == "tutorial":
		cell_view.set_emphasis({})
		hud.set_highlight([])
	o.queue_free()
	if had_focus:
		if back != null and is_instance_valid(back) and back.is_visible_in_tree() and not back.is_queued_for_deletion():
			back.grab_focus()
		else:
			get_viewport().gui_release_focus()
	if o.kind == "tutorial" and overlays.is_empty():
		_show_next_beat()


func _top_kind() -> String:
	return "" if overlays.is_empty() else overlays[-1].kind


func _place_overlays() -> void:
	var view: Vector2 = get_viewport_rect().size
	for o: OverlayPanel in overlays:
		var area: Rect2 = Rect2(Vector2.ZERO, view)
		if not o.modal:
			area = Rect2(0.0, _top_height, view.x, maxf(view.y - _top_height, 40.0))
		o.position = area.position
		o.size = area.size
		var w: float = minf(o.preferred_width, area.size.x - 16.0)
		o.set_panel_width(w)
		var min_size: Vector2 = o.panel.get_combined_minimum_size()
		o.panel.size = Vector2(maxf(w, min_size.x), min_size.y)
		# If the card is taller than the frame (tiny frame, extra-large text), shrink it to fit.
		var fit: float = minf(1.0, (area.size.y - 12.0) / maxf(o.panel.size.y, 1.0))
		fit = minf(fit, (area.size.x - 8.0) / maxf(o.panel.size.x, 1.0))
		o.panel.scale = Vector2(fit, fit)
		var shown: Vector2 = o.panel.size * fit
		var pos: Vector2 = (area.size - shown) * 0.5
		if o.kind == "tutorial":
			o.targets.clear()
			o.target_gaps.clear()
			if o.target_organelles != "":
				o.targets.append(cell_view.emphasis_point(o.target_organelles))
				o.target_gaps.append(model.layout.spacing * cell_view.cell_scale * 0.62)
			if o.target_meter != "" and hud.row_rects.has(o.target_meter):
				o.targets.append(hud.row_point(o.target_meter))
				o.target_gaps.append(0.0)
			# Call-outs sit over the cell area, at whichever end is away from what they point at.
			var cell_rect: Rect2 = Rect2(cell_view.position, cell_view.size)
			pos.x = clampf(cell_rect.position.x + (cell_rect.size.x - shown.x) * 0.5, 4.0, maxf(4.0, view.x - shown.x - 4.0))
			var at_top: bool = false
			if o.avoid_target and not o.targets.is_empty():
				at_top = o.targets[0].y > cell_rect.get_center().y
			pos.y = (cell_rect.position.y + 6.0) if at_top else (view.y - shown.y - 8.0)
		var global_rect: Rect2 = Rect2(area.position + pos, shown)
		var reserved_rect: Rect2 = Rect2(view.x - _reserved.x, 0.0, _reserved.x, _reserved.y)
		if global_rect.intersects(reserved_rect):
			pos.y = _reserved.y + 4.0 - area.position.y
		o.panel.position = pos
		o.queue_redraw()


# --- Cards ---
func _show_start_card() -> void:
	var o: OverlayPanel = _new_overlay("start", false, false, 0.45)
	o.preferred_width = 560.0
	var text: String = "%s\n\n%s\n\n%s" % [Tutorials.OPENING[level - 1], Tutorials.OPENING_NOTES[level - 1], Tutorials.HOW_TO]
	o.set_text("%s\nLevel %d: %s" % [Tutorials.GAME_TITLE, level, str(model.cfg["name"])], text)
	o.add_button("Start", press_start)
	# Focus is not taken at load: the first Tab lands on Start because it leads the ring.
	_push_overlay(o, false)


func _show_result_card(won: bool) -> void:
	var o: OverlayPanel = _new_overlay("result", false, false, 0.45)
	o.preferred_width = 540.0
	o.arm_delay = 0.8
	if won:
		o.set_text("Level %d complete" % level, Tutorials.WIN_TEXT[level - 1])
		if level < LevelConfigs.LEVEL_COUNT:
			o.add_button("Next level", load_level.bind(level + 1))
		else:
			o.add_button("Play again from Level 1", load_level.bind(1))
		o.add_button("Replay this level", restart_level)
		announcer.say("Level %d complete. %s" % [level, Tutorials.WIN_TEXT[level - 1]])
		print("cell-designer: won level %d" % level)
	else:
		var why: String = str(Tutorials.FAIL_TEXT.get(model.fail_reason, Tutorials.FAIL_TEXT["atp_out"]))
		o.set_text("The cell could not keep going", why + "\n\nTry a different balance of organelles.")
		o.add_button("Try again", restart_level)
		announcer.alert("The cell could not keep going. " + why)
		print("cell-designer: failed level %d (%s)" % [level, model.fail_reason])
	_update_top_buttons()
	_push_overlay(o)


func _open_help() -> void:
	if _top_kind() == "help":
		return
	if is_modal_open():
		return
	_help_page = 0
	_show_help_page()


func _show_help_page() -> void:
	_close_overlays_of_kind("help")
	var page: Dictionary = Tutorials.HELP_PAGES[_help_page]
	var o: OverlayPanel = _new_overlay("help", true, true, 0.55)
	o.preferred_width = 600.0
	o.set_text("Help %d of %d: %s" % [_help_page + 1, Tutorials.HELP_PAGES.size(), str(page["title"])], str(page["text"]))
	if bool(page.get("legend", false)):
		o.add_extra(_make_legend())
	o.add_button("Next page", _next_help_page)
	o.add_button("Close", _close_top)
	_push_overlay(o)
	announcer.say("%s. %s" % [str(page["title"]), str(page["text"])])


func _next_help_page() -> void:
	_help_page = (_help_page + 1) % Tutorials.HELP_PAGES.size()
	_show_help_page()


func _make_legend() -> Control:
	var legend: Control = Control.new()
	legend.custom_minimum_size = Vector2(0.0, 4.0 * 34.0)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.draw.connect(func() -> void:
		var font: Font = ThemeDB.fallback_font
		var kinds: Array[String] = ["glucose", "oxygen", "co2", "water", "amino", "protein", "atp", "starch"]
		var col_w: float = legend.size.x * 0.5
		for i: int in range(kinds.size()):
			var cx: float = float(i % 2) * col_w + 18.0
			var cy: float = float(i >> 1) * 34.0 + 16.0
			legend.draw_circle(Vector2(cx, cy), 15.0, Color(0.93, 0.93, 0.90, 1))
			PlaceholderArt.draw_glyph(legend, kinds[i], Vector2(cx, cy), 9.0, 1.0)
			legend.draw_string(font, Vector2(cx + 24.0, cy + 5.0), str(PlaceholderArt.GLYPH_NAMES[kinds[i]]),
				HORIZONTAL_ALIGNMENT_LEFT, col_w - 44.0, UiTheme.FONT_SIZE, UiTheme.TEXT))
	return legend


func _open_settings() -> void:
	if _top_kind() == "settings":
		return
	if is_modal_open():
		return
	_show_settings(0)


func _show_settings(focus_index: int) -> void:
	_close_overlays_of_kind("settings")
	var o: OverlayPanel = _new_overlay("settings", true, true, 0.55)
	o.preferred_width = 420.0
	o.set_text("Settings", "These change how the game looks, not how the cell works.")
	o.add_button("ATP particles: " + ("On" if settings.show_atp_particles else "Off"), _toggle_atp_particles)
	o.add_button("Reduced motion: " + ("On" if settings.reduced_motion else "Off"), _toggle_reduced_motion)
	o.add_button("Text size: " + GameSettings.TEXT_NAMES[settings.text_size], _cycle_text_size)
	o.add_button("Level: %d (changing it restarts)" % level, _cycle_level)
	o.add_button("Close", _close_top)
	_push_overlay(o)
	if focus_index >= 0 and focus_index < o.buttons.size():
		o.buttons[focus_index].grab_focus()


func _toggle_atp_particles() -> void:
	settings.show_atp_particles = not settings.show_atp_particles
	settings.save()
	cell_view.apply_settings()
	_show_settings(0)
	announcer.say("ATP particles " + ("on" if settings.show_atp_particles else "off"))


func _toggle_reduced_motion() -> void:
	settings.reduced_motion = not settings.reduced_motion
	settings.reduced_motion_chosen = true
	settings.save()
	cell_view.apply_settings()
	_show_settings(1)
	announcer.say("Reduced motion " + ("on" if settings.reduced_motion else "off"))


func _cycle_text_size() -> void:
	settings.text_size = (settings.text_size + 1) % GameSettings.TEXT_SCALES.size()
	settings.save()
	apply_layout()
	_show_settings(2)
	announcer.say("Text size " + GameSettings.TEXT_NAMES[settings.text_size])


func _cycle_level() -> void:
	var next: int = level % LevelConfigs.LEVEL_COUNT + 1
	settings.start_level = next
	load_level(next)


# --- Play ---
func _on_organelle_pressed(id: int) -> void:
	if not is_running():
		return
	var o: SimulationModel.Org = model.find(id)
	if o == null:
		return
	var kind: String = o.kind
	var reason: String = model.try_divide(id)
	if reason == "":
		_handle_events()
		_check_beats()
		var kind_name: String = "Chloroplast" if kind == SimulationModel.KIND_CHLORO else "Mitochondrion"
		announcer.say("%s divided. %d mitochondria, %d chloroplasts." % [kind_name,
			model.count(SimulationModel.KIND_MITO), model.count(SimulationModel.KIND_CHLORO)])
		return
	var text: String = Tutorials.block_text(reason, model.division_atp_cost(kind), model.division_protein_cost(kind))
	if text != "":
		cell_view.show_float(id, text, reason == "not_ready")
		announcer.alert(text)


func _on_organelle_focused(id: int) -> void:
	if cell_view.buttons.has(id):
		var b: OrganelleButton = cell_view.buttons[id]
		announcer.say(b.describe())


func _handle_events() -> void:
	for e: String in model.take_events():
		if e.begins_with("divided"):
			_divided_once = true
			cell_view.sync_organelles()
			_queue_event_beats("divided")
			continue
		_queue_event_beats(e)
		match e:
			"check_started":
				announcer.say("Check started.")
			"night_first":
				cell_view.show_toast(Tutorials.NIGHT_BANNER, 7.0)
				announcer.say(Tutorials.NIGHT_BANNER)
			"night_start":
				announcer.say("Night %d of %d." % [model.cycle_index() + 1, int(model.cfg["cycles"])])
			"day_start":
				announcer.say("Day %d of %d." % [model.cycle_index() + 1, int(model.cfg["cycles"])])
			"final_cycle_started":
				cell_view.show_toast("Final day and night: keep protein production at 2 per second for 8 seconds.", 6.0)
			"protein_goal_met":
				cell_view.show_toast("Protein goal met. Now keep the cell going until dawn.", 5.0)
				announcer.say("Protein goal met.")
			"crisis_start":
				cell_view.show_toast("ATP crisis: the cell is running out of energy.", 4.0)
				announcer.alert("ATP crisis.")
			"won":
				_show_result_card(true)
			"failed":
				_show_result_card(false)


func _queue_event_beats(event_name: String) -> void:
	for b: Dictionary in Tutorials.beats_for(level):
		if str(b["trigger"]) == "event" and str(b["event"]) == event_name:
			_queue_beat(b)


func _queue_beat(b: Dictionary) -> void:
	var id: String = str(b["id"])
	if _shown_beats.has(id):
		return
	_shown_beats[id] = true
	_pending_beats.append(b)


func _check_beats() -> void:
	if model.is_finished():
		_pending_beats.clear()
		return
	for b: Dictionary in Tutorials.beats_for(level):
		if _shown_beats.has(str(b["id"])):
			continue
		var trigger: String = str(b["trigger"])
		if trigger == "time" and model.time >= float(b["at"]):
			if bool(b.get("skip_if_divided", false)) and _divided_once:
				_shown_beats[str(b["id"])] = true
			else:
				_queue_beat(b)
		elif trigger == "mito" and model.count(SimulationModel.KIND_MITO) >= int(b["count"]):
			_queue_beat(b)
		elif trigger == "space" and model.space_used() >= int(b["count"]):
			_queue_beat(b)
	if overlays.is_empty():
		_show_next_beat()


func _show_next_beat() -> void:
	if _pending_beats.is_empty() or not overlays.is_empty() or model.is_finished():
		return
	var b: Dictionary = _pending_beats.pop_front()
	var o: OverlayPanel = _new_overlay("tutorial", true, true, 0.0)
	o.preferred_width = 500.0
	o.arm_delay = 0.6
	o.set_text("", str(b["text"]))
	o.add_button("Got it", _close_top)
	var organelles: String = str(b.get("organelles", ""))
	var meters: Array = b.get("meters", [])
	cell_view.set_emphasis({
		"glyphs": b.get("glyphs", []),
		"organelles": organelles,
		"starch": bool(b.get("starch", false)),
		"ribosomes": bool(b.get("ribosomes", false)),
	})
	hud.set_highlight(meters)
	if organelles != "":
		o.target_organelles = organelles
	elif bool(b.get("starch", false)):
		o.target_organelles = SimulationModel.KIND_CHLORO
	o.avoid_target = o.target_organelles != ""
	if not meters.is_empty():
		o.target_meter = str(meters[0])
	_push_overlay(o)
	announcer.say(str(b["text"]))
	print("cell-designer: callout %s" % str(b["id"]))
