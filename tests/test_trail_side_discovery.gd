extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Evidence = preload("res://src/sim/scouting/observation.gd")
const Root = preload("res://src/core/game_root.gd")


func run(test: Object) -> bool:
	var successful: SimulationController
	var failed: SimulationController
	for seed: int in 24:
		var candidate: SimulationController = _fixture(seed + 1)
		candidate.advance(4.0)
		var first: TransitCohort = candidate.run.trails.cohorts.get("cohort_1")
		if first != null and first.detour != null and successful == null:
			successful = candidate
		elif first != null and first.detour_attempted and first.detour == null and failed == null:
			failed = candidate
		if successful != null and failed != null:
			break
	test.check(successful != null and failed != null, "Seeded chance yields both a bounded detour and a no-detour outcome")
	if successful == null or failed == null:
		return false
	var run: RunState = successful.run
	var cohort: TransitCohort = run.trails.cohorts.cohort_1
	test.check(cohort.detour.source_id == "protein_picnic" and cohort.detour.path.size() <= 13 and run.active_scout_count() == 1, "Nearby unknown cue creates one bounded individual detour")
	test.check(run.colony.piles.home.workers_available == 35 and run.trails.routes.route_1.active_workers == 5 and run.colony.piles.home.workers.invariant_holds(), "Detouring worker stays inside the trail commitment")
	test.check(not run.knowledge.nodes.has("known:protein_picnic") and run.delivered_observations.is_empty(), "Trail-side private cue does not reach colony knowledge early")
	var root := Root.new()
	root.simulation = successful
	var status: Dictionary = root.outward_status("home")
	test.check(status.active_scouts == 1 and status.trails[0].checking_workers == 1 and not status.has("world") and not status.trails[0].has("detour_position"), "Normal status counts active detail without exposing the physical detour")
	root.free()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(snapshot), "Mid-detour version-5 snapshot restores")
	if copy.run.to_dict() != run.to_dict():
		test.check(false, "Mid-detour snapshot is exact")
		return false
	var damaged: Dictionary = snapshot.duplicate(true)
	damaged.trails.cohorts[0].detour.path[1] = [39.0, 39.0]
	var stable: Dictionary = run.to_dict()
	test.check(not successful.restore_snapshot(damaged) and successful.run.to_dict() == stable, "Disconnected detour path rejects atomically")
	damaged = snapshot.duplicate(true)
	damaged.trails.cohorts[0].detour.observation.source_node_id = "water_01"
	test.check(not successful.restore_snapshot(damaged) and successful.run.to_dict() == stable, "Forged detour evidence rejects atomically")
	damaged = snapshot.duplicate(true)
	damaged.trails.cohorts[0].detour.id = "scout_1"
	damaged.trails.cohorts[0].detour.observation.scout_id = "scout_1"
	damaged.trails.cohorts[0].detour.observation.id = "scout_1:protein_picnic"
	test.check(not successful.restore_snapshot(damaged) and successful.run.to_dict() == stable, "Detour cannot reuse a historical scout identity")
	var held_ticks: int = cohort.remaining_ticks
	var joined: bool = false
	var report_checked: bool = false
	for tick: int in 500:
		successful.advance(0.25)
		copy.advance(0.25)
		if tick < 24:
			test.check(successful.run.to_dict() == copy.run.to_dict(), "Mid-detour continuation repeats exactly")
		if successful.run.trails.cohorts.has("cohort_1"):
			var current: TransitCohort = successful.run.trails.cohorts.cohort_1
			if current.detour != null:
				test.check(current.remaining_ticks == held_ticks, "Aggregate cohort waits while its worker investigates")
			if current.detour_report != null:
				joined = true
				test.check(not successful.run.knowledge.nodes.has("known:protein_picnic"), "Rejoined worker's report still waits for home arrival")
				if not report_checked:
					var carried: Dictionary = JSON.parse_string(JSON.stringify(successful.run.to_dict(), "", true, true))
					var carried_copy := Controller.new()
					test.check(carried_copy.restore_snapshot(carried) and carried_copy.run.to_dict() == successful.run.to_dict(), "Rejoined private report survives a mid-return save")
					report_checked = true
		else:
			break
	successful.advance(0.25)
	copy.advance(0.25)
	test.check(joined and report_checked and successful.run.knowledge.nodes.has("known:protein_picnic") and successful.run.colony.piles.home.workers.invariant_holds(), "Worker rejoins trail and delivers evidence only with homebound cohort")
	test.check(successful.run.to_dict() == copy.run.to_dict(), "Completed detour and later resource traffic continue exactly after reload")
	var no_cue := _fixture(1, 5.0)
	no_cue.advance(8.0)
	test.check(not no_cue.run.trails.cohorts.cohort_1.detour_attempted and no_cue.run.active_scout_count() == 0, "A source beyond chemical range triggers no detour")
	test.check(failed.run.trails.cohorts.cohort_1.detour_attempted and failed.run.trails.cohorts.cohort_1.detour == null, "A failed chance does not reroll for the same cohort")
	var parallel := _fixture(successful.run.run_seed)
	parallel.advance(8.0)
	var unresolved: int = 0
	for traveller: TransitCohort in parallel.run.trails.cohorts.values():
		if traveller.detour != null or traveller.detour_report != null:
			unresolved += 1
	test.check(unresolved == 1, "One route keeps at most one unresolved side-source report")
	var authored := _fixture(successful.run.run_seed, 3.0, true)
	authored.advance(4.0)
	test.check(authored.run.trails.cohorts.cohort_1.detour != null and authored.run.world.nodes.protein_picnic.active, "The authored picnic episode can be found from a nearby carbohydrate trail")
	var wet := _fixture(successful.run.run_seed)
	wet.advance(4.0)
	wet.run.rain.phase = "raining"
	wet.advance(0.25)
	test.check(wet.run.rain.phase == "raining" and wet.run.trails.cohorts.cohort_1.detour != null and wet.run.colony.piles.home.workers.invariant_holds(), "Rain leaves a worker's active detour and trail commitment intact")
	var blocked := _fixture(successful.run.run_seed)
	blocked.advance(4.0)
	var blocked_detour: TrailDetour = blocked.run.trails.cohorts.cohort_1.detour
	var next_cell: Vector2 = blocked_detour.path[blocked_detour.cursor]
	blocked.run.world.terrain.append({"id": "detour_block", "bounds": [next_cell.x, next_cell.y, 1.0, 1.0], "exposure": 0.0, "traversable": false, "movement_cost": 1.0})
	var held_position: Vector2 = blocked_detour.position
	blocked.advance(2.0)
	test.check(blocked_detour.position == held_position and blocked.run.trails.cohorts.cohort_1.detour != null and blocked.run.colony.piles.home.workers.invariant_holds(), "Blocked detour waits without losing its worker or private evidence")
	blocked.run.world.terrain.pop_back()
	blocked.advance(20.0)
	test.check(blocked.run.trails.cohorts.cohort_1.detour == null, "Unblocked detour returns to its trail")
	var full := _fixture(1)
	for index: int in 8:
		test.check(full.dispatch_scout("home", PI), "Regular scout reserves a detailed-scout slot")
	full.advance(4.0)
	test.check(full.run.active_scout_count() == 8 and not full.run.trails.cohorts.cohort_1.detour_attempted, "Full detailed-scout cap defers trail detour without rolling")
	var recalled := _fixture(successful.run.run_seed)
	recalled.advance(4.0)
	test.check(recalled.run.trails.cohorts.cohort_1.detour != null and recalled.set_trail_workers("route_1", 0), "Recall accepts a route with a detour in flight")
	for tick: int in 500:
		if recalled.run.trails.cohorts.is_empty():
			break
		recalled.advance(0.25)
	test.check(recalled.run.trails.cohorts.is_empty() and recalled.run.colony.piles.home.workers_available == 40 and recalled.run.colony.piles.home.workers.invariant_holds(), "Recall waits for detour and releases all five workers at home")
	var legacy := snapshot.duplicate(true)
	for record: Dictionary in legacy.trails.cohorts:
		record.erase("detour_attempted")
		record.erase("detour")
		record.erase("detour_report")
	var older := Controller.new()
	test.check(older.restore_snapshot(legacy) and older.run.trails.cohorts.cohort_1.detour == null, "Older cohort snapshots default to no detour")
	var slow := _fixture(successful.run.run_seed)
	var fast := _fixture(successful.run.run_seed)
	fast.set_time_scale(4)
	for tick: int in 64:
		slow.advance(0.25)
		fast.advance(0.0625)
	var accelerated: Dictionary = fast.run.to_dict()
	accelerated.clock.scale = 1
	test.check(slow.run.to_dict() == accelerated, "Automatic discovery follows simulated ticks at 1× and 4×")
	return true


func _fixture(seed: int, side_distance: float = 3.0, authored_episode: bool = false) -> SimulationController:
	var game := Controller.new(seed)
	var picnic: WorldNodeState = game.run.world.nodes.protein_picnic
	picnic.position = Vector2(25.0, 20.0 + side_distance)
	if not authored_episode:
		picnic.quantity = 24.0
		picnic.active = true
	var observation := Evidence.new()
	observation.id = "scout_1:carb_exposed"
	observation.scout_id = "scout_1"
	observation.origin_pile = "home"
	observation.source_node_id = "carb_exposed"
	observation.definition_id = "carbohydrate"
	observation.first_observed_at = 0.0
	observation.observed_at = 0.0
	observation.estimated_position = Vector2(30.0, 20.0)
	observation.uncertainty_radius = 0.25
	observation.closest_distance = 0.0
	observation.proximity_confirmed = true
	var inbox: Dictionary[String, Observation] = {observation.id: observation}
	assert(game.run.knowledge.consume(inbox, 0.0))
	game.run.next_scout_id = 2
	game.run.colony.piles.home.deposit_resource("carbohydrate", 100.0)
	if authored_episode:
		game.advance(450.0)
	assert(game.create_trail("home", "known:carb_exposed"))
	return game
