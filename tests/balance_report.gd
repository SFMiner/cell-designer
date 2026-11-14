extends "res://tests/test_base.gd"
## Not a pass/fail test: prints how each scripted strategy plays out over many seeds, for tuning.
## Run:  Godot --headless --path . --script tests/balance_report.gd


func _init() -> void:
	var seeds: int = 30
	_report("L1 greedy to 8", 1, seeds, 120.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 8))
	_report("L1 greedy to 16", 1, seeds, 120.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 16))
	_report("L1 do nothing", 1, 3, 120.0, Callable())
	_report("L2 greedy to 24", 2, seeds, 300.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 24))
	_report("L2 greedy to 30", 2, seeds, 300.0, func(m: SimulationModel) -> void: divide_kind(m, "mito", 30))
	_report("L2 do nothing", 2, 3, 120.0, Callable())
	for n: int in [1, 2, 3, 4, 5]:
		_report("L3 chloroplasts to %d" % n, 3, seeds, 120.0,
			func(m: SimulationModel) -> void: divide_kind(m, "chloro", n))
	_report("L3 mitochondria only (to 16)", 3, seeds, 120.0,
		func(m: SimulationModel) -> void: divide_kind(m, "mito", 16))
	_report("L3 mito first then chloro", 3, seeds, 120.0, func(m: SimulationModel) -> void:
		divide_kind(m, "mito", 12)
		divide_kind(m, "chloro", 4))
	_report("L3 3 chloro + mito to fill", 3, seeds, 120.0, func(m: SimulationModel) -> void:
		divide_kind(m, "chloro", 3)
		if m.count("chloro") >= 3:
			divide_kind(m, "mito", 16))
	quit(0)


func _report(label: String, level: int, seeds: int, max_time: float, policy: Callable) -> void:
	var wins: int = 0
	var fails: int = 0
	var end_times: Array[float] = []
	var reasons: Dictionary = {}
	var min_atp: float = INF
	var first_events: Dictionary = {}
	for s: int in range(1, seeds + 1):
		var m: SimulationModel = new_model(level, s)
		var ticks: int = int(max_time / TICK)
		for i: int in range(ticks):
			if m.is_finished():
				break
			if policy.is_valid():
				policy.call(m)
			m.tick(TICK)
			min_atp = minf(min_atp, m.atp)
			for e: String in m.take_events():
				if not e.begins_with("divided") and not first_events.has(e):
					first_events[e] = snappedf(m.time, 0.1)
		if m.won:
			wins += 1
		if m.failed:
			fails += 1
			reasons[m.fail_reason] = int(reasons.get(m.fail_reason, 0)) + 1
		end_times.append(snappedf(m.time, 0.1))
	end_times.sort()
	print("%-30s wins %2d/%d fails %2d  end %.1f..%.1f s  min ATP %.1f  %s  events(seed1..): %s" % [label, wins,
		seeds, fails, end_times[0], end_times[-1], min_atp, str(reasons), str(first_events)])
