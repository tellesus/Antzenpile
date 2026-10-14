class_name FoundingSystem
extends RefCounted
## Selects a physical camp owner; completed foundations keep their proof/connection.
const Camp=preload("res://src/sim/colony/founding_camp_system.gd")
const CONFIG=preload("res://data/resources/default_founding.tres")
const TRAILS=preload("res://data/trails/default_trails.tres")
var _run: RunState
var last_error: String=""
var last_established_id: String=""
func _init(run: RunState) -> void: _run=run
func _next_destination() -> String:
	var index: int=2
	while index<WorkerLedger.MAX_COUNT:
		var id: String="satellite_%d" % index
		var reserved: bool=_run.colony.piles.has(id)
		for state: FoundingState in _run.all_foundings():
			if state.phase not in ["none","failed"] and state.destination_pile==id: reserved=true
		if not reserved: return id
		index+=1
	return ""
func _owner(knowledge_id: String, origin: String) -> FoundingCampSystem:
	for state: FoundingState in _run.all_foundings():
		if state.phase=="none" or not _run.trails.routes.has(state.route_id): continue
		if _run.trails.routes[state.route_id].destination_knowledge_id==knowledge_id and (state.origin_pile==origin or state.phase=="established"):
			return Camp.new(_run,state.origin_pile,state.destination_pile,"" if state==_run.founding else state.route_id)
	if origin=="home" and _run.founding.phase in ["none","failed"]: return Camp.new(_run)
	return Camp.new(_run,origin,_next_destination(),"route_%d" % _run.trails.next_route_id)
func blocker(knowledge_id: String, origin: String="home") -> String:
	if not _run.colony.piles.has(origin): return "Unknown founding origin"
	for state: FoundingState in _run.all_foundings():
		if state.phase in ["none","failed","established"]: continue
		if state.origin_pile==origin: return "This pile already has a committed founding group"
		if _run.trails.routes[state.route_id].destination_knowledge_id==knowledge_id: return "Another colony party is already preparing this site"
	var owner: FoundingCampSystem=_owner(knowledge_id,origin)
	if owner.destination_id.is_empty(): return "Pile identity unavailable"
	return owner.blocker(knowledge_id)
func start(knowledge_id: String, origin: String="home") -> bool:
	last_error=blocker(knowledge_id,origin)
	if not last_error.is_empty(): return false
	var owner: FoundingCampSystem=_owner(knowledge_id,origin)
	var accepted: bool=owner.start(knowledge_id);last_error=owner.last_error
	return accepted
func establish(knowledge_id: String, origin: String="home") -> bool:
	var owner: FoundingCampSystem=_owner(knowledge_id,origin)
	var accepted: bool=owner.establish(knowledge_id);last_error=owner.last_error
	if accepted:last_established_id=owner.destination_id
	return accepted
func tick() -> void:
	Camp.new(_run).tick()
	var keys: Array=_run.extra_foundings.keys();keys.sort()
	for key: String in keys:
		var state: FoundingState=_run.extra_foundings[key]
		Camp.new(_run,state.origin_pile,state.destination_pile,key).tick()
func summary(knowledge_id: String, origin: String="home") -> Dictionary:
	var owner: FoundingCampSystem=_owner(knowledge_id,origin)
	var result: Dictionary=owner.summary(knowledge_id)
	result.origin_pile=owner.origin_id;result.destination_pile=owner.destination_id
	result.blocker=blocker(knowledge_id,origin)
	return result
func _costs(endpoint: Vector2, profile_id: String="") -> Dictionary:
	return Camp.new(_run)._costs(endpoint,profile_id)
