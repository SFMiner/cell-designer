class_name GameSettings
extends RefCounted
## Player settings and the whitelisted class settings read from the page address.
## Settings only change presentation (and the starting level); none of them touch the simulation rules.

# === CONSTANTS ===
const SAVE_PATH: String = "user://settings.cfg"
const TEXT_SCALES: Array[float] = [1.0, 1.2, 1.4]
const TEXT_NAMES: Array[String] = ["Normal", "Large", "Extra large"]
const SPEEDS: Array[float] = [1.0, 2.0, 0.5]
const SPEED_NAMES: Array[String] = ["1x", "2x", "0.5x"]

# === PUBLIC VARIABLES ===
## Cosmetic ATP glyphs in the cytoplasm. The ATP bar and the slowdown stay either way.
var show_atp_particles: bool = true
var reduced_motion: bool = false
## Index into TEXT_SCALES.
var text_size: int = 0
## Level the game opens on (1-3). Set by the `level` class setting or the Settings panel.
var start_level: int = 1
## True once the player (or a saved file) has chosen reduced motion, so the browser default no longer applies.
var reduced_motion_chosen: bool = false
## Tests turn this off so they never write to the player's saved settings.
var persist: bool = true


# === PUBLIC METHODS ===
func load_saved() -> void:
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	show_atp_particles = bool(cf.get_value("view", "show_atp_particles", true))
	text_size = clampi(int(cf.get_value("view", "text_size", 0)), 0, TEXT_SCALES.size() - 1)
	if cf.has_section_key("view", "reduced_motion"):
		reduced_motion = bool(cf.get_value("view", "reduced_motion", false))
		reduced_motion_chosen = true


func save() -> void:
	if not persist:
		return
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("view", "show_atp_particles", show_atp_particles)
	cf.set_value("view", "text_size", text_size)
	if reduced_motion_chosen:
		cf.set_value("view", "reduced_motion", reduced_motion)
	cf.save(SAVE_PATH)


func text_scale() -> float:
	return TEXT_SCALES[text_size]


## Parses a page query string ("?level=2&particles=off") into the settings it recognises:
## {"level": 1|2|3} and/or {"particles": true|false}. Unknown keys and out-of-range values are
## ignored. The text is only ever compared with fixed strings; it is never used as a path or run.
static func parse_query(search: String) -> Dictionary:
	var out: Dictionary = {}
	var text: String = search.strip_edges()
	if text.begins_with("?"):
		text = text.substr(1)
	if text.length() > 512:
		return out
	for pair: String in text.split("&", false):
		var parts: PackedStringArray = pair.split("=", true, 1)
		if parts.size() != 2:
			continue
		var key: String = parts[0]
		var value: String = parts[1]
		if key == "level":
			if value == "1" or value == "2" or value == "3":
				out["level"] = int(value)
		elif key == "particles":
			if value == "on":
				out["particles"] = true
			elif value == "off":
				out["particles"] = false
	return out


## Applies the result of parse_query() for this session.
func apply_query(query: Dictionary) -> void:
	if query.has("level"):
		start_level = clampi(int(query["level"]), 1, LevelConfigs.LEVEL_COUNT)
	if query.has("particles"):
		show_atp_particles = bool(query["particles"])


## Reads the page address and the browser's reduced-motion preference. Web builds only.
func read_browser() -> void:
	if not OS.has_feature("web"):
		return
	var search: Variant = JavaScriptBridge.eval("window.location.search", true)
	if search is String:
		apply_query(parse_query(search))
	if not reduced_motion_chosen:
		var prefers: Variant = JavaScriptBridge.eval(
			"(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) ? 1 : 0", true)
		if prefers is float or prefers is int:
			reduced_motion = int(prefers) == 1
