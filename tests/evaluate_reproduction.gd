extends "res://tests/evaluate_expanded_colony.gd"
## Ordinary paid growth and returned-source decisions; no injected mature population.
func _run() -> void:
	var rows: Array[Dictionary] = []
	for scenario: String in ["backyard_slice","garden_edge"]:
		for seed_value: int in [482817,591]:
			var colony := Root.new(); colony.simulation=Controller.new(seed_value,scenario)
			colony.set_exploration(5)
			var row: Dictionary={"scenario":scenario,"seed":seed_value,"events":[],"laid_at":-1.0,"ready_at":-1.0,"saved_exact":true,"captures":{}}
			while colony.simulation.run.simulation_time<5400:
				var pile: PileState=colony.simulation.run.colony.piles.home
				if colony.simulation.run.clock.tick_count%20==0:
					if row.laid_at<0 and pile.brood_matured_total>=32:
						colony.set_brood_intent("manual")
						# Clear a selected trial deliberately before reproductive laying.
						colony.queue_adaptation("")
						var prior: Dictionary=colony.simulation.run.to_dict()
						var request: Dictionary=colony.start_reproduction()
						if request.accepted:
							row.laid_at=colony.simulation.run.simulation_time
							FileAccess.open("res://.godot/card103_%s_%d_prepared.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(prior))
					paid_policy(colony,row)
				colony.simulation.advance(0.25)
				if not pile.workers.invariant_holds(): failed=true
				var phase: String=pile.reproduction.phase
				if phase in ["egg","larva","pupa","ready"] and not row.captures.has(phase):
					var snapshot: Dictionary=colony.simulation.run.to_dict()
					FileAccess.open("res://.godot/card103_%s_%d_%s.json" % [scenario,seed_value,phase],FileAccess.WRITE).store_string(JSON.stringify(snapshot))
					row.captures[phase]=colony.simulation.run.simulation_time
					var copy := Controller.new()
					var exact: bool=copy.restore_snapshot(JSON.parse_string(JSON.stringify(snapshot)))
					for tick: int in 40:
						colony.simulation.advance(0.25); copy.advance(0.25)
						exact=exact and colony.simulation.run.to_dict()==copy.run.to_dict()
					row.saved_exact=row.saved_exact and exact
				if phase=="ready":
					row.ready_at=row.captures.ready
					break
			var pile: PileState=colony.simulation.run.colony.piles.home
			row.final={"workers":pile.workers_total,"emerged":pile.brood_matured_total,"active_queens":pile.queen_count,"phase":pile.reproduction.phase,"nurses":pile.workers.count("reproduction:home"),"stores":pile.resources.duplicate(),"known_nodes":colony.simulation.run.knowledge.nodes.size()}
			row.passed=row.ready_at>=0 and row.saved_exact and pile.workers.invariant_holds() and pile.queen_count==1
			failed=failed or not row.passed; rows.append(row)
			print("[REPRODUCTION] ",{"scenario":scenario,"seed":seed_value,"laid_at":row.laid_at,"ready_at":row.ready_at,"final":row.final,"passed":row.passed})
			colony.free()
	FileAccess.open("res://.godot/card103_reproduction.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
	quit(1 if failed else 0)

func paid_policy(colony: Node,row: Dictionary) -> void:
	# The existing evidence policy pays chambers, rejects guests, tends known honeydew
	# and switches/rechecks returned supplies. Limit brood when saving a founding group.
	var pile: PileState=colony.simulation.run.colony.piles.home
	var preserved_intent: String=pile.brood_intent
	if pile.brood_matured_total>=32:
		# Suppress the inherited policy's manual requests, not physical development.
		row.standing_growth=true
	super.policy(colony,row)
	if pile.brood_matured_total>=32: colony.set_brood_intent(preserved_intent)
	if pile.midden.revealed:
		colony.set_sanitation_workers(2)
		if pile.midden.state=="primitive": colony.start_midden()
	if pile.nursery_state=="developed": colony.set_humidity_workers(1)
