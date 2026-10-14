extends "res://tests/evaluate_reproduction.gd"
func _run() -> void:
	var rows: Array[Dictionary]=[]
	for scenario: String in ["backyard_slice","garden_edge"]:
		for seed_value: int in [482817,591]:
			var colony:=Root.new(); colony.simulation=Controller.new(seed_value,scenario); colony.set_exploration(5)
			var row: Dictionary={"scenario":scenario,"seed":seed_value,"events":[],"laid_at":-1.0,"founding_at":-1.0,"camp_at":-1.0,"saved_exact":true,"captures":{}}
			while colony.simulation.run.simulation_time<6000:
				var pile: PileState=colony.simulation.run.colony.piles.home
				if colony.simulation.run.clock.tick_count%20==0:
					if row.laid_at<0 and pile.brood_matured_total>=32:
						colony.set_brood_intent("manual"); colony.queue_adaptation("")
						if colony.start_reproduction().accepted: row.laid_at=colony.simulation.run.simulation_time
					if row.founding_at<0 and pile.reproduction.phase=="ready":
						for signal_data: Dictionary in colony.sensory_snapshot("home"):
							if signal_data.category!="nest_site": continue
							var prepared: Dictionary=colony.simulation.run.to_dict()
							if colony.start_founding(signal_data.source_knowledge_id).accepted:
								row.founding_at=colony.simulation.run.simulation_time
								FileAccess.open("res://.godot/card104_%s_%d_prepared.json" % [scenario,seed_value],FileAccess.WRITE).store_string(JSON.stringify(prepared))
					paid_policy(colony,row)
				colony.simulation.advance(0.25)
				var state: FoundingState=colony.simulation.run.founding
				if state.phase!="none" and not row.captures.has(state.phase):
					var saved: Dictionary=colony.simulation.run.to_dict(); var twin:=Controller.new()
					row.captures[state.phase]=colony.simulation.run.simulation_time
					FileAccess.open("res://.godot/card104_%s_%d_%s.json" % [scenario,seed_value,state.phase],FileAccess.WRITE).store_string(JSON.stringify(saved))
					var exact: bool=twin.restore_snapshot(JSON.parse_string(JSON.stringify(saved)))
					for tick: int in 40:
						colony.simulation.advance(0.25); twin.advance(0.25); exact=exact and colony.simulation.run.to_dict()==twin.run.to_dict()
					row.saved_exact=row.saved_exact and exact
				if state.phase=="ready": row.camp_at=row.captures.ready; break
			var pile: PileState=colony.simulation.run.colony.piles.home
			row.final={"workers":pile.workers_total,"emerged":pile.brood_matured_total,"active_queens":pile.queen_count,"available":pile.workers_available,"committed_settlers":colony.simulation.run.founding.assigned(),"stores":pile.resources.duplicate(),"knowledge":colony.simulation.run.knowledge.nodes.size()}
			row.passed=row.camp_at>0 and row.saved_exact and pile.workers.invariant_holds() and pile.queen_count==1
			failed=failed or not row.passed; rows.append(row)
			print("[FOUNDING] ",{"scenario":scenario,"seed":seed_value,"departed":row.founding_at,"reported":row.camp_at,"final":row.final,"passed":row.passed})
			colony.free()
	FileAccess.open("res://.godot/card104_founding.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"passed":not failed},"\t"))
	quit(1 if failed else 0)
