class_name UiTheme
extends RefCounted
## Builds the game's theme in code: dark panels with near-white text (well above 4.5:1), buttons with
## a visible border, and a thick focus outline on every button.

# === CONSTANTS ===
const TEXT: Color = Color(0.95, 0.96, 0.98, 1)
const PANEL_BG: Color = Color(0.07, 0.11, 0.16, 0.98)
const PANEL_EDGE: Color = Color(0.78, 0.84, 0.90, 1)
const BUTTON_BG: Color = Color(0.15, 0.23, 0.32, 1)
const BUTTON_HOVER: Color = Color(0.21, 0.31, 0.42, 1)
const BUTTON_PRESSED: Color = Color(0.10, 0.16, 0.23, 1)
const BUTTON_EDGE: Color = Color(0.60, 0.72, 0.84, 1)
const FOCUS: Color = Color(1.0, 0.85, 0.29, 1)
const FONT_SIZE: int = 15


# === PUBLIC METHODS ===
static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = FONT_SIZE
	t.set_stylebox("normal", "Button", _box(BUTTON_BG, BUTTON_EDGE, 2))
	t.set_stylebox("hover", "Button", _box(BUTTON_HOVER, Color.WHITE, 2))
	t.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED, Color.WHITE, 2))
	t.set_stylebox("disabled", "Button", _box(Color(0.12, 0.16, 0.21, 1), Color(0.35, 0.41, 0.48, 1), 2))
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), FOCUS, 4)
	focus.draw_center = false
	focus.expand_margin_left = 2.0
	focus.expand_margin_right = 2.0
	focus.expand_margin_top = 2.0
	focus.expand_margin_bottom = 2.0
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.62, 0.67, 0.72, 1))
	t.set_color("font_color", "Label", TEXT)
	var panel: StyleBoxFlat = _box(PANEL_BG, PANEL_EDGE, 2)
	panel.set_content_margin_all(14.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


# === PRIVATE METHODS ===
static func _box(bg: Color, edge: Color, border: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb
