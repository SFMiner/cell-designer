class_name Hud
extends Control
## The status panel: goal, progress, day/night strip, labelled resource meters and rate read-outs.
## Every meter has a text label and numbers, so nothing depends on colour. Rows that a level does
## not use are hidden. It only reads the model.

# === CONSTANTS ===
const TEXT: Color = Color(0.95, 0.96, 0.98, 1)
const TEXT_DIM: Color = Color(0.78, 0.83, 0.88, 1)
const PANEL: Color = Color(0.08, 0.12, 0.17, 1)
const BAR_BG: Color = Color(0.17, 0.23, 0.30, 1)
const BAR_EDGE: Color = Color(0.62, 0.71, 0.80, 1)
const FS: int = 14
const FS_TITLE: int = 16
const ROW_H: float = 24.0
const PAD: float = 10.0
const METER_COLORS: Dictionary = {
	"atp": Color(0.95, 0.72, 0.20, 1),
	"glucose": Color(0.86, 0.64, 0.36, 1),
	"oxygen": Color(0.45, 0.70, 1.0, 1),
	"protein": Color(0.90, 0.50, 0.70, 1),
	"starch": Color(0.92, 0.88, 0.72, 1),
	"space": Color(0.72, 0.77, 0.82, 1),
	"check": Color(0.55, 0.85, 0.60, 1),
	"day": Color(1.0, 0.86, 0.35, 1),
}

# === PUBLIC VARIABLES ===
var model: SimulationModel = null
## Meter keys a tutorial is pointing at: drawn with a thick outline and a pointer.
var highlight: Array = []
## Short frames: drop the goal sentence and footnote and tighten rows so the meters fit without scrolling.
var compact: bool = false
## Row rectangles from the last draw, by key (for tutorial pointer lines).
var row_rects: Dictionary = {}

# === PRIVATE VARIABLES ===
var _y: float = 0.0
var _measuring: bool = false


# === LIFECYCLE METHODS ===
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_measuring = false
	draw_rect(Rect2(Vector2.ZERO, size), PANEL)
	_layout(size.x)


# === PUBLIC METHODS ===
## Height the panel needs at `width`.
func content_height(width: float) -> float:
	_measuring = true
	_layout(width)
	_measuring = false
	return _y + PAD


func set_highlight(keys: Array) -> void:
	highlight = keys
	queue_redraw()


## Global-canvas centre of a highlighted row, or of the panel.
func row_point(key: String) -> Vector2:
	if row_rects.has(key):
		var r: Rect2 = row_rects[key]
		return global_position + Vector2(r.end.x + 2.0, r.get_center().y)
	return global_position + size * 0.5


# === PRIVATE METHODS ===
func _layout(width: float) -> void:
	_y = PAD
	if model == null:
		return
	var font: Font = ThemeDB.fallback_font
	var cfg: Dictionary = model.cfg
	var inner: float = maxf(width - PAD * 2.0, 60.0)
	if not _measuring:
		row_rects.clear()

	_text_line(font, "Level %d: %s" % [model.level, str(cfg["name"])], FS_TITLE, TEXT)
	if not compact:
		_wrapped(font, "Goal: " + str(cfg["goal"]), inner, TEXT_DIM)
		_y += 2.0

	var n_mito: int = model.count(SimulationModel.KIND_MITO)
	var n_chloro: int = model.count(SimulationModel.KIND_CHLORO)
	var target: int = int(cfg["mito_target"])
	if target > 0:
		_text_line(font, "Mitochondria: %d / %d" % [n_mito, target], FS, TEXT)
	else:
		_text_line(font, "Mitochondria: %d    Chloroplasts: %d" % [n_mito, n_chloro], FS, TEXT)

	if bool(cfg["day_night"]):
		_day_row(font, inner)
	_check_row(font, inner)
	_y += 3.0

	var crisis: bool = model.atp < float(cfg["atp_critical"])
	var low: bool = model.atp < float(cfg["atp_low"])
	var atp_note: String = "CRISIS" if crisis else ("low" if low else "")
	_meter(font, inner, "atp", "ATP", model.atp, float(cfg["atp_cap"]), atp_note)
	_meter(font, inner, "glucose", "Glucose", model.glucose, float(cfg["glucose_cap"]), "")
	_meter(font, inner, "oxygen", "Oxygen", model.oxygen, float(cfg["oxygen_cap"]), "")
	if bool(cfg["protein_enabled"]):
		_meter(font, inner, "protein", "Proteins", model.protein, float(cfg["protein_cap"]), "")
	if bool(cfg["starch_enabled"]):
		_meter(font, inner, "starch", "Starch", model.starch, float(cfg["starch_cap"]), "")
	if bool(cfg["space_shown"]):
		_meter(font, inner, "space", "Space", float(model.space_used()), float(int(cfg["space_cap"])), "")
	_y += 3.0

	var rates_top: float = _y
	_text_line(font, "ATP/s: made %.1f, used %.1f" % [model.atp_made_rate, model.atp_used_rate], FS, TEXT)
	if not bool(cfg["day_night"]):
		_text_line(font, "Fuel supply allows up to %.0f ATP/s" % model.supply_atp_ceiling(), FS, TEXT_DIM)
	_mark_row("rates", Rect2(PAD - 4.0, rates_top - 2.0, inner + 8.0, _y - rates_top + 2.0))
	if bool(cfg["protein_enabled"]):
		var top: float = _y
		_text_line(font, "Proteins/s: made %.1f" % model.protein_rate, FS, TEXT)
		_mark_row("protein_rate", Rect2(PAD - 4.0, top - 2.0, inner + 8.0, _y - top + 2.0))
	if not compact:
		_wrapped(font, "Model units, not counts of real molecules.", inner, TEXT_DIM, 12)


func _text_line(font: Font, text: String, font_size: int, col: Color) -> void:
	if not _measuring:
		draw_string(font, Vector2(PAD, _y + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, col)
	_y += font.get_height(font_size) + 2.0


func _wrapped(font: Font, text: String, width: float, col: Color, font_size: int = FS) -> void:
	var sz: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	if not _measuring:
		draw_multiline_string(font, Vector2(PAD, _y + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, col)
	_y += sz.y + 3.0


func _mark_row(key: String, r: Rect2) -> void:
	if _measuring:
		return
	row_rects[key] = r
	if highlight.has(key):
		# Thick light outline with a dark edge and a pointer: visible without colour.
		draw_rect(r.grow(1.0), Color.WHITE, false, 3.0)
		draw_rect(r.grow(3.5), Color(0, 0, 0, 1), false, 1.5)
		var tip: Vector2 = Vector2(r.position.x - 1.0, r.get_center().y)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-7.0, -6.0), tip + Vector2(1.0, 0.0), tip + Vector2(-7.0, 6.0)]), Color.WHITE)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r, BAR_BG)
	var f: float = clampf(frac, 0.0, 1.0)
	if f > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col)
	draw_rect(r, BAR_EDGE, false, 1.0)


func _meter(font: Font, inner: float, key: String, label: String, value: float, cap: float, note: String) -> void:
	var row_h: float = ROW_H - 3.0 if compact else ROW_H
	var row: Rect2 = Rect2(PAD - 4.0, _y - 1.0, inner + 8.0, row_h - 1.0)
	if not _measuring:
		var icon_c: Vector2 = Vector2(PAD + 8.0, _y + row_h * 0.5 - 1.0)
		if key == "space":
			draw_rect(Rect2(icon_c - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), TEXT_DIM, false, 2.0)
		else:
			# Same glyph as in the cytoplasm, on a light chip so its shape stays readable.
			draw_circle(icon_c, 8.5, Color(0.93, 0.93, 0.90, 1))
			PlaceholderArt.draw_glyph(self, key, icon_c, 5.5, 1.0)
		var label_x: float = PAD + 22.0
		var label_w: float = 66.0
		var base_y: float = _y + row_h * 0.5 + 4.5
		draw_string(font, Vector2(label_x, base_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FS, TEXT)
		var value_text: String = "%d / %d" % [int(floorf(value + 0.001)), int(cap)]
		if note != "":
			value_text = note + " " + value_text
		var value_w: float = font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FS).x
		var bar_x: float = label_x + label_w
		var bar_w: float = maxf(inner - (bar_x - PAD) - value_w - 8.0, 20.0)
		var bar_y: float = _y + row_h * 0.5 - 8.0
		_bar(Rect2(bar_x, bar_y, bar_w, 14.0), value / cap if cap > 0.0 else 0.0, METER_COLORS.get(key, TEXT))
		if note == "CRISIS":
			# Hatching marks the crisis state without relying on colour.
			var hx: float = bar_x + 3.0
			while hx < bar_x + bar_w - 4.0:
				draw_line(Vector2(hx, bar_y + 13.0), Vector2(hx + 6.0, bar_y + 1.0), TEXT, 1.5, true)
				hx += 9.0
		draw_string(font, Vector2(PAD + inner - value_w, base_y), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FS, TEXT)
	_mark_row(key, row)
	_y += row_h


func _check_row(font: Font, inner: float) -> void:
	var cfg: Dictionary = model.cfg
	var kind: String = str(cfg["check_kind"])
	var need: float = float(cfg["check_seconds"])
	var label: String = ""
	var status: String = ""
	var frac: float = 0.0
	if kind == "atp":
		label = "Power test"
		status = "%.1f / %d s" % [model.check_timer, int(need)] if model.check_active else "at %d mitochondria" % int(cfg["mito_target"])
	elif kind == "protein":
		label = "Protein check"
		status = "%.1f / %d s" % [model.check_timer, int(need)] if model.check_active else "at %d mitochondria" % int(cfg["mito_target"])
	else:
		label = "Protein goal"
		if model.final_cycle_goal_met:
			status = "met"
		elif model.check_active:
			status = "%.1f / %d s" % [model.check_timer, int(need)]
		else:
			status = "final cycle only"
	if model.won or model.final_cycle_goal_met:
		frac = 1.0
	elif model.check_active:
		frac = model.check_timer / need
	var top: float = _y
	if not _measuring:
		draw_string(font, Vector2(PAD, _y + font.get_ascent(FS)), label + ": " + status, HORIZONTAL_ALIGNMENT_LEFT, inner, FS, TEXT)
	_y += font.get_height(FS) + 2.0
	if not _measuring:
		_bar(Rect2(PAD, _y, inner, 8.0), frac, METER_COLORS["check"])
	_y += 11.0
	_mark_row("check", Rect2(PAD - 4.0, top - 2.0, inner + 8.0, _y - top + 1.0))


func _day_row(font: Font, inner: float) -> void:
	var cfg: Dictionary = model.cfg
	var day: bool = model.is_day()
	var number: int = model.cycle_index() + 1
	var top: float = _y
	if not _measuring:
		var icon_c: Vector2 = Vector2(PAD + 9.0, _y + 10.0)
		if day:
			PlaceholderArt.draw_sun(self, icon_c, 9.0, METER_COLORS["day"])
		else:
			PlaceholderArt.draw_moon(self, icon_c, 9.0, Color(0.92, 0.94, 1.0, 1), PANEL)
		var text: String = "%s %d of %d: %d s left" % ["Day" if day else "Night", number, int(cfg["cycles"]),
			int(ceilf(model.phase_time_left()))]
		draw_string(font, Vector2(PAD + 24.0, _y + font.get_ascent(FS)), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FS, TEXT)
	_y += font.get_height(FS) + 2.0
	if not _measuring:
		_bar(Rect2(PAD, _y, inner, 8.0), model.phase_fraction(), METER_COLORS["day"] if day else Color(0.75, 0.80, 0.95, 1))
	_y += 12.0
	_mark_row("day", Rect2(PAD - 4.0, top - 2.0, inner + 8.0, _y - top))
