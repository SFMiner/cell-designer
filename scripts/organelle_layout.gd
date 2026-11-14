class_name OrganelleLayout
extends RefCounted
## Deterministic placement of organelles inside the cell cutaway.
## The cell lives in a fixed logical space of CELL_SIZE units; cell_view.gd scales it to the screen.
## Organelles sit in pre-computed slots (a hex grid clipped to the cytoplasm), so two
## organelles can never overlap each other, the boundary, or the plant vacuole, and "is there
## room?" is answered before any resource is spent.

# === CONSTANTS ===
const CELL_SIZE: Vector2 = Vector2(1000.0, 560.0)
const ANIMAL_CENTER: Vector2 = Vector2(500.0, 280.0)
const ANIMAL_RADII: Vector2 = Vector2(486.0, 266.0)
## Cytoplasm of the plant cell (inside wall and membrane).
const PLANT_INNER: Rect2 = Rect2(34.0, 30.0, 932.0, 500.0)
const VACUOLE_CENTER: Vector2 = Vector2(500.0, 280.0)
const VACUOLE_RADII: Vector2 = Vector2(205.0, 88.0)
const MIN_SPACING: float = 60.0

# === PUBLIC VARIABLES ===
var cell_type: String = "animal"
## Distance between slot centres, in logical units. Organelle art is sized from this.
var spacing: float = 100.0
var slots: Array[Vector2] = []
## Small decorative positions between slots (ribosomes).
var ribosome_points: Array[Vector2] = []


# === PUBLIC METHODS ===
## Builds at least `needed` slots, shrinking the spacing from `preferred_spacing` only if it must.
func build(type: String, preferred_spacing: float, needed: int) -> void:
	cell_type = type
	var s: float = preferred_spacing
	while true:
		slots = _make_slots(s)
		if slots.size() >= needed or s <= MIN_SPACING:
			break
		s -= 4.0
	spacing = s
	_make_ribosome_points()


## True if a circle of radius `margin` at `p` lies inside the cytoplasm (and clear of the vacuole).
func is_inside(p: Vector2, margin: float) -> bool:
	if cell_type == "plant":
		var r: Rect2 = PLANT_INNER.grow(-margin)
		if r.size.x <= 0.0 or r.size.y <= 0.0 or not r.has_point(p):
			return false
		var v: Vector2 = (p - VACUOLE_CENTER) / (VACUOLE_RADII + Vector2(margin, margin))
		return v.length_squared() > 1.0
	var radii: Vector2 = ANIMAL_RADII - Vector2(margin, margin)
	if radii.x <= 0.0 or radii.y <= 0.0:
		return false
	var e: Vector2 = (p - ANIMAL_CENTER) / radii
	return e.length_squared() <= 1.0


## The free slot closest to `from_slot`, or -1 when every slot is taken. `occupied` maps slot -> anything.
func nearest_free(from_slot: int, occupied: Dictionary) -> int:
	var best: int = -1
	var best_d: float = INF
	var origin: Vector2 = slots[from_slot]
	for i: int in range(slots.size()):
		if occupied.has(i):
			continue
		var d: float = origin.distance_squared_to(slots[i])
		if d < best_d - 0.001:
			best_d = d
			best = i
	return best


## `count` slots spread through the cell (farthest-point sampling), for the starting organelles.
func spread_slots(count: int) -> Array[int]:
	var chosen: Array[int] = []
	if slots.is_empty():
		return chosen
	var anchor: Vector2 = ANIMAL_CENTER if cell_type == "animal" else Vector2(210.0, 150.0)
	var first: int = 0
	var best_d: float = INF
	for i: int in range(slots.size()):
		var d: float = anchor.distance_squared_to(slots[i])
		if d < best_d:
			best_d = d
			first = i
	chosen.append(first)
	while chosen.size() < count and chosen.size() < slots.size():
		var pick: int = -1
		var pick_d: float = -1.0
		for i: int in range(slots.size()):
			if chosen.has(i):
				continue
			var nearest: float = INF
			for c: int in chosen:
				nearest = minf(nearest, slots[i].distance_squared_to(slots[c]))
			if nearest > pick_d + 0.001:
				pick_d = nearest
				pick = i
		chosen.append(pick)
	return chosen


## Slot indices in reading order (top row first, left to right), used for the Tab order.
func reading_order(slot_indices: Array[int]) -> Array[int]:
	var sorted: Array[int] = slot_indices.duplicate()
	var row_h: float = spacing * 0.6
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var ra: int = int(floorf(slots[a].y / row_h))
		var rb: int = int(floorf(slots[b].y / row_h))
		if ra != rb:
			return ra < rb
		if not is_equal_approx(slots[a].x, slots[b].x):
			return slots[a].x < slots[b].x
		return a < b)
	return sorted


## A stable pseudo-random value in 0..1 for a slot (art rotation, jitter). Not the simulation RNG.
static func slot_hash(index: int, salt: int) -> float:
	var h: int = (index * 73856093) ^ (salt * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 10007) / 10007.0


# === PRIVATE METHODS ===
func _make_slots(s: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var margin: float = s * 0.5
	var row_h: float = s * 0.8660254
	var rows: int = int(floorf((CELL_SIZE.y - s) / row_h)) + 1
	var y0: float = (CELL_SIZE.y - float(rows - 1) * row_h) * 0.5
	for row: int in range(rows):
		var y: float = y0 + float(row) * row_h
		var cols: int = int(floorf((CELL_SIZE.x - s) / s)) + 1
		var x0: float = (CELL_SIZE.x - float(cols - 1) * s) * 0.5
		if row % 2 == 1:
			x0 += s * 0.5
		for col: int in range(cols):
			var p: Vector2 = Vector2(x0 + float(col) * s, y)
			if is_inside(p, margin + 2.0):
				result.append(p)
	return result


func _make_ribosome_points() -> void:
	ribosome_points.clear()
	if slots.is_empty():
		return
	# Centres of the hex grid's triangles: the gaps between three neighbouring organelles.
	var candidates: Array[Vector2] = []
	for p: Vector2 in slots:
		var c: Vector2 = p + Vector2(spacing * 0.5, spacing * 0.2887)
		if is_inside(c, spacing * 0.2):
			candidates.append(c)
	var anchor: Vector2 = Vector2(CELL_SIZE.x * 0.5, CELL_SIZE.y * 0.5)
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var da: float = a.distance_squared_to(anchor)
		var db: float = b.distance_squared_to(anchor)
		if not is_equal_approx(da, db):
			return da < db
		if not is_equal_approx(a.x, b.x):
			return a.x < b.x
		return a.y < b.y)
	# Take every other candidate so the ribosomes spread out a little.
	var i: int = 0
	while i < candidates.size() and ribosome_points.size() < 4:
		ribosome_points.append(candidates[i])
		i += 3
