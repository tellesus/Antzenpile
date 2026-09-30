extends RefCounted

const Perception = preload("res://src/presentation/perception_model.gd")
const Known = preload("res://src/sim/knowledge/known_node.gd")
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const SensoryFixture = preload("res://tests/test_observations.gd")


func known_at(id: String, position: Vector2, definition: String = "carbohydrate") -> KnownNode:
	var known := Known.new()
	known.id = id
	known.definition_id = definition
	known.estimated_position = position
	known.uncertainty_radius = 0.75
	known.confidence = 0.8
	known.last_observed_at = 10.0
	return known


func run(test: Object) -> bool:
	var model := Perception.new()
	var origin := Vector2(20, 20)
	var cardinal_offsets: Array[Vector2] = [Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0), Vector2(0, -10)]
	for index: int in cardinal_offsets.size():
		var known := known_at("known:direction", origin + cardinal_offsets[index])
		var signal_data: PerceivedSignal = model.project([known], origin, 10.0)[0]
		test.check(is_equal_approx(signal_data.bearing, index * PI / 2) and is_equal_approx(signal_data.estimated_distance, 10.0), "Cardinal bearing clockwise from east with estimated range")
		test.check(signal_data.confidence == 0.8 and is_equal_approx(signal_data.strength, 0.4) and signal_data.age == 0.0, "Known confidence and distance determine signal salience")
		test.check(signal_data.risk == null and signal_data.traffic == null and signal_data.uncertainty_radius == 0.75, "Unknown risk/traffic stay null; location uncertainty survives projection")
	var nearby := known_at("known:near", origin)
	var coincident: PerceivedSignal = model.project([nearby], origin, 10.0)[0]
	test.check(coincident.bearing == null and coincident.estimated_distance == 0 and coincident.strength == coincident.confidence, "Coincident estimate has no invented direction or division by zero")
	var shifted: PerceivedSignal = model.project([nearby], origin + Vector2(10, 0), 10.0)[0]
	test.check(is_equal_approx(shifted.bearing, PI) and shifted.estimated_distance == 10.0 and shifted.id == coincident.id, "Changing pile origin recomputes geometry without changing signal identity")
	test.check(Perception.relative_bearing(null, 0.0) == null and Perception.relative_bearing(0.0, INF) == null, "Undefined and invalid directions remain unknown")
	test.check(is_equal_approx(Perception.relative_bearing(deg_to_rad(359), deg_to_rad(1)), deg_to_rad(-2)), "Wrap across east seam in one direction")
	test.check(is_equal_approx(Perception.relative_bearing(deg_to_rad(1), deg_to_rad(359)), deg_to_rad(2)), "Wrap across east seam in other direction")
	test.check(is_equal_approx(Perception.relative_bearing(PI, 0.0), -PI) and is_equal_approx(Perception.relative_bearing(-PI, 0.0), -PI), "Opposite-facing seam uses consistent half-open interval")
	test.check(is_equal_approx(Perception.relative_bearing(PI / 2, TAU * 5), PI / 2) and is_equal_approx(Perception.relative_bearing(PI / 2, -TAU * 5), PI / 2), "Multiple rotations preserve relative bearing")
	var entries: Array[KnownNode] = [known_at("known:z", origin + Vector2(0, 10), "protein"), known_at("known:a", origin + Vector2(10, 0), "water"), known_at("known:m", origin + Vector2(-10, 0), "unclassified")]
	var signals: Array[PerceivedSignal] = model.project(entries, origin, 10.0)
	test.check(signals[0].category == "water" and signals[1].category == "unknown" and signals[2].category == "protein", "Authored categories and unknown classification fallback")
	test.check(signals[0].id == "signal:known:a" and signals[1].source_knowledge_id == "known:m" and entries[0].id == "known:z", "Output sorted by knowledge ID without sorting the input")
	var fresh: Dictionary = model.project([nearby], origin, 10.0)[0].to_dict()
	var aged: Dictionary = model.project([nearby], origin, 310.0)[0].to_dict()
	var ancient: Dictionary = model.project([nearby], origin, 1e9)[0].to_dict()
	test.check(aged.id == fresh.id and aged.confidence == fresh.confidence * 0.5 and aged.strength == fresh.strength * 0.5 and aged.age == 300, "Confidence and strength age while ID and memory remain stable")
	test.check(ancient.confidence == 0 and ancient.strength == 0 and ancient.id == fresh.id, "Exhausted confidence remains bounded without deleting known identity")
	test.check(fresh.confidence_label == "clear" and aged.confidence_label == "likely" and ancient.confidence_label == "uncertain", "Qualitative labels derive in presentation")
	test.check(Perception.confidence_label(0.25) == "likely" and Perception.confidence_label(0.65) == "clear", "Confidence label thresholds have explicit inclusive lower bounds")
	for key: String in ["world", "position", "estimated_position", "source_node_id", "quantity", "observations", "evidence_ids"]:
		test.check(not fresh.has(key), "Signal does not expose hidden or authoritative field: " + key)
	signals[0].strength = 99.0
	fresh.confidence = 99.0
	test.check(model.project(entries, origin, 10.0)[0].strength <= 1 and model.project([nearby], origin, 10.0)[0].confidence == 0.8, "Mutating derived objects/dictionaries cannot mutate input or future output")
	test.check(model.project(entries, Vector2(INF, 0), 10.0).is_empty() and model.project(entries, origin, NAN).is_empty() and model.project(entries, origin, -1.0).is_empty(), "Invalid origin/time produces no projection")
	var root := Root.new()
	root.simulation = SensoryFixture.new().fixture()
	test.check(root.sensory_snapshot("home").is_empty() and root.sensory_snapshot("missing").is_empty(), "Fresh hidden world and invalid pile emit no signals")
	root.simulation.advance(25.0)
	test.check(not root.simulation.run.scouts.scout_1.observations.is_empty() and root.sensory_snapshot("home").is_empty(), "Private sensed evidence emits no signal")
	root.simulation.advance(60.0)
	var projected: Array[Dictionary] = root.sensory_snapshot("home")
	test.check(projected.size() == 1 and projected[0].category == "carbohydrate", "Returned evidence emits signal through the presentation boundary")
	var state_before: Dictionary = root.simulation.run.to_dict()
	for index: int in range(20):
		root.sensory_snapshot("home")
		Perception.relative_bearing(projected[0].bearing, index * 0.5)
	test.check(root.simulation.run.to_dict() == state_before, "Repeated projection and facing changes leave run, clock and RNG untouched")
	root.simulation.run.world.nodes.carb_exposed.position = Vector2(1, 1)
	root.simulation.run.world.nodes.carb_exposed.quantity = 0
	root.simulation.run.world.nodes.carb_exposed.active = false
	test.check(root.sensory_snapshot("home") == projected, "Hidden movement/depletion cannot change perceived output without new evidence")
	var saved: Dictionary = root.simulation.run.to_dict()
	var restored := Root.new()
	restored.simulation = Controller.new()
	test.check(restored.simulation.run.restore(JSON.parse_string(JSON.stringify(saved, "", true, true))) and restored.sensory_snapshot("home") == projected, "Signals rebuild identically from restored colony memory")
	root.simulation.advance(300.0)
	restored.simulation.advance(300.0)
	test.check(root.sensory_snapshot("home") == restored.sensory_snapshot("home") and root.sensory_snapshot("home")[0].confidence < projected[0].confidence, "Derived signals age identically after reload")
	var detached: Array[Dictionary] = root.sensory_snapshot("home")
	detached[0].source_knowledge_id = "changed"
	detached.clear()
	test.check(root.sensory_snapshot("home") == restored.sensory_snapshot("home"), "Presentation boundary returns detached values")
	root.free()
	restored.free()
	return true
