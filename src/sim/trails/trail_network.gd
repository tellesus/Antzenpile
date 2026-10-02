class_name TrailNetwork
extends RefCounted

const Route = preload("res://src/sim/trails/trail_route_state.gd")
const Segment = preload("res://src/sim/trails/trail_segment_state.gd")
const Cohort = preload("res://src/sim/trails/transit_cohort.gd")
const CONFIG = preload("res://data/trails/default_trails.tres")
var routes: Dictionary[String, TrailRouteState] = {}
var segments: Dictionary[String, TrailSegmentState] = {}
var cohorts: Dictionary[String, TransitCohort] = {}
var next_route_id: int = 1
var next_cohort_id: int = 1


func find_route(origin_id: String, knowledge_id: String) -> TrailRouteState:
	for route: TrailRouteState in routes.values():
		if route.origin_pile == origin_id and route.destination_knowledge_id == knowledge_id:
			return route
	return null


func pending_losses(route_id: String) -> int:
	var total: int = 0
	for cohort: TransitCohort in cohorts.values():
		if cohort.route_id == route_id:
			total += cohort.lost_workers
	return total


func pending_for_pile(pile_id: String, adapted: bool = false) -> int:
	var total: int = 0
	for cohort: TransitCohort in cohorts.values():
		if routes[cohort.route_id].origin_pile == pile_id:
			total += cohort.adapted_lost_workers if adapted else cohort.lost_workers
	return total


func pending_trait(pile_id: String, trait_id: String) -> int:
	var total: int = 0
	for cohort: TransitCohort in cohorts.values():
		if routes[cohort.route_id].origin_pile == pile_id:
			for key: String in cohort.lost_profiles:
				if trait_id in GeneticRepertoire.traits_for(key):
					total += cohort.lost_profiles[key]
	return total


func to_dict() -> Dictionary:
	var route_records: Array[Dictionary] = []
	var segment_records: Array[Dictionary] = []
	var cohort_records: Array[Dictionary] = []
	var ids: Array = routes.keys()
	ids.sort()
	for id: String in ids:
		route_records.append(routes[id].to_dict())
	ids = segments.keys()
	ids.sort()
	for id: String in ids:
		segment_records.append(segments[id].to_dict())
	ids = cohorts.keys()
	ids.sort()
	for id: String in ids:
		cohort_records.append(cohorts[id].to_dict())
	return {"next_route_id": next_route_id, "next_cohort_id": next_cohort_id,
		"routes": route_records, "segments": segment_records, "cohorts": cohort_records}


func restore(data: Dictionary, colony: ColonyState, knowledge: KnowledgeBase, world: WorldState, time: float) -> bool:
	if not data.has_all(["next_route_id", "next_cohort_id", "routes", "segments", "cohorts"]) or not WorkerLedger.valid_count(data.next_route_id) or data.next_route_id < 1 or not WorkerLedger.valid_count(data.next_cohort_id) or data.next_cohort_id < 1 or not data.routes is Array or not data.segments is Array or not data.cohorts is Array:
		return false
	var restored_routes: Dictionary[String, TrailRouteState] = {}
	var restored_segments: Dictionary[String, TrailSegmentState] = {}
	var restored_cohorts: Dictionary[String, TransitCohort] = {}
	var pairs: Dictionary[String, bool] = {}
	for record: Variant in data.routes:
		var route := Route.new()
		if not record is Dictionary or not route.restore(record, colony, knowledge, world.bounds) or restored_routes.has(route.id) or route.last_loss_time > time or route.last_foreign_time > time or route.conflict_observed_at > time or route.last_empty_report_at > time:
			return false
		var suffix: String = route.id.trim_prefix("route_")
		if route.id != "route_" + suffix or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= data.next_route_id or route.segment_id != "segment_" + suffix:
			return false
		var pair: String = route.origin_pile + ":" + route.destination_knowledge_id
		if pairs.has(pair):
			return false
		pairs[pair] = true
		restored_routes[route.id] = route
	for record: Variant in data.segments:
		var segment := Segment.new()
		if not record is Dictionary or not segment.restore(record, world.bounds) or restored_segments.has(segment.id):
			return false
		restored_segments[segment.id] = segment
	var active_counts: Dictionary[String, int] = {}
	var cohort_counts: Dictionary[String, int] = {}
	for record: Variant in data.cohorts:
		var cohort := Cohort.new()
		if not record is Dictionary or not cohort.restore(record, world, colony, time) or restored_cohorts.has(cohort.id) or not restored_routes.has(cohort.route_id):
			return false
		var suffix: String = cohort.id.trim_prefix("cohort_")
		if cohort.id != "cohort_" + suffix or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() >= data.next_cohort_id:
			return false
		var route: TrailRouteState = restored_routes[cohort.route_id]
		if not restored_segments.has(route.segment_id) or cohort.worker_count + cohort.lost_workers > CONFIG.workers_per_cohort:
			return false
		var segment: TrailSegmentState = restored_segments[route.segment_id]
		if cohort.remaining_ticks > CONFIG.leg_ticks(segment.start.distance_to(segment.end)):
			return false
		if cohort.detour != null:
			var join: Vector2 = cohort.detour.path[0] if cohort.detour.phase == "outbound" else cohort.detour.path.back()
			if cohort.detour.origin_pile != route.origin_pile or cohort.detour.source_id == knowledge.nodes[route.destination_knowledge_id].source_node_id or _distance_to_segment(join, segment.start, segment.end) > 1.5:
				return false
		if cohort.detour_report != null and (cohort.detour_report.origin_pile != route.origin_pile or cohort.detour_report.source_node_id == knowledge.nodes[route.destination_knowledge_id].source_node_id):
			return false
		var pile: PileState = colony.piles[route.origin_pile]
		if cohort.chemistry_fraction > 0.0 and "persistent" not in pile.genetics.established:
			return false
		if not record.has("lost_profiles") and cohort.adapted_lost_workers > 0 and pile.adaptation_repertoire != "":
			cohort.lost_profiles[pile.adaptation_repertoire] = cohort.adapted_lost_workers
		var foraging_losses: int = 0
		for key: String in cohort.lost_profiles:
			if cohort.lost_profiles[key] > pile.genetics.lost.get(key, 0):
				return false
			if pile.adaptation_repertoire in GeneticRepertoire.traits_for(key):
				foraging_losses += cohort.lost_profiles[key]
		if foraging_losses != cohort.adapted_lost_workers:
			return false
		var fraction: float = 0.0
		if pile.adaptation_repertoire == "lean":
			fraction = (1.0 - cohort.energy_multiplier) / 0.3
		elif pile.adaptation_repertoire == "load":
			fraction = (cohort.energy_multiplier - 1.0) / 0.2
		elif not is_equal_approx(cohort.energy_multiplier, 1.0) or not is_equal_approx(cohort.carry_multiplier, 1.0):
			return false
		# A journey keeps its departure phenotype even if adapted adults die meanwhile.
		if fraction < -0.00002 or fraction > 1.0 + 0.00002 or absf(cohort.carry_multiplier - AdaptationRules.carry_multiplier(pile.adaptation_repertoire, fraction)) > 0.00002:
			return false
		var maximum_energy_cost: float = CONFIG.round_trip_energy_cost(cohort.worker_count + cohort.lost_workers, segment.start.distance_to(segment.end), Segment.terrain_cost_for(world, segment.start, segment.end)) * cohort.energy_multiplier * (1.0 + AdaptationRules.CHEMISTRY.extra_travel_energy * cohort.chemistry_fraction)
		if cohort.unpaid_energy_cost > maximum_energy_cost + 0.00001 or (cohort.unpaid_energy_cost > 0.0 and knowledge.nodes[route.destination_knowledge_id].definition_id != "carbohydrate"):
			return false
		var source_id: String = knowledge.nodes[route.destination_knowledge_id].source_node_id
		if not world.nodes.has(source_id):
			return false
		if cohort.payload > float(cohort.worker_count) * CONFIG.carry_per_worker * cohort.carry_multiplier + 0.00001 or (not cohort.resource_id.is_empty() and cohort.resource_id != world.nodes[source_id].definition_id):
			return false
		active_counts[route.id] = active_counts.get(route.id, 0) + cohort.worker_count
		cohort_counts[route.id] = cohort_counts.get(route.id, 0) + 1
		restored_cohorts[cohort.id] = cohort
	if restored_routes.size() != restored_segments.size():
		return false
	var used_segments: Dictionary[String, bool] = {}
	for route: TrailRouteState in restored_routes.values():
		if active_counts.get(route.id, 0) != route.active_workers or cohort_counts.get(route.id, 0) > CONFIG.max_cohorts_per_route:
			return false
		if not restored_segments.has(route.segment_id) or used_segments.has(route.segment_id):
			return false
		used_segments[route.segment_id] = true
		var segment: TrailSegmentState = restored_segments[route.segment_id]
		if segment.route_id != route.id or segment.start != colony.piles[route.origin_pile].position or segment.end != route.estimated_destination or not is_equal_approx(segment.exposure, Segment.exposure_for(world, segment.start, segment.end)):
			return false
		if segment.persistent_chemistry > 0 and "persistent" not in colony.piles[route.origin_pile].genetics.established:
			return false
		var pending: int = 0
		for cohort: TransitCohort in restored_cohorts.values():
			if cohort.route_id == route.id:
				pending += cohort.lost_workers
		if route.desired_workers > route.allocated_workers + pending + route.reported_losses or route.allocated_workers > WorkerLedger.MAX_COUNT - pending:
			return false
		var commitment: String = "trail:" + route.id
		var ledger: WorkerLedger = colony.piles[route.origin_pile].workers
		if route.status != "inactive":
			var record: Dictionary = ledger.to_dict().commitments.get(commitment, {})
			if record.get("kind") != "trail" or record.get("owner_id") != route.id or record.get("count") != route.allocated_workers:
				return false
		elif ledger.count(commitment) != -1:
			return false
	for pile: PileState in colony.piles.values():
		var pending_profiles: Dictionary[String, int] = {}
		for cohort: TransitCohort in restored_cohorts.values():
			if restored_routes[cohort.route_id].origin_pile == pile.id:
				for key: String in cohort.lost_profiles:
					pending_profiles[key] = pending_profiles.get(key, 0) + cohort.lost_profiles[key]
		for key: String in pending_profiles:
			if pending_profiles[key] > pile.genetics.lost.get(key, 0):
				return false
		for id: String in pile.workers.to_dict().commitments:
			var entry: Dictionary = pile.workers.to_dict().commitments[id]
			if entry.kind == "trail" or id.begins_with("trail:"):
				var route_id: String = id.trim_prefix("trail:")
				if id != "trail:" + route_id or not restored_routes.has(route_id) or restored_routes[route_id].origin_pile != pile.id or restored_routes[route_id].status == "inactive" or entry.kind != "trail" or entry.owner_id != route_id:
					return false
	routes = restored_routes
	segments = restored_segments
	cohorts = restored_cohorts
	next_route_id = int(data.next_route_id)
	next_cohort_id = int(data.next_cohort_id)
	return true


static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var span: Vector2 = finish - start
	if span.length_squared() <= 0.0:
		return point.distance_to(start)
	var t: float = clampf((point - start).dot(span) / span.length_squared(), 0.0, 1.0)
	return point.distance_to(start + span * t)
