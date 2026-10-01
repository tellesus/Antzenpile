extends RefCounted

const Scent = preload("res://src/presentation/outward/trail_visual.gd")
const Art = preload("res://src/presentation/sensory_art.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")
const Inward = preload("res://src/presentation/inward/inward_view.gd")
const Audio = preload("res://src/audio/audio_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")


func run(test: Object) -> bool:
	var signals: Array[Dictionary] = []
	var routes: Array[Dictionary] = []
	for index: int in 20:
		signals.append({"id": "signal_%d" % index, "source_knowledge_id": "known_%d" % index,
			"bearing": 0.0, "estimated_distance": 10.0, "strength": 0.7, "uncertainty_radius": 1.0, "category": "water"})
		routes.append({"id": "route_%d" % index, "destination_knowledge_id": "known_%d" % index,
			"pheromone_strength": 0.8, "route_familiarity": 0.8, "active_workers": 10000})
	var size := Vector2(1280, 720)
	var placed: Array[Dictionary] = Panorama.project(signals, 0.0, size)
	var before: Array[Dictionary] = routes.duplicate(true)
	var ants: Array[Dictionary] = Scent.representatives(routes, placed, size, 1.0)
	test.check(ants.size() == Scent.MAX_ANTS and Scent.paths(routes, placed, size).size() == Scent.MAX_LINKS, "Large labor/route counts cannot exceed the six-link/eighteen-ant rendering cap")
	test.check(Scent.representatives(routes, [], size, 1.0).is_empty() and Scent.representatives(routes, Panorama.project(signals, PI, size), size, 1.0).is_empty(), "Unseen and rear-facing sources produce no traveler visuals")
	var moved: Array[Dictionary] = Scent.representatives(routes, placed, size, 2.0)
	test.check(ants != moved and routes == before, "Representative movement never mutates route summaries")
	for ant: Dictionary in ants:
		test.check(ant.position.is_finite() and ant.direction.length_squared() > 0.0 and ant.category == "water", "Representative has finite sensory placement and resource identity")
	for route: Dictionary in routes:
		route.pheromone_strength = 0.0
	test.check(Scent.representatives(routes, placed, size, 1.0).is_empty() and Scent.strokes(routes, placed, size)[0].ghost, "Memory ghosts carry no invented ant traffic")
	for route: Dictionary in routes:
		route.pheromone_strength = 0.8
		route.active_workers = 0
	test.check(Scent.representatives(routes, placed, size, 1.0).is_empty(), "Idle chemical trails show no representative workers")
	test.check(Art.color_for("carbohydrate") != Art.color_for("water") and Art.color_for("protein") != Art.color_for("carbohydrate"), "Resource families retain distinct palettes")
	var game := Controller.new(3047)
	var root := Root.new()
	root.simulation = game
	var snapshot: Dictionary = game.run.to_dict()
	var outward := Outward.new()
	var inward := Inward.new()
	test.get_root().add_child(outward)
	test.get_root().add_child(inward)
	outward.signal_provider = root.sensory_snapshot.bind("home")
	outward.status_provider = root.outward_status.bind("home")
	inward.status_provider = root.inward_status.bind("home")
	outward._process(0.05)
	inward._process(0.05)
	test.check(outward._placed.is_empty() and game.run.to_dict() == snapshot, "Animated empty views cannot reveal world objects or advance simulation/RNG")
	var out_time: float = outward._animation_time
	var in_time: float = inward._animation_time
	game.set_time_scale(64)
	outward._process(0.05)
	inward._process(0.05)
	test.check(is_equal_approx(outward._animation_time - out_time, 0.05) and is_equal_approx(inward._animation_time - in_time, 0.05), "Decorative motion remains readable at 64x rather than following simulation speed")
	game.toggle_pause()
	outward._process(0.01)
	inward._process(0.01)
	out_time = outward._animation_time
	in_time = inward._animation_time
	snapshot = game.run.to_dict()
	outward._process(10.0)
	inward._process(10.0)
	test.check(outward._animation_time == out_time and inward._animation_time == in_time and game.run.to_dict() == snapshot, "Pause freezes decorative traffic and rendering never mutates run state")
	var losses: Array[int] = [2]
	var audio := Audio.new()
	audio.alarm_provider = func() -> int: return losses[0]
	test.get_root().add_child(audio)
	test.check(not audio.poll_returned_alarm() and audio.alarm_player != null and not audio.alarm_player.playing, "Audio baselines existing alarms without replay and stays silent headlessly")
	losses[0] = 3
	test.check(audio.poll_returned_alarm() and not audio.poll_returned_alarm(), "One newly delivered loss batch triggers exactly one semantic cue")
	losses[0] = 10
	audio.restart_after_load()
	test.check(not audio.poll_returned_alarm() and not audio.alarm_player.playing and Audio.ALARM_CUE.loop_mode == AudioStreamWAV.LOOP_DISABLED and Audio.ALARM_CUE.get_length() < 0.5, "Loading suppresses old alarms and cue stays short/non-looping")
	audio.free()
	outward.free()
	inward.free()
	root.free()
	return true
