class_name PlaceholderArt
extends RefCounted
## Procedural placeholder art, drawn with draw_*() calls, plus the lookup that lets Illustrator
## artwork replace it. If res://assets/vector/<name>.svg (or .png) exists it is drawn instead of the
## placeholder, centred on the same point and fitted to the same box, so hit areas, loading rings
## and the simulation are untouched by an art swap. See docs/ASSET_INTEGRATION.md.

# === CONSTANTS ===
const ART_DIR: String = "res://assets/vector/"
const INK: Color = Color(0.09, 0.13, 0.18, 1)
const PAPER: Color = Color(1, 1, 1, 1)
const MITO_FILL: Color = Color(0.78, 0.35, 0.25, 1)
const MITO_LINE: Color = Color(0.30, 0.10, 0.07, 1)
const MITO_DETAIL: Color = Color(0.98, 0.82, 0.74, 1)
const CHLORO_FILL: Color = Color(0.45, 0.70, 0.36, 1)
const CHLORO_LINE: Color = Color(0.10, 0.28, 0.10, 1)
const CHLORO_DETAIL: Color = Color(0.13, 0.36, 0.14, 1)
const GLYPH_COLORS: Dictionary = {
	"glucose": Color(0.62, 0.38, 0.05, 1),
	"oxygen": Color(0.10, 0.36, 0.72, 1),
	"co2": Color(0.28, 0.30, 0.34, 1),
	"water": Color(0.05, 0.50, 0.62, 1),
	"amino": Color(0.48, 0.25, 0.66, 1),
	"protein": Color(0.66, 0.14, 0.42, 1),
	"atp": Color(0.80, 0.42, 0.02, 1),
	"starch": Color(0.42, 0.30, 0.10, 1),
}
const GLYPH_NAMES: Dictionary = {
	"glucose": "Glucose (sugar)",
	"oxygen": "Oxygen",
	"co2": "Carbon dioxide",
	"water": "Water",
	"amino": "Amino acid",
	"protein": "Protein",
	"atp": "ATP",
	"starch": "Starch",
}
const GLYPH_FILES: Dictionary = {
	"glucose": "mol_glucose",
	"oxygen": "mol_oxygen",
	"co2": "mol_carbon_dioxide",
	"water": "mol_water",
	"amino": "mol_amino_acid",
	"protein": "mol_protein",
	"atp": "mol_atp",
	"starch": "starch_granule_small",
}

## Other file names accepted for an asset, tried after the main name.
const ALIASES: Dictionary = {
	"mitochondrion_body": ["mitochondrion"],
	"chloroplast_body": ["chloroplast"],
}

# === PRIVATE VARIABLES ===
static var _cache: Dictionary = {}


# === PUBLIC METHODS ===
## The replacement texture for `asset_name` (no extension), or null to use the placeholder.
static func texture(asset_name: String) -> Texture2D:
	if _cache.has(asset_name):
		return _cache[asset_name]
	var found: Texture2D = null
	var names: Array = [asset_name]
	names.append_array(ALIASES.get(asset_name, []))
	for candidate: String in names:
		for ext: String in [".svg", ".png"]:
			var path: String = ART_DIR + candidate + ext
			if found == null and ResourceLoader.exists(path):
				var res: Resource = load(path)
				if res is Texture2D:
					found = res
	_cache[asset_name] = found
	return found


## Draws `tex` centred at `c`, scaled so its whole rectangle fits inside a circle of `radius`.
## Used for organelles: whatever the artwork's proportions or angle, it stays inside its loading ring.
static func draw_in_circle(ci: CanvasItem, tex: Texture2D, c: Vector2, radius: float, rot: float, mod: Color) -> void:
	var ts: Vector2 = tex.get_size()
	var half_diagonal: float = ts.length() * 0.5
	if half_diagonal <= 0.0:
		return
	var sz: Vector2 = ts * (radius / half_diagonal)
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws `tex` centred at `c`, fitted inside `box`, rotated by `rot`.
static func draw_fitted(ci: CanvasItem, tex: Texture2D, c: Vector2, box: Vector2, rot: float, mod: Color) -> void:
	var ts: Vector2 = tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var k: float = minf(box.x / ts.x, box.y / ts.y)
	var sz: Vector2 = ts * k
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func capsule_points(length: float, width: float, steps: int = 10) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var r: float = width * 0.5
	var half: float = maxf(length * 0.5 - r, 0.0)
	for i: int in range(steps + 1):
		var a: float = -PI * 0.5 + PI * float(i) / float(steps)
		pts.append(Vector2(half + cos(a) * r, sin(a) * r))
	for i: int in range(steps + 1):
		var a: float = PI * 0.5 + PI * float(i) / float(steps)
		pts.append(Vector2(-half + cos(a) * r, sin(a) * r))
	return pts


static func ellipse_points(rx: float, ry: float, steps: int = 28) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps):
		var a: float = TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


## Mitochondrion: capsule ("bean") with zigzag cristae folds.
static func draw_mito(ci: CanvasItem, c: Vector2, length: float, width: float, rot: float, alpha: float = 1.0) -> void:
	var tex: Texture2D = texture("mitochondrion_body")
	if tex != null:
		draw_in_circle(ci, tex, c, length * 0.55, rot, Color(1, 1, 1, alpha))
		return
	ci.draw_set_transform(c, rot, Vector2.ONE)
	var body: PackedVector2Array = capsule_points(length, width)
	ci.draw_colored_polygon(body, Color(MITO_FILL, alpha))
	ci.draw_polyline(closed(body), Color(MITO_LINE, alpha), maxf(2.0, width * 0.09), true)
	var zig: PackedVector2Array = PackedVector2Array()
	var n: int = 7
	var span: float = length * 0.66
	for i: int in range(n + 1):
		var x: float = -span * 0.5 + span * float(i) / float(n)
		var y: float = width * 0.24 * (1.0 if i % 2 == 0 else -1.0)
		zig.append(Vector2(x, y))
	ci.draw_polyline(zig, Color(MITO_DETAIL, alpha), maxf(1.5, width * 0.08), true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Chloroplast: larger oval with stacked discs (grana). `starch` 0..1 sizes its starch granules.
static func draw_chloro(ci: CanvasItem, c: Vector2, length: float, width: float, rot: float, alpha: float = 1.0) -> void:
	var tex: Texture2D = texture("chloroplast_body")
	if tex != null:
		draw_in_circle(ci, tex, c, length * 0.51, rot, Color(1, 1, 1, alpha))
		return
	ci.draw_set_transform(c, rot, Vector2.ONE)
	var body: PackedVector2Array = ellipse_points(length * 0.5, width * 0.5)
	ci.draw_colored_polygon(body, Color(CHLORO_FILL, alpha))
	ci.draw_polyline(closed(body), Color(CHLORO_LINE, alpha), maxf(2.0, width * 0.07), true)
	# Three stacks of flat discs.
	var disc_w: float = length * 0.15
	var disc_h: float = maxf(1.5, width * 0.055)
	for s: int in range(3):
		var x: float = (float(s) - 1.0) * length * 0.25
		var count: int = 4 if s == 1 else 3
		for d: int in range(count):
			var y: float = (float(d) - float(count - 1) * 0.5) * disc_h * 2.1
			ci.draw_rect(Rect2(x - disc_w * 0.5, y - disc_h * 0.5, disc_w, disc_h), Color(CHLORO_DETAIL, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Starch granule: a cluster of linked hexagons. `emphasis` adds the thick tutorial outline.
static func draw_starch(ci: CanvasItem, c: Vector2, size: float, alpha: float, emphasis: bool) -> void:
	var tex: Texture2D = texture("starch_granule_small")
	if emphasis:
		ci.draw_circle(c, size * 0.95, Color(PAPER, 0.95))
		ci.draw_arc(c, size * 0.95, 0.0, TAU, 24, INK, maxf(2.5, size * 0.16), true)
	if tex != null:
		draw_fitted(ci, tex, c, Vector2(size * 1.6, size * 1.6), 0.0, Color(1, 1, 1, alpha))
		return
	var col: Color = Color(1.0, 0.97, 0.86, alpha)
	var line: Color = Color(GLYPH_COLORS["starch"], alpha)
	var r: float = size * 0.36
	var offsets: Array[Vector2] = [Vector2(-r * 0.95, -r * 0.3), Vector2(r * 0.95, -r * 0.3), Vector2(0.0, r * 0.9)]
	for off: Vector2 in offsets:
		var hex: PackedVector2Array = PackedVector2Array()
		for i: int in range(6):
			var a: float = TAU * float(i) / 6.0
			hex.append(c + off + Vector2(cos(a), sin(a)) * r)
		ci.draw_colored_polygon(hex, col)
		ci.draw_polyline(closed(hex), line, maxf(1.2, size * 0.09), true)


## Ribosome: two stacked subunits. `chain` 0..1 is how far the new protein chain has grown.
static func draw_ribosome(ci: CanvasItem, c: Vector2, size: float, chain: float, alpha: float = 1.0) -> void:
	var tex: Texture2D = texture("ribosome")
	if tex != null:
		draw_fitted(ci, tex, c, Vector2(size * 1.6, size * 1.6), 0.0, Color(1, 1, 1, alpha))
	else:
		var big: PackedVector2Array = ellipse_points(size * 0.62, size * 0.42, 18)
		var small: PackedVector2Array = ellipse_points(size * 0.46, size * 0.28, 16)
		ci.draw_set_transform(c + Vector2(0.0, size * 0.18), 0.0, Vector2.ONE)
		ci.draw_colored_polygon(big, Color(0.42, 0.40, 0.58, alpha))
		ci.draw_polyline(closed(big), Color(INK, alpha), 1.5, true)
		ci.draw_set_transform(c + Vector2(0.0, -size * 0.36), 0.0, Vector2.ONE)
		ci.draw_colored_polygon(small, Color(0.62, 0.60, 0.78, alpha))
		ci.draw_polyline(closed(small), Color(INK, alpha), 1.5, true)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if chain > 0.02:
		var pts: PackedVector2Array = PackedVector2Array()
		var n: int = 2 + int(chain * 8.0)
		for i: int in range(n):
			var t: float = float(i)
			pts.append(c + Vector2(size * 0.6 + t * size * 0.22, -size * 0.05 + sin(t * 1.9) * size * 0.2))
		ci.draw_polyline(pts, Color(GLYPH_COLORS["protein"], alpha), maxf(2.0, size * 0.16), true)


## Membrane ion pump: a two-part gate across the membrane with one ion passing through.
static func draw_pump(ci: CanvasItem, c: Vector2, normal: Vector2, size: float, phase: float) -> void:
	var tex: Texture2D = texture("ion_pump")
	var rot: float = normal.angle() + PI * 0.5
	if tex != null:
		draw_fitted(ci, tex, c, Vector2(size * 2.0, size * 2.0), rot, Color.WHITE)
	else:
		ci.draw_set_transform(c, rot, Vector2.ONE)
		var w: float = size * 0.42
		var h: float = size * 1.3
		for side: float in [-1.0, 1.0]:
			var r: Rect2 = Rect2(side * size * 0.3 - w * 0.5, -h * 0.5, w, h)
			ci.draw_rect(r, Color(0.36, 0.42, 0.62, 1))
			ci.draw_rect(r, INK, false, 1.5)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var along: float = (fposmod(phase, 1.0) - 0.5) * size * 2.2
	var ion: Vector2 = c + normal * along
	ci.draw_circle(ion, size * 0.17, Color(0.98, 0.93, 0.55, 1))
	ci.draw_arc(ion, size * 0.17, 0.0, TAU, 12, INK, 1.2, true)


## Transport vesicle: a round sac with a few cargo dots.
static func draw_vesicle(ci: CanvasItem, c: Vector2, size: float) -> void:
	var tex: Texture2D = texture("transport_vesicle")
	if tex != null:
		draw_fitted(ci, tex, c, Vector2(size * 2.0, size * 2.0), 0.0, Color.WHITE)
		return
	ci.draw_circle(c, size, Color(0.93, 0.80, 0.86, 0.9))
	ci.draw_arc(c, size, 0.0, TAU, 20, Color(0.45, 0.22, 0.34, 1), 2.0, true)
	for i: int in range(3):
		var a: float = TAU * float(i) / 3.0 + 0.4
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * size * 0.42, size * 0.17, Color(0.45, 0.22, 0.34, 1))


static func draw_sun(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var tex: Texture2D = texture("sun_icon")
	if tex != null:
		draw_fitted(ci, tex, c, Vector2(size * 2.0, size * 2.0), 0.0, Color.WHITE)
		return
	ci.draw_circle(c, size * 0.45, col)
	for i: int in range(8):
		var a: float = TAU * float(i) / 8.0
		var d: Vector2 = Vector2(cos(a), sin(a))
		ci.draw_line(c + d * size * 0.62, c + d * size, col, maxf(2.0, size * 0.14), true)


static func draw_moon(ci: CanvasItem, c: Vector2, size: float, col: Color, bg: Color) -> void:
	var tex: Texture2D = texture("moon_icon")
	if tex != null:
		draw_fitted(ci, tex, c, Vector2(size * 2.0, size * 2.0), 0.0, Color.WHITE)
		return
	ci.draw_circle(c, size * 0.8, col)
	ci.draw_circle(c + Vector2(size * 0.38, -size * 0.22), size * 0.68, bg)


static func draw_clock(ci: CanvasItem, c: Vector2, size: float) -> void:
	ci.draw_circle(c, size, PAPER)
	ci.draw_arc(c, size, 0.0, TAU, 20, INK, 2.0, true)
	ci.draw_line(c, c + Vector2(0.0, -size * 0.62), INK, 2.0, true)
	ci.draw_line(c, c + Vector2(size * 0.45, 0.0), INK, 2.0, true)


## A molecule glyph. Shapes differ by geometry, so they read without colour:
## glucose = hexagon, oxygen = 2 circles, CO2 = 3 circles in a row, water = bent triple,
## amino acid = triangle with a tail, protein = squiggle, ATP = block with 3 dots, starch = hex cluster.
static func draw_glyph(ci: CanvasItem, kind: String, c: Vector2, size: float, alpha: float, emphasis: bool = false) -> void:
	var col: Color = Color(GLYPH_COLORS.get(kind, INK), alpha)
	if emphasis:
		ci.draw_circle(c, size * 1.15, Color(PAPER, minf(1.0, alpha + 0.2)))
		ci.draw_arc(c, size * 1.15, 0.0, TAU, 20, Color(INK, alpha), maxf(2.0, size * 0.16), true)
	if kind == "starch":
		draw_starch(ci, c, size * 1.4, alpha, false)
		return
	var tex: Texture2D = texture(str(GLYPH_FILES.get(kind, "")))
	if tex != null:
		draw_fitted(ci, tex, c, Vector2(size * 2.0, size * 2.0), 0.0, Color(1, 1, 1, alpha))
		return
	var lw: float = maxf(1.5, size * 0.2)
	match kind:
		"glucose":
			var hex: PackedVector2Array = PackedVector2Array()
			for i: int in range(7):
				var a: float = TAU * float(i) / 6.0 + PI / 6.0
				hex.append(c + Vector2(cos(a), sin(a)) * size * 0.85)
			ci.draw_polyline(hex, col, lw, true)
			ci.draw_circle(hex[5], size * 0.22, col)
		"oxygen":
			ci.draw_circle(c + Vector2(-size * 0.42, 0.0), size * 0.46, col)
			ci.draw_circle(c + Vector2(size * 0.42, 0.0), size * 0.46, col)
		"co2":
			ci.draw_circle(c, size * 0.36, col)
			ci.draw_arc(c + Vector2(-size * 0.72, 0.0), size * 0.3, 0.0, TAU, 12, col, lw * 0.8, true)
			ci.draw_arc(c + Vector2(size * 0.72, 0.0), size * 0.3, 0.0, TAU, 12, col, lw * 0.8, true)
		"water":
			ci.draw_circle(c, size * 0.44, col)
			ci.draw_circle(c + Vector2(-size * 0.55, size * 0.5), size * 0.24, col)
			ci.draw_circle(c + Vector2(size * 0.55, size * 0.5), size * 0.24, col)
		"amino":
			var tri: PackedVector2Array = PackedVector2Array([
				c + Vector2(-size * 0.75, size * 0.5), c + Vector2(0.0, -size * 0.7), c + Vector2(size * 0.35, size * 0.5)])
			ci.draw_colored_polygon(tri, col)
			ci.draw_line(c + Vector2(size * 0.2, 0.0), c + Vector2(size * 0.95, -size * 0.35), col, lw, true)
		"protein":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in range(9):
				var t: float = float(i) / 8.0
				pts.append(c + Vector2((t - 0.5) * size * 2.0, sin(t * TAU * 1.5) * size * 0.5))
			ci.draw_polyline(pts, col, lw * 1.2, true)
		"atp":
			ci.draw_rect(Rect2(c + Vector2(-size * 0.95, -size * 0.4), Vector2(size * 0.8, size * 0.8)), col)
			for i: int in range(3):
				ci.draw_circle(c + Vector2(size * 0.15 + float(i) * size * 0.4, 0.0), size * 0.17, col)
		_:
			ci.draw_circle(c, size * 0.5, col)


## Draws a chemical formula with small lowered digits ("CO2", "H2O", "O2") without needing
## subscript glyphs in the font.
static func draw_formula(ci: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, col: Color) -> void:
	var x: float = pos.x
	var small: int = maxi(6, int(float(font_size) * 0.72))
	for i: int in range(text.length()):
		var ch: String = text[i]
		if ch.is_valid_int():
			ci.draw_string(font, Vector2(x, pos.y + float(font_size) * 0.22), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small, col)
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small).x
		else:
			ci.draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, col)
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
