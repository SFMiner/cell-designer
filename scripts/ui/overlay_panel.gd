class_name OverlayPanel
extends Control
## A message panel with buttons: the Start card, tutorial call-outs, Pause, Help, Settings and
## the win/fail cards. game_controller.gd keeps them in a stack and positions them.
## A modal overlay covers the whole view; a non-modal one (Start, results) leaves the top bar usable.

# === SIGNALS ===
signal closed

# === PUBLIC VARIABLES ===
var kind: String = ""
var modal: bool = true
## Escape closes it. Start and result cards are not closable: Escape there leaves the game.
var escape_closes: bool = true
## Darkness of the backdrop, 0..1.
var dim: float = 0.5
var preferred_width: float = 520.0
var panel: PanelContainer = null
var title_label: Label = null
var body_label: Label = null
var button_row: HFlowContainer = null
var buttons: Array[Button] = []
## Global-canvas points this call-out points at. Recomputed by the controller on every layout pass
## from target_organelles / target_meter, so the lines follow a resize.
var targets: Array[Vector2] = []
## For each target, how far short of it the pointer line stops (so it does not cover what it points at).
var target_gaps: Array[float] = []
## "mito" or "chloro": point at the first organelle of that kind. "" for none.
var target_organelles: String = ""
## HUD row key to point at. "" for none.
var target_meter: String = ""
## If true, the controller keeps the panel away from targets[0].
var avoid_target: bool = false
## Seconds before the buttons accept a press, so a key being mashed cannot dismiss a new message unread.
var arm_delay: float = 0.0
## Control that had focus before this overlay opened.
var previous_focus: Control = null

# === PRIVATE VARIABLES ===
var _box: VBoxContainer = null


# === LIFECYCLE METHODS ===
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	panel.add_child(_box)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(title_label)
	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(body_label)
	button_row = HFlowContainer.new()
	button_row.add_theme_constant_override("h_separation", 8)
	button_row.add_theme_constant_override("v_separation", 8)
	_box.add_child(button_row)


func _process(delta: float) -> void:
	if arm_delay > 0.0:
		arm_delay -= delta


func _draw() -> void:
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.07, dim))
	var box: Rect2 = Rect2(panel.position, panel.size * panel.scale)
	for t: Vector2 in targets:
		var local: Vector2 = t - global_position
		if box.has_point(local):
			continue
		var from: Vector2 = Vector2(clampf(local.x, box.position.x, box.end.x), clampf(local.y, box.position.y, box.end.y))
		var index: int = targets.find(t)
		var gap: float = target_gaps[index] if index >= 0 and index < target_gaps.size() else 0.0
		var length: float = from.distance_to(local)
		if length <= gap + 4.0:
			continue
		var tip: Vector2 = local + (from - local) / length * gap
		draw_line(from, tip, Color(0.02, 0.04, 0.07, 1), 6.0, true)
		draw_line(from, tip, Color.WHITE, 3.0, true)
		draw_circle(tip, 7.0, Color(0.02, 0.04, 0.07, 1))
		draw_circle(tip, 4.5, Color.WHITE)


# === PUBLIC METHODS ===
func set_text(title: String, body: String) -> void:
	title_label.text = title
	title_label.visible = title != ""
	body_label.text = body
	body_label.visible = body != ""


## Adds an extra control between the text and the buttons.
func add_extra(c: Control) -> void:
	_box.add_child(c)
	_box.move_child(c, button_row.get_index())


func add_button(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	# Presses are ignored (not disabled, so focus and Tab still work) until the overlay is armed.
	b.pressed.connect(func() -> void:
		if arm_delay <= 0.0:
			on_press.call())
	button_row.add_child(b)
	buttons.append(b)
	return b


## Sets the panel width so the wrapped labels can work out their height.
func set_panel_width(w: float) -> void:
	var inner: float = maxf(w - 32.0, 80.0)
	title_label.custom_minimum_size.x = inner
	body_label.custom_minimum_size.x = inner
	panel.custom_minimum_size.x = w


func close() -> void:
	closed.emit()
