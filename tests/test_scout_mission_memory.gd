extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Trace = preload("res://src/presentation/outward/scout_trace_visual.gd")
const Save = preload("res://src/core/save_service.gd")


func run(test: Object) -> bool:
	var root := Root.new()
	root.simulation = Controller.new(6241)
	var game: SimulationController = root.simulation
	test.check(game.dispatch_scout("home", TAU + 0.2), "Scout memory follows an accepted dispatch")
	var record: Dictionary = root.scout_mission_summaries("home")[0]
	test.check(is_equal_approx(record.bearing, 0.2) and record.departed_at == 0.0 and record.returned_at == -1.0 and record.course.is_empty(), "Home knows launch direction/time but no away course")
	record.course.append({"bearing": 1.0, "estimated_distance": 10.0})
	test.check(game.run.scout_missions.scout_1.course.is_empty(), "Mission summaries cannot mutate authoritative memory")
	game.advance(4.25)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict()))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict() == game.run.to_dict(), "Private mission with departure scent saves exactly")
	for field: String in ["time", "bearing", "scent", "course", "return", "duplicate", "origin"]:
		var invalid: Dictionary = saved.duplicate(true)
		match field:
			"time": invalid.scout_missions[0].departed_at = 10000.0
			"bearing": invalid.scout_missions[0].bearing = true
			"scent": invalid.scout_missions[0].scent = -1.0
			"course": invalid.scout_missions[0].course = [{"bearing": 0.0, "estimated_distance": 10.0}]
			"return": invalid.scout_missions[0].returned_at = 1.0
			"duplicate": invalid.scout_missions.append(invalid.scout_missions[0].duplicate(true))
			"origin": invalid.scout_missions[0].origin_pile = "missing"
		var before: Dictionary = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before, "Malformed mission memory rejects atomically: " + field)
	game.advance(60.0)
	copy.set_time_scale(4)
	copy.advance(15.0)
	copy.set_time_scale(1)
	test.check(copy.run.to_dict() == game.run.to_dict(), "Mission decay, return and remembered course match across speeds")
	var memory: ScoutMissionMemory = game.run.scout_missions.scout_1
	test.check(memory.returned_at >= 0.0 and not memory.course.is_empty() and memory.course.size() <= 8 and not game.run.knowledge.nodes.is_empty(), "Only actual home arrival delivers a bounded remembered course and discovery")
	record = root.scout_mission_summaries("home")[0]
	var duration: float = record.away_seconds
	game.advance(1.0)
	test.check(root.scout_mission_summaries("home")[0].away_seconds == duration, "Completed mission retains its actual duration")
	test.check(copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict()))), "Returned course restores through disk-shaped snapshot")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("scout_missions")
	test.check(copy.restore_snapshot(legacy) and copy.run.scout_missions.is_empty(), "Legacy active scouts retain unknown departure history")
	copy.advance(100.0)
	test.check(copy.run.scout_missions.is_empty(), "Legacy return does not invent launch time or course memory")
	for index: int in 19:
		test.check(game.investigate_known_source("home", "known:carb_exposed"), "Known-source repeat creates a separate home mission")
		game.advance(45.0)
	test.check(game.run.scouts.is_empty() and game.run.scout_missions.size() == 16, "Recent returns are bounded without retaining every historical mission")
	test.check(copy.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict()))), "Bounded mission history restores")
	root.free()
	_test_decay(test)
	_test_view(test)
	return true


func _test_decay(test: Object) -> void:
	var dry := Controller.new(82)
	for node: WorldNodeState in dry.run.world.nodes.values():
		node.active = false
	for terrain: Dictionary in dry.run.world.terrain:
		terrain.movement_cost = 20.0
	dry.dispatch_scout("home", 0.0)
	var wet := Controller.new()
	wet.restore_snapshot(JSON.parse_string(JSON.stringify(dry.run.to_dict())))
	wet.run.rain.phase = "raining"
	dry.advance(60.0)
	wet.advance(60.0)
	test.check(wet.run.scout_missions.scout_1.scent < 0.1 and dry.run.scout_missions.scout_1.scent > 0.7, "Rain fades launch scent faster than ordinary elapsed time")
	test.check(wet.run.scout_missions.scout_1.returned_at == -1.0 and wet.run.scout_missions.scout_1.course.is_empty(), "Rain does not reveal a remote course or conclude a scout died")
	var traces: Array[Dictionary] = Trace.traces([wet.run.scout_missions.scout_1.to_dict()], 0.0, Vector2(1280,720))
	test.check(traces.size() == 1 and traces[0].stub and Trace.pick(traces, traces[0].center, "") == "mission:scout_1", "Faded scent leaves a selectable directional memory stub")
	wet.toggle_pause()
	var before: Dictionary = wet.run.to_dict()
	wet.advance(40.0)
	test.check(wet.run.to_dict() == before, "Pause freezes departure age and scent")


func _test_view(test: Object) -> void:
	var root := Root.new()
	root.simulation = Controller.new(99)
	var view: OutwardView = View.new()
	test.get_root().add_child(view)
	view.signal_provider = root.sensory_snapshot.bind("home")
	view.status_provider = root.outward_status.bind("home")
	view.dispatch_command = root.dispatch_facing
	view._process(0.0)
	view._run_command("scout")
	view._process(0.1)
	test.check(view._departures.size() == 1, "Accepted home launch creates one finite representative")
	var entry: Dictionary = view._departures[0]
	var start: Dictionary = Trace.departure(0.0, entry.side, Vector2(1280,720))
	var finish: Dictionary = Trace.departure(2.9, entry.side, Vector2(1280,720))
	test.check(start.position.y > finish.position.y and absf(start.position.x - 640.0) > absf(finish.position.x - 640.0) and Trace.departure(3.0, entry.side, Vector2(1280,720)).is_empty(), "Representative approaches from side, climbs to exit and stops rendering")
	root.simulation.toggle_pause()
	var age: float = entry.age
	view._process(2.0)
	test.check(entry.age == age, "Paused departure does not move")
	root.simulation.toggle_pause()
	for frame: int in 35:
		view._process(0.1)
	test.check(view._departures.is_empty() and root.simulation.run.active_scout_count() == 1, "Away scout does not cause an endless entrance loop")
	root.simulation.dispatch_scout("home", 0.04)
	view._process(0.0)
	var traces: Array[Dictionary] = view._mission_traces
	test.check(traces.size() == 1 and traces[0].missions.size() == 2, "Nearby mission directions share a bounded trace")
	test.check(Trace.pick(traces, traces[0].points[8], "") != "", "Outer scout trail stroke is selectable as well as its cap")
	for kind: String in ["mouse", "touch"]:
		view._pointer_press(traces[0].center, kind)
		view._pointer_release(traces[0].center, kind)
		test.check(view.selected_id.begins_with("mission:") and not view._selected_mission().is_empty(), "Shared selection inspects a mission: " + kind)
	test.check(view.selected_id == "mission:scout_1", "Repeated selection cycles overlapping missions")
	root._outward_view = view
	root.save_service = Save.new("res://.godot/tests/mission_memory.json")
	test.check(root.quick_save().accepted and root.quick_load().accepted and view._departures.is_empty(), "Load clears decoration and selection")
	view._process(0.0)
	test.check(view._departures.is_empty() and view.selected_id == "", "Load does not replay historical departures")
	var rejected: Dictionary = root.simulation.run.to_dict()
	view._status.available_workers = 0
	view._run_command("scout")
	test.check(view._departures.is_empty() and root.simulation.run.to_dict() == rejected, "Rejected launch creates no departure or mission memory")
	for size: Vector2 in [Vector2(1280,720), Vector2(900,600)]:
		traces = Trace.traces(root.scout_mission_summaries("home"), 0.0, size)
		test.check(traces.size() <= 8 and Trace.pick(traces, traces[0].center, "") != "" and Trace.traces(root.scout_mission_summaries("home"), PI, size).is_empty(), "Trace target, cap and facing visibility hold at " + str(size))
	view.free()
	root.free()
