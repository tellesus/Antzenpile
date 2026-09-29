extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Pathfinder = preload("res://src/sim/scouting/scout_pathfinder.gd")


func run(test: Object) -> bool:
	var a := Controller.new(6241)
	var b := Controller.new(6241)
	test.check(a.dispatch_scout("home", 0.0) and b.dispatch_scout("home", 0.0), "Directional mission accepted")
	test.check(a.run.scouts.scout_1.phase == "departing" and a.run.colony.piles.home.workers_available == 39, "Departure commits one worker")
	var outbound: Vector2 = a.run.scouts.scout_1.path.back() - Vector2(20, 20)
	test.check(absf(outbound.angle()) <= PI / 4 + 0.1 and outbound.length() >= 7.0, "Directional target respects cone and distance")
	var saw_return: bool = false
	var different := Controller.new(81)
	different.dispatch_scout("home", 0.0)
	test.check(different.run.scouts.scout_1.path != a.run.scouts.scout_1.path, "Different seed changes route")
	for index: int in range(320):
		a.advance(0.25)
		b.advance(0.25)
		test.check(a.run.to_dict() == b.run.to_dict(), "Seeded trajectory repeats")
		test.check(a.run.colony.piles.home.workers.invariant_holds(), "Scout movement conserves workers")
		if a.run.scouts.has("scout_1"):
			saw_return = saw_return or a.run.scouts.scout_1.phase == "returning"
	test.check(saw_return and a.run.scouts.is_empty() and a.run.colony.piles.home.workers_available == 40 and a.run.colony.piles.home.workers.to_dict().commitments.is_empty(), "Return releases exactly one worker and retires commitment")
	var capped := Controller.new()
	for index: int in range(4):
		test.check(capped.dispatch_scout("home"), "Scout within cap accepted")
	var before: Dictionary = capped.run.to_dict()
	test.check(not capped.dispatch_scout("home") and capped.run.to_dict() == before, "Cap rejection is atomic including RNG")
	var invalid := Controller.new()
	for bearing: Variant in [NAN, INF, true, "east"]:
		before = invalid.run.to_dict()
		test.check(not invalid.dispatch_scout("home", bearing) and invalid.run.to_dict() == before, "Invalid direction rejected atomically")
	invalid.run.colony.piles.home.workers.create_commitment("busy", "internal", "test")
	invalid.run.colony.piles.home.workers.allocate("busy", 40)
	before = invalid.run.to_dict()
	test.check(not invalid.dispatch_scout("home") and invalid.run.to_dict() == before, "No available worker rejection")
	var isolated := Controller.new()
	isolated.run.world.terrain.append({"id": "wall", "bounds": [19.0, 0.0, 2.0, 40.0], "exposure": 0.0, "traversable": false, "movement_cost": 1.0})
	before = isolated.run.to_dict()
	test.check(not isolated.dispatch_scout("home") and isolated.run.to_dict() == before, "Unreachable origin rejects without consuming RNG")
	var path_world := Controller.new().run.world
	path_world.terrain.append({"id": "obstacle", "bounds": [22.0, 18.0, 2.0, 4.0], "exposure": 0.0, "traversable": false, "movement_cost": 1.0})
	var detour: Array[Vector2] = Pathfinder.new(path_world).path(Vector2(20, 20), Vector2(26, 20))
	test.check(detour.size() > 7, "Obstacle forces detour")
	for point: Vector2 in detour:
		test.check(is_finite(Pathfinder.travel_cost(path_world, point)), "Path avoids blocked cells")
	path_world.terrain.back().traversable = true
	path_world.terrain.back().movement_cost = 20.0
	var cheaper_detour: Array[Vector2] = Pathfinder.new(path_world).path(Vector2(20, 20), Vector2(26, 20))
	test.check(cheaper_detour.size() > 7, "Path chooses cheaper detour over expensive terrain")
	var cheap := Controller.new(111)
	var expensive := Controller.new(111)
	for terrain: Dictionary in expensive.run.world.terrain:
		terrain.movement_cost = 4.0
	test.check(cheap.dispatch_scout("home", 0) and expensive.dispatch_scout("home", 0), "Terrain cost missions start")
	cheap.advance(1.25)
	expensive.advance(1.25)
	test.check(cheap.run.scouts.scout_1.position.distance_to(Vector2(20, 20)) > expensive.run.scouts.scout_1.position.distance_to(Vector2(20, 20)), "Expensive terrain slows travel")
	var original := Controller.new(926)
	original.dispatch_scout("home")
	original.advance(4.375)
	var restored := Controller.new(1)
	test.check(restored.run.restore(JSON.parse_string(JSON.stringify(original.run.to_dict()))), "Mid-mission JSON snapshot restores")
	before = restored.run.to_dict()
	var broken: Dictionary = before.duplicate(true)
	broken.scouts[0].path[1] = [1.0, 1.0]
	test.check(not restored.run.restore(broken) and restored.run.to_dict() == before, "Disconnected scout path rejects atomically")
	broken = before.duplicate(true)
	broken.scouts.clear()
	test.check(not restored.run.restore(broken) and restored.run.to_dict() == before, "Orphan scout commitment rejects atomically")
	for index: int in range(320):
		original.advance(0.25)
		restored.advance(0.25)
		test.check(original.run.to_dict() == restored.run.to_dict(), "Reloaded mission continuation matches")
	var blocked := Controller.new(18)
	blocked.dispatch_scout("home", 0)
	blocked.advance(30.25)
	blocked.run.world.terrain.append({"id": "blocked", "bounds": [0.0, 0.0, 40.0, 40.0], "exposure": 0.0, "traversable": false, "movement_cost": 1.0})
	blocked.advance(1.0)
	test.check(blocked.run.scouts.scout_1.phase == "blocked_returning" and blocked.run.colony.piles.home.workers_available == 39, "Blocked return retains worker")
	var blocked_copy := Controller.new()
	test.check(blocked_copy.run.restore(JSON.parse_string(JSON.stringify(blocked.run.to_dict()))), "Blocked return snapshot restores")
	blocked.run.world.terrain.pop_back()
	blocked.advance(50.0)
	test.check(blocked.run.scouts.is_empty() and blocked.run.colony.piles.home.workers_available == 40, "Unblocked return releases only at home")
	print("[SCOUT] deterministic missions, cap, pathing, return accounting and snapshot continuation verified")
	return true
