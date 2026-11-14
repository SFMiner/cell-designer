class_name SimulationModel
extends RefCounted
## The sole authoritative resource state for one level (GDD section 3).
## Pure logic: no nodes, no drawing, no input. The views read this state and call try_divide();
## cosmetic particles never feed back into it. Given the same level, seed and sequence of
## try_divide() calls, it produces the same history.

# === INNER CLASSES ===
class Org:
	extends RefCounted
	var id: int = 0
	## "mito" or "chloro".
	var kind: String = "mito"
	var slot: int = 0
	## Seconds until this organelle may divide again. 0 = ready.
	var cooldown: float = 0.0
	var cooldown_total: float = 0.0
	## Slot of the parent it split from (-1 for starting organelles). Used only for the fission animation.
	var parent_slot: int = -1
	var born_at: float = -100.0

	func is_ready() -> bool:
		return cooldown <= 0.0

	## 0..1 progress of the maturation ring.
	func ring_fraction() -> float:
		if cooldown_total <= 0.0:
			return 1.0
		return clampf(1.0 - cooldown / cooldown_total, 0.0, 1.0)


# === CONSTANTS ===
const RATE_WINDOW: int = 20
const KIND_MITO: String = "mito"
const KIND_CHLORO: String = "chloro"

# === PUBLIC VARIABLES ===
var cfg: Dictionary = {}
var level: int = 1
var time: float = 0.0
var atp: float = 0.0
var glucose: float = 0.0
var oxygen: float = 0.0
var amino: float = 0.0
var protein: float = 0.0
var starch: float = 0.0
var organelles: Array[Org] = []
var layout: OrganelleLayout = OrganelleLayout.new()

## Extra ATP demand (per second) from the automatic cell-workload test.
var workload: float = 0.0
var check_active: bool = false
var check_timer: float = 0.0
var crisis_timer: float = 0.0
var won: bool = false
var failed: bool = false
## "" or one of: "sugar_out", "oxygen_short", "atp_out", "protein_low".
var fail_reason: String = ""
## Level 3: the protein goal was met at some point in the final cycle.
var final_cycle_goal_met: bool = false

## Things that happened since the controller last looked. Drained with take_events().
var events: Array[String] = []

## Smoothed meters (1 s window), per second.
var atp_made_rate: float = 0.0
var atp_used_rate: float = 0.0
var protein_rate: float = 0.0
## 0..1: how fast ATP-dependent activity can run right now.
var activity: float = 1.0
## Last tick's raw flows, per second (cosmetic particle pacing only).
var respiration_now: float = 0.0
var photosynthesis_now: float = 0.0
## Positive while storing starch, negative while breaking it down (portions per second).
var starch_flow_now: float = 0.0
## Proteins that went to the rest of the cell because the construction pool was full.
var protein_to_cell_total: float = 0.0

# === PRIVATE VARIABLES ===
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_id: int = 1
var _made_hist: PackedFloat32Array = PackedFloat32Array()
var _used_hist: PackedFloat32Array = PackedFloat32Array()
var _prot_hist: PackedFloat32Array = PackedFloat32Array()
var _hist_pos: int = 0
var _hist_count: int = 0
var _was_day: bool = true
var _once: Dictionary = {}


# === PUBLIC METHODS ===
## Resets everything for `p_level`. The seed only drives the 3-5 s maturation times.
func setup(p_level: int, rng_seed: int) -> void:
	level = clampi(p_level, 1, LevelConfigs.LEVEL_COUNT)
	cfg = LevelConfigs.get_config(level)
	_rng.seed = rng_seed
	time = 0.0
	atp = float(cfg["atp_start"])
	glucose = float(cfg["glucose_start"])
	oxygen = float(cfg["oxygen_start"])
	amino = float(cfg["amino_start"])
	protein = float(cfg["protein_start"])
	starch = float(cfg["starch_start"])
	workload = 0.0
	check_active = false
	check_timer = 0.0
	crisis_timer = 0.0
	won = false
	failed = false
	fail_reason = ""
	final_cycle_goal_met = false
	events.clear()
	_once.clear()
	atp_made_rate = 0.0
	atp_used_rate = 0.0
	protein_rate = 0.0
	activity = 1.0
	respiration_now = 0.0
	photosynthesis_now = 0.0
	starch_flow_now = 0.0
	protein_to_cell_total = 0.0
	_made_hist.resize(RATE_WINDOW)
	_used_hist.resize(RATE_WINDOW)
	_prot_hist.resize(RATE_WINDOW)
	_made_hist.fill(0.0)
	_used_hist.fill(0.0)
	_prot_hist.fill(0.0)
	_hist_pos = 0
	_hist_count = 0
	_was_day = true
	_next_id = 1
	organelles.clear()
	var mito_start: int = int(cfg["mito_start"])
	var chloro_start: int = int(cfg["chloro_start"])
	# Enough slots that the space budget, not the slot count, is what runs out.
	var needed: int = int(cfg["space_cap"])
	layout = OrganelleLayout.new()
	layout.build(str(cfg["cell_type"]), float(cfg["slot_spacing"]), needed)
	var start_slots: Array[int] = layout.spread_slots(mito_start + chloro_start)
	for i: int in range(start_slots.size()):
		var o: Org = Org.new()
		o.id = _next_id
		_next_id += 1
		o.kind = KIND_CHLORO if i < chloro_start else KIND_MITO
		o.slot = start_slots[i]
		organelles.append(o)


func is_finished() -> bool:
	return won or failed


func count(kind: String) -> int:
	var n: int = 0
	for o: Org in organelles:
		if o.kind == kind:
			n += 1
	return n


func space_used() -> int:
	return count(KIND_MITO) * int(cfg["mito_space"]) + count(KIND_CHLORO) * int(cfg["chloro_space"])


func find(id: int) -> Org:
	for o: Org in organelles:
		if o.id == id:
			return o
	return null


func cycle_length() -> float:
	return float(cfg["day_len"]) + float(cfg["night_len"])


## Always true in levels without a day/night cycle.
func is_day() -> bool:
	if not bool(cfg["day_night"]):
		return true
	return fmod(time, cycle_length()) < float(cfg["day_len"])


## 0-based index of the current day/night cycle.
func cycle_index() -> int:
	if not bool(cfg["day_night"]):
		return 0
	return mini(int(floorf(time / cycle_length())), int(cfg["cycles"]) - 1)


## Seconds left in the current day or night.
func phase_time_left() -> float:
	if not bool(cfg["day_night"]):
		return 0.0
	var t: float = fmod(time, cycle_length())
	if t < float(cfg["day_len"]):
		return float(cfg["day_len"]) - t
	return cycle_length() - t


## 0..1 progress through the current day or night.
func phase_fraction() -> float:
	if not bool(cfg["day_night"]):
		return 0.0
	var t: float = fmod(time, cycle_length())
	if t < float(cfg["day_len"]):
		return t / float(cfg["day_len"])
	return (t - float(cfg["day_len"])) / float(cfg["night_len"])


## ATP per second the mitochondria could make with unlimited fuel and demand.
func potential_atp_rate() -> float:
	return float(count(KIND_MITO)) * float(cfg["mito_atp_rate"])


## ATP per second that the steady outside supply of glucose and oxygen can support (levels 1-2).
func supply_atp_ceiling() -> float:
	return minf(float(cfg["glucose_supply"]), float(cfg["oxygen_supply"])) * float(cfg["atp_per_glucose"])


func maintenance_rate() -> float:
	return float(cfg["base_maint"]) + float(count(KIND_MITO)) * float(cfg["mito_maint"]) \
		+ float(count(KIND_CHLORO)) * float(cfg["chloro_maint"]) + workload


func division_atp_cost(kind: String) -> float:
	return float(cfg["chloro_div_atp"]) if kind == KIND_CHLORO else float(cfg["mito_div_atp"])


func division_protein_cost(kind: String) -> float:
	return float(cfg["chloro_div_protein"]) if kind == KIND_CHLORO else float(cfg["mito_div_protein"])


func division_space(kind: String) -> int:
	return int(cfg["chloro_space"]) if kind == KIND_CHLORO else int(cfg["mito_space"])


## Why organelle `id` cannot divide right now: "" (it can), "over", "missing", "not_ready",
## "need_atp", "need_protein" or "no_room". Never changes state.
func division_block(id: int) -> String:
	if is_finished():
		return "over"
	var o: Org = find(id)
	if o == null:
		return "missing"
	if not o.is_ready():
		return "not_ready"
	if atp < division_atp_cost(o.kind):
		return "need_atp"
	if protein < division_protein_cost(o.kind):
		return "need_protein"
	if space_used() + division_space(o.kind) > int(cfg["space_cap"]):
		return "no_room"
	if layout.nearest_free(o.slot, _occupied()) < 0:
		return "no_room"
	return ""


## Transactional division: every check passes and the exact cost is spent once, or nothing changes.
## Returns "" on success, otherwise the same reason code as division_block().
func try_divide(id: int) -> String:
	var reason: String = division_block(id)
	if reason != "":
		return reason
	var parent: Org = find(id)
	var free_slot: int = layout.nearest_free(parent.slot, _occupied())
	atp -= division_atp_cost(parent.kind)
	protein -= division_protein_cost(parent.kind)
	var a: Org = _make_daughter(parent, parent.slot)
	var b: Org = _make_daughter(parent, free_slot)
	var index: int = organelles.find(parent)
	organelles.remove_at(index)
	organelles.insert(index, a)
	organelles.insert(index + 1, b)
	events.append("divided:%d:%d:%d" % [id, a.id, b.id])
	_check_start()
	return ""


## Advances the model by `dt` seconds (GDD "Per-tick algorithm").
func tick(dt: float) -> void:
	if is_finished():
		return
	time += dt
	var n_mito: int = count(KIND_MITO)
	var n_chloro: int = count(KIND_CHLORO)
	var day: bool = is_day()
	if bool(cfg["day_night"]) and day != _was_day:
		events.append("day_start" if day else "night_start")
		if not day:
			_emit_once("night_first")
	_was_day = day

	for o: Org in organelles:
		if o.cooldown > 0.0:
			o.cooldown = maxf(0.0, o.cooldown - dt)

	var glucose_cap: float = float(cfg["glucose_cap"])
	var oxygen_cap: float = float(cfg["oxygen_cap"])

	# 1. Outside supplies arrive at fixed rates into capped buffers.
	glucose = minf(glucose_cap, glucose + float(cfg["glucose_supply"]) * dt)
	oxygen = minf(oxygen_cap, oxygen + float(cfg["oxygen_supply"]) * dt)
	amino = minf(float(cfg["amino_cap"]), amino + float(cfg["amino_supply"]) * dt)

	# 2. Photosynthesis: daylight only, and only if the sugar has somewhere to go.
	var photo: float = 0.0
	var starch_on: bool = bool(cfg["starch_enabled"])
	if day and n_chloro > 0:
		var room: float = glucose_cap - glucose
		if starch_on:
			room += minf(float(cfg["starch_cap"]) - starch, float(cfg["starch_store_rate"]) * dt)
		photo = clampf(float(n_chloro) * float(cfg["chloro_rate"]) * dt, 0.0, maxf(room, 0.0))
		glucose += photo
		# Photosynthesis releases oxygen; what the buffer cannot hold leaves the cell.
		oxygen = minf(oxygen_cap, oxygen + photo)
	photosynthesis_now = photo / dt

	# 3. Starch: store a surplus or cover a deficit, never both in one tick.
	starch_flow_now = 0.0
	if starch_on:
		var high: float = float(cfg["glucose_high"])
		var low: float = float(cfg["glucose_low"])
		if glucose > high:
			var store: float = minf(minf(glucose - high, float(cfg["starch_store_rate"]) * dt),
				float(cfg["starch_cap"]) - starch)
			if store > 0.0:
				starch += store
				glucose -= store
				starch_flow_now = store / dt
				_emit_once("starch_store_first")
		elif glucose < low and starch > 0.0:
			var release: float = minf(minf(low - glucose, float(cfg["starch_release_rate"]) * dt), starch)
			if release > 0.0:
				starch -= release
				glucose += release
				starch_flow_now = -release / dt
				_emit_once("starch_breakdown_first")
	glucose = minf(glucose, glucose_cap)

	# 4. Respiration: limited by mitochondria, by fuel, and by how much ATP is wanted this tick.
	var atp_low: float = float(cfg["atp_low"])
	var throttle: float = clampf(atp / atp_low, 0.0, 1.0)
	var maint: float = maintenance_rate() * dt
	var prot_cost: float = float(cfg["protein_atp_cost"])
	var prot_want: float = 0.0
	if bool(cfg["protein_enabled"]):
		prot_want = minf(float(cfg["protein_max_rate"]) * dt * throttle, amino)
		if not bool(cfg["protein_overflow_to_cell"]):
			prot_want = minf(prot_want, float(cfg["protein_cap"]) - protein)
		prot_want = maxf(prot_want, 0.0)
	var demand: float = maint + prot_want * prot_cost
	var per_glucose: float = float(cfg["atp_per_glucose"])
	var potential: float = float(n_mito) * float(cfg["mito_atp_rate"]) * dt
	var fuel_limit: float = minf(glucose, oxygen) * per_glucose
	var wanted: float = (float(cfg["atp_cap"]) - atp) + demand
	var produced: float = maxf(0.0, minf(minf(potential, fuel_limit), wanted))
	glucose = maxf(0.0, glucose - produced / per_glucose)
	oxygen = maxf(0.0, oxygen - produced / per_glucose)
	atp += produced
	respiration_now = produced / dt

	# 5. Spend: maintenance first, then protein synthesis with what is left.
	var paid: float = minf(atp, maint)
	atp -= paid
	var shortfall: float = maint - paid
	var made: float = 0.0
	if prot_want > 0.0:
		made = minf(prot_want, atp / prot_cost)
		atp -= made * prot_cost
		amino = maxf(0.0, amino - made)
		var into_pool: float = minf(made, float(cfg["protein_cap"]) - protein)
		protein += into_pool
		protein_to_cell_total += made - into_pool
	atp = clampf(atp, 0.0, float(cfg["atp_cap"]))

	activity = throttle
	if maint > 0.0 and shortfall > 0.0:
		activity = minf(activity, 1.0 - shortfall / maint)

	_push_rates(produced / dt, (paid + made * prot_cost) / dt, made / dt)

	# 7. Derived events, checks and outcomes come from this same state.
	if level >= 2 and activity < 0.7:
		_emit_once("atp_low_first")
	if not bool(cfg["day_night"]) and level >= 2 and potential_atp_rate() >= supply_atp_ceiling():
		_emit_once("supply_limit_first")
	_check_start()
	_update_outcome(dt)


## Returns and clears the pending events.
func take_events() -> Array[String]:
	var out: Array[String] = events.duplicate()
	events.clear()
	return out


## Seconds of the current sustained check that have been met.
func check_progress() -> float:
	return check_timer


## A plain snapshot of the gameplay state, for determinism and "drawing changes nothing" tests.
func snapshot() -> Dictionary:
	var orgs: Array[String] = []
	for o: Org in organelles:
		orgs.append("%d:%s:%d:%.4f" % [o.id, o.kind, o.slot, o.cooldown])
	return {
		"time": snappedf(time, 0.0001), "atp": atp, "glucose": glucose, "oxygen": oxygen,
		"amino": amino, "protein": protein, "starch": starch, "organelles": orgs,
		"won": won, "failed": failed, "fail_reason": fail_reason, "check_timer": check_timer,
	}


# === PRIVATE METHODS ===
func _occupied() -> Dictionary:
	var occ: Dictionary = {}
	for o: Org in organelles:
		occ[o.slot] = true
	return occ


func _make_daughter(parent: Org, slot: int) -> Org:
	var d: Org = Org.new()
	d.id = _next_id
	_next_id += 1
	d.kind = parent.kind
	d.slot = slot
	d.cooldown_total = _rng.randf_range(float(cfg["cooldown_min"]), float(cfg["cooldown_max"]))
	d.cooldown = d.cooldown_total
	d.parent_slot = parent.slot
	d.born_at = time
	return d


func _emit_once(event_name: String) -> void:
	if _once.has(event_name):
		return
	_once[event_name] = true
	events.append(event_name)


func _push_rates(made: float, used: float, prot: float) -> void:
	_made_hist[_hist_pos] = made
	_used_hist[_hist_pos] = used
	_prot_hist[_hist_pos] = prot
	_hist_pos = (_hist_pos + 1) % RATE_WINDOW
	_hist_count = mini(_hist_count + 1, RATE_WINDOW)
	var sm: float = 0.0
	var su: float = 0.0
	var sp: float = 0.0
	for i: int in range(RATE_WINDOW):
		sm += _made_hist[i]
		su += _used_hist[i]
		sp += _prot_hist[i]
	atp_made_rate = sm / float(_hist_count)
	atp_used_rate = su / float(_hist_count)
	protein_rate = sp / float(_hist_count)


## Levels 1-2: reaching the mitochondria target starts the automatic workload check.
func _check_start() -> void:
	if check_active or is_finished():
		return
	var target: int = int(cfg["mito_target"])
	if target > 0 and count(KIND_MITO) >= target:
		check_active = true
		check_timer = 0.0
		workload = float(cfg["check_workload"])
		events.append("check_started")


func _update_outcome(dt: float) -> void:
	var eps: float = float(cfg["rate_epsilon"])
	var critical: float = float(cfg["atp_critical"])
	var kind: String = str(cfg["check_kind"])
	var in_crisis: bool = atp < critical

	if in_crisis:
		if crisis_timer <= 0.0:
			events.append("crisis_start")
		crisis_timer += dt
	else:
		if crisis_timer > 0.0:
			events.append("crisis_end")
		crisis_timer = 0.0

	if kind == "atp" and check_active:
		if atp_made_rate >= float(cfg["check_rate"]) - eps and not in_crisis:
			check_timer += dt
		else:
			check_timer = 0.0
		if check_timer >= float(cfg["check_seconds"]):
			_win()
			return
	elif kind == "protein" and check_active:
		if protein_rate >= float(cfg["check_rate"]) - eps and not in_crisis:
			check_timer = minf(check_timer + dt, float(cfg["check_seconds"]))
		else:
			check_timer = 0.0
		if check_timer >= float(cfg["check_seconds"]) and atp >= float(cfg["end_atp_min"]):
			_win()
			return
	elif kind == "cycles":
		var cycles: int = int(cfg["cycles"])
		var in_final: bool = time >= float(cycles - 1) * cycle_length()
		if in_final and not final_cycle_goal_met:
			if not check_active:
				check_active = true
				check_timer = 0.0
				events.append("final_cycle_started")
			if protein_rate >= float(cfg["check_rate"]) - eps and not in_crisis:
				check_timer += dt
			else:
				check_timer = 0.0
			if check_timer >= float(cfg["check_seconds"]):
				final_cycle_goal_met = true
				events.append("protein_goal_met")
		if time >= float(cycles) * cycle_length() - 0.0001:
			if final_cycle_goal_met:
				_win()
			else:
				_fail("protein_low")
			return

	if crisis_timer > float(cfg["crisis_fail_seconds"]):
		if bool(cfg["starch_enabled"]) and glucose < 0.5 and starch < 0.5:
			_fail("sugar_out")
		elif oxygen < 0.5 and glucose >= 0.5:
			_fail("oxygen_short")
		else:
			_fail("atp_out")


func _win() -> void:
	won = true
	workload = 0.0
	events.append("won")


func _fail(reason: String) -> void:
	failed = true
	fail_reason = reason
	workload = 0.0
	events.append("failed")
