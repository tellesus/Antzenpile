class_name BroodCareRelief
extends RefCounted
## Voluntary, named reassignment through existing job owners; no workers teleport.
var _run: RunState
var _jobs: Dictionary

func _init(run_state: RunState, jobs: Dictionary) -> void:
	_run = run_state
	_jobs = jobs

func plan(pile_id: String) -> Dictionary:
	if not _run.colony.piles.has(pile_id): return {}
	var pile: PileState = _run.colony.piles[pile_id]
	var missing: int = maxi(0, pile.brood_care_workers_required() - pile.workers_available)
	if missing == 0: return {}
	for route: TrailRouteState in _run.trails.routes.values():
		if route.origin_pile == pile_id and route.purpose == "food" and route.desired_workers < route.allocated_workers + _run.trails.pending_losses(route.id): return {"kind":"returning"}
	if pile.humidity.carers > 0:
		return {"kind":"climate", "target":maxi(0,pile.humidity.carers-missing), "workers":mini(missing,pile.humidity.carers)}
	if pile.midden.cleaners > 0:
		return {"kind":"cleanup", "target":maxi(0,pile.midden.cleaners-missing), "workers":mini(missing,pile.midden.cleaners)}
	if pile_id == "home" and _run.honeydew.relationship == "tended":
		return {"kind":"aphids", "workers":_run.honeydew.protection_workers}
	var ids: Array = _run.trails.routes.keys(); ids.sort()
	for id: String in ids:
		var route: TrailRouteState = _run.trails.routes[id]
		if route.origin_pile == pile_id and route.purpose == "food" and route.desired_workers > 0:
			return {"kind":"gatherers", "route_id":id, "target":maxi(0,route.desired_workers-missing), "workers":mini(missing,route.desired_workers)}
	for memory: ScoutMissionMemory in _run.scout_missions.values():
		if memory.origin_pile == pile_id and memory.completed_at() < 0:
			return {"kind":"scouts"}
	var response: JourneyResponseState = _run.journey_response
	if response.active() and _run.trails.routes[response.route_id].origin_pile == pile_id:
		return {"kind":"response"}
	if pile_id == "home" and _run.supply.enabled:
		return {"kind":"supplies"}
	if pile_id == "home" and _run.guest.phase == "rejecting":
		return {"kind":"rejection"}
	return {}

func apply(pile_id: String, expected: Dictionary) -> bool:
	if expected.is_empty() or expected != plan(pile_id): return false
	match expected.kind:
		"climate": return _jobs.climate.set_workers(pile_id, int(expected.target))
		"cleanup": return _jobs.cleanup.set_workers(pile_id, int(expected.target))
		"aphids": return _jobs.aphids.stop_tending(pile_id)
		"gatherers": return _jobs.gatherers.set_workers(expected.route_id, int(expected.target))
		"scouts":
			_jobs.scouts.set_effort(0, pile_id)
			for memory: ScoutMissionMemory in _run.scout_missions.values():
				if memory.origin_pile == pile_id and memory.completed_at() < 0: _jobs.scouts.recall(memory.id)
			return true
		"response": return _jobs.response.recall()
		"supplies": return _jobs.supplies.set_enabled(false)
		"rejection": return _jobs.rejection.stop_rejection()
	return false
