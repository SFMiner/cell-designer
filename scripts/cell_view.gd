class_name CellView
extends Control
## Draws the living cell cutaway and hosts the organelle buttons and the cosmetic molecule layer.
## Everything here is presentation of SimulationModel state; the only thing it sends back is
## "the player pressed organelle N".

# === SIGNALS ===
signal organelle_pressed(id: int)
signal organelle_focused(id: int)

# === CONSTANTS ===
const FISSION_SECONDS: float = 0.7
const ANIMAL_CYTOPLASM: Color = Color(0.96, 0.90, 0.78, 1)
const PLANT_CYTOPLASM: Color = Color(0.88, 0.94, 0.78, 1)
const NIGHT_TINT: Color = Color(0.50, 0.56, 0.68, 1)
const BACKDROP: Color = Color(0.09, 0.13, 0.18, 1)

# === PUBLIC VARIABLES ===
var model: SimulationModel = null
var settings: GameSettings = null
var molecules: MoleculeVisuals = null
## Smallest allowed organelle hit size in this control's pixels (44 CSS px).
var min_hit: float = 44.0
var cell_scale: float = 1.0
var cell_origin: Vector2 = Vector2.ZERO
## id -> OrganelleButton
var buttons: Dictionary = {}
## Tutorial emphasis: {"glyphs": Array, "organelles": String, "starch": bool, "ribosomes": bool}.
var emphasis: Dictionary = {}

# === PRIVATE VARIABLES ===
var _fx: Control = null
var _pump_phase: float = 0.0
var _vesicle_phase: float = 0.0
var _ribosome_phase: float = 0.0
var _repair_phase: float = 0.0
var _night_mix: float = 0.0
var _pulse_time: float = 0.0
var _floats: Array[Dictionary] = []
var _toast_text: String = ""
var _toast_time: float = 0.0


# === LIFECYCLE METHODS ===
func _init() -> void:
	clip_contents = true
	molecules = MoleculeVisuals.new()
	molecules.name = "Molecules"
	add_child(molecules)
	_fx = Control.new()
	_fx.name = "Fx"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout_cell()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	if model == null:
		return
	draw_set_transform(cell_origin, 0.0, Vector2(cell_scale, cell_scale))
	var plant: bool = model.layout.cell_type == "plant"
	var cyto: Color = (PLANT_CYTOPLASM if plant else ANIMAL_CYTOPLASM).lerp(NIGHT_TINT, _night_mix * 0.75)
	if plant:
		_draw_plant_cell(cyto)
	else:
		_draw_animal_cell(cyto)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# From here on positions are converted with to_view(): the art helpers set their own transforms.
	_draw_activities(plant)
	if not emphasis.is_empty():
		# Dim the scenery so the emphasised items stand out (they are drawn above this veil).
		draw_rect(Rect2(cell_origin, OrganelleLayout.CELL_SIZE * cell_scale), Color(0.05, 0.08, 0.12, 0.22))
	if bool(model.cfg["protein_enabled"]):
		_draw_ribosomes()


# === PUBLIC METHODS ===
## Shows a new model (level load or restart). Nothing animates until advance() is called.
func set_model(p_model: SimulationModel) -> void:
	model = p_model
	for id: Variant in buttons.keys():
		var b: OrganelleButton = buttons[id]
		b.queue_free()
	buttons.clear()
	_floats.clear()
	_toast_text = ""
	_toast_time = 0.0
	_pump_phase = 0.0
	_vesicle_phase = 0.0
	_ribosome_phase = 0.0
	_repair_phase = 0.0
	_night_mix = 0.0
	_pulse_time = 0.0
	emphasis = {}
	layout_cell()
	sync_organelles()
	molecules.reset(model)
	apply_settings()
	queue_redraw()
	_fx.queue_redraw()


func apply_settings() -> void:
	if settings == null:
		return
	molecules.show_atp = settings.show_atp_particles
	molecules.reduced_motion = settings.reduced_motion
	for id: Variant in buttons.keys():
		var b: OrganelleButton = buttons[id]
		b.reduced_motion = settings.reduced_motion
		b.queue_redraw()
	molecules.queue_redraw()


## Fits the logical cell into this control and repositions every organelle.
func layout_cell() -> void:
	var pad: float = 6.0
	var avail: Vector2 = Vector2(maxf(size.x - pad * 2.0, 10.0), maxf(size.y - pad * 2.0, 10.0))
	var cs: Vector2 = OrganelleLayout.CELL_SIZE
	cell_scale = minf(avail.x / cs.x, avail.y / cs.y)
	cell_origin = (size - cs * cell_scale) * 0.5
	molecules.position = Vector2.ZERO
	molecules.size = size
	molecules.cell_scale = cell_scale
	molecules.cell_origin = cell_origin
	_fx.position = Vector2.ZERO
	_fx.size = size
	if model == null:
		return
	for id: Variant in buttons.keys():
		_place_button(buttons[id])
	queue_redraw()
	molecules.queue_redraw()
	_fx.queue_redraw()


## Local position of a logical cell point.
func to_view(p: Vector2) -> Vector2:
	return cell_origin + p * cell_scale


## Creates buttons for new organelles and removes buttons whose organelle is gone.
func sync_organelles() -> void:
	if model == null:
		return
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_slot: int = -1
	var alive: Dictionary = {}
	for o: SimulationModel.Org in model.organelles:
		alive[o.id] = true
	for id: Variant in buttons.keys():
		if alive.has(id):
			continue
		var old: OrganelleButton = buttons[id]
		if old == focused:
			focus_slot = old.org.slot
		buttons.erase(id)
		old.queue_free()
	for o: SimulationModel.Org in model.organelles:
		if buttons.has(o.id):
			continue
		var b: OrganelleButton = OrganelleButton.new()
		b.org = o
		b.name = "Organelle%d" % o.id
		b.reduced_motion = settings != null and settings.reduced_motion
		var fresh: bool = o.parent_slot >= 0 and model.time - o.born_at < 0.2
		b.birth = 0.0 if (fresh and not b.reduced_motion) else 1.0
		b.pressed.connect(_on_button_pressed.bind(o.id))
		b.focus_entered.connect(_on_button_focused.bind(o.id))
		add_child(b)
		move_child(b, _fx.get_index())
		buttons[o.id] = b
		_place_button(b)
		if focus_slot >= 0 and o.slot == focus_slot:
			b.grab_focus()
	_apply_emphasis()


## Organelle buttons in reading order (top-left to bottom-right), for the Tab ring.
func ordered_buttons() -> Array[Control]:
	var out: Array[Control] = []
	if model == null:
		return out
	var by_slot: Dictionary = {}
	var slot_list: Array[int] = []
	for o: SimulationModel.Org in model.organelles:
		if buttons.has(o.id):
			by_slot[o.slot] = buttons[o.id]
			slot_list.append(o.slot)
	for s: int in model.layout.reading_order(slot_list):
		out.append(by_slot[s])
	return out


func set_emphasis(e: Dictionary) -> void:
	emphasis = e
	_apply_emphasis()
	queue_redraw()
	molecules.queue_redraw()


## Global-canvas centre of the first organelle of `kind`, or of this view if there is none.
func emphasis_point(kind: String) -> Vector2:
	for b: Control in ordered_buttons():
		var ob: OrganelleButton = b
		if ob.org.kind == kind:
			return ob.global_position + ob.size * 0.5
	return global_position + size * 0.5


## Brief text above an organelle (blocked division reasons). `clock` adds the "not ready" pictogram.
func show_float(id: int, text: String, clock: bool) -> void:
	if not buttons.has(id):
		return
	var b: OrganelleButton = buttons[id]
	if clock:
		b.clock_time = 1.4
		b.bump = 0.35
	_floats.append({"text": text, "pos": b.position + Vector2(b.size.x * 0.5, 0.0), "time": 1.6})
	b.queue_redraw()
	_fx.queue_redraw()


## A one-line non-blocking banner at the bottom of the cell.
func show_toast(text: String, seconds: float) -> void:
	_toast_text = text
	_toast_time = seconds
	_fx.queue_redraw()


## Advances every animation by `dt` seconds of visible game time. Never called before Start or while paused.
func advance(dt: float) -> void:
	if model == null or dt <= 0.0:
		return
	var reduced: bool = settings != null and settings.reduced_motion
	var act: float = model.activity
	if not reduced:
		_pump_phase += dt * act * 0.9
		_vesicle_phase += dt * act * 0.07
		_repair_phase += dt * act * 0.5
		var max_rate: float = float(model.cfg["protein_max_rate"])
		if max_rate > 0.0:
			_ribosome_phase += dt * (model.protein_rate / max_rate) * 0.9
	var night_target: float = 0.0 if model.is_day() else 1.0
	_night_mix = night_target if reduced else move_toward(_night_mix, night_target, dt * 1.2)
	_advance_feedback(dt)
	molecules.advance(dt)
	_refresh_buttons(dt)
	queue_redraw()
	_fx.queue_redraw()


## Runs only the tutorial highlight pulse and message timers (used while a tutorial pop-up has paused the level).
func advance_highlight(dt: float) -> void:
	if settings != null and settings.reduced_motion:
		return
	_pulse_time += dt
	_refresh_buttons(0.0)
	queue_redraw()


# === PRIVATE METHODS ===
func _advance_feedback(dt: float) -> void:
	_pulse_time += dt
	if _toast_time > 0.0:
		_toast_time = maxf(0.0, _toast_time - dt)
	var i: int = _floats.size() - 1
	while i >= 0:
		_floats[i]["time"] = float(_floats[i]["time"]) - dt
		if float(_floats[i]["time"]) <= 0.0:
			_floats.remove_at(i)
		i -= 1


func _refresh_buttons(dt: float) -> void:
	var reduced: bool = settings != null and settings.reduced_motion
	var pulse: float = 0.0 if reduced else 0.5 + 0.5 * sin(_pulse_time * 4.0)
	var n_chloro: int = model.count(SimulationModel.KIND_CHLORO)
	var starch_frac: float = 0.0
	if n_chloro > 0 and bool(model.cfg["starch_enabled"]):
		starch_frac = model.starch / float(model.cfg["starch_cap"])
	for id: Variant in buttons.keys():
		var b: OrganelleButton = buttons[id]
		if b.birth < 1.0:
			b.birth = minf(1.0, b.birth + dt / FISSION_SECONDS)
		if b.bump > 0.0:
			b.bump = maxf(0.0, b.bump - dt)
		if b.clock_time > 0.0:
			b.clock_time = maxf(0.0, b.clock_time - dt)
		b.pulse = pulse
		b.starch_fraction = starch_frac
		b.queue_redraw()


func _apply_emphasis() -> void:
	var kind: String = str(emphasis.get("organelles", ""))
	var starch: bool = bool(emphasis.get("starch", false))
	for id: Variant in buttons.keys():
		var b: OrganelleButton = buttons[id]
		b.emphasized = kind != "" and b.org.kind == kind
		b.dimmed = (kind != "" and b.org.kind != kind) or (starch and b.org.kind != SimulationModel.KIND_CHLORO)
		b.starch_emphasis = starch
		b.queue_redraw()
	molecules.emphasis = emphasis.get("glyphs", [])


func _place_button(b: OrganelleButton) -> void:
	var unit: float = model.layout.spacing * cell_scale
	var side: float = maxf(unit, min_hit)
	var centre: Vector2 = to_view(model.layout.slots[b.org.slot])
	b.unit = unit
	b.size = Vector2(side, side)
	b.position = centre - b.size * 0.5
	b.rot = (OrganelleLayout.slot_hash(b.org.slot, 7) - 0.5) * 0.9
	if b.org.parent_slot >= 0:
		b.from_offset = (model.layout.slots[b.org.parent_slot] - model.layout.slots[b.org.slot]) * cell_scale
	else:
		b.from_offset = Vector2.ZERO
	b.queue_redraw()


func _on_button_pressed(id: int) -> void:
	organelle_pressed.emit(id)


func _on_button_focused(id: int) -> void:
	organelle_focused.emit(id)


func _animal_outline() -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 72
	for i: int in range(steps):
		var a: float = TAU * float(i) / float(steps)
		pts.append(OrganelleLayout.ANIMAL_CENTER + Vector2(cos(a), sin(a)) * OrganelleLayout.ANIMAL_RADII * _wobble(a))
	return pts


## The animal cell's slightly irregular outline, as a factor on the ellipse radius (stays inside the logical box).
func _wobble(a: float) -> float:
	return 1.012 + 0.008 * sin(a * 3.0 + 1.0) + 0.006 * sin(a * 5.0 + 0.4)


func _rounded_rect(r: Rect2, radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [
		Vector2(r.end.x - radius, r.position.y + radius), Vector2(r.end.x - radius, r.end.y - radius),
		Vector2(r.position.x + radius, r.end.y - radius), Vector2(r.position.x + radius, r.position.y + radius)]
	for ci: int in range(4):
		var start: float = -PI * 0.5 + PI * 0.5 * float(ci)
		for i: int in range(7):
			var a: float = start + PI * 0.5 * float(i) / 6.0
			pts.append(corners[ci] + Vector2(cos(a), sin(a)) * radius)
	return pts


func _draw_animal_cell(cyto: Color) -> void:
	var tex: Texture2D = PlaceholderArt.texture("animal_cell_outline")
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, OrganelleLayout.CELL_SIZE), false)
		return
	var outline: PackedVector2Array = _animal_outline()
	draw_colored_polygon(outline, cyto)
	var closed: PackedVector2Array = PlaceholderArt.closed(outline)
	draw_polyline(closed, Color(0.66, 0.47, 0.25, 1), 9.0, true)
	draw_polyline(closed, Color(0.30, 0.20, 0.10, 1), 2.0, true)


func _draw_plant_cell(cyto: Color) -> void:
	var wall_tex: Texture2D = PlaceholderArt.texture("plant_cell_outline")
	if wall_tex != null:
		draw_texture_rect(wall_tex, Rect2(Vector2.ZERO, OrganelleLayout.CELL_SIZE), false)
	else:
		var wall: PackedVector2Array = _rounded_rect(Rect2(Vector2(4.0, 4.0), OrganelleLayout.CELL_SIZE - Vector2(8.0, 8.0)), 44.0)
		draw_colored_polygon(wall, Color(0.38, 0.55, 0.27, 1))
		draw_polyline(PlaceholderArt.closed(wall), Color(0.12, 0.26, 0.10, 1), 3.0, true)
		var inner: PackedVector2Array = _rounded_rect(OrganelleLayout.PLANT_INNER.grow(6.0), 30.0)
		draw_colored_polygon(inner, cyto)
		draw_polyline(PlaceholderArt.closed(inner), Color(0.62, 0.50, 0.22, 1), 4.0, true)
	var vac_tex: Texture2D = PlaceholderArt.texture("plant_vacuole")
	var vr: Vector2 = OrganelleLayout.VACUOLE_RADII
	if vac_tex != null:
		draw_texture_rect(vac_tex, Rect2(OrganelleLayout.VACUOLE_CENTER - vr, vr * 2.0), false)
		return
	var vac: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in PlaceholderArt.ellipse_points(vr.x, vr.y, 48):
		vac.append(OrganelleLayout.VACUOLE_CENTER + p)
	draw_colored_polygon(vac, Color(0.74, 0.87, 0.94, 0.9).lerp(NIGHT_TINT, _night_mix * 0.5))
	draw_polyline(PlaceholderArt.closed(vac), Color(0.22, 0.42, 0.58, 1), 3.0, true)


## Points on the membrane for pumps and the repair patch: [position, outward normal].
func _membrane_points(plant: bool) -> Array:
	var out: Array = []
	if plant:
		var r: Rect2 = OrganelleLayout.PLANT_INNER.grow(6.0)
		out.append([Vector2(r.position.x + r.size.x * 0.30, r.position.y), Vector2.UP])
		out.append([Vector2(r.position.x + r.size.x * 0.72, r.end.y), Vector2.DOWN])
		out.append([Vector2(r.position.x, r.position.y + r.size.y * 0.62), Vector2.LEFT])
		out.append([Vector2(r.end.x, r.position.y + r.size.y * 0.36), Vector2.RIGHT])
	else:
		for a: float in [0.55, 2.2, 3.6, 5.3]:
			var dir: Vector2 = Vector2(cos(a), sin(a))
			var p: Vector2 = OrganelleLayout.ANIMAL_CENTER + dir * OrganelleLayout.ANIMAL_RADII * _wobble(a)
			var n: Vector2 = (dir / OrganelleLayout.ANIMAL_RADII).normalized()
			out.append([p, n])
	return out


## Background ATP-dependent activity: ion pumps, transport vesicles and membrane repair.
## Their speed follows model.activity, so the cell visibly slows when ATP is short.
func _draw_activities(plant: bool) -> void:
	var points: Array = _membrane_points(plant)
	for i: int in range(points.size()):
		var entry: Array = points[i]
		var p: Vector2 = to_view(entry[0])
		var n: Vector2 = entry[1]
		if i == points.size() - 1:
			_draw_repair(p, n)
		else:
			PlaceholderArt.draw_pump(self, p, n, 15.0 * cell_scale, _pump_phase + float(i) * 0.37)
	var centre: Vector2 = OrganelleLayout.CELL_SIZE * 0.5
	var path: Vector2 = Vector2(330.0, 170.0) if plant else Vector2(300.0, 150.0)
	for v: int in range(2):
		var u: float = (_vesicle_phase + float(v) * 0.5) * TAU
		PlaceholderArt.draw_vesicle(self, to_view(centre + Vector2(cos(u) * path.x, sin(u) * path.y)), 12.0 * cell_scale)


func _draw_repair(p: Vector2, n: Vector2) -> void:
	var tex: Texture2D = PlaceholderArt.texture("membrane_repair_patch")
	if tex != null:
		PlaceholderArt.draw_fitted(self, tex, p, Vector2(44.0, 44.0) * cell_scale, n.angle() + PI * 0.5, Color.WHITE)
		return
	var t: Vector2 = n.orthogonal() * cell_scale
	n = n * cell_scale
	draw_line(p - t * 24.0, p + t * 24.0, Color(0.95, 0.80, 0.45, 1), 9.0 * cell_scale, true)
	# Stitches appear one by one as the patch is repaired, then the cycle repeats.
	var done: int = int(fposmod(_repair_phase, 1.0) * 5.0)
	for i: int in range(5):
		var q: Vector2 = p + t * (float(i) - 2.0) * 10.0
		var col: Color = PlaceholderArt.INK if i <= done else Color(PlaceholderArt.INK, 0.25)
		draw_line(q - n * 6.0, q + n * 6.0, col, 2.0, true)


func _draw_ribosomes() -> void:
	var em: bool = bool(emphasis.get("ribosomes", false))
	var pts: Array[Vector2] = model.layout.ribosome_points
	for i: int in range(pts.size()):
		var p: Vector2 = to_view(pts[i])
		if em:
			draw_circle(p, 30.0 * cell_scale, Color(PlaceholderArt.PAPER, 0.9))
			draw_arc(p, 30.0 * cell_scale, 0.0, TAU, 28, PlaceholderArt.INK, 3.5, true)
		PlaceholderArt.draw_ribosome(self, p, 17.0 * cell_scale, fposmod(_ribosome_phase + float(i) * 0.31, 1.0))


func _draw_fx() -> void:
	if model == null:
		return
	var font: Font = ThemeDB.fallback_font
	# Day or night, as a pictogram and a word (never colour alone).
	if bool(model.cfg["day_night"]):
		var day: bool = model.is_day()
		var plate: Rect2 = Rect2(8.0, 8.0, 92.0, 30.0)
		_fx.draw_rect(plate, Color(0.08, 0.12, 0.17, 0.92))
		_fx.draw_rect(plate, Color(1, 1, 1, 0.8), false, 1.5)
		if day:
			PlaceholderArt.draw_sun(_fx, plate.position + Vector2(17.0, 15.0), 10.0, Color(1.0, 0.86, 0.35, 1))
		else:
			PlaceholderArt.draw_moon(_fx, plate.position + Vector2(17.0, 15.0), 10.0, Color(0.92, 0.94, 1.0, 1), Color(0.08, 0.12, 0.17, 1))
		_fx.draw_string(font, plate.position + Vector2(34.0, 21.0), "Day" if day else "Night", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color.WHITE)
	for f: Dictionary in _floats:
		var text: String = str(f["text"])
		var t: float = float(f["time"])
		var reduced: bool = settings != null and settings.reduced_motion
		var rise: float = 0.0 if reduced else (1.6 - t) * 10.0
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x + 14.0
		var pos: Vector2 = f["pos"]
		var r: Rect2 = Rect2(pos.x - w * 0.5, pos.y - 22.0 - rise, w, 22.0)
		r.position.x = clampf(r.position.x, 2.0, maxf(2.0, size.x - w - 2.0))
		r.position.y = maxf(r.position.y, 2.0)
		_fx.draw_rect(r, Color(0.08, 0.12, 0.17, 0.95))
		_fx.draw_rect(r, Color.WHITE, false, 1.5)
		_fx.draw_string(font, r.position + Vector2(7.0, 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)
	if _toast_time > 0.0 and _toast_text != "":
		var max_w: float = maxf(size.x - 24.0, 60.0)
		var ts: Vector2 = font.get_multiline_string_size(_toast_text, HORIZONTAL_ALIGNMENT_LEFT, max_w - 20.0, 14)
		var box: Rect2 = Rect2((size.x - ts.x - 20.0) * 0.5, size.y - ts.y - 22.0, ts.x + 20.0, ts.y + 12.0)
		_fx.draw_rect(box, Color(0.08, 0.12, 0.17, 0.95))
		_fx.draw_rect(box, Color.WHITE, false, 1.5)
		_fx.draw_multiline_string(font, box.position + Vector2(10.0, 6.0 + font.get_ascent(14)), _toast_text,
			HORIZONTAL_ALIGNMENT_LEFT, max_w - 20.0, 14, -1, Color.WHITE)
