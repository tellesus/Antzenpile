extends "res://tests/evaluate_nursery_expansion.gd"
## Ordinary paid colony, then paired deliberate withdrawal/continued supply after local evidence.
func _run():
	var rows: Array[Dictionary] = []
	for seed_value: int in [482817,591,202603]:
		var root := Root.new(); root.simulation = Controller.new(seed_value,"roadside"); root.set_exploration(5); root.set_brood_intent("grow")
		var row: Dictionary = {"seed":seed_value,"standing_growth":true,"expand_enabled":true,"events":[],"withheld":[],"intake_at":-1.0,"loss_at":-1.0}
		while root.simulation.run.simulation_time < 2400 and root.inward_status("home").food_sharing.losses == 0:
			if root.simulation.run.clock.tick_count % 20 == 0: policy(root,row)
			root.simulation.advance(0.25)
			if not _conserved(root): failed = true; break
			# Truth only records physical metrics; commands above use detached known information.
			if row.intake_at < 0 and root.simulation.run.colony.piles.home.food_toxicity.mass > 0:
				row.intake_at = root.inward_status("home").time; _save(root,seed_value,"intake")
		if root.inward_status("home").food_sharing.losses == 0: failed = true; root.free(); continue
		row.loss_at = root.inward_status("home").time
		_save(root,seed_value,"loss")
		var snapshot: Dictionary = Snapshot.new().snapshot(root.simulation)
		var copy := Root.new(); copy.simulation = Controller.new()
		if not copy.simulation.restore_snapshot(snapshot): failed = true; root.free(); copy.free(); continue
		# Newly established ordinary food supplies are suspects; producer/rival evidence remains distinct.
		var suspect_id: String = ""
		var first_seen: Array[String] = []
		var outside: Dictionary = root.outward_status("home")
		var producer: String = outside.honeydew.get("knowledge_id","")
		for event: Dictionary in row.events:
			if str(event.action).begins_with("gather "):
				var id: String = str(event.action).trim_prefix("gather ")
				if id in first_seen: continue
				first_seen.append(id)
				for signal_data: Dictionary in root.sensory_snapshot("home"):
					if signal_data.source_knowledge_id == id and signal_data.category == "carbohydrate" and id != producer:
						for route: Dictionary in outside.trails:
							if route.destination_knowledge_id == id and route.foreign_reports == 0 and route.status == "active" and route.delivered_total > 0: suspect_id = id
		var suspect: Dictionary = {}
		for route: Dictionary in root.outward_status("home").trails:
			if route.destination_knowledge_id == suspect_id: suspect = route
		if suspect.is_empty(): failed = true; root.free(); copy.free(); continue
		row.suspect = suspect_id; row.withheld = [suspect_id]
		_event(root,row,"stop suspect supply",root.set_trail_target(suspect.id,0))
		_save(root,seed_value,"withdrawal")
		# Exact continuation under the same player response, including outstanding inbound cargo.
		var twin := Root.new(); twin.simulation = Controller.new(); twin.simulation.restore_snapshot(Snapshot.new().snapshot(root.simulation))
		for tick: int in 240:
			root.simulation.advance(0.25); twin.simulation.advance(0.25)
			if not _conserved(root) or not _conserved(twin): failed = true; break
		row.save_exact = root.simulation.run.to_dict() == twin.simulation.run.to_dict(); twin.free()
		if not row.save_exact: failed = true
		while root.simulation.run.simulation_time < row.loss_at + 1500:
			if root.simulation.run.clock.tick_count % 20 == 0: policy(root,row)
			root.simulation.advance(0.25)
			if not _conserved(root): failed = true; break
		while copy.simulation.run.simulation_time < row.loss_at + 1500:
			if copy.simulation.run.clock.tick_count % 20 == 0: policy(copy,{"standing_growth":true,"expand_enabled":true,"events":[],"withheld":[]})
			copy.simulation.advance(0.25)
			if not _conserved(copy): failed = true; break
		row.stopped = _metrics(root); row.continued = _metrics(copy)
		_save(root,seed_value,"recovered")
		if row.stopped.losses >= row.continued.losses or row.stopped.recent: failed = true
		print("[CONTAMINATION] ",JSON.stringify(row))
		rows.append(row); root.free(); copy.free()
	FileAccess.open("res://docs/evidence/card080_contamination.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"policy":"Ordinary Roadside growth and returned-evidence supply policy. After the first known home food-sharing failure, suspect the most recently first-established active ordinary carbohydrate supply with no returned foreign contact, excluding the identified living producer; stop it and withhold it from further gathering. This is a fallible player heuristic, not chemical source identification. Compare continued supply from the same snapshot, 1500 more simulated seconds. No injected stores/knowledge or suppressed threats; truth only measures material.","rows":rows},"\t",true,true))
	quit(1 if failed else 0)

func _metrics(root: Node) -> Dictionary:
	var summary: Dictionary = root.inward_status("home")
	var pile: PileState = root.simulation.run.colony.piles.home
	return {"time":summary.time,"losses":summary.food_sharing.losses,"recent":summary.food_sharing.recent,"last_loss_age":summary.food_sharing.age,"workers":summary.workers_total,"brood_emerged":summary.brood_matured_total,"stores":summary.resources,"mass":pile.food_toxicity.mass,"dose":pile.food_toxicity.dose_units}

func _conserved(root: Node) -> bool:
	var pile: PileState = root.simulation.run.colony.piles.home
	if not pile.workers.invariant_holds(): return false
	for amount: float in pile.resources.values():
		if not is_finite(amount) or amount < 0: return false
	return true

func _save(root: Node,seed_value: int,label: String):
	FileAccess.open("res://.godot/card080_%d_%s.json" % [seed_value,label],FileAccess.WRITE).store_string(JSON.stringify(root.simulation.run.to_dict(),"",true,true))
