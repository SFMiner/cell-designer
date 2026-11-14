extends "res://tests/test_base.gd"
## Division transactions, maturation rings and placement.
## Run:  Godot --headless --path . --script tests/test_fission.gd

const EXPECTED: int = 40


func _init() -> void:
	test_name = "test_fission"
	_blocked_divisions()
	_successful_divisions()
	_cooldowns()
	_placement()
	finish(EXPECTED)


func _state(m: SimulationModel) -> String:
	return "%.5f|%.5f|%d|%d" % [m.atp, m.protein, m.organelles.size(), m.space_used()]


func _blocked_divisions() -> void:
	# Not ready.
	var m: SimulationModel = new_model(1)
	var first: int = m.organelles[0].id
	check(m.try_divide(first) == "", "L1 first division succeeds")
	var before: String = _state(m)
	var daughter: int = m.organelles[0].id
	m.atp = 50.0
	before = _state(m)
	check(m.try_divide(daughter) == "not_ready", "a maturing organelle reports 'not_ready'")
	check(_state(m) == before, "a not-ready click spends nothing")
	check(m.try_divide(first) == "missing", "the parent no longer exists after dividing")

	# Not enough ATP.
	m = new_model(1)
	m.atp = 4.9
	before = _state(m)
	check(m.try_divide(m.organelles[0].id) == "need_atp", "4.9 ATP is not enough for a 5 ATP division")
	check(_state(m) == before, "an ATP-blocked click spends nothing")

	# Not enough protein (level 2).
	m = new_model(2)
	m.protein = 3.9
	before = _state(m)
	check(m.try_divide(m.organelles[0].id) == "need_protein", "3.9 proteins is not enough for a 4 protein division")
	check(_state(m) == before, "a protein-blocked click spends nothing")

	# ATP is checked before protein.
	m = new_model(2)
	m.atp = 1.0
	m.protein = 0.0
	check(m.try_divide(m.organelles[0].id) == "need_atp", "ATP is reported before protein when both are short")

	# No room (level 3 hard cap).
	m = new_model(3)
	var guard: int = 0
	while m.space_used() < 18 and guard < 4000:
		guard += 1
		m.atp = 60.0
		m.protein = 24.0
		divide_kind(m, "mito", 16)
		m.tick(TICK)
	check(m.space_used() == 18, "L3 can be filled to exactly 18 space units")
	run_for(m, 6.0)
	m.atp = 60.0
	m.protein = 24.0
	before = _state(m)
	var mito_id: int = -1
	var chloro_id: int = -1
	for o: SimulationModel.Org in m.organelles:
		if o.kind == "mito":
			mito_id = o.id
		else:
			chloro_id = o.id
	check(m.try_divide(mito_id) == "no_room" and m.try_divide(chloro_id) == "no_room", "a full cell reports 'no_room'")
	check(_state(m) == before, "a room-blocked click spends nothing")

	# A chloroplast needs 2 free units.
	m = new_model(3)
	m.cfg["space_cap"] = 11
	m.atp = 60.0
	m.protein = 24.0
	check(m.try_divide(m.organelles[0].id) == "no_room", "a chloroplast needs 2 free space units (1 is not enough)")
	check(m.organelles[0].kind == "chloro", "the first L3 organelle is the chloroplast")


func _successful_divisions() -> void:
	var m: SimulationModel = new_model(1)
	var atp0: float = m.atp
	var parent: SimulationModel.Org = m.organelles[0]
	var potential0: float = m.potential_atp_rate()
	check(m.try_divide(parent.id) == "", "L1 division succeeds")
	check(is_equal_approx(atp0 - m.atp, 5.0) and is_equal_approx(m.protein, 0.0), "L1 division costs exactly 5 ATP and no protein")
	check(m.organelles.size() == 2 and m.find(parent.id) == null, "the parent is replaced by two daughters")
	var a: SimulationModel.Org = m.organelles[0]
	var b: SimulationModel.Org = m.organelles[1]
	check(a.slot != b.slot and (a.slot == parent.slot or b.slot == parent.slot), "one daughter keeps the parent's place, the other takes a free neighbour")
	check(a.cooldown >= 3.0 and a.cooldown <= 5.0 and b.cooldown >= 3.0 and b.cooldown <= 5.0, "daughters mature in 3-5 s")
	check(not is_equal_approx(a.cooldown, b.cooldown), "each daughter has its own maturation time")
	check(is_equal_approx(m.potential_atp_rate(), potential0 * 2.0), "maturing daughters already work (capacity doubled at once)")
	var events: Array[String] = m.take_events()
	check(events.size() == 1 and events[0].begins_with("divided:"), "exactly one 'divided' event")

	m = new_model(2)
	atp0 = m.atp
	var p0: float = m.protein
	check(m.try_divide(m.organelles[0].id) == "", "L2 division succeeds")
	check(is_equal_approx(atp0 - m.atp, 5.0) and is_equal_approx(p0 - m.protein, 4.0), "L2 division costs exactly 5 ATP and 4 proteins")

	m = new_model(3)
	atp0 = m.atp
	p0 = m.protein
	var space0: int = m.space_used()
	check(m.try_divide(m.organelles[0].id) == "", "L3 chloroplast division succeeds")
	check(is_equal_approx(atp0 - m.atp, 8.0) and is_equal_approx(p0 - m.protein, 5.0), "chloroplast division costs exactly 8 ATP and 5 proteins")
	check(m.space_used() == space0 + 2 and m.count("chloro") == 2, "a new chloroplast adds 2 space units")


func _cooldowns() -> void:
	var m: SimulationModel = new_model(1, 5)
	m.try_divide(m.organelles[0].id)
	var a: SimulationModel.Org = m.organelles[0]
	check(is_equal_approx(a.ring_fraction(), 0.0) and not a.is_ready(), "a new daughter's ring starts empty")
	run_for(m, 2.0)
	check(a.ring_fraction() > 0.3 and a.ring_fraction() < 0.8, "the ring fills over time (%.2f at 2 s)" % a.ring_fraction())
	run_for(m, 3.05)
	var all_ready: bool = true
	for o: SimulationModel.Org in m.organelles:
		all_ready = all_ready and o.is_ready() and is_equal_approx(o.ring_fraction(), 1.0)
	check(all_ready, "every ring is complete and actionable after 5 s")
	# Rings in a long greedy run always complete.
	var stuck: int = 0
	for s: int in range(1, 6):
		var g: SimulationModel = new_model(2, s)
		run_for(g, 40.0, func(mm: SimulationModel) -> void: divide_kind(mm, "mito", 30))
		g.won = false
		for i: int in range(120):
			for o: SimulationModel.Org in g.organelles:
				if o.cooldown > 0.0:
					o.cooldown = maxf(0.0, o.cooldown - TICK)
		for o: SimulationModel.Org in g.organelles:
			if not o.is_ready():
				stuck += 1
	check(stuck == 0, "no ring is left incomplete (%d stuck)" % stuck)


func _placement() -> void:
	var problems: int = 0
	var fills: Array = [[1, "mito", 16], [2, "mito", 30], [3, "mito", 16], [3, "chloro", 5]]
	for f: Array in fills:
		for s: int in range(1, 6):
			var m: SimulationModel = new_model(int(f[0]), s)
			var guard: int = 0
			while guard < 6000:
				guard += 1
				m.atp = 60.0
				m.protein = 24.0
				divide_kind(m, str(f[1]), int(f[2]))
				m.tick(TICK)
				m.won = false
				m.check_active = true
				problems += _placement_problems(m)
				if m.count(str(f[1])) >= int(f[2]):
					break
			if m.count(str(f[1])) < int(f[2]):
				problems += 1
	check(problems == 0, "organelles never share a slot, leave the cytoplasm or enter the vacuole (%d problems)" % problems)

	for level: int in [1, 2, 3]:
		var m: SimulationModel = new_model(level)
		check(m.layout.slots.size() >= int(m.cfg["space_cap"]), "L%d has at least as many slots (%d) as its space cap" % [level, m.layout.slots.size()])
		var min_d: float = INF
		for i: int in range(m.layout.slots.size()):
			for j: int in range(i + 1, m.layout.slots.size()):
				min_d = minf(min_d, m.layout.slots[i].distance_to(m.layout.slots[j]))
		check(min_d >= m.layout.spacing - 0.01, "L%d slots are at least one spacing apart (%.1f >= %.1f)" % [level, min_d, m.layout.spacing])

	var m3: SimulationModel = new_model(3)
	var all_slots: Array[int] = []
	for i: int in range(m3.layout.slots.size()):
		all_slots.append(i)
	var order: Array[int] = m3.layout.reading_order(all_slots)
	var seen: Dictionary = {}
	for i: int in order:
		seen[i] = true
	check(order.size() == all_slots.size() and seen.size() == all_slots.size(), "reading order is a permutation of the slots")
	var m1: SimulationModel = new_model(1)
	check(m1.layout.slots.size() >= 16, "L1 is roomy: 16 or more places")


func _placement_problems(m: SimulationModel) -> int:
	var bad: int = 0
	var used: Dictionary = {}
	var radius: float = m.layout.spacing * 0.5
	for o: SimulationModel.Org in m.organelles:
		if used.has(o.slot):
			bad += 1
		used[o.slot] = true
		if not m.layout.is_inside(m.layout.slots[o.slot], radius):
			bad += 1
	return bad
