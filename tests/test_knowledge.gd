extends RefCounted

const Knowledge = preload("res://src/sim/knowledge/knowledge_base.gd")
const Evidence = preload("res://src/sim/scouting/observation.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const SensoryFixture = preload("res://tests/test_observations.gd")
const DebugModel = preload("res://src/debug/debug_world_model.gd")


func evidence(scout_id: String, time: float, radius: float = 1.0, confirmed: bool = true) -> Observation:
	var result := Evidence.new()
	result.id = scout_id + ":carb_exposed"
	result.scout_id = scout_id
	result.origin_pile = "home"
	result.source_node_id = "carb_exposed"
	result.definition_id = "carbohydrate"
	result.first_observed_at = time
	result.observed_at = time
	result.estimated_position = Vector2(30, 20)
	result.uncertainty_radius = radius
	result.closest_distance = 1.0
	result.proximity_confirmed = confirmed
	return result


func deliver(knowledge: KnowledgeBase, report: Observation, time: float) -> bool:
	var inbox: Dictionary[String, Observation] = {report.id: report}
	return knowledge.consume(inbox, time) and inbox.is_empty()


func run(test: Object) -> bool:
	var knowledge := Knowledge.new()
	var first := evidence("scout_1", 10.0)
	test.check(deliver(knowledge, first, 30.0), "Delivery consumes inbox")
	var known: KnownNode = knowledge.nodes["known:carb_exposed"]
	test.check(knowledge.nodes.size() == 1 and known.last_observed_at == 10.0 and known.last_delivered_at == 30.0, "Knowledge keeps observation and delivery times separate")
	var before: Dictionary = knowledge.to_dict()
	test.check(deliver(knowledge, first, 60.0) and knowledge.to_dict() == before, "Identical re-delivery changes neither certainty nor timestamps")
	first.estimated_position = Vector2(4, 4)
	test.check(knowledge.to_dict() == before, "Archive owns detached evidence")
	var batch: Dictionary[String, Observation] = {first.id: first, "scout_2:carb_exposed": evidence("scout_2", 20.0)}
	test.check(not knowledge.consume(batch, 60.0) and batch.size() == 2 and knowledge.to_dict() == before, "Conflicting ID rejects entire batch without consuming new report")
	var newer := evidence("scout_2", 20.0, 2.0, false)
	newer.estimated_position = Vector2(28, 23)
	test.check(deliver(knowledge, newer, 40.0), "Newer cue delivered")
	known = knowledge.nodes["known:carb_exposed"]
	test.check(known.estimated_position == newer.estimated_position and known.selected_evidence_id == newer.id and knowledge.nodes.size() == 1, "Newer conflicting estimate replaces rather than averages or duplicates")
	var old := evidence("scout_3", 5.0, 0.25)
	test.check(deliver(knowledge, old, 50.0), "Out-of-order report retained")
	known = knowledge.nodes["known:carb_exposed"]
	test.check(known.selected_evidence_id == newer.id and known.first_observed_at == 5.0 and known.evidence_ids.size() == 3 and known.first_delivered_at == 30.0 and known.last_delivered_at == 50.0, "Stale evidence adds provenance without refreshing estimate")
	test.check(known.confidence_at(20.0) > 0 and known.confidence_at(20.0) <= 1 and is_equal_approx(known.confidence_at(320.0), known.confidence_at(20.0) * 0.5), "Confidence bounded and halves with observation age")
	before = knowledge.to_dict()
	test.check(known.age_at(320.0) == 300.0 and known.age_at(0.0) == 0.0 and known.confidence_at(1e9) == 0.0 and knowledge.to_dict() == before, "Age queries never mutate estimates or snapshots")
	var ties: Array[Observation] = [evidence("scout_9", 60.0, 2.0), evidence("scout_8", 60.0, 1.0, false), evidence("scout_7", 60.0), evidence("scout_6", 60.0)]
	var forward := Knowledge.new()
	var reverse := Knowledge.new()
	for report: Observation in ties:
		deliver(forward, report, 70.0)
	ties.reverse()
	for report: Observation in ties:
		deliver(reverse, report, 70.0)
	test.check(forward.to_dict() == reverse.to_dict() and forward.nodes["known:carb_exposed"].selected_evidence_id == "scout_6:carb_exposed", "Equal-time resolution independent of delivery order")
	for invalid_value: float in [-1.0, NAN, INF]:
		var malformed := evidence("scout_4", 60.0, invalid_value)
		test.check(not deliver(knowledge, malformed, 70.0) and knowledge.to_dict() == before, "Invalid uncertainty rejected atomically")
	test.check(not deliver(knowledge, evidence("scout_4", 90.0), 70.0) and knowledge.to_dict() == before, "Future evidence rejected")
	var fixture := SensoryFixture.new().fixture()
	for index: int in 80:
		if fixture.run.scouts.has("scout_1") and not fixture.run.scouts.scout_1.observations.is_empty():
			break
		fixture.advance(0.25)
	test.check(fixture.run.knowledge.nodes.is_empty() and fixture.run.scouts.has("scout_1") and not fixture.run.scouts.scout_1.observations.is_empty(), "Private sensing creates no colony knowledge")
	fixture.advance(60.0)
	test.check(fixture.run.delivered_observations.is_empty() and fixture.run.knowledge.nodes.size() == 1 and fixture.run.scouts.is_empty(), "Return automatically consumes evidence into one Known Node")
	var saved: Dictionary = fixture.run.to_dict()
	var restored := Controller.new()
	test.check(restored.run.restore(JSON.parse_string(JSON.stringify(saved, "", true, true))) and restored.run.to_dict() == saved, "Populated knowledge full-precision JSON round trip")
	for index: int in range(100):
		fixture.advance(0.25)
		restored.advance(0.25)
		test.check(fixture.run.to_dict() == restored.run.to_dict(), "Knowledge continuation matches")
	var rng_before: int = fixture.run.rng.state
	before = fixture.run.knowledge.to_dict()
	fixture.run.world.nodes.carb_exposed.position = Vector2(35, 35)
	fixture.run.world.nodes.carb_exposed.quantity = 0
	fixture.run.world.nodes.carb_exposed.active = false
	fixture.advance(300.0)
	var debug := DebugModel.new()
	debug.refresh(fixture.run.to_dict(), Vector2(1280, 720))
	var inspected: Dictionary = debug.known_for("carb_exposed")
	test.check(inspected.estimated_position == before.nodes[0].estimated_position and inspected.age > 300 and inspected.effective_confidence < before.nodes[0].confidence, "Debug inspects stale estimate with aged confidence")
	inspected.estimated_position[0] = -99.0
	test.check(fixture.run.knowledge.to_dict() == before and fixture.run.rng.state == rng_before, "Truth mutation, confidence aging and diagnostics never refresh memory or use RNG")
	test.check(debug.known_for("unknown").is_empty(), "Unobserved source has no knowledge")
	before = restored.run.to_dict()
	var invalid: Dictionary = saved.duplicate(true)
	invalid.knowledge.nodes[0].estimated_position[0] += 1
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Estimate inconsistent with archive rejects atomically")
	invalid = saved.duplicate(true)
	invalid.knowledge.nodes[0].confidence = 1.0
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Invented confidence rejects atomically")
	for confidence: Variant in [saved.knowledge.nodes[0].confidence + 0.000000001, NAN, "uncertain"]:
		invalid = saved.duplicate(true)
		invalid.knowledge.nodes[0].confidence = confidence
		test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Confidence edits beyond serialization noise reject atomically")
	for time: float in [-1.0, saved.clock.time + 1, NAN]:
		invalid = saved.duplicate(true)
		invalid.knowledge.observations[0].received_at = time
		test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Invalid delivery timestamp rejects atomically")
	invalid = saved.duplicate(true)
	invalid.delivered_observations.append(invalid.knowledge.observations[0].evidence.duplicate(true))
	test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Snapshot cannot duplicate pending and consumed evidence")
	# A genuine unconsumed delivery remains valid and is processed on the next tick.
	var pending: Dictionary = saved.duplicate(true)
	pending.delivered_observations.append(pending.knowledge.observations[0].evidence.duplicate(true))
	pending.knowledge = {"nodes": [], "observations": []}
	test.check(restored.run.restore(pending), "Pending delivery restores before consumption")
	restored.advance(0.25)
	test.check(restored.run.delivered_observations.is_empty() and restored.run.knowledge.nodes.size() == 1, "Restored controller still processes delivered evidence")
	return true
