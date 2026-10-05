class_name RivalState
extends RefCounted

const Ledger = preload("res://src/sim/colony/worker_ledger.gd")
const CONFIG = preload("res://data/ecology/backyard_rival.tres")
const TRAILS = preload("res://data/trails/default_trails.tres")
var workers: WorkerLedger = Ledger.new()
var direction: String = "dormant"
var remaining_ticks: int = 0
var cargo: float = 0.0
var stored_carbohydrate: float = 0.0
var pheromone: float = 0.0
var contacts_total: int = 0
var unreturned_contacts: int = 0
var reinforcement: RivalReinforcementState = RivalReinforcementState.new()


func _init() -> void:
	workers.add_living_workers("available", CONFIG.population, "Rival founding workers")


func to_dict() -> Dictionary:
	return {"workers": workers.to_dict(), "direction": direction, "remaining_ticks": remaining_ticks,
		"cargo": cargo, "stored_carbohydrate": stored_carbohydrate, "pheromone": pheromone,
		"contacts_total": contacts_total, "unreturned_contacts": unreturned_contacts, "reinforcement": reinforcement.to_dict()}


func restore(data: Dictionary, world: WorldState, tick: int) -> bool:
	if not data.has_all(["workers", "direction", "remaining_ticks", "cargo", "stored_carbohydrate", "pheromone", "contacts_total", "unreturned_contacts"]) or not data.workers is Dictionary:
		return false
	var ledger := Ledger.new()
	if not ledger.restore(data.workers) or ledger.total + ledger.lost_total != CONFIG.population or not data.direction in ["dormant", "outbound", "inbound"] or not WorkerLedger.valid_count(data.remaining_ticks):
		return false
	for field: String in ["cargo", "stored_carbohydrate", "pheromone"]:
		if not typeof(data[field]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[field])) or data[field] < 0.0:
			return false
	if data.pheromone > 1.0 or data.cargo > maxi(0, ledger.count("rival:trail")) * TRAILS.carry_per_worker or (data.direction != "inbound" and data.cargo != 0.0) or not WorkerLedger.valid_count(data.contacts_total) or not WorkerLedger.valid_count(data.unreturned_contacts) or data.unreturned_contacts > data.contacts_total:
		return false
	var commitments: Dictionary = ledger.to_dict().commitments
	var restored_reinforcement := RivalReinforcementState.new()
	if not restored_reinforcement.restore(data.get("reinforcement",restored_reinforcement.to_dict()),ledger,world): return false
	if data.direction == "dormant":
		if not commitments.is_empty() or data.remaining_ticks != 0 or data.stored_carbohydrate != 0.0 or data.pheromone != 0.0 or data.contacts_total != 0:
			return false
	else:
		if tick < CONFIG.first_tick or not world.nodes.has(CONFIG.food_id) or world.nodes[CONFIG.food_id].definition_id != "carbohydrate" or not world.bounds.has_point(CONFIG.pile_position):
			return false
		var leg: int = TRAILS.leg_ticks(CONFIG.pile_position.distance_to(world.nodes[CONFIG.food_id].position))
		var maximum_store: float = floorf(float(tick - CONFIG.first_tick) / (leg * 2)) * CONFIG.trail_workers * TRAILS.carry_per_worker
		if data.stored_carbohydrate > maximum_store + 0.00001 or world.nodes[CONFIG.food_id].quantity > CONFIG.food_capacity:
			return false
		if data.remaining_ticks < 1 or data.remaining_ticks > leg or commitments.size() != (1 if restored_reinforcement.phase == "idle" else 2) or commitments.get("rival:trail", {}).get("kind") != "trail" or commitments.get("rival:trail", {}).get("owner_id") != "rival_route_1" or ledger.count("rival:trail") > CONFIG.trail_workers:
			return false
	workers = ledger
	direction = data.direction
	remaining_ticks = int(data.remaining_ticks)
	cargo = float(data.cargo)
	stored_carbohydrate = float(data.stored_carbohydrate)
	pheromone = float(data.pheromone)
	# Runtime scent already uses this grid; recover only JSON representation noise.
	var canonical_scent: float=snappedf(pheromone,0.0000000001)
	if absf(pheromone-canonical_scent)<=1e-15: pheromone=canonical_scent
	contacts_total = int(data.contacts_total)
	unreturned_contacts = int(data.unreturned_contacts)
	reinforcement = restored_reinforcement
	return true
