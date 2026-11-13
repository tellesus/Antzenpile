class_name ConflictRecruitment
extends RefCounted
## Reassign local labor through job owners, then reserve only workers actually home.
var _run: RunState
var jobs: Dictionary = {}

func _init(run_state: RunState) -> void:
	_run = run_state

static func pool(route_id: String) -> String:
	return "response:" + route_id

func request(route_id: String, count: int, kind: String, all_hands: bool, trail_target: int = 0) -> void:
	cancel(route_id)
	var route: TrailRouteState = _run.trails.routes[route_id]
	var pile: PileState = _run.colony.piles[route.origin_pile]
	var commitment_created: bool = pile.workers.create_commitment(pool(route_id), "other", route_id); assert(commitment_created)
	var entry: Dictionary = {"count":count, "kind":kind, "all_hands":all_hands, "waiting":{}, "trail_target":trail_target}
	_run.journey_response.orders.recruitment[route_id] = entry
	if kind == "defend": _recall_trail(entry, route, count)
	fill(route_id)

func cancel(route_id: String) -> void:
	if not _run.journey_response.orders.recruitment.has(route_id): return
	var pile: PileState = _run.colony.piles[_run.trails.routes[route_id].origin_pile]
	var id: String = pool(route_id)
	var workers_released: bool = pile.workers.release(id, pile.workers.count(id)); assert(workers_released)
	var commitment_retired: bool = pile.workers.retire_commitment(id); assert(commitment_retired)
	_run.journey_response.orders.recruitment.erase(route_id)

func ready(route_id: String) -> bool:
	if not _run.journey_response.orders.recruitment.has(route_id): return false
	var entry: Dictionary = _run.journey_response.orders.recruitment[route_id]
	var pile: PileState = _run.colony.piles[_run.trails.routes[route_id].origin_pile]
	return pile.workers.count(pool(route_id)) == entry.count and _returning(entry) == 0

func consume(route_id: String, destination: String, count: int) -> void:
	var pile: PileState = _run.colony.piles[_run.trails.routes[route_id].origin_pile]
	var workers_transferred: bool = pile.workers.transfer(pool(route_id), destination, count); assert(workers_transferred)
	var commitment_retired: bool = pile.workers.retire_commitment(pool(route_id)); assert(commitment_retired)
	_run.journey_response.orders.recruitment.erase(route_id)

func fill(route_id: String) -> void:
	var entry: Dictionary = _run.journey_response.orders.recruitment[route_id]
	var pile: PileState = _run.colony.piles[_run.trails.routes[route_id].origin_pile]
	_reserve(route_id, entry, pile)
	if entry.all_hands and entry.count > pile.workers.count(pool(route_id)) + _returning(entry):
		_release_other_jobs(route_id, entry, pile)
		_reserve(route_id, entry, pile)

func _reserve(route_id: String, entry: Dictionary, pile: PileState) -> void:
	var needed: int = maxi(0, int(entry.count) - pile.workers.count(pool(route_id)) - _returning(entry))
	var available: int = mini(needed, pile.workers_assignable)
	if available > 0: var workers_allocated: bool = pile.allocate_workers(pool(route_id), available); assert(workers_allocated)

func _returning(entry: Dictionary) -> int:
	var returning: int = 0
	for id: String in entry.waiting:
		var route: TrailRouteState = _run.trails.routes[id]
		# Pending private losses stay in the commanded/expected count until delivered.
		returning += maxi(0, route.allocated_workers + _run.trails.pending_losses(id) - int(entry.waiting[id]))
	return returning

func _recall_trail(entry: Dictionary, route: TrailRouteState, wanted: int) -> void:
	var expected: int = route.allocated_workers + _run.trails.pending_losses(route.id)
	var draw: int = mini(wanted, expected)
	if draw == 0:
		if route.waiting_workers>0: var target_set: bool = jobs.gatherers.set_workers(route.id,0); assert(target_set)
		return
	var target: int = mini(route.desired_workers, expected - draw)
	var target_set2: bool = jobs.gatherers.set_workers(route.id, target); assert(target_set2)
	entry.waiting[route.id] = target

func _release_other_jobs(route_id: String, entry: Dictionary, pile: PileState) -> void:
	var needed: int = int(entry.count) - pile.workers.count(pool(route_id)) - _returning(entry)
	if pile.midden.cleaners > 0:
		var target_set: bool = jobs.cleanup.set_workers(pile.id, maxi(0, pile.midden.cleaners - needed)); assert(target_set)
		_reserve(route_id, entry, pile)
	needed = int(entry.count) - pile.workers.count(pool(route_id)) - _returning(entry)
	if needed <= 0: return
	if pile.humidity.carers > 0:
		var target_set2: bool = jobs.climate.set_workers(pile.id, maxi(0, pile.humidity.carers - needed)); assert(target_set2)
		_reserve(route_id, entry, pile)
	needed = int(entry.count) - pile.workers.count(pool(route_id)) - _returning(entry)
	if needed <= 0: return
	var service: ProducerServiceState=_run.honeydew.services.get(pile.id)
	if service!=null and service.count>0:
		if service.known_target()>0:var service_stopped: bool = jobs.aphids.stop_tending(pile.id); assert(service_stopped)
		_reserve(route_id,entry,pile)
		if service.count>0:return # The deliberately recalled crew must physically reach this nest first.
	var ids: Array = _run.trails.routes.keys(); ids.sort()
	for id: String in ids:
		needed = int(entry.count) - pile.workers.count(pool(route_id)) - _returning(entry)
		if needed <= 0: return
		var route: TrailRouteState = _run.trails.routes[id]
		if id != route_id and route.origin_pile == pile.id and route.purpose == "food" and route.desired_workers > 0:
			_recall_trail(entry, route, needed)
			_reserve(route_id, entry, pile)
	needed = int(entry.count) - pile.workers.count(pool(route_id)) - _returning(entry)
	if needed <= 0: return
	jobs.scouts.set_effort(0, pile.id)
	for memory: ScoutMissionMemory in _run.scout_missions.values():
		if memory.origin_pile == pile.id and memory.completed_at() < 0: jobs.scouts.recall(memory.id)
	if pile.id == "home":
		if _run.supply.enabled: jobs.supplies.set_enabled(false)
		if _run.guest.phase == "rejecting": jobs.rejection.stop_rejection()
	elif _run.daughter_supply.enabled:
		jobs.daughter_supplies.set_enabled(false)

func summary(origin_id: String) -> Dictionary:
	var result: Dictionary = {}
	for id: String in _run.journey_response.orders.recruitment:
		var route: TrailRouteState = _run.trails.routes[id]
		if route.origin_pile != origin_id: continue
		var entry: Dictionary = _run.journey_response.orders.recruitment[id]
		var reserved: int = _run.colony.piles[origin_id].workers.count(pool(id))
		result[id] = {"kind":entry.kind,"requested":entry.count,"reserved":reserved,"returning":_returning(entry),"all_hands":entry.all_hands,
			"shortfall":maxi(0, int(entry.count) - reserved - _returning(entry))}
	return result
