extends SceneTree
## Shared helpers for the headless tests. Each test script extends this, implements run(), and
## must report the exact number of checks it expects, so an aborted test cannot pass quietly.
## Run:  Godot --headless --path . --script tests/<name>.gd

# === CONSTANTS ===
const TICK: float = 0.05

# === PUBLIC VARIABLES ===
var passed: int = 0
var failures: int = 0
var test_name: String = "test"


# === PUBLIC METHODS ===
func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		print("  FAIL: " + label)


func finish(expected_total: int) -> void:
	var total: int = passed + failures
	var ok: bool = failures == 0 and total == expected_total
	print("%s: %d/%d passed (expected %d checks) -> %s" % [test_name, passed, total, expected_total,
		"PASS" if ok else "FAIL"])
	quit(0 if ok else 1)


func new_model(level: int, rng_seed: int = 1) -> SimulationModel:
	var m: SimulationModel = SimulationModel.new()
	m.setup(level, rng_seed)
	return m


## Runs `seconds` of model time, calling `policy` (may be an empty Callable) before every tick.
## Returns the number of bound violations seen (any resource below 0 or above its cap).
func run_for(m: SimulationModel, seconds: float, policy: Callable = Callable()) -> int:
	var violations: int = 0
	var ticks: int = int(round(seconds / TICK))
	for i: int in range(ticks):
		if m.is_finished():
			break
		if policy.is_valid():
			policy.call(m)
		m.tick(TICK)
		violations += bounds_violations(m)
	return violations


func bounds_violations(m: SimulationModel) -> int:
	var v: int = 0
	var pairs: Array = [
		[m.atp, m.cfg["atp_cap"]], [m.glucose, m.cfg["glucose_cap"]], [m.oxygen, m.cfg["oxygen_cap"]],
		[m.amino, m.cfg["amino_cap"]], [m.protein, m.cfg["protein_cap"]], [m.starch, m.cfg["starch_cap"]],
	]
	for p: Array in pairs:
		var value: float = p[0]
		var cap: float = p[1]
		if value < -0.00001 or value > cap + 0.00001:
			v += 1
	if m.space_used() > int(m.cfg["space_cap"]):
		v += 1
	return v


## Policy: divide every organelle of `kind` that can divide, while fewer than `limit` of that kind exist.
func divide_kind(m: SimulationModel, kind: String, limit: int) -> void:
	for o: SimulationModel.Org in m.organelles.duplicate():
		if m.count(kind) >= limit:
			return
		if o.kind == kind and m.division_block(o.id) == "":
			m.try_divide(o.id)
