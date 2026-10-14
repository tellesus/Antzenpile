extends SceneTree
## Commands use detached local/returned facts; truth is measured only afterward.
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Snapshot = preload("res://tests/test_guest.gd")
var failures: int = 0
var rows: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func verify(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	for seed_value: int in [3048,3030,482817]:
		var initial := Controller.new(seed_value)
		initial.dispatch_scout("home",0.0); initial.advance(670)
		if not initial.run.knowledge.nodes.has("known:carb_exposed"):
			initial.set_exploration(5); initial.set_exploration_bias(0.0)
			for tick: int in 2400:
				initial.advance(0.25)
				if initial.run.knowledge.nodes.has("known:carb_exposed"): break
		verify(initial.create_trail("home","known:carb_exposed"),"Ordinary returned source funds route")
		for tick: int in 2400:
			initial.advance(0.25)
			if initial.run.trails.routes.route_1.conflict_report in ["withdrew","dispersed"] and initial.run.trails.routes.route_1.allocated_workers == 0: break
		verify(initial.run.trails.routes.route_1.desired_workers == 0,"Ordinary failed attempt returns and pauses")
		var saved: Dictionary = Snapshot.new().snapshot(initial)
		for action: String in ["avoid","retry","reinforce_after_pressure","withdraw_after_pressure"]:
			var game := Controller.new(); verify(game.restore_snapshot(saved),"Evaluation branch restores")
			var root := Root.new(); root.simulation = game
			var route: TrailRouteState = game.run.trails.routes.route_1
			var before_losses: int = route.reported_rival_losses
			var before_cargo: float = route.delivered_total
			var started: float = game.run.simulation_time
			var baseline_serial: int = route.conflict_serial
			if action != "avoid": verify(root.set_trail_target(route.id,13).accepted,"Explicit prepared retry")
			var copy := Controller.new(); verify(copy.restore_snapshot(Snapshot.new().snapshot(game)),"Funded branch twin restores")
			var acted: bool = false
			var reports: Array[Dictionary] = []
			var last: float = route.conflict_received_at
			for tick: int in 2000:
				game.advance(0.25); copy.advance(0.25)
				var known: Dictionary = root.trail_summaries("home")[0]
				if known.conflict_received_at > last:
					last = known.conflict_received_at
					reports.append({"received_after":game.run.simulation_time-started,"observation_age":game.run.simulation_time-known.conflict_observed_at,"report":known.conflict_report,"encounter":known.conflict_serial})
				if not acted and known.conflict_serial > baseline_serial and known.conflict_report in ["holding","resisted","reinforced"]:
					if action == "reinforce_after_pressure":
						verify(root.set_trail_target(route.id,known.desired_workers+4).accepted and copy.set_trail_workers(route.id,known.desired_workers+4),"Returned pressure permits real follow-up higher target")
						acted = true
					elif action == "withdraw_after_pressure":
						verify(root.set_trail_target(route.id,0).accepted and copy.set_trail_workers(route.id,0),"Returned pressure permits physical withdrawal")
						acted = true
			verify(game.run.to_dict() == copy.run.to_dict(),"Exact mixed conflict/return continuation")
			verify(game.run.rival.workers.invariant_holds() and game.run.colony.piles.home.workers.invariant_holds(),"Both ledgers conserve")
			verify(game.run.rival.reinforcement.mobilizations <= 3,"Reserve recruitment stays finite")
			if action == "avoid": verify(game.run.swarm.serial == baseline_serial,"Avoidance cannot re-engage")
			rows.append({"seed":seed_value,"action":action,"followup_issued":acted,"duration":500,"reports":reports,"returned_losses":route.reported_rival_losses-before_losses,"delivered":route.delivered_total-before_cargo,"desired":route.desired_workers,"allocated":route.allocated_workers,"latest":route.conflict_report,"alarm":root.trail_summaries("home")[0].journey_alarm,"encounters":game.run.swarm.serial-baseline_serial,"rival_mobilizations":game.run.rival.reinforcement.mobilizations})
			root.free()
	var file := FileAccess.open("res://.godot/card123_counterplay.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"trials":rows,"failures":failures},"\t",true,true)); file.close()
	print("[CONFLICT-COUNTERPLAY] ordinary trials=",rows.size()," failures=",failures)
	quit(1 if failures else 0)
