extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Outward = preload("res://src/presentation/outward/outward_view.gd")


func run(test: Object) -> bool:
	var game := Controller.new(3040)
	var initial: Dictionary = game.run.to_dict()
	test.check(not game.investigate_known_source("home", "known:protein_picnic") and game.run.to_dict() == initial, "Unknown investigation rejects without changing the run")
	game.advance(450.0)
	test.check(game.dispatch_scout("home", PI / 4.0), "Frontier scout searches the active source")
	var known_id := "known:protein_picnic"
	test.check(not game.run.knowledge.nodes.has(known_id), "Private scout evidence is not colony knowledge")
	test.check(_until(game, func() -> bool: return game.run.knowledge.nodes.has(known_id), 80.0), "Scout delivers the first picnic report")
	if not game.run.knowledge.nodes.has(known_id):
		return false
	test.check(not game.run.knowledge.temporal_hint(known_id).possible_recurrence, "One positive report cannot imply a recurrence")
	game.run.colony.piles.home.deposit_resource("carbohydrate", 10.0)
	test.check(game.create_trail("home", known_id), "Known source can be visited by a normal trail")
	test.check(_until(game, func() -> bool: return game.run.trails.routes.route_1.status == "depleted", 120.0), "Trail eventually returns empty from the depleted spill")
	var history: Array = game.run.knowledge.outcomes.get("protein_picnic", [])
	test.check(history.size() >= 2 and history[0].available and not history.back().available, "Loaded and empty trail returns become source-specific evidence")
	test.check(not game.run.knowledge.temporal_hint(known_id).possible_recurrence, "An empty report alone does not predict a return")
	var other_id := "known:carb_exposed"
	test.check(game.run.knowledge.temporal_hint(other_id).is_empty(), "Temporal evidence does not leak to another source")
	game.advance(650.0 - game.run.simulation_time)
	test.check(not game.run.world.nodes.protein_picnic.active, "Source is physically absent at first expiry")
	var before_probe: Dictionary = game.run.to_dict()
	test.check(game.investigate_known_source("home", known_id), "Known estimate accepts a deliberate scout investigation")
	var agent: ScoutAgent = game.run.scouts["scout_%d" % (game.run.next_scout_id - 1)]
	test.check(agent.investigation_source_id == "protein_picnic" and game.run.colony.piles.home.workers.invariant_holds(), "Investigation uses one real ledger worker and records its target")
	test.check(not game.investigate_known_source("home", "known:missing") and game.run.scouts.size() == 1, "Invalid second investigation does not allocate a worker")
	var paused_tick: int = game.run.clock.tick_count
	game.toggle_pause()
	game.advance(20.0)
	test.check(game.run.clock.tick_count == paused_tick and agent.position == game.run.colony.piles.home.position, "Pause freezes an investigation in flight")
	game.toggle_pause()
	game.set_time_scale(4)
	game.advance(0.0625)
	game.set_time_scale(1)
	test.check(game.run.clock.tick_count == paused_tick + 1, "Investigation follows the fixed clock at 4×")
	var midflight: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var copy := Controller.new()
	test.check(copy.restore_snapshot(midflight), "Investigation in flight restores")
	var legacy_agent: Dictionary = midflight.duplicate(true)
	legacy_agent.scouts[0].erase("investigation_source_id")
	var old_scout := Controller.new()
	test.check(old_scout.restore_snapshot(legacy_agent) and old_scout.run.scouts.values()[0].investigation_source_id.is_empty(), "Older version-5 scout snapshots default to a frontier mission")
	test.check(_until(game, func() -> bool: return game.run.scouts.is_empty(), 80.0), "Empty known-source investigation returns home")
	copy.advance(game.run.simulation_time - copy.run.simulation_time)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Empty investigation continues exactly after reload")
	test.check(game.run.knowledge.outcomes.protein_picnic.back().available == false and game.run.knowledge.to_dict().observations == before_probe.knowledge.observations, "Empty investigation records absence without inventing a positive scout report")
	game.advance(1050.0 - game.run.simulation_time)
	test.check(game.run.world.nodes.protein_picnic.active and not game.run.knowledge.temporal_hint(known_id).possible_recurrence, "Unobserved reappearance creates no recurrence hint")
	var root := Root.new()
	root.simulation = game
	var view := Outward.new()
	test.get_root().add_child(view)
	view._signals = root.sensory_snapshot("home")
	view._status = root.outward_status("home")
	view.selected_id = view._signals[0].id
	view.investigate_command = root.investigate_known_source
	var button: Vector2 = view._investigate_button_rect().get_center()
	test.check(view._button_at(button) == "investigate" and view._investigate_button_rect().size.y >= 44.0, "Selected trace offers a touch-sized investigation action")
	view._pointer_press(button, "touch")
	test.check(game.run.scouts.size() == 1, "Touch investigation dispatches a semantic scout command")
	var mouse_calls: Array[int] = [0]
	view.investigate_command = func(_id: String) -> Dictionary:
		mouse_calls[0] += 1
		return {"accepted": false, "reason": "Test rejection"}
	view._pointer_press(button, "mouse")
	test.check(mouse_calls[0] == 1 and game.run.scouts.size() == 1, "Mouse uses the same contextual command path without changing the run on rejection")
	view.free()
	root.free()
	test.check(_until(game, func() -> bool: return game.run.scouts.is_empty(), 80.0), "Scout returns from the later live source")
	var hint: Dictionary = game.run.knowledge.temporal_hint(known_id)
	test.check(hint.possible_recurrence and hint.label.contains("uncertain"), "Positive-empty-positive evidence yields an explicitly uncertain recurrence hint")
	var normal := Root.new()
	normal.simulation = game
	var detached: Dictionary = normal.outward_status("home")
	test.check(detached.temporal_hints.has(known_id) and detached.temporal_hints[known_id] == hint and not detached.has("world") and not detached.has("schedule"), "Normal view receives detached evidence language without world schedule")
	normal.free()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_dict(), "", true, true))
	var bad: Dictionary = snapshot.duplicate(true)
	bad.knowledge.outcomes[0].visits[0].time = -1.0
	var stable: Dictionary = game.run.to_dict()
	test.check(not game.restore_snapshot(bad) and game.run.to_dict() == stable, "Malformed temporal history rejects atomically")
	bad = snapshot.duplicate(true)
	bad.knowledge.outcomes[0].visits.append(bad.knowledge.outcomes[0].visits.back().duplicate(true))
	test.check(not game.restore_snapshot(bad) and game.run.to_dict() == stable, "Repeated identical outcome rejects atomically")
	var old: Dictionary = snapshot.duplicate(true)
	old.knowledge.erase("outcomes")
	test.check(copy.restore_snapshot(old) and copy.run.knowledge.outcomes.is_empty(), "Older version-5 snapshots without source history still load")
	for index: int in 40:
		game.run.knowledge.record_outcome("protein_picnic", index % 2 == 0, game.run.simulation_time, "trail")
	test.check(game.run.knowledge.outcomes.protein_picnic.size() == 16, "Source outcome history stays bounded during repeated changes")
	test.check(game.run.colony.piles.home.workers.invariant_holds(), "Repeated investigations preserve worker conservation")
	return true


func _until(game: SimulationController, predicate: Callable, limit_seconds: float) -> bool:
	for step: int in int(limit_seconds / 0.25):
		if predicate.call():
			return true
		game.advance(0.25)
	return predicate.call()
