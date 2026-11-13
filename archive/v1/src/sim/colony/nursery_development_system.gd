class_name NurseryDevelopmentSystem
extends RefCounted
## Prepaid development and one need-revealed expansion, with ledger-owned labor.

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
	if pile.workers_assignable < CONFIG.workers_required:
		return _reject("Four available workers required")
	var costs: Dictionary = CONFIG.costs()
	for resource_id: String in costs:
		if pile.resources[resource_id] < costs[resource_id]:
			return _reject("More " + resource_id + " required")
	var commitment: String = "nursery:" + pile_id
	if not pile.workers.create_commitment(commitment, "internal", pile_id):
		return _reject("Nursery labor unavailable")
	if not pile.allocate_workers(commitment, CONFIG.workers_required):
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
		_tick_expansion(pile, delta)
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


func start_expansion(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id): return _reject("Unknown pile")
	var pile: PileState = _run.colony.piles[pile_id]
	if pile.nursery_state != "developed" or pile.nursery_expansion_state != "available": return _reject("Nursery expansion is not available")
	if pile.workers_assignable < CONFIG.expansion_workers: return _reject("Eight available workers required")
	var costs: Dictionary = CONFIG.expansion_costs()
	for resource_id: String in costs:
		if pile.resources[resource_id] < costs[resource_id]: return _reject("More " + resource_id + " required")
	var commitment: String = "nursery_expansion:" + pile_id
	if not pile.workers.create_commitment(commitment, "internal", pile_id): return _reject("Expansion labor unavailable")
	if not pile.allocate_workers(commitment, CONFIG.expansion_workers):
		pile.workers.retire_commitment(commitment)
		return _reject("Could not reserve expansion workers")
	if not pile.consume_resources(costs):
		pile.workers.release(commitment, CONFIG.expansion_workers)
		pile.workers.retire_commitment(commitment)
		return _reject("Could not pay expansion cost")
	pile.nursery_expansion_state = "developing"
	pile.nursery_expansion_progress = 0.0
	last_error = ""
	return true


func _tick_expansion(pile: PileState, delta: float) -> void:
	if pile.nursery_state != "developed": return
	if pile.nursery_expansion_state == "latent" and pile.brood_matured_total >= CONFIG.expansion_matured_required and pile.shared_nursery_occupied_space() >= pile.nursery_brood_capacity():
		pile.nursery_expansion_state = "available"
	if pile.nursery_expansion_state != "developing": return
	pile.nursery_expansion_progress = minf(CONFIG.expansion_seconds, pile.nursery_expansion_progress + delta)
	if pile.nursery_expansion_progress < CONFIG.expansion_seconds: return
	var commitment: String = "nursery_expansion:" + pile.id
	var released: bool = pile.workers.release(commitment, CONFIG.expansion_workers)
	assert(released)
	var retired: bool = pile.workers.retire_commitment(commitment)
	assert(retired)
	pile.nursery_expansion_state = "developed"
	chamber_online.emit(pile.id)


func _reject(reason: String) -> bool:
	last_error = reason
	return false
