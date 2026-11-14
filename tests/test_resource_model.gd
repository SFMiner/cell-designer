extends "res://tests/test_base.gd"
## Resource model: start states, bounds, conservation, demand-limited respiration, night photosynthesis,
## starch storage and release, ATP-dependent throttling, supply saturation, determinism.
## Run:  Godot --headless --path . --script tests/test_resource_model.gd

const EXPECTED: int = 48


func _init() -> void:
	test_name = "test_resource_model"
	_start_states()
	_bounds()
	_respiration_rules()
	_photosynthesis_and_starch()
	_throttling()
	_saturation()
	_determinism()
	finish(EXPECTED)


func _start_states() -> void:
	var m1: SimulationModel = new_model(1)
	check(m1.count("mito") == 1 and m1.count("chloro") == 0, "L1 starts with exactly 1 mitochondrion")
	check(is_equal_approx(m1.atp, 12.0), "L1 starts with 12 ATP")
	check(is_equal_approx(m1.division_protein_cost("mito"), 0.0), "L1 division has no protein cost")
	run_for(m1, 20.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 8))
	check(is_equal_approx(m1.protein, 0.0) and is_equal_approx(m1.protein_rate, 0.0), "L1 has no protein synthesis")

	var m2: SimulationModel = new_model(2)
	check(m2.count("mito") == 6 and m2.count("chloro") == 0, "L2 starts with exactly 6 mitochondria")
	check(is_equal_approx(m2.atp, 25.0) and is_equal_approx(m2.protein, 12.0), "L2 starts with 25 ATP and 12 proteins")
	run_for(m2, 2.0)
	check(m2.protein_rate > 0.5, "L2 ribosomes synthesise protein on their own")

	var m3: SimulationModel = new_model(3)
	check(m3.count("mito") == 8 and m3.count("chloro") == 1, "L3 starts with 8 mitochondria and 1 chloroplast")
	check(is_equal_approx(m3.starch, 12.0) and is_equal_approx(float(m3.cfg["starch_cap"]), 40.0), "L3 starch starts 12 of 40")
	check(is_equal_approx(m3.protein, 12.0) and is_equal_approx(float(m3.cfg["protein_cap"]), 24.0), "L3 protein starts 12 of 24")
	check(is_equal_approx(m3.atp, 30.0), "L3 starts with 30 ATP")
	check(m3.space_used() == 10 and int(m3.cfg["space_cap"]) == 18, "L3 uses 10 of 18 space at the start")


func _bounds() -> void:
	var total: int = 0
	for s: int in range(1, 6):
		total += run_for(new_model(1, s), 60.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 16))
		total += run_for(new_model(2, s), 60.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 30))
		total += run_for(new_model(3, s), 95.0, func(m: SimulationModel) -> void: divide_kind(m, "chloro", 5))
		total += run_for(new_model(3, s), 95.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 16))
		total += run_for(new_model(3, s), 95.0)
	check(total == 0, "no resource leaves 0..cap in 25 scripted runs (%d violations)" % total)


func _respiration_rules() -> void:
	# No ATP from no fuel.
	var m: SimulationModel = new_model(1)
	m.cfg["glucose_supply"] = 0.0
	m.glucose = 0.0
	m.atp = 20.0
	m.tick(TICK)
	check(is_equal_approx(m.respiration_now, 0.0), "no glucose -> no ATP is made")
	check(m.atp < 20.0, "maintenance still draws ATP with no fuel")

	# No oxygen, same result.
	m = new_model(1)
	m.cfg["oxygen_supply"] = 0.0
	m.oxygen = 0.0
	m.tick(TICK)
	check(is_equal_approx(m.respiration_now, 0.0), "no oxygen -> no ATP is made")

	# Full ATP: respiration only covers demand, and fuel use matches it exactly.
	m = new_model(1)
	m.atp = float(m.cfg["atp_cap"])
	var g0: float = m.glucose
	var supplied: float = float(m.cfg["glucose_supply"]) * TICK
	m.tick(TICK)
	var demand_rate: float = m.maintenance_rate()
	check(absf(m.respiration_now - demand_rate) < 0.001, "at full ATP, production equals demand (%.3f vs %.3f)" % [m.respiration_now, demand_rate])
	var used: float = g0 + supplied - m.glucose
	check(absf(used - demand_rate * TICK / 8.0) < 0.0001, "at full ATP, no extra glucose is burned")
	check(absf(m.atp - float(m.cfg["atp_cap"])) < 0.001, "ATP stays at its cap, not above")

	# Glucose and oxygen are used one-for-one, 1 portion of each per 8 ATP.
	m = new_model(3)
	m.time = 31.0  # night: no photosynthesis, so sugar only goes down
	var sugar0: float = m.glucose + m.starch
	var made: float = 0.0
	var oxygen_used: float = 0.0
	for i: int in range(100):
		var o_before: float = m.oxygen + float(m.cfg["oxygen_supply"]) * TICK
		m.tick(TICK)
		made += m.respiration_now * TICK
		oxygen_used += minf(o_before, float(m.cfg["oxygen_cap"])) - m.oxygen
	var sugar_used: float = sugar0 - (m.glucose + m.starch)
	check(absf(sugar_used - made / 8.0) < 0.001, "sugar is conserved: used %.3f = ATP made / 8 = %.3f" % [sugar_used, made / 8.0])
	check(absf(oxygen_used - made / 8.0) < 0.001, "oxygen used matches glucose used (%.3f)" % oxygen_used)

	# Mitochondria respire at night too.
	check(made > 1.0, "mitochondria make ATP at night while fuel lasts")


func _photosynthesis_and_starch() -> void:
	var m: SimulationModel = new_model(3)
	var night_photo: float = 0.0
	var day_photo: float = 0.0
	var flips: int = 0
	var last_sign: int = 0
	var starch_at_dusk: float = -1.0
	var policy: Callable = func(mm: SimulationModel) -> void: divide_kind(mm, "chloro", 3)
	while not m.is_finished():
		policy.call(m)
		var was_day: bool = m.is_day()
		m.tick(TICK)
		if m.is_day():
			day_photo += m.photosynthesis_now
		else:
			night_photo += m.photosynthesis_now
			if was_day and starch_at_dusk < 0.0:
				starch_at_dusk = m.starch
		var sign: int = 0
		if m.starch_flow_now > 0.0:
			sign = 1
		elif m.starch_flow_now < 0.0:
			sign = -1
		if sign != 0 and last_sign != 0 and sign != last_sign:
			flips += 1
		if sign != 0:
			last_sign = sign
	check(is_equal_approx(night_photo, 0.0), "photosynthesis is exactly zero at night")
	check(day_photo > 0.0, "chloroplasts make sugar in daylight")
	check(flips <= 6, "starch does not flap between storing and releasing (%d direction changes in 90 s)" % flips)
	check(starch_at_dusk > 12.0, "3 chloroplasts replenish starch by the first dusk (%.1f)" % starch_at_dusk)

	# Doing nothing drains the reserve.
	m = new_model(3)
	run_for(m, 44.0)
	check(m.starch < 0.5, "with 1 chloroplast the starch reserve is used up by the first night (%.2f)" % m.starch)

	# One tick never stores and releases together: flow sign is consistent with the buffer level.
	m = new_model(3)
	var bad: int = 0
	for i: int in range(1800):
		divide_kind(m, "chloro", 2)
		m.tick(TICK)
		if m.starch_flow_now > 0.0 and m.glucose < float(m.cfg["glucose_low"]):
			bad += 1
		if m.starch_flow_now < 0.0 and m.glucose > float(m.cfg["glucose_high"]):
			bad += 1
	check(bad == 0, "storage and release never happen in the same tick")

	# Photosynthesis stops when there is nowhere to put the sugar (no matter created and thrown away).
	m = new_model(3)
	m.glucose = float(m.cfg["glucose_cap"])
	m.starch = float(m.cfg["starch_cap"])
	m.atp = float(m.cfg["atp_cap"])
	m.tick(TICK)
	check(m.photosynthesis_now <= m.respiration_now / 8.0 + 0.3, "photosynthesis is limited when glucose and starch are both full")

	# Photosynthesis adds sugar, not ATP: with no mitochondria no ATP appears.
	m = new_model(3)
	m.organelles = m.organelles.filter(func(o: SimulationModel.Org) -> bool: return o.kind == "chloro")
	m.tick(TICK)
	check(is_equal_approx(m.respiration_now, 0.0) and m.photosynthesis_now > 0.0, "chloroplasts add sugar but no ATP to the cell's pool")


func _throttling() -> void:
	var rates: Array[float] = []
	var acts: Array[float] = []
	for a: float in [1.0, 5.0, 20.0]:
		var m: SimulationModel = new_model(2)
		m.atp = a
		m.tick(TICK)
		rates.append(m.protein_rate)
		acts.append(m.activity)
	check(rates[0] < rates[1] and rates[1] < rates[2], "protein synthesis scales continuously with ATP (%s)" % str(rates))
	check(absf(rates[2] - 4.0) < 0.001, "L2 protein synthesis tops out at 4 per second")
	check(acts[0] < acts[1] and acts[1] < 1.0 and is_equal_approx(acts[2], 1.0), "background activity factor falls as ATP runs short (%s)" % str(acts))

	# Amino acids limit synthesis too.
	var m2: SimulationModel = new_model(2)
	m2.amino = 0.0
	m2.cfg["amino_supply"] = 0.0
	m2.tick(TICK)
	check(is_equal_approx(m2.protein_rate, 0.0), "no amino acids -> no protein synthesis")

	# Full construction pool: stock stays capped; surplus goes to the rest of the cell (documented departure).
	m2 = new_model(2)
	m2.protein = 24.0
	m2.atp = 40.0
	run_for(m2, 2.0)
	check(is_equal_approx(m2.protein, 24.0) and m2.protein_to_cell_total > 1.0, "full protein pool stays at its cap; surplus goes to cell use")

	# The literal GDD rule is still available as a switch.
	m2 = new_model(2)
	m2.cfg["protein_overflow_to_cell"] = false
	m2.protein = 24.0
	m2.atp = 40.0
	m2.tick(TICK)
	check(is_equal_approx(m2.protein_rate, 0.0), "with overflow off, assembly pauses at a full pool")

	# Maintenance is paid before synthesis.
	m2 = new_model(2)
	m2.atp = 0.0
	m2.glucose = 0.0
	m2.cfg["glucose_supply"] = 0.0
	m2.tick(TICK)
	check(is_equal_approx(m2.protein_rate, 0.0) and is_equal_approx(m2.atp, 0.0) and m2.activity < 0.05, "with no ATP: no synthesis, ATP clamps at 0, activity stops")


## Sandbox: a level-2 cell forced to `n` mitochondria under heavy demand.
func _sandbox_rate(n: int) -> float:
	var m: SimulationModel = new_model(2)
	m.cfg["space_cap"] = 30
	var guard: int = 0
	while m.count("mito") < n and guard < 4000:
		guard += 1
		m.atp = 60.0
		m.protein = 24.0
		divide_kind(m, "mito", n)
		m.tick(TICK)
	m.check_active = true  # stop the automatic check from starting or ending during the measurement
	m.cfg["crisis_fail_seconds"] = 1.0e9
	m.workload = 200.0
	m.atp = 0.0
	# 40 s: long enough for the 16-portion buffers to drain, so only the steady supply remains.
	for i: int in range(800):
		m.tick(TICK)
	return m.atp_made_rate


func _saturation() -> void:
	var r10: float = _sandbox_rate(10)
	var r22: float = _sandbox_rate(22)
	var r26: float = _sandbox_rate(26)
	var r30: float = _sandbox_rate(30)
	check(absf(r10 - 20.0) < 0.1, "10 mitochondria make 20 ATP/s under heavy demand (%.2f)" % r10)
	check(absf(r22 - 44.0) < 0.1, "22 mitochondria reach the 44 ATP/s supply ceiling (%.2f)" % r22)
	check(absf(r26 - r22) < 0.1 and absf(r30 - r22) < 0.1, "26 and 30 mitochondria make no more than 22 (%.2f, %.2f)" % [r26, r30])
	var m: SimulationModel = new_model(2)
	check(absf(m.supply_atp_ceiling() - 44.0) < 0.001, "L2 supply ceiling is 44 ATP/s")
	var m1: SimulationModel = new_model(1)
	check(absf(m1.supply_atp_ceiling() - 16.0) < 0.001, "L1 supply ceiling is 16 ATP/s")


func _determinism() -> void:
	var a: SimulationModel = new_model(3, 42)
	var b: SimulationModel = new_model(3, 42)
	var c: SimulationModel = new_model(3, 43)
	var policy: Callable = func(m: SimulationModel) -> void:
		divide_kind(m, "chloro", 3)
		if m.count("chloro") >= 3:
			divide_kind(m, "mito", 11)
	run_for(a, 60.0, policy)
	run_for(b, 60.0, policy)
	run_for(c, 60.0, policy)
	check(str(a.snapshot()) == str(b.snapshot()), "same seed and inputs -> identical state")
	check(str(a.snapshot()["organelles"]) != str(c.snapshot()["organelles"]), "a different seed changes maturation times")
	check(a.count("chloro") == 3 and a.count("mito") == 11, "scripted build reached 3 chloroplasts and 11 mitochondria")
	# take_events drains.
	check(a.take_events().size() > 0 and a.take_events().size() == 0, "take_events returns then clears events")
	# Finished models do not advance.
	var d: SimulationModel = new_model(1)
	d.failed = true
	var t0: float = d.time
	d.tick(TICK)
	check(is_equal_approx(d.time, t0), "a finished level no longer advances")
	check(d.try_divide(d.organelles[0].id) == "over", "no division after the level is over")
