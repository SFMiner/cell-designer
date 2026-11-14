class_name LevelConfigs
extends RefCounted
## Named per-level constants for the resource model (GDD section 3).
## All figures are tunable model units, not measured cellular rates or molecule counts.
## Anything changed from the GDD's starting values is listed in README.md ("Tuning record").

# === CONSTANTS ===
const LEVEL_COUNT: int = 3
## Fixed simulation step in seconds, independent of rendering.
const TICK: float = 0.05

const COMMON: Dictionary = {
	"atp_cap": 60.0,
	## Below this reserve, protein synthesis and background activity slow in proportion.
	"atp_low": 10.0,
	## Below this reserve the cell is in an ATP crisis.
	"atp_critical": 3.0,
	"crisis_fail_seconds": 7.0,
	"glucose_cap": 16.0,
	"oxygen_cap": 16.0,
	"amino_cap": 12.0,
	"protein_cap": 24.0,
	"protein_atp_cost": 2.5,
	## When the construction pool is full, new proteins go to the rest of the cell (growth and repair)
	## instead of pausing the ribosomes. See README "Departures from the GDD".
	"protein_overflow_to_cell": true,
	"mito_atp_rate": 2.0,
	"mito_maint": 0.30,
	"atp_per_glucose": 8.0,
	"mito_div_atp": 5.0,
	"mito_space": 1,
	"chloro_rate": 1.1,
	"chloro_maint": 0.35,
	"chloro_div_atp": 8.0,
	"chloro_div_protein": 5.0,
	"chloro_space": 2,
	"cooldown_min": 3.0,
	"cooldown_max": 5.0,
	"starch_cap": 40.0,
	"starch_store_rate": 6.0,
	"starch_release_rate": 4.0,
	## Starch is broken down when usable glucose falls below glucose_low, and surplus above
	## glucose_high is stored. The gap stops one portion being stored and released in the same tick.
	"glucose_low": 2.0,
	"glucose_high": 6.0,
	"day_len": 30.0,
	"night_len": 15.0,
	"cycles": 2,
	"rate_epsilon": 0.05,
}

const LEVELS: Array[Dictionary] = [
	{
		"level": 1,
		"name": "Power Up",
		"cell_type": "animal",
		"goal": "Grow to 8 mitochondria, then pass the ATP power test.",
		"atp_start": 12.0,
		"glucose_start": 8.0,
		"oxygen_start": 8.0,
		"glucose_supply": 2.0,
		"oxygen_supply": 2.0,
		"amino_start": 0.0,
		"amino_supply": 0.0,
		"protein_enabled": false,
		"protein_start": 0.0,
		"protein_max_rate": 0.0,
		"mito_start": 1,
		"chloro_start": 0,
		"mito_div_protein": 0.0,
		"base_maint": 0.5,
		"space_cap": 16,
		"space_shown": false,
		"slot_spacing": 128.0,
		"starch_enabled": false,
		"starch_start": 0.0,
		"day_night": false,
		"mito_target": 8,
		"check_kind": "atp",
		"check_rate": 14.0,
		"check_seconds": 8.0,
		"check_workload": 12.5,
		"end_atp_min": 0.0,
	},
	{
		"level": 2,
		"name": "Grow and Build",
		"cell_type": "animal",
		"goal": "Grow to 24 mitochondria and keep protein production at 4 per second.",
		"atp_start": 25.0,
		"glucose_start": 8.0,
		"oxygen_start": 8.0,
		"glucose_supply": 5.5,
		"oxygen_supply": 5.5,
		"amino_start": 6.0,
		"amino_supply": 4.0,
		"protein_enabled": true,
		"protein_start": 12.0,
		"protein_max_rate": 4.0,
		"mito_start": 6,
		"chloro_start": 0,
		"mito_div_protein": 4.0,
		"base_maint": 3.0,
		"space_cap": 30,
		"space_shown": false,
		"slot_spacing": 100.0,
		"starch_enabled": false,
		"starch_start": 0.0,
		"day_night": false,
		"mito_target": 24,
		"check_kind": "protein",
		"check_rate": 4.0,
		"check_seconds": 10.0,
		"check_workload": 20.0,
		"end_atp_min": 12.0,
	},
	{
		"level": 3,
		"name": "Through the Night",
		"cell_type": "plant",
		"goal": "Keep the cell active through 2 days and 2 nights.",
		"atp_start": 30.0,
		"glucose_start": 2.2,
		"oxygen_start": 8.0,
		"glucose_supply": 0.0,
		"oxygen_supply": 3.0,
		"amino_start": 6.0,
		"amino_supply": 2.0,
		"protein_enabled": true,
		"protein_start": 12.0,
		"protein_max_rate": 2.0,
		"mito_start": 8,
		"chloro_start": 1,
		"mito_div_protein": 4.0,
		"base_maint": 3.0,
		"space_cap": 18,
		"space_shown": true,
		"slot_spacing": 112.0,
		"starch_enabled": true,
		"starch_start": 12.0,
		"day_night": true,
		"mito_target": 0,
		"check_kind": "cycles",
		"check_rate": 2.0,
		"check_seconds": 8.0,
		"check_workload": 0.0,
		"end_atp_min": 0.0,
	},
]


# === PUBLIC METHODS ===
## The merged constants for level 1, 2 or 3. Out-of-range levels fall back to level 1.
static func get_config(level: int) -> Dictionary:
	var index: int = level - 1
	if index < 0 or index >= LEVELS.size():
		index = 0
	var cfg: Dictionary = COMMON.duplicate(true)
	cfg.merge(LEVELS[index], true)
	return cfg
