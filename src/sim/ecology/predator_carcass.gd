class_name PredatorCarcass
extends RefCounted
const ID = "ambusher_carcass"
const CONFIG = preload("res://data/ecology/default_journey_response.tres")
const PREDATOR = preload("res://data/ecology/backyard_predator.tres")

static func create(run: RunState) -> void:
	assert(not run.world.nodes.has(ID))
	var node := WorldNodeState.new()
	node.id = ID; node.definition_id = "protein"; node.position = PREDATOR.position
	node.source_type = "hunted_arthropod"
	node.quantity = CONFIG.carcass_protein
	node.properties = {"carcass": true, "killed_at": run.simulation_time}
	run.world.nodes[ID] = node

static func report(run: RunState, origin: String, observed_at: float) -> void:
	# This ID identifies an existing returning worker's observation, not a new ant.
	if run.next_scout_id >= WorkerLedger.MAX_COUNT: return
	var evidence := Observation.new()
	evidence.scout_id = "scout_%d" % run.next_scout_id; run.next_scout_id += 1
	evidence.source_node_id = ID; evidence.id = evidence.scout_id + ":" + ID
	evidence.origin_pile = origin; evidence.definition_id = "protein"
	evidence.source_type = run.world.nodes[ID].source_type
	evidence.first_observed_at = observed_at; evidence.observed_at = observed_at
	evidence.estimated_position = PREDATOR.position; evidence.uncertainty_radius = 0.25
	evidence.closest_distance = 0; evidence.proximity_confirmed = true
	var inbox: Dictionary[String, Observation] = {evidence.id: evidence}
	assert(run.knowledge.consume(inbox, run.simulation_time))

static func valid(world: WorldState, predator: PredatorState) -> bool:
	if world.nodes.has(ID) != predator.killed: return false
	if not predator.killed: return true
	var node: WorldNodeState = world.nodes[ID]
	return node.definition_id == "protein" and node.source_type in ["","hunted_arthropod"] and node.position == PREDATOR.position and node.quantity <= CONFIG.carcass_protein and node.properties.get("carcass", false) == true and node.properties.get("killed_at", -1) == predator.defeated_at
