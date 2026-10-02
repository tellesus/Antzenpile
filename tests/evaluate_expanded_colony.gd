extends SceneTree
## Decisions consume the same detached evidence as normal views; truth only verifies invariants.
const Root = preload("res://src/core/game_root.gd")
const Controller = preload("res://src/core/simulation_controller.gd")
const Snapshot = preload("res://tests/test_guest.gd")
const Activity = preload("res://src/presentation/inward/colony_activity.gd")
var failed: bool = false

func _initialize(): _run.call_deferred()

func _run():
	var rows: Array[Dictionary] = []
	for scenario: String in ["backyard_slice", "garden_edge"]:
		for seed_value: int in [482817, 591, 202603]:
			var root := Root.new()
			root.simulation = Controller.new(seed_value, scenario)
			root.set_exploration(5)
			var row: Dictionary = {"scenario": scenario, "seed": seed_value, "events": [], "captures": {}, "save_exact": false, "strained_seconds": 0.0}
			while root.simulation.run.simulation_time < 3600:
				if root.simulation.run.clock.tick_count % 20 == 0:
					_observe(root, row)
					policy(root, row)
				root.simulation.advance(0.25)
				var pile: PileState = root.simulation.run.colony.piles.home
				if not pile.workers.invariant_holds() or pile.resources.values().any(func(value): return value < 0):
					printerr("Expanded conservation failed"); failed = true; break
				if root.simulation.run.simulation_time == 1200:
					var copy := Root.new()
					copy.simulation = Controller.new()
					if not copy.simulation.restore_snapshot(Snapshot.new().snapshot(root.simulation)):
						printerr("Expanded restore failed"); failed = true; copy.free(); break
					for tick: int in 240:
						if root.simulation.run.clock.tick_count % 20 == 0:
							policy(root, row)
							policy(copy, {"events": []})
						root.simulation.advance(0.25)
						copy.simulation.advance(0.25)
					row.save_exact = root.simulation.run.to_dict() == copy.simulation.run.to_dict()
					copy.free()
					if not row.save_exact: printerr("Expanded continuation failed"); failed = true; break
			var summary: Dictionary = root.inward_status("home")
			row["final"] = {"time": summary.time, "workers": summary.workers_total, "emerged": summary.brood_matured_total,
				"brood_losses": summary.brood_losses, "stores": summary.resources, "nursery": summary.nursery_state,
				"midden": summary.midden, "humidity": summary.humidity, "repertoire": summary.genetic_repertoire,
				"returned_losses": root.returned_losses("home"), "sources": root.sensory_snapshot("home").size()}
			_capture(root, row, "final")
			rows.append(row)
			print("[EXPANDED] ", scenario, " seed=", seed_value, " ", JSON.stringify(row.final), " exact=", row.save_exact)
			root.free()
	var output := FileAccess.open("res://docs/evidence/card075_expanded.json", FileAccess.WRITE)
	if output == null: quit(1); return
	output.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "platform": OS.get_name(), "duration_seconds": 3600,
		"policy": "Detached-summary ordinary paid growth, known alternatives/recovery, inherited trials and remedies after known pressure; no truth-based decisions or injected resources/knowledge. Seed 202603 chooses Lean/security; others Load/tolerance when available. Pause/speed and human usability are separate checks.", "rows": rows}, "\t", true, true))
	quit(1 if failed else 0)

func _event(root: Node, row: Dictionary, name: String, result: Dictionary) -> void:
	if result.get("accepted", false): row.events.append({"time": root.inward_status("home").time, "action": name})

func policy(root: Node, row: Dictionary) -> void:
	var inside: Dictionary = root.inward_status("home")
	var outside: Dictionary = root.outward_status("home")
	var signals: Array[Dictionary] = root.sensory_snapshot("home")
	if inside.food_exchange_state == "primitive": _event(root, row, "develop Food Exchange", root.start_food_exchange())
	if inside.nursery_state == "primitive": _event(root, row, "develop Nursery", root.start_nursery_development())
	var traits: Array[String] = ["lean" if root.current_seed() == 202603 else "load", "persistent", "security" if root.current_seed() == 202603 else "tolerance"]
	for trait_id: String in traits:
		if inside.adaptation_options.get(trait_id, {}).get("available", false):
			_event(root, row, "trial " + trait_id, root.start_adaptation(trait_id))
			break
	_event(root, row, "lay brood", root.start_brood())
	if inside.midden.revealed and inside.midden.larval_rate < 1.0 and inside.midden.cleaners == 0:
		_event(root, row, "assign cleanup 2", root.set_sanitation_workers(2))
	if inside.midden.revealed and inside.midden.state == "primitive" and inside.midden.cleaners > 0:
		_event(root, row, "develop Midden", root.start_midden())
	if inside.nursery_state == "developed" and inside.humidity.larval_rate < 1.0 and inside.humidity.carers == 0:
		_event(root, row, "assign climate 1", root.set_humidity_workers(1))
	if inside.guest.get("reported_losses", 0) > 0 and inside.guest.observation != "purged" and not inside.guest.rejection_active:
		_event(root, row, "reject observed guest", root.set_guest_rejection(true))
	var used: Array[String] = []
	for route: Dictionary in outside.trails:
		var kind: String = ""
		for signal_data: Dictionary in signals:
			if signal_data.source_knowledge_id == route.destination_knowledge_id: kind = signal_data.category
		var hint: Dictionary = outside.temporal_hints.get(route.destination_knowledge_id, {})
		if route.foreign_reports > 0:
			if route.desired_workers > 0: _event(root, row, "withdraw foreign contact", root.set_trail_target(route.id, 0))
			continue
		if route.status == "depleted":
			if not route.resume_on_report: _event(root, row, "watch reported depletion", root.toggle_investigation_priority(route.destination_knowledge_id))
			if kind == "carbohydrate" and not hint.get("possible_recurrence", false) and route.desired_workers > 0:
				_event(root, row, "recall empty food", root.set_trail_target(route.id, 0))
		# A waiting, empty route does not supply this resource; try a returned alternative.
		if route.desired_workers > 0 and route.status != "depleted" and not hint.get("last_return_empty", false): used.append(kind)
	signals.sort_custom(func(a, b): return a.source_knowledge_id < b.source_knowledge_id)
	for signal_data: Dictionary in signals:
		if signal_data.category != "carbohydrate" and signal_data.category in used: continue
		var id: String = signal_data.source_knowledge_id
		var hint: Dictionary = outside.temporal_hints.get(id, {})
		if hint.get("last_return_empty", false): continue
		var existing: Dictionary = {}
		for route: Dictionary in outside.trails:
			if route.destination_knowledge_id == id: existing = route
		if not existing.is_empty() and (existing.foreign_reports > 0 or existing.status == "depleted" and not existing.recovery_ready): continue
		if root.inward_status("home").workers_available >= 10:
			_event(root, row, "gather " + id, root.create_trail_for(id))
			used.append(signal_data.category)
	if inside.honeydew.get("relationship", "") == "exploited" and inside.workers_available >= inside.honeydew.required_workers + 4:
		_event(root, row, "protect harvested producer", root.set_honeydew_protection(true))
	if inside.honeydew.get("relationship", "") == "tended":
		for route: Dictionary in outside.trails:
			if route.destination_knowledge_id == inside.honeydew.knowledge_id and route.status == "active" and route.desired_workers < 10 and inside.workers_available >= 10 - route.desired_workers + 4:
				_event(root, row, "support known risky producer", root.set_trail_target(route.id, 10))

func _capture(root: Node, row: Dictionary, tag: String) -> void:
	if row.captures.has(tag): return
	var path: String = "res://.godot/card075_%s_%d_%s.json" % [row.scenario, row.seed, tag]
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(root.simulation.run.to_dict(), "", true, true))
	row.captures[tag] = root.inward_status("home").time

func _observe(root: Node, row: Dictionary) -> void:
	var status: Dictionary = root.inward_status("home")
	if not Activity.pressure(status, "nursery").is_empty():
		row.strained_seconds += 5.0
		_capture(root, row, "pressure")
	if status.midden.larval_rate < 1.0: _capture(root, row, "refuse")
	if status.humidity.larval_rate < 1.0: _capture(root, row, "climate")
	if status.guest.get("reported_losses", 0) > 0 and status.guest.observation != "purged": _capture(root, row, "guest")
	if root.returned_losses("home") > 0: _capture(root, row, "loss")
	if not status.genetic_repertoire.is_empty(): _capture(root, row, "adaptation")
