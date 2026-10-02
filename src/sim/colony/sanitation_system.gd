extends RefCounted
const CONFIG = preload("res://data/resources/default_sanitation.tres")
var _run: RunState
var last_error: String = ""
func _init(run_state: RunState) -> void:
	_run = run_state
func set_workers(pile_id: String, target: Variant) -> bool:
	if not _run.colony.piles.has(pile_id) or typeof(target) != TYPE_INT or not WorkerLedger.valid_count(target) or target > CONFIG.cleaner_cap:
		return _reject("Unknown pile or invalid cleanup effort")
	var pile: PileState = _run.colony.piles[pile_id]
	var current: int = pile.midden.cleaners
	if not pile.midden.revealed:
		return _reject("Refuse isolation need has not emerged")
	if target > current and pile.workers_available < target - current:
		return _reject("More available cleanup workers required")
	var id: String = "sanitation:" + pile_id
	if target > current:
		if current == 0 and not pile.workers.create_commitment(id, "internal", pile_id):
			return _reject("Cleanup commitment unavailable")
		var allocated: bool = pile.workers.allocate(id, target - current)
		assert(allocated)
	elif target < current:
		var released: bool = pile.workers.release(id, current - target)
		assert(released)
		if target == 0:
			var retired: bool = pile.workers.retire_commitment(id)
			assert(retired)
	pile.midden.cleaners = target
	last_error = ""
	return true
func start(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id):
		return _reject("Unknown pile")
	var pile: PileState = _run.colony.piles[pile_id]
	if not pile.midden.revealed or pile.midden.state != "primitive":
		return _reject("Midden development is not available")
	if pile.workers_available < CONFIG.build_workers:
		return _reject("Four excavation workers required")
	for resource: String in CONFIG.costs():
		if pile.resources[resource] < CONFIG.costs()[resource]:
			return _reject("More " + resource + " required")
	var id: String = "midden:" + pile_id
	if not pile.workers.create_commitment(id, "internal", pile_id):
		return _reject("Midden excavation commitment unavailable")
	var allocated: bool = pile.workers.allocate(id, CONFIG.build_workers)
	var paid: bool = pile.consume_resources(CONFIG.costs())
	assert(allocated and paid)
	pile.midden.state = "developing"
	last_error = ""
	return true
func tick() -> void:
	var ids: Array = _run.colony.piles.keys()
	ids.sort()
	for id: String in ids:
		var pile: PileState = _run.colony.piles[id]
		var state: SanitationState = pile.midden
		var quarters: int = state.remainder_quarters + pile.workers_total * CONFIG.worker_quarters_per_tick + pile.nursery_occupied_space() * CONFIG.brood_quarters_per_tick
		@warning_ignore("integer_division")
		var generated: int = quarters / 4
		if generated > WorkerLedger.MAX_COUNT - state.generated_units:
			push_error("Refuse accounting exceeds exact snapshot range")
			continue
		state.generated_units += generated
		state.remainder_quarters = quarters % 4
		state.revealed = state.generated_units >= CONFIG.reveal_units
		if state.state == "developing":
			state.progress_ticks += 1
			if state.progress_ticks == CONFIG.build_ticks:
				var released: bool = pile.workers.release("midden:" + id, CONFIG.build_workers)
				var retired: bool = pile.workers.retire_commitment("midden:" + id)
				assert(released and retired)
				state.state = "developed"
		var capacity: int = state.cleaners * CONFIG.removal_units_per_worker_tick * (CONFIG.developed_multiplier if state.state == "developed" else 1)
		state.isolated_units += mini(state.burden_units, capacity)
func _reject(reason: String) -> bool:
	last_error = reason
	return false
