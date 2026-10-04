class_name SwarmState
extends RefCounted

const CONFIG = preload("res://data/ecology/default_swarm.tres")
const RIVAL = preload("res://data/ecology/backyard_rival.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
var serial: int = 0
var route_id: String = ""
var position: Vector2 = Vector2.ZERO
var phase: String = "idle"
var round_ticks: int = 0
var formation_ticks: int = 0
var rival_engaged: bool = false
var player_losses: int = 0
var rival_losses: int = 0
var last_finish_tick: int = -1
var rounds: int = 0
var pressure_reports_sent: int = 0


func active() -> bool:
	return phase in ["forming", "fighting"]


func to_dict() -> Dictionary:
	return {"serial": serial, "route_id": route_id, "position": [position.x, position.y],
		"phase": phase, "round_ticks": round_ticks, "formation_ticks": formation_ticks,
		"rival_engaged": rival_engaged, "player_losses": player_losses, "rival_losses": rival_losses,
		"last_finish_tick": str(last_finish_tick), "rounds":rounds,"pressure_reports_sent":pressure_reports_sent}


func restore(data: Dictionary, trails: TrailNetwork, rival: RivalState, world: WorldState, tick: int) -> bool:
	if not data.has_all(["serial", "route_id", "position", "phase", "round_ticks", "formation_ticks", "rival_engaged", "player_losses", "rival_losses", "last_finish_tick"]):
		return false
	if not WorkerLedger.valid_count(data.get("rounds",0)) or not WorkerLedger.valid_count(data.get("pressure_reports_sent",0)) or data.get("pressure_reports_sent",0) > CONFIG.max_pressure_reports: return false
	if rival.reinforcement.swarm_serial > data.serial or rival.reinforcement.phase == "engaged" and (data.phase != "fighting" or rival.reinforcement.swarm_serial != data.serial or not data.rival_engaged): return false
	for key: String in ["serial", "round_ticks", "formation_ticks", "player_losses", "rival_losses"]:
		if not WorkerLedger.valid_count(data[key]):
			return false
	if not data.route_id is String or not data.phase in ["idle", "forming", "fighting", "finished"] or typeof(data.rival_engaged) != TYPE_BOOL or not data.last_finish_tick is String or not data.last_finish_tick.is_valid_int() or str(data.last_finish_tick.to_int()) != data.last_finish_tick:
		return false
	if not data.position is Array or data.position.size() != 2:
		return false
	for coordinate: Variant in data.position:
		if not typeof(coordinate) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)):
			return false
	var point := Vector2(data.position[0], data.position[1])
	var last: int = data.last_finish_tick.to_int()
	if last < -1 or last > tick or (last >= 0 and last < RIVAL.first_tick) or data.round_ticks > CONFIG.round_ticks or data.rival_losses != rival.workers.lost_total:
		return false
	var held: int = 0
	var losses: int = 0
	for route: TrailRouteState in trails.routes.values():
		if route.conflict_serial > data.serial or route.settled_conflict_serial > data.serial: return false
		losses += route.reported_rival_losses
	for cohort: TransitCohort in trails.cohorts.values():
		if cohort.conflict_serial > data.serial: return false
		losses += cohort.rival_losses
		if cohort.swarm_engaged:
			if cohort.route_id != data.route_id or cohort.worker_count <= 0 or not data.phase in ["forming", "fighting"]:
				return false
			held += cohort.worker_count
	if losses != data.player_losses:
		return false
	if data.phase == "idle":
		if data.serial != 0 or data.route_id != "" or point != Vector2.ZERO or data.round_ticks != 0 or data.formation_ticks != 0 or data.rival_engaged or last != -1 or data.player_losses != 0 or data.rival_losses != 0:
			return false
	else:
		if data.serial < 1 or not trails.routes.has(data.route_id) or not world.nodes.has(RIVAL.food_id):
			return false
		var route: TrailRouteState = trails.routes[data.route_id]
		var segment: TrailSegmentState = trails.segments[route.segment_id]
		var matched: bool = false
		for intersection: Vector2 in segment.intersections(RIVAL.pile_position, world.nodes[RIVAL.food_id].position):
			if point.is_equal_approx(intersection): matched = true
		if data.phase != "finished" and not matched: return false
		var max_wait: int = TRAILS.leg_ticks(RIVAL.pile_position.distance_to(world.nodes[RIVAL.food_id].position)) * 2 + 1
		if data.formation_ticks > max_wait:
			return false
		if data.phase == "finished" and (last < 0 or data.round_ticks != 0 or data.formation_ticks != 0 or data.rival_engaged or held != 0):
			return false
		if data.phase == "forming" and (data.formation_ticks < 1 or data.round_ticks != 0):
			return false
		if data.phase == "fighting" and (not data.rival_engaged or held == 0 or maxi(0,rival.workers.count("rival:trail")) + (maxi(0,rival.workers.count("rival:reinforcement")) if rival.reinforcement.phase == "engaged" else 0) <= 0 or data.round_ticks < 1 or data.formation_ticks != 0):
			return false
	serial = int(data.serial)
	route_id = data.route_id
	position = point
	phase = data.phase
	round_ticks = int(data.round_ticks)
	formation_ticks = int(data.formation_ticks)
	rival_engaged = data.rival_engaged
	player_losses = int(data.player_losses)
	rival_losses = int(data.rival_losses)
	last_finish_tick = last
	rounds = int(data.get("rounds",0)); pressure_reports_sent = int(data.get("pressure_reports_sent",0))
	return true
