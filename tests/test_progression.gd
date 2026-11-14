extends "res://tests/test_base.gd"
## Scripted three-level playthroughs: legal winning paths, failure paths, event-once behaviour.
## Rare outcomes are judged on 30 seeds (the seed only changes the 3-5 s maturation times).
## Run:  Godot --headless --path . --script tests/test_progression.gd

const EXPECTED: int = 36
const SEEDS: int = 30


func _init() -> void:
	test_name = "test_progression"
	_level_1()
	_level_2()
	_level_3()
	finish(EXPECTED)


## Plays one run. Returns {"won", "failed", "reason", "time", "events": {name: [times]}, "min_atp"}.
func _play(level: int, rng_seed: int, max_time: float, policy: Callable) -> Dictionary:
	var m: SimulationModel = new_model(level, rng_seed)
	var events: Dictionary = {}
	var min_atp: float = INF
	var ticks: int = int(max_time / TICK)
	for i: int in range(ticks):
		if m.is_finished():
			break
		if policy.is_valid():
			policy.call(m)
		m.tick(TICK)
		min_atp = minf(min_atp, m.atp)
		for e: String in m.take_events():
			var key: String = "divided" if e.begins_with("divided") else e
			if not events.has(key):
				events[key] = []
			events[key].append(m.time)
	return {"won": m.won, "failed": m.failed, "reason": m.fail_reason, "time": m.time, "events": events,
		"min_atp": min_atp, "model": m}


func _wins(level: int, max_time: float, policy: Callable) -> int:
	var n: int = 0
	for s: int in range(1, SEEDS + 1):
		if bool(_play(level, s, max_time, policy)["won"]):
			n += 1
	return n


func _level_1() -> void:
	var to8: Callable = func(m: SimulationModel) -> void: divide_kind(m, "mito", 8)
	var r: Dictionary = _play(1, 1, 120.0, to8)
	var ev: Dictionary = r["events"]
	check(bool(r["won"]), "L1: dividing each ready mitochondrion up to 8 wins")
	check(ev.has("check_started") and ev["divided"].size() == 7, "L1: 7 divisions reach 8 and start the power test")
	var check_t: float = ev["check_started"][0]
	var won_t: float = ev["won"][0]
	check(won_t - check_t >= 8.0 - 0.051, "L1: the win comes only after 8 s of power test (%.2f s)" % (won_t - check_t))
	check(_wins(1, 120.0, to8) == SEEDS, "L1: the scripted path wins on all %d seeds" % SEEDS)
	var r7: Dictionary = _play(1, 1, 120.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 7))
	check(not bool(r7["won"]) and not bool(r7["failed"]), "L1: 7 mitochondria never win (and nothing fails)")
	var m7: SimulationModel = r7["model"]
	check(not m7.check_active, "L1: the power test does not start before 8 mitochondria")
	var idle: Dictionary = _play(1, 1, 60.0, Callable())
	check(not bool(idle["won"]) and not bool(idle["failed"]), "L1: doing nothing neither wins nor fails")
	check(_wins(1, 120.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 16)) == SEEDS,
		"L1: overbuilding to 16 still wins on all seeds")
	# The sustained timer resets when output drops below 14 ATP/s.
	var m: SimulationModel = new_model(1, 1)
	run_for(m, 14.0, to8)
	var mid: float = m.check_timer
	m.glucose = 0.0
	m.cfg["glucose_supply"] = 0.0
	run_for(m, 1.5)
	check(mid > 2.0 and is_equal_approx(m.check_timer, 0.0) and not m.won, "L1: the 8 s count restarts if ATP output drops")


func _level_2() -> void:
	var to24: Callable = func(m: SimulationModel) -> void: divide_kind(m, "mito", 24)
	var r: Dictionary = _play(2, 1, 300.0, to24)
	var m: SimulationModel = r["model"]
	check(bool(r["won"]), "L2: dividing whenever possible up to 24 wins")
	check(m.count("mito") == 24 and m.atp >= 12.0, "L2: wins with 24 mitochondria and at least 12 ATP (%.1f)" % m.atp)
	check(m.protein_rate >= 4.0 - 0.05, "L2: protein output is 4 per second at the win (%.2f)" % m.protein_rate)
	var ev: Dictionary = r["events"]
	check(float(ev["won"][0]) - float(ev["check_started"][0]) >= 10.0 - 0.051, "L2: the win needs 10 s of sustained output")
	check(ev.has("supply_limit_first") and ev["supply_limit_first"].size() == 1, "L2: the supply-limit lesson fires once")
	check(_wins(2, 300.0, to24) == SEEDS, "L2: the scripted path wins on all %d seeds" % SEEDS)
	var r23: Dictionary = _play(2, 1, 120.0, func(mm: SimulationModel) -> void: divide_kind(mm, "mito", 23))
	check(not bool(r23["won"]), "L2: 23 mitochondria never win")
	var idle: Dictionary = _play(2, 1, 120.0, Callable())
	check(not bool(idle["won"]) and float(idle["min_atp"]) < 10.0, "L2: doing nothing never wins; ATP sits low and synthesis is throttled")
	# Failure rule in a constructed shortage: fuel cut off -> crisis -> fail after more than 7 s.
	var cut: SimulationModel = new_model(2, 1)
	cut.cfg["glucose_supply"] = 0.0
	cut.glucose = 0.0
	var crisis_at: float = -1.0
	for i: int in range(2000):
		cut.tick(TICK)
		if crisis_at < 0.0 and cut.crisis_timer > 0.0:
			crisis_at = cut.time
		if cut.is_finished():
			break
	check(cut.failed and cut.fail_reason == "atp_out", "L2: with fuel cut off the cell fails (reason '%s')" % cut.fail_reason)
	check(cut.time - crisis_at >= 7.0 - 0.001 and cut.time - crisis_at < 7.3, "L2: failure comes only after more than 7 s of crisis (%.2f s)" % (cut.time - crisis_at))
	# End-of-check ATP floor.
	var low: SimulationModel = new_model(2, 1)
	run_for(low, 300.0, func(mm: SimulationModel) -> void:
		divide_kind(mm, "mito", 24)
		if mm.check_active:
			mm.atp = minf(mm.atp, 11.0))
	check(not low.won, "L2: no win while the ATP reserve is under 12")


func _level_3() -> void:
	var chloro3: Callable = func(m: SimulationModel) -> void: divide_kind(m, "chloro", 3)
	var r: Dictionary = _play(3, 1, 120.0, chloro3)
	var ev: Dictionary = r["events"]
	check(bool(r["won"]) and absf(float(r["time"]) - 90.0) < 0.06, "L3: early chloroplast investment wins at the second dawn (t=%.2f)" % float(r["time"]))
	check(ev.has("protein_goal_met") and float(ev["protein_goal_met"][0]) >= 45.0, "L3: the protein goal is met during the final cycle")
	check(ev["starch_store_first"].size() == 1 and ev["starch_breakdown_first"].size() == 1 and ev["night_first"].size() == 1,
		"L3: first storage, first breakdown and first night each fire exactly once")
	check(ev["night_start"].size() == 2 and ev["day_start"].size() == 1, "L3: two nights and one new dawn before the end")
	check(_wins(3, 120.0, chloro3) == SEEDS, "L3: the chloroplast strategy wins on all %d seeds" % SEEDS)

	var idle: Dictionary = _play(3, 1, 120.0, Callable())
	var iev: Dictionary = idle["events"]
	check(bool(idle["failed"]) and str(idle["reason"]) == "sugar_out" and float(idle["time"]) < 90.0,
		"L3: doing nothing fails before the second dawn: stored sugar ran out (t=%.1f)" % float(idle["time"]))
	check(iev["starch_breakdown_first"].size() == 1 and float(iev["starch_breakdown_first"][0]) < 10.0,
		"L3: starch breakdown starts early in the first day (t=%.1f) and its event fires once" % float(iev["starch_breakdown_first"][0]))
	check(not iev.has("starch_store_first"), "L3: with 1 chloroplast there is never surplus sugar to store")
	check(iev.has("crisis_start") and float(iev["crisis_start"][0]) > 30.0 and float(iev["crisis_start"][0]) < 45.0,
		"L3: doing nothing causes an energy shortage during the first night (t=%.1f)" % float(iev["crisis_start"][0]))
	check(float(idle["time"]) - float(iev["crisis_start"][0]) >= 7.0 - 0.001,
		"L3: an ATP dip does not end the game at once (crisis from %.1f s, failure at %.1f s)" % [
			float(iev["crisis_start"][0]), float(idle["time"])])
	# A short dip that recovers is survivable.
	var dip: SimulationModel = new_model(3, 1)
	run_for(dip, 5.0, chloro3)
	dip.atp = 0.0
	run_for(dip, 10.0, chloro3)
	check(not dip.failed and dip.atp > 3.0, "L3: a brief dip below the crisis line recovers without failing (ATP %.1f)" % dip.atp)
	var idle_fails: int = 0
	for s: int in range(1, SEEDS + 1):
		if bool(_play(3, s, 120.0, Callable())["failed"]):
			idle_fails += 1
	check(idle_fails == SEEDS, "L3: doing nothing fails on all %d seeds" % SEEDS)

	var mito_only: Dictionary = _play(3, 1, 120.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 16))
	check(bool(mito_only["failed"]) and float(mito_only["time"]) < 45.0, "L3: spending everything on mitochondria fails in the first night")

	# The cycle goal: surviving without ever sustaining protein output is a failure with its own cause.
	var weak: SimulationModel = new_model(3, 1)
	weak.cfg["amino_supply"] = 1.0
	run_for(weak, 120.0, chloro3)
	check(weak.failed and weak.fail_reason == "protein_low" and absf(weak.time - 90.0) < 0.06,
		"L3: surviving without the protein goal fails at the second dawn ('%s')" % weak.fail_reason)

	# The protein goal only counts in the final cycle.
	var early: SimulationModel = new_model(3, 1)
	run_for(early, 44.0, chloro3)
	check(not early.final_cycle_goal_met and early.protein_rate > 1.9, "L3: protein output in the first cycle does not count toward the goal")

	# Oxygen can limit an overbuilt plant cell at night (extra mitochondria are not free).
	var crowded: SimulationModel = new_model(3, 1)
	crowded.cfg["glucose_supply"] = 10.0
	var guard: int = 0
	while crowded.count("mito") < 16 and guard < 4000:
		guard += 1
		crowded.atp = 60.0
		crowded.protein = 24.0
		divide_kind(crowded, "mito", 16)
		crowded.tick(TICK)
	crowded.time = 31.0
	crowded.cfg["crisis_fail_seconds"] = 1.0e9
	crowded.workload = 100.0
	crowded.atp = 0.0
	crowded.time = 31.0
	# The stored oxygen buffer drains first; hold the clock in the night while it does.
	for i: int in range(600):
		crowded.time = 31.0
		crowded.tick(TICK)
	check(absf(crowded.atp_made_rate - 24.0) < 0.2, "L3: at night 16 mitochondria are held to 24 ATP/s by oxygen supply (%.1f)" % crowded.atp_made_rate)
