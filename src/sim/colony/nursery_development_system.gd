class_name NurseryDevelopmentSystem
extends RefCounted
## One prepaid Primitive -> Developed Nursery transition, with ledger-owned labor.

signal chamber_online(pile_id: String)

const CONFIG = preload("res://data/resources/default_nursery_development.tres")
var _run: RunState
var last_error: String = ""


func _init(run_state: RunState) -> void:
	_run = run_state


func start(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id):
		return _reject("Unknown pile")
	var pile: PileState = _run.colony.piles[pile_id]
	if pile.nursery_state != "primitive":
		return _reject("Nursery is already developing or complete")
	if pile.workers_available < CONFIG.workers_required:
		return _reject("Four available workers required")
	var costs: Dictionary = CONFIG.costs()
	for resource_id: String in costs:
		if pile.resources[resource_id] < costs[resource_id]:
			return _reject("More " + resource_id + " required")
	var commitment: String = "nursery:" + pile_id
	if not pile.workers.create_commitment(commitment, "internal", pile_id):
		return _reject("Nursery labor unavailable")
	if not pile.workers.allocate(commitment, CONFIG.workers_required):
		pile.workers.retire_commitment(commitment)
		return _reject("Could not reserve workers")
	if not pile.consume_resources(costs):
		pile.workers.release(commitment, CONFIG.workers_required)
		pile.workers.retire_commitment(commitment)
		return _reject("Could not pay development cost")
	pile.nursery_state = "developing"
	pile.nursery_progress_seconds = 0.0
	last_error = ""
	return true


func tick(delta: float) -> void:
	var ids: Array = _run.colony.piles.keys()
	ids.sort()
	for pile_id: String in ids:
		var pile: PileState = _run.colony.piles[pile_id]
		if pile.nursery_state != "developing":
			continue
		pile.nursery_progress_seconds = minf(CONFIG.build_seconds, pile.nursery_progress_seconds + delta)
		if pile.nursery_progress_seconds < CONFIG.build_seconds:
			continue
		var commitment: String = "nursery:" + pile_id
		var released: bool = pile.workers.release(commitment, CONFIG.workers_required)
		assert(released)
		var retired: bool = pile.workers.retire_commitment(commitment)
		assert(retired)
		pile.nursery_state = "developed"
		chamber_online.emit(pile_id)


func _reject(reason: String) -> bool:
	last_error = reason
	return false
