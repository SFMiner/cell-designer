class_name MoleculeVisuals
extends Control
## Cosmetic molecule glyphs drifting in the cytoplasm. Illustration only:
## - Counts follow the model's stocks approximately; they are never read back into the model.
## - It uses its own RNG, so showing, hiding or animating particles cannot change any outcome.
## - It ignores the mouse, and is drawn underneath the organelles.
## Positions are kept in the layout's logical cell units and scaled by the cell view.

# === INNER CLASSES ===
class Particle:
	extends RefCounted
	var kind: String = ""
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var alpha: float = 0.0
	## 0 = present, 1 = leaving (fading toward `dest`), 2 = short-lived product (CO2, water).
	var state: int = 0
	var life: float = 0.0
	var dest: Vector2 = Vector2.ZERO


# === CONSTANTS ===
const MAX_PER_KIND: int = 12
const MAX_PRODUCTS: int = 16
## Total cap on cosmetic particles (GDD: about 100).
const MAX_TOTAL: int = 100
const BASE_OPACITY: float = 0.34
const STOCK_KINDS: Array[String] = ["glucose", "oxygen", "amino", "protein", "atp"]
const LABELS: Dictionary = {"oxygen": "O2", "co2": "CO2", "water": "H2O"}

# === PUBLIC VARIABLES ===
var model: SimulationModel = null
var cell_scale: float = 1.0
var cell_origin: Vector2 = Vector2.ZERO
var show_atp: bool = true
var reduced_motion: bool = false
## Molecule kinds currently emphasised by a tutorial (bold outline, others fade back).
var emphasis: Array = []
var particles: Array[Particle] = []

# === PRIVATE VARIABLES ===
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _adjust_timer: float = 0.0
var _co2_acc: float = 0.0
var _water_acc: float = 0.0


# === LIFECYCLE METHODS ===
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_rng.seed = 20261114


func _draw() -> void:
	if model == null:
		return
	var font: Font = ThemeDB.fallback_font
	var g_size: float = clampf(8.5 * cell_scale / 0.75, 6.0, 11.0)
	var has_emphasis: bool = not emphasis.is_empty()
	for p: Particle in particles:
		if p.kind == "atp" and not show_atp:
			continue
		var em: bool = has_emphasis and emphasis.has(p.kind)
		var a: float = p.alpha * BASE_OPACITY
		if em:
			a = maxf(p.alpha, 0.5) * 0.95
		elif has_emphasis:
			a *= 0.5
		var c: Vector2 = cell_origin + p.pos * cell_scale
		PlaceholderArt.draw_glyph(self, p.kind, c, g_size, a, em)
		if LABELS.has(p.kind):
			PlaceholderArt.draw_formula(self, font, c + Vector2(g_size * 1.1, g_size * 0.45), str(LABELS[p.kind]),
				10, Color(PlaceholderArt.INK, minf(1.0, a * 1.6)))


# === PUBLIC METHODS ===
## Clears everything and fills the cell to match the model's starting stocks (no animation).
func reset(p_model: SimulationModel) -> void:
	model = p_model
	particles.clear()
	_rng.seed = 20261114
	_adjust_timer = 0.0
	_co2_acc = 0.0
	_water_acc = 0.0
	if model == null:
		return
	for kind: String in STOCK_KINDS:
		var want: int = _desired(kind)
		for i: int in range(want):
			var p: Particle = _new_particle(kind, _random_inside())
			p.alpha = 1.0
			particles.append(p)
	queue_redraw()


## Advances the cosmetic layer by `dt` seconds of visible game time.
func advance(dt: float) -> void:
	if model == null or dt <= 0.0:
		return
	_adjust_timer -= dt
	if _adjust_timer <= 0.0:
		_adjust_timer = 0.12
		for kind: String in STOCK_KINDS:
			_adjust(kind)
	_emit_products(dt)
	var i: int = particles.size() - 1
	while i >= 0:
		var p: Particle = particles[i]
		if _step(p, dt):
			particles.remove_at(i)
		i -= 1
	queue_redraw()


func count_of(kind: String) -> int:
	var n: int = 0
	for p: Particle in particles:
		if p.kind == kind and p.state == 0:
			n += 1
	return n


# === PRIVATE METHODS ===
func _desired(kind: String) -> int:
	var cfg: Dictionary = model.cfg
	var frac: float = 0.0
	match kind:
		"glucose":
			frac = model.glucose / float(cfg["glucose_cap"])
		"oxygen":
			frac = model.oxygen / float(cfg["oxygen_cap"])
		"amino":
			frac = model.amino / float(cfg["amino_cap"]) if bool(cfg["protein_enabled"]) else 0.0
		"protein":
			frac = model.protein / float(cfg["protein_cap"]) if bool(cfg["protein_enabled"]) else 0.0
		"atp":
			frac = model.atp / float(cfg["atp_cap"])
	return clampi(int(round(frac * float(MAX_PER_KIND))), 0, MAX_PER_KIND)


func _adjust(kind: String) -> void:
	var have: int = count_of(kind)
	var want: int = _desired(kind)
	if have < want and particles.size() < MAX_TOTAL:
		var p: Particle = _new_particle(kind, _entry_point(kind))
		if reduced_motion:
			p.pos = _random_inside()
			p.alpha = 1.0
		particles.append(p)
	elif have > want:
		for p: Particle in particles:
			if p.kind == kind and p.state == 0:
				p.state = 1
				p.life = 0.8
				p.dest = _sink_point(kind, p.pos)
				break


func _emit_products(dt: float) -> void:
	# Carbon dioxide and water appear near mitochondria while respiration runs.
	var rate: float = model.respiration_now / 16.0
	_co2_acc += rate * dt * 1.6
	_water_acc += rate * dt * 1.2
	var mitos: Array[Vector2] = _organelle_points(SimulationModel.KIND_MITO)
	if mitos.is_empty():
		_co2_acc = 0.0
		_water_acc = 0.0
		return
	while _co2_acc >= 1.0:
		_co2_acc -= 1.0
		_spawn_product("co2", mitos[_rng.randi_range(0, mitos.size() - 1)], 3.4)
	while _water_acc >= 1.0:
		_water_acc -= 1.0
		_spawn_product("water", mitos[_rng.randi_range(0, mitos.size() - 1)], 1.8)


func _spawn_product(kind: String, at: Vector2, life: float) -> void:
	var existing: int = 0
	for q: Particle in particles:
		if q.state == 2:
			existing += 1
	if existing >= MAX_PRODUCTS or particles.size() >= MAX_TOTAL:
		return
	var p: Particle = _new_particle(kind, at + Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 20.0)))
	p.state = 2
	p.life = life
	p.alpha = 1.0 if reduced_motion else 0.0
	if kind == "co2":
		# Carbon dioxide heads for a chloroplast in daylight (it is used in photosynthesis), otherwise out of the cell.
		var chloros: Array[Vector2] = _organelle_points(SimulationModel.KIND_CHLORO)
		var target: Vector2 = at + (at - OrganelleLayout.CELL_SIZE * 0.5).normalized() * 400.0
		if not chloros.is_empty() and model.is_day():
			target = chloros[_rng.randi_range(0, chloros.size() - 1)]
		p.vel = (target - p.pos).normalized() * 46.0
	else:
		# Water barely moves: it mixes into the surrounding fluid and fades from view.
		p.vel = Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0))
	if reduced_motion:
		p.vel = Vector2.ZERO
	particles.append(p)


## Moves one particle. Returns true when it should be removed.
func _step(p: Particle, dt: float) -> bool:
	if p.state == 2:
		p.life -= dt
		if p.life <= 0.0:
			return true
		p.pos += p.vel * dt
		if not reduced_motion:
			p.alpha = clampf(minf(p.alpha + dt * 3.0, p.life / 0.9), 0.0, 1.0)
		return false
	if p.state == 1:
		if reduced_motion:
			return true
		p.life -= dt
		p.pos = p.pos.lerp(p.dest, clampf(dt * 3.0, 0.0, 1.0))
		p.alpha = clampf(p.life / 0.8, 0.0, 1.0)
		return p.life <= 0.0
	if reduced_motion:
		p.alpha = 1.0
		return false
	p.alpha = minf(1.0, p.alpha + dt * 1.5)
	p.vel = p.vel.rotated(_rng.randf_range(-0.6, 0.6) * dt)
	var next: Vector2 = p.pos + p.vel * dt
	if model.layout.is_inside(next, 16.0):
		p.pos = next
	else:
		# Turn back toward the middle of the cytoplasm.
		var home: Vector2 = _home_point()
		p.vel = (home - p.pos).normalized().rotated(_rng.randf_range(-0.7, 0.7)) * p.vel.length()
		p.pos += p.vel * dt
	return false


func _new_particle(kind: String, at: Vector2) -> Particle:
	var p: Particle = Particle.new()
	p.kind = kind
	p.pos = at
	var speed: float = _rng.randf_range(9.0, 20.0)
	p.vel = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * speed
	return p


func _home_point() -> Vector2:
	if model.layout.cell_type == "plant":
		# Not the vacuole: aim at a random slot instead.
		var slots: Array[Vector2] = model.layout.slots
		if not slots.is_empty():
			return slots[_rng.randi_range(0, slots.size() - 1)]
	return OrganelleLayout.CELL_SIZE * 0.5


func _random_inside() -> Vector2:
	for attempt: int in range(40):
		var p: Vector2 = Vector2(_rng.randf_range(0.0, OrganelleLayout.CELL_SIZE.x),
			_rng.randf_range(0.0, OrganelleLayout.CELL_SIZE.y))
		if model.layout.is_inside(p, 18.0):
			return p
	return _home_point()


func _organelle_points(kind: String) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for o: SimulationModel.Org in model.organelles:
		if o.kind == kind:
			pts.append(model.layout.slots[o.slot])
	return pts


## Where a new particle of `kind` appears.
func _entry_point(kind: String) -> Vector2:
	if kind == "protein":
		var ribs: Array[Vector2] = model.layout.ribosome_points
		if not ribs.is_empty():
			return ribs[_rng.randi_range(0, ribs.size() - 1)]
	elif kind == "atp":
		var mitos: Array[Vector2] = _organelle_points(SimulationModel.KIND_MITO)
		if not mitos.is_empty():
			return mitos[_rng.randi_range(0, mitos.size() - 1)]
	elif kind == "glucose" or kind == "oxygen":
		# In the plant cell by day, sugar and oxygen come out of chloroplasts.
		var chloros: Array[Vector2] = _organelle_points(SimulationModel.KIND_CHLORO)
		if not chloros.is_empty() and (kind == "glucose" or model.is_day()):
			return chloros[_rng.randi_range(0, chloros.size() - 1)]
	return _edge_point()


## A point just inside the cell boundary (supplies diffuse in from outside).
func _edge_point() -> Vector2:
	var centre: Vector2 = OrganelleLayout.CELL_SIZE * 0.5
	var dir: Vector2 = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	var p: Vector2 = centre
	var reach: Vector2 = centre
	# Walk outward from a point known to be inside until the boundary is reached.
	var start: Vector2 = _home_point()
	p = start
	for i: int in range(60):
		var next: Vector2 = p + dir * 12.0
		if not model.layout.is_inside(next, 16.0):
			break
		p = next
		reach = p
	return reach if reach != centre else p


## Where a used-up particle of `kind` heads as it fades.
func _sink_point(kind: String, from: Vector2) -> Vector2:
	var pts: Array[Vector2] = []
	if kind == "glucose" or kind == "oxygen":
		pts = _organelle_points(SimulationModel.KIND_MITO)
	elif kind == "amino":
		pts = model.layout.ribosome_points
	else:
		return from
	if pts.is_empty():
		return from
	var best: Vector2 = pts[0]
	for q: Vector2 in pts:
		if from.distance_squared_to(q) < from.distance_squared_to(best):
			best = q
	return best
