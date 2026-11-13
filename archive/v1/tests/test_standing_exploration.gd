extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")
const Snapshot = preload("res://tests/test_guest.gd")


func run(test: Object) -> bool:
	var game := Controller.new(6060)
	var pile: PileState = game.run.colony.piles.home
	for invalid: Variant in [-1, 9, 2.5, "5", true]:
		var before: Dictionary = game.run.to_dict()
		test.check(not game.set_exploration(invalid) and game.run.to_dict() == before, "Invalid standing target rejects atomically")
	var before: Dictionary = game.run.to_dict()
	test.check(not game.set_exploration_bias(NAN) and game.run.to_dict() == before, "Invalid exploration bearing rejects atomically")
	test.check(game.set_exploration(5) and game.set_exploration_bias(-PI / 4), "Set a standing five-scout target and explicit bearing")
	game.advance(0.25)
	test.check(game.scouting.standing_count() == 1 and pile.workers_available == 39 and game.run.knowledge.nodes.is_empty(), "First pulse commits one real worker with no immediate discovery")
	game.advance(6)
	test.check(game.scouting.standing_count() == 4 and pile.workers_available == 36, "Departures are staggered rather than an instantaneous wave")
	var copy := Controller.new()
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)), "Standing policy, departure cooldown and partial travel restore")
	game.advance(0.5)
	copy.advance(0.5)
	test.check(game.run.to_dict() == copy.run.to_dict(), "Standing continuation is exact before recall")
	var available: int = pile.workers_available
	test.check(game.set_exploration(0) and pile.workers_available == available, "Stopping exploration recalls without instant release")
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)), "Partial-grid-step recall has a valid saved path")
	for tick: int in 300:
		game.advance(0.25)
		copy.advance(0.25)
	test.check(game.scouting.standing_count() == 0 and pile.workers_available == 40 and game.run.to_dict() == copy.run.to_dict(), "Recalled workers arrive and release exactly once")
	game.set_exploration(5)
	game.advance(10)
	var first_id: int = game.run.next_scout_id
	game.advance(420)
	test.check(game.run.next_scout_id > first_id + 5 and game.scouting.standing_count() <= 5 and game.run.active_scout_count() <= 8, "Returned scouts are replaced across bounded search cycles under the shared cap")
	test.check(pile.workers.invariant_holds() and pile.workers_available + game.run.scouts.size() == pile.workers_total, "Continuous scouting conserves available and individually committed adults")
	test.check(copy.restore_snapshot(Snapshot.new().snapshot(game)), "Multiple standing cycles preserve mission/observation history")
	game.toggle_pause()
	before = game.run.to_dict()
	game.advance(20)
	test.check(game.run.to_dict() == before, "Pause freezes scheduler, travel and coverage delivery")
	game.toggle_pause()
	for scale: int in [4,16,64]:
		copy.restore_snapshot(Snapshot.new().snapshot(game))
		copy.set_time_scale(scale)
		copy.advance(64.0 / scale)
		copy.set_time_scale(1)
		game.advance(64)
		test.check(copy.run.to_dict() == game.run.to_dict(), "Standing exploration is identical at %dx" % scale)
	var busy := Controller.new(6061)
	var ledger: WorkerLedger = busy.run.colony.piles.home.workers
	ledger.create_commitment("test:busy", "other", "test")
	ledger.allocate("test:busy", 40)
	busy.set_exploration(5)
	busy.advance(10)
	test.check(busy.run.scouts.is_empty() and busy.run.exploration.target == 5, "Labor shortage preserves intent without creating workers")
	ledger.release("test:busy", 3)
	busy.advance(0.25)
	test.check(busy.run.scouts.size() == 1 and ledger.available == 2, "Freed labor fills an unmet target while retaining existing brood carers")
	var legacy: Dictionary = Snapshot.new().snapshot(Controller.new())
	legacy.erase("exploration")
	test.check(copy.restore_snapshot(legacy) and copy.run.exploration.target == 0, "Old saves retain manual/off exploration until player chooses effort")
	for key: String in ["target", "cooldown_ticks", "bias"]:
		var invalid: Dictionary = Snapshot.new().snapshot(game)
		invalid.exploration[key] = 99
		before = copy.run.to_dict()
		test.check(not copy.restore_snapshot(invalid) and copy.run.to_dict() == before, "Malformed standing policy rejects atomically: " + key)
	var root := Root.new()
	root.simulation = Controller.new()
	var view := View.new()
	test.get_root().add_child(view)
	view.exploration_command = root.set_exploration
	view.exploration_bias_command = root.set_exploration_bias
	view._status = root.outward_status("home")
	view._pointer_press(view._button_rect("scout").get_center(), "touch")
	test.check(view.exploration_open and root.simulation.run.scouts.is_empty(), "Exploration button opens controls without dispatching a unit")
	view._pointer_press(view._exploration_rect("explore_5").get_center(), "mouse")
	view._pointer_press(view._exploration_rect("exploration_bias").get_center(), "touch")
	var bias: float = root.simulation.run.exploration.bias
	view.turn_pixels(200,1280)
	test.check(root.simulation.run.exploration.target == 5 and root.simulation.run.exploration.bias == bias and view.facing != bias, "Mouse/touch set effort and explicit interest; camera rotation does not retarget")
	view.free()
	root.free()
	return true
