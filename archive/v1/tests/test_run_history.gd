extends RefCounted
const Snapshot = preload("res://tests/test_adaptation_queue.gd")
const Parent = preload("res://tests/test_parent_supply.gd")
const Impact = preload("res://tests/test_surface_disturbance.gd")
const Root = preload("res://src/core/game_root.gd")

func run(test: Object) -> bool:
	var game := SimulationController.new(71,"roadside")
	var rng: int = game.run.rng.state; var genes: int = game.run.genetic_rng.state
	test.check(game.review_snapshot().is_empty() and game.run.history.frames.size()==1,"New run records physical reality privately without exposing it")
	game.run.history.record(game.run,true)
	test.check(game.run.rng.state==rng and game.run.genetic_rng.state==genes and game.run.knowledge.nodes.is_empty(),"Recording never consumes gameplay RNG or adds colony knowledge")
	var twin := SimulationController.new()
	test.check(twin.restore_snapshot(Snapshot.new().snapshot(game)),"Initial history JSON restores")
	game.dispatch_scout("home",0); twin.dispatch_scout("home",0)
	game.advance(16); twin.advance(16)
	test.check(game.run.to_dict()==twin.run.to_dict() and game.run.history.frames.size()>1,"Private explorer history preserves exact saved continuation")
	var first: Dictionary = game.run.history.frames[0].duplicate(true)
	game.advance(200)
	test.check(game.run.history.frames[0]==first and game.run.history.events.any(func(e): return e.kind=="findings_returned"),"Original world and later returned findings occupy distinct historical times")
	game.end_run()
	var before: Dictionary = game.run.to_dict()
	test.check(game.run.history.ended and game.run.clock.paused and game.run.history.frames.back().tick==str(game.run.clock.tick_count),"Ending records exact final tick and freezes the run")
	var reveal: Dictionary = game.review_snapshot()
	reveal.history.frames[0].nodes.clear()
	test.check(not game.run.history.frames[0].nodes.is_empty(),"Review projection is detached from authoritative history")
	game.toggle_pause()
	test.check(not game.advance(100) and not game.dispatch_scout("home") and not game.set_time_scale(64) and not game.start_brood("home") and not game.set_exploration(4) and not game.queue_adaptation("home","fighter") and not game.end_run() and game.run.to_dict()==before,"Revealed run rejects gameplay commands, repeat ending and time changes atomically")
	test.check(twin.restore_snapshot(Snapshot.new().snapshot(game)) and twin.run.to_dict()==before and not twin.advance(1),"Ended history persists through saved JSON without restoring play")
	var root := Root.new();root.simulation=game
	test.check(root.sensory_snapshot("home").is_empty() and not root.set_mode("outward") and not root.quick_save().accepted and not root.respond_to_journey("survey","").accepted and not root.relieve_brood_care({}).accepted,"Ended root blocks normal field, save overwrite and direct job callbacks")
	root.free()
	var saved: Dictionary = Snapshot.new().snapshot(game)
	for mode: String in ["future","duplicate","position","shape","event","size","unpaused"]:
		var bad: Dictionary = saved.duplicate(true)
		var frames: Array = bad.history.frames.map(func(value): return JSON.parse_string(value))
		match mode:
			"future":frames[-1].tick=str(game.run.clock.tick_count+1)
			"duplicate":frames[1].tick=frames[0].tick
			"position":frames[0].nodes[0].position=[999,999]
			"shape":frames[0].piles[0].stores=[-1,2,3]
			"event":bad.history.events.append({"tick":"0","kind":"Invented catastrophe","amount":1})
			"size":frames.resize(RunHistory.MAX_FRAMES+1)
			"unpaused":bad.clock.paused=false
		bad.history.frames=frames.map(func(value):return JSON.stringify(value,"",true,true))
		before=twin.run.to_dict()
		test.check(not twin.restore_snapshot(bad) and twin.run.to_dict()==before,"Malformed %s review history rejects without replacing run"%mode)
	test.check(game.start_new_run(3030,"garden_edge") and not game.run.history.ended and game.review_snapshot().is_empty() and game.run.history.frames.size()==1,"New colony discards revealed history and starts private recording")
	game.advance(90)
	saved=Snapshot.new().snapshot(game);saved.erase("history")
	test.check(twin.restore_snapshot(saved) and twin.run.history.frames.size()==1 and twin.run.history.frames[0].tick==str(twin.run.clock.tick_count),"Legacy absent history begins at load, without fabricated past")
	var physical := Impact.new().fixture(71)
	for tick: int in 200:
		if physical.run.surface_impact.kills_total>0: break
		physical.advance(0.25)
	test.check(physical.run.history.frames.back().stats[6]==physical.run.surface_impact.kills_total and physical.run.history.events.any(func(e):return e.kind=="impact_loss") and physical.run.trails.routes.route_1.reported_losses==0 and physical.review_snapshot().is_empty(),"Physical casualty history captures the cause while colony return evidence remains private")
	physical.end_run()
	var slot := SaveService.new("res://.godot/card133-ended-slot.json")
	test.check(slot.save(physical.run) and slot.load_into(twin) and twin.run.history.ended and twin.run.to_dict()==physical.run.to_dict(),"Actual save envelope persists ended physical history without reopening play")
	var capped := RunHistory.new()
	for note: int in RunHistory.MAX_EVENTS+20: capped._event("0","emergence",1)
	test.check(capped.events.size()==RunHistory.MAX_EVENTS and capped.omitted_events==20,"Event cap explicitly counts omitted old notes")
	var daughter := Parent.new().fixture()
	daughter.run.history.record(daughter.run,true)
	daughter.end_run()
	test.check(daughter.review_snapshot().history.frames.back().piles.size()==2 and daughter.review_snapshot().history.frames.back().trails.size()>0,"Review records real two-pile connection and separate physical populations")
	var baseline := SimulationController.new(58)
	var plain := SimulationController.new(58)
	for step: int in 200:
		baseline.advance(1); plain.advance(1)
		plain.run.history=RunHistory.new()
	var recorded: Dictionary = baseline.run.to_dict(); var empty: Dictionary = plain.run.to_dict()
	recorded.erase("history");empty.erase("history")
	test.check(recorded==empty,"Recorder does not alter ordinary simulation outcomes")
	for scale: int in [1,4,16,64]:
		var scaled := SimulationController.new(94);scaled.set_time_scale(scale); scaled.advance(64.0/scale)
		var target := SimulationController.new(94);target.advance(64)
		test.check(scaled.run.history.to_dict()==target.run.history.to_dict(),"History samples are fixed-tick equivalent at %dx"%scale)
	var long_run := SimulationController.new(111)
	for step: int in 240: long_run.advance(60)
	long_run.end_run()
	var history: RunHistory = long_run.run.history
	test.check(history.thinned and history.frames.size()<=RunHistory.MAX_FRAMES and history.events.size()<=RunHistory.MAX_EVENTS and history.frames[0].tick=="0" and history.frames.back().tick==str(long_run.run.clock.tick_count),"Four-hour history stays bounded while retaining start, final and recent samples")
	var payload: String = JSON.stringify(long_run.run.to_dict(),"",true,true)
	var envelope: String = JSON.stringify({"format":SaveService.FORMAT,"file_version":1,"payload":payload,"sha256":payload.sha256_text()},"",true,true)
	test.check(envelope.to_utf8_buffer().size()<SaveService.MAX_FILE_BYTES and twin.restore_snapshot(JSON.parse_string(payload)),"Bounded completed-run JSON fits real save envelope and restores")
	print("[HISTORY] four-hour slot bytes=",envelope.to_utf8_buffer().size()," frames=",history.frames.size()," events=",history.events.size())
	return true
