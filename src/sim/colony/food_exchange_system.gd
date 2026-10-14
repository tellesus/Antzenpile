extends RefCounted
## One prepaid Primitive -> Developed transition, with ledger-owned labor.

signal chamber_online(pile_id: String)

const CONFIG = preload("res://data/resources/default_food_exchange.tres")
var _run: RunState
var last_error: String = ""


func _init(run_state: RunState) -> void:
	_run = run_state


func start(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id):
		return _reject("Unknown pile")
	var pile: PileState = _run.colony.piles[pile_id]
	if pile.food_exchange_state != "primitive":
		return _reject("Food Exchange is already developing or complete")
	if pile.workers_assignable < CONFIG.workers_required:
		return _reject("Four available workers required")
	var costs: Dictionary = CONFIG.costs()
	for resource_id: String in costs:
		if pile.resources[resource_id] < costs[resource_id]:
			return _reject("More " + resource_id + " required")
	var commitment: String = "food_exchange:" + pile_id
	if not pile.workers.create_commitment(commitment, "internal", pile_id):
		return _reject("Food Exchange labor unavailable")
	if not pile.allocate_workers(commitment, CONFIG.workers_required):
		pile.workers.retire_commitment(commitment)
		return _reject("Could not reserve workers")
	if not pile.consume_resources(costs):
		pile.workers.release(commitment, CONFIG.workers_required)
		pile.workers.retire_commitment(commitment)
		return _reject("Could not pay development cost")
	pile.food_exchange_state = "developing"
	pile.food_exchange_progress_seconds = 0.0
	last_error = ""
	return true


func tick(delta: float) -> void:
	var ids: Array = _run.colony.piles.keys()
	ids.sort()
	for pile_id: String in ids:
		var pile: PileState = _run.colony.piles[pile_id]
		if pile.food_exchange_state != "developing":
			continue
		pile.food_exchange_progress_seconds = minf(CONFIG.build_seconds, pile.food_exchange_progress_seconds + delta)
		if pile.food_exchange_progress_seconds < CONFIG.build_seconds:
			continue
		var commitment: String = "food_exchange:" + pile_id
		var released: bool = pile.workers.release(commitment, CONFIG.workers_required)
		assert(released)
		var retired: bool = pile.workers.retire_commitment(commitment)
		assert(retired)
		pile.food_exchange_state = "developed"
		chamber_online.emit(pile_id)


func _reject(reason: String) -> bool:
	last_error = reason
	return false
