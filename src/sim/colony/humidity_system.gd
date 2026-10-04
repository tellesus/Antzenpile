extends RefCounted
const CONFIG = preload("res://data/resources/default_humidity.tres")
var _run: RunState
var last_error: String = ""

func _init(run_state: RunState) -> void:
	_run = run_state

func set_workers(pile_id: String, target: Variant) -> bool:
	if not _run.colony.piles.has(pile_id) or typeof(target) != TYPE_INT or not WorkerLedger.valid_count(target) or target > CONFIG.care_cap:
		return _reject("Unknown pile or invalid climate effort")
	var pile: PileState = _run.colony.piles[pile_id]
	if pile.nursery_state != "developed":
		return _reject("Develop the Nursery before assigning climate carers")
	var current: int = pile.humidity.carers
	if target > current and pile.workers_assignable < target - current:
		return _reject("More available climate carers required")
	var id: String = "humidity:" + pile_id
	if target > current:
		if current == 0 and not pile.workers.create_commitment(id, "internal", pile_id):
			return _reject("Climate commitment unavailable")
		var allocated: bool = pile.allocate_workers(id, target - current)
		assert(allocated)
	elif target < current:
		var released: bool = pile.workers.release(id, current - target)
		assert(released)
		if target == 0:
			var retired: bool = pile.workers.retire_commitment(id)
			assert(retired)
	pile.humidity.carers = target
	last_error = ""
	return true

func tick() -> void:
	var ids: Array = _run.colony.piles.keys()
	ids.sort()
	for id: String in ids:
		var pile: PileState = _run.colony.piles[id]
		if pile.nursery_state != "developed":
			continue
		var state: HumidityState = pile.humidity
		var raining: bool = _run.rain.phase == "raining"
		var ambient: int = CONFIG.wet_ambient if raining else CONFIG.dry_ambient
		var drift: int = CONFIG.wet_step if raining else CONFIG.dry_step
		state.moisture = int(move_toward(state.moisture, ambient, drift))
		var adjustment: int = mini(absi(CONFIG.starting - state.moisture), state.carers * CONFIG.care_step)
		if state.moisture < CONFIG.starting and adjustment > 0:
			# Moisture and water cost share the same authored per-worker ratio.
			var cost: int = ceili(float(adjustment) * CONFIG.water_units_per_worker_tick / CONFIG.care_step)
			if pile.resources.water < cost / 100000.0:
				cost = floori(pile.resources.water * 100000.0)
			if cost > WorkerLedger.MAX_COUNT - state.water_used_units:
				continue
			adjustment = mini(adjustment, floori(float(cost) * CONFIG.care_step / CONFIG.water_units_per_worker_tick))
			var paid: bool = pile.consume_resources({"water": cost / 100000.0})
			assert(paid)
			state.water_used_units += cost
		state.moisture = int(move_toward(state.moisture, CONFIG.starting, adjustment))

func _reject(reason: String) -> bool:
	last_error = reason
	return false
