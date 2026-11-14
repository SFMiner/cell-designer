class_name OrganelleButton
extends BaseButton
## One clickable, focusable organelle: body art, maturation ring, fission animation, focus outline.
## It is a view of a SimulationModel.Org; it holds no game state of its own. The hit area is this
## control's rectangle, which is at least 44 CSS px and does not depend on the art.

# === CONSTANTS ===
const RING_STEPS: int = 8
const FOCUS_COLOR: Color = Color(1.0, 0.85, 0.29, 1)

# === PUBLIC VARIABLES ===
var org: SimulationModel.Org = null
## Slot spacing in this control's pixels; the art and ring are sized from it.
var unit: float = 60.0
var rot: float = 0.0
## 0..1 progress of the elongate -> constrict -> separate animation (1 = finished).
var birth: float = 1.0
## Where the parent was, relative to this control's centre.
var from_offset: Vector2 = Vector2.ZERO
## Seconds left of the "not ready" bump.
var bump: float = 0.0
## Seconds left to show the clock pictogram.
var clock_time: float = 0.0
var emphasized: bool = false
var dimmed: bool = false
var reduced_motion: bool = false
## Chloroplasts only: 0..1 share of the starch reserve shown as granules.
var starch_fraction: float = 0.0
var starch_emphasis: bool = false
## 0..1 pulse for tutorial highlights (0 when reduced motion is on).
var pulse: float = 0.0


# === LIFECYCLE METHODS ===
func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	if org == null:
		return
	var c: Vector2 = size * 0.5
	var ring_r: float = unit * 0.46
	var is_chloro: bool = org.kind == SimulationModel.KIND_CHLORO
	var length: float = unit * (0.84 if is_chloro else 0.78)
	var width: float = unit * (0.56 if is_chloro else 0.40)
	var alpha: float = 0.5 if dimmed else 1.0
	var eased: float = 1.0 - pow(1.0 - clampf(birth, 0.0, 1.0), 2.0)
	var body_c: Vector2 = c + from_offset * (1.0 - eased)
	if bump > 0.0 and not reduced_motion:
		body_c += Vector2(sin(bump * 45.0) * unit * 0.04, 0.0)

	# Fission: a neck joins the daughters while they pull apart, thinning as it constricts.
	# (Skipped when replacement artwork is in use: the neck is drawn in the placeholder's colour.)
	var has_art: bool = PlaceholderArt.texture("chloroplast_body" if is_chloro else "mitochondrion_body") != null
	if birth < 0.6 and from_offset.length() > 0.5 and not has_art:
		var neck: float = width * 0.7 * (1.0 - birth / 0.6)
		var fill: Color = PlaceholderArt.CHLORO_FILL if is_chloro else PlaceholderArt.MITO_FILL
		draw_line(body_c, c + from_offset, Color(fill, alpha), maxf(neck, 1.0), true)

	var body_scale: float = 0.8 + 0.2 * eased
	if is_chloro:
		PlaceholderArt.draw_chloro(self, body_c, length * body_scale, width * body_scale, rot, alpha)
		_draw_starch(body_c, length, width)
	else:
		PlaceholderArt.draw_mito(self, body_c, length * body_scale, width * body_scale, rot, alpha)

	# Maturation ring: an incomplete arc while growing, a complete thick ring when ready.
	var frac: float = org.ring_fraction()
	if reduced_motion and frac < 1.0:
		frac = floorf(frac * float(RING_STEPS)) / float(RING_STEPS)
	var ink: Color = Color(PlaceholderArt.INK, alpha)
	var paper: Color = Color(PlaceholderArt.PAPER, alpha)
	if frac >= 1.0:
		draw_arc(c, ring_r, 0.0, TAU, 56, paper, maxf(6.0, unit * 0.085), true)
		draw_arc(c, ring_r, 0.0, TAU, 56, ink, maxf(3.5, unit * 0.05), true)
	else:
		draw_arc(c, ring_r, 0.0, TAU, 56, Color(PlaceholderArt.INK, 0.3 * alpha), 1.5, true)
		if frac > 0.005:
			var a0: float = -PI * 0.5
			var a1: float = a0 + TAU * frac
			var pts: int = maxi(4, int(56.0 * frac))
			draw_arc(c, ring_r, a0, a1, pts, paper, maxf(6.0, unit * 0.085), true)
			draw_arc(c, ring_r, a0, a1, pts, ink, maxf(3.5, unit * 0.05), true)

	if emphasized:
		var grow: float = pulse * unit * 0.04
		draw_arc(c, ring_r + unit * 0.09 + grow, 0.0, TAU, 56, PlaceholderArt.PAPER, 5.0, true)
		draw_arc(c, ring_r + unit * 0.09 + grow + 3.5, 0.0, TAU, 56, PlaceholderArt.INK, 2.0, true)

	if has_focus():
		var fr: float = minf(ring_r + unit * 0.07, minf(size.x, size.y) * 0.5 - 2.0)
		fr = maxf(fr, ring_r + 3.0)
		draw_arc(c, fr, 0.0, TAU, 56, PlaceholderArt.INK, 6.5, true)
		draw_arc(c, fr, 0.0, TAU, 56, FOCUS_COLOR, 3.5, true)
	elif is_hovered():
		draw_arc(c, ring_r + 4.0, 0.0, TAU, 56, Color(PlaceholderArt.INK, 0.45), 1.5, true)

	if clock_time > 0.0:
		PlaceholderArt.draw_clock(self, c + Vector2(ring_r * 0.75, -ring_r * 0.75), maxf(8.0, unit * 0.13))


# === PUBLIC METHODS ===
## Short spoken description for assistive technology.
func describe() -> String:
	if org == null:
		return ""
	var kind_name: String = "Chloroplast" if org.kind == SimulationModel.KIND_CHLORO else "Mitochondrion"
	if org.is_ready():
		return kind_name + ", ready to divide"
	return "%s, growing, %d percent" % [kind_name, int(org.ring_fraction() * 100.0)]


# === PRIVATE METHODS ===
func _draw_starch(body_c: Vector2, length: float, width: float) -> void:
	if starch_fraction <= 0.004:
		return
	# Up to three granules inside the plastid; they grow and multiply with the reserve.
	var count: int = clampi(int(ceilf(starch_fraction * 3.0)), 1, 3)
	var g_size: float = unit * (0.07 + 0.07 * clampf(starch_fraction, 0.0, 1.0))
	if starch_emphasis:
		g_size *= 1.0 + 0.25 * pulse
	var axis: Vector2 = Vector2.RIGHT.rotated(rot)
	var down: Vector2 = Vector2.DOWN.rotated(rot)
	for i: int in range(count):
		var along: float = (float(i) - float(count - 1) * 0.5) * length * 0.24
		var p: Vector2 = body_c + axis * along + down * width * 0.2
		PlaceholderArt.draw_starch(self, p, g_size, 0.5 if dimmed else 1.0, starch_emphasis)
