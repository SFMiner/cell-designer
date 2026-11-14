class_name Tutorials
extends RefCounted
## All player-facing teaching text and when it appears. Data only: game_controller.gd shows it.
##
## Each beat: id, level, trigger ("time" with `at` seconds of level time, "event" with a model event
## name, "mito" with a mitochondria `count`, or "space" with space units used), text, and what to
## emphasise: `glyphs` (molecule kinds), `organelles` ("mito"/"chloro"), `meters` (HUD rows),
## `starch` / `ribosomes` (true to outline them). Each beat shows once per attempt at a level.

# === CONSTANTS ===
const GAME_TITLE: String = "Cell Designer: Power & Growth"

const OPENING: Array[String] = [
	"Your cell needs more ATP. Help it increase its ability to carry out cellular respiration.",
	"This cell must grow and build. Divide mitochondria so there is enough ATP to keep making proteins.",
	"This plant cell must stay active through two days and two nights. Balance its chloroplasts and mitochondria.",
]

const OPENING_NOTES: Array[String] = [
	"In this first level, dividing costs only ATP. Real cells also need proteins to build new organelles. That starts in Level 2.",
	"Dividing now costs ATP and proteins. Ribosomes make the proteins for you.",
	"Chloroplasts make sugar only in light. Mitochondria use sugar to supply ATP all the time.",
]

const HOW_TO: String = "Click or tap an organelle with a complete ring to divide it. Keyboard: Tab moves, Enter or Space divides, Escape closes a message or leaves the game."

const WIN_TEXT: Array[String] = [
	"Your 8 mitochondria made at least 14 ATP per second for 8 seconds. More mitochondria raised the cell's ability to carry out cellular respiration.",
	"Your cell kept building proteins because its mitochondria supplied enough ATP. Notice that glucose and oxygen set a limit on how much ATP any number of mitochondria can make.",
	"Your plant cell stayed active for two days and two nights. Chloroplasts made sugar in the light, extra sugar was stored as starch, and mitochondria used sugar to supply ATP day and night.",
]

const FAIL_TEXT: Dictionary = {
	"sugar_out": "Stored sugar ran out; ATP production fell.",
	"oxygen_short": "Oxygen ran short, so the mitochondria could not make enough ATP.",
	"atp_out": "The cell used ATP faster than its mitochondria could make it.",
	"protein_low": "The cell survived, but in the final day and night it never kept protein production at 2 per second for 8 seconds.",
}

const NIGHT_BANNER: String = "No light: chloroplasts stop making sugar. Stored starch can still fuel respiration."

const BEATS: Array[Dictionary] = [
	{
		"id": "l1_respiration", "level": 1, "trigger": "time", "at": 1.5,
		"text": "Mitochondria use glucose and oxygen during cellular respiration to supply ATP. Carbon dioxide and water are released.",
		"glyphs": ["glucose", "oxygen"], "meters": ["glucose", "oxygen"],
	},
	{
		"id": "l1_divide", "level": 1, "trigger": "time", "at": 4.5, "skip_if_divided": true,
		"text": "Click a mitochondrion to divide it. Dividing costs 5 ATP.",
		"organelles": "mito", "meters": ["atp"],
	},
	{
		"id": "l1_ring", "level": 1, "trigger": "event", "event": "divided",
		"text": "New mitochondria need a few seconds to grow. When the ring around one is complete, it is ready to divide again.",
		"organelles": "mito",
	},
	{
		"id": "l1_capacity", "level": 1, "trigger": "mito", "count": 4,
		"text": "More mitochondria can make more ATP each second, as long as glucose and oxygen keep arriving.",
		"meters": ["rates"],
	},
	{
		"id": "l1_test", "level": 1, "trigger": "event", "event": "check_started",
		"text": "Power test! The cell is now working hard and using much more ATP. Your mitochondria must make at least 14 ATP per second for 8 seconds.",
		"meters": ["check", "rates"],
	},
	{
		"id": "l2_protein", "level": 2, "trigger": "time", "at": 1.0,
		"text": "Ribosomes join amino acids into proteins. Building proteins uses energy from ATP.",
		"glyphs": ["amino", "protein"], "ribosomes": true, "meters": ["protein", "protein_rate"],
	},
	{
		"id": "l2_cost", "level": 2, "trigger": "time", "at": 4.0,
		"text": "Dividing a mitochondrion now costs 5 ATP and 4 proteins. Grow from 6 to 24 mitochondria.",
		"organelles": "mito", "meters": ["atp", "protein"],
	},
	{
		"id": "l2_low", "level": 2, "trigger": "event", "event": "atp_low_first",
		"text": "ATP is running low, so ribosomes, pumps and vesicles are slowing down. More mitochondria can supply more ATP.",
		"meters": ["atp", "rates"],
	},
	{
		"id": "l2_supply", "level": 2, "trigger": "event", "event": "supply_limit_first",
		"text": "Glucose and oxygen arrive at a limited rate. Once mitochondria use them as fast as they arrive, extra mitochondria cannot make more ATP, but each one still costs ATP to maintain.",
		"glyphs": ["glucose", "oxygen"], "meters": ["glucose", "oxygen", "rates"],
	},
	{
		"id": "l2_check", "level": 2, "trigger": "event", "event": "check_started",
		"text": "Sustainability check! The cell is working hard. Keep making at least 4 proteins per second for 10 seconds, and finish with at least 12 ATP in reserve.",
		"meters": ["check", "protein_rate", "atp"],
	},
	{
		"id": "l3_plant", "level": 3, "trigger": "time", "at": 0.05,
		"text": "This is a plant cell. In light, chloroplasts use carbon dioxide and water to make sugar and release oxygen. Mitochondria still supply the cell's ATP, day and night.",
		"organelles": "chloro", "meters": ["day"],
	},
	{
		"id": "l3_starch_breakdown", "level": 3, "trigger": "event", "event": "starch_breakdown_first",
		"text": "Your cell is using stored starch to release sugar. This reserve will run out. Divide chloroplasts to make more sugar while sunlight is available!",
		"glyphs": ["starch"], "starch": true, "meters": ["starch"],
	},
	{
		"id": "l3_starch_store", "level": 3, "trigger": "event", "event": "starch_store_first",
		"text": "Extra sugar is being stored as starch. The cell can use it when there is no sunlight.",
		"glyphs": ["starch"], "starch": true, "meters": ["starch"],
	},
	{
		"id": "l3_room", "level": 3, "trigger": "space", "count": 14,
		"text": "Room is limited. A chloroplast takes 2 spaces and a mitochondrion takes 1. Every organelle also costs ATP to maintain.",
		"meters": ["space"],
	},
]

const HELP_PAGES: Array[Dictionary] = [
	{
		"title": "How to play",
		"text": "Click or tap an organelle to make it divide. An organelle can divide when the ring around it is complete. Dividing costs ATP (and proteins from Level 2 on), and new organelles need a few seconds to grow.\n\nSupplies enter the cell and products leave on their own. Watch the meters to see what your choices change.\n\nKeyboard: Tab and Shift+Tab move between buttons and organelles. Enter or Space divides. Escape closes a message; with nothing open, Escape leaves the game.",
	},
	{
		"title": "What the shapes mean",
		"text": "Each kind of molecule has its own shape:",
		"legend": true,
	},
	{
		"title": "About this model",
		"text": "This is a simplified model. Its ATP, glucose and protein numbers are model units, not counts of real molecules. One glucose does not make 8 ATP in a real cell.\n\nNothing here is drawn to scale: real molecules are far smaller than organelles. Real organelles also take much longer than a few seconds to grow and divide.\n\nOverall, cellular respiration turns glucose and oxygen into carbon dioxide and water, releasing energy that the cell captures in ATP. Photosynthesis uses light, carbon dioxide and water to make sugar and oxygen.",
	},
]


# === PUBLIC METHODS ===
## Player-facing reason a division was refused.
static func block_text(reason: String, atp_cost: float, protein_cost: float) -> String:
	match reason:
		"not_ready":
			return "Not ready"
		"need_atp":
			return "Need %d ATP" % int(atp_cost)
		"need_protein":
			return "Need %d proteins" % int(protein_cost)
		"no_room":
			return "Not enough room"
	return ""


static func beats_for(level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in BEATS:
		if int(b["level"]) == level:
			out.append(b)
	return out
