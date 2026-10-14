class_name RivalReinforcementState
extends RefCounted
## Finite paid reserve deployments, owned exclusively by the rival ledger.
const CONFIG = preload("res://data/ecology/default_swarm.tres")
const RIVAL = preload("res://data/ecology/backyard_rival.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
var phase: String = "idle"
var remaining_ticks: int = 0
var travel_ticks: int = 0
var mobilizations: int = 0
var swarm_serial: int = 0

func to_dict() -> Dictionary:
	return {"phase":phase,"remaining_ticks":remaining_ticks,"travel_ticks":travel_ticks,"mobilizations":mobilizations,"swarm_serial":swarm_serial}

func restore(data: Variant, ledger: WorkerLedger, world: WorldState) -> bool:
	if not data is Dictionary or data.size() != 5 or not data.has_all(to_dict().keys()) or data.phase not in ["idle","outbound","engaged","inbound"]: return false
	for key: String in ["remaining_ticks","travel_ticks","mobilizations","swarm_serial"]:
		if not WorkerLedger.valid_count(data[key]): return false
	if data.mobilizations > CONFIG.max_rival_mobilizations or (data.mobilizations == 0) != (data.swarm_serial == 0): return false
	var count: int = ledger.count("rival:reinforcement")
	if data.phase == "idle":
		if count != -1 or data.remaining_ticks != 0 or data.travel_ticks != 0: return false
	else:
		if data.mobilizations == 0 or count < 0 or count > CONFIG.rival_reinforcement_workers or not world.nodes.has(RIVAL.food_id): return false
		var commitment: Dictionary = ledger.to_dict().commitments.get("rival:reinforcement",{})
		if commitment.get("kind") != "other" or commitment.get("owner_id") != "rival_swarm": return false
		if data.travel_ticks < 1 or data.travel_ticks > TRAILS.leg_ticks(RIVAL.pile_position.distance_to(world.nodes[RIVAL.food_id].position)): return false
		if data.phase == "engaged":
			if data.remaining_ticks != 0: return false
		elif data.remaining_ticks < 1 or data.remaining_ticks > data.travel_ticks: return false
		if data.phase == "outbound" and count != CONFIG.rival_reinforcement_workers: return false
	phase = data.phase; remaining_ticks = int(data.remaining_ticks); travel_ticks = int(data.travel_ticks)
	mobilizations = int(data.mobilizations); swarm_serial = int(data.swarm_serial)
	return true
