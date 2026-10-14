extends RefCounted
const Fixture=preload("res://tests/test_reproduction.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func snapshot(game: SimulationController) -> Dictionary: return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func run(test: Object) -> bool:
	var game: SimulationController=Fixture.new().fixture()
	var pile: PileState=game.run.colony.piles.home
	game.set_brood_intent("home","grow")
	var before: Dictionary=game.run.to_dict();var stores: Dictionary=pile.resources.duplicate();var ledger: Dictionary=pile.workers.to_dict()
	test.check(game.queue_reproduction("home") and pile.resources==stores and pile.workers.to_dict()==ledger and pile.nursery_occupied_space()==0 and str(game.run.rng.state)==before.rng_state,"Reproductive queue under Auto Brood spends no ants, food, space or RNG")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Queued reproductive intent restores before funding")
	game.advance(0.25);twin.advance(0.25)
	test.check(pile.reproduction.phase=="egg" and pile.brood_intent=="grow" and pile.brood_cohorts.is_empty() and not pile.investments.reproduction and game.run.to_dict()==twin.run.to_dict(),"Eligible reproduction takes the next opportunity ahead of Auto Brood exactly once")
	test.check(pile.resources.carbohydrate==stores.carbohydrate-12 and pile.workers.count("reproduction:home")==4,"Actual laying pays once and reserves its existing four nurses")
	test.check(twin.restore_snapshot(snapshot(game)) and twin.run.to_dict()==game.run.to_dict(),"The first funded tick restores exactly without claiming eggs older than their laying date")
	game.advance(0.25)
	test.check(pile.brood_cohorts.size()==1 and pile.brood_intent=="grow","Ordinary automatic growth resumes into remaining supported space")
	var paid: Dictionary=pile.reproduction.to_dict();ledger=pile.workers.to_dict();stores=pile.resources.duplicate()
	test.check(game.queue_reproduction("home") and game.queue_reproduction("home",false) and pile.reproduction.to_dict()==paid and pile.workers.to_dict()==ledger and pile.resources==stores,"Canceling follow-up intent cannot erase or refund the already paid group")
	for first: String in ["adaptation","reproduction"]:
		game=Fixture.new().fixture();pile=game.run.colony.piles.home
		game.queue_adaptation("home","lean");game.queue_reproduction("home")
		test.check(pile.investments.first()=="adaptation","Earlier queued intent is the default priority")
		if first=="reproduction": game.prioritize_investment("home","reproduction")
		twin=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Simultaneous priority restores without spending")
		game.advance(0.25);twin.advance(0.25)
		test.check(game.run.to_dict()==twin.run.to_dict() and (pile.trial_cohort()!=null if first=="adaptation" else pile.reproduction.phase=="egg"),"The chosen first investment owns the actual laying opportunity")
		game.advance(0.25);twin.advance(0.25)
		test.check(pile.trial_cohort()!=null and pile.reproduction.phase=="egg" and pile.investments.priority.is_empty() and game.run.to_dict()==twin.run.to_dict(),"Separate opportunities fund both groups without eviction, duplication or lost priority")
	game=Fixture.new().fixture();pile=game.run.colony.piles.home
	game.start_brood("home");game.start_brood("home");game.set_brood_intent("home","grow");game.queue_reproduction("home")
	stores=pile.resources.duplicate();game.advance(0.25)
	test.check(pile.investments.reproduction and pile.reproduction.phase=="none" and pile.brood_cohorts.size()==2 and pile.resources.protein==stores.protein and pile.workers.count("reproduction:home")==-1 and game.investments.summary("home").reproduction_wait.contains("spaces"),"Full Nursery preserves both paid groups and explains the reproductive space wait")
	game=Controller.new();pile=game.run.colony.piles.home
	for resource: String in PileState.RESOURCE_IDS: pile.deposit_resource(resource,500)
	game.queue_reproduction("home");game.set_brood_intent("home","grow");game.advance(360.25)
	test.check(pile.brood_matured_total>=8 and not pile.brood_cohorts.is_empty() and pile.investments.reproduction and pile.reproduction.phase=="none","Early structurally ineligible reproduction permits ordinary growth toward maturity")
	game=preload("res://tests/test_adaptation_queue.gd").new().funded();pile=game.run.colony.piles.home
	game.queue_reproduction("home");game.queue_adaptation("home","load");game.advance(0.25)
	test.check(pile.trial_cohort()!=null and pile.investments.reproduction and pile.investments.first()=="reproduction","Structurally ineligible first intent allows a later eligible investment without discarding its priority")
	game=Fixture.new().fixture();pile=game.run.colony.piles.home;pile.resources.protein=0
	game.queue_reproduction("home");game.set_brood_intent("home","grow");ledger=pile.workers.to_dict();game.advance(1)
	test.check(pile.reproduction.phase=="none" and pile.brood_cohorts.is_empty() and pile.workers.to_dict()==ledger and game.investments.summary("home").reproduction_wait.contains("protein"),"Eligible but underfunded reproduction keeps its opportunity rather than consuming it with automatic brood")
	pile.deposit_resource("protein",100);game.advance(0.25)
	test.check(pile.reproduction.phase=="egg" and pile.brood_intent=="grow","Real returned/deposited food permits paid reproductive laying with Auto still on")
	test.check(game.run.reports.entries.any(func(entry: Dictionary) -> bool: return entry.kind=="investment" and entry.detail=="reproduction_laid"),"Paid reproductive laying has a retained local semantic report")
	var saved: Dictionary=snapshot(game)
	for invalid: Dictionary in [{"reproduction":1,"priority":[]},{"reproduction":false,"priority":["reproduction"]},{"reproduction":true,"priority":["reproduction","reproduction"]},{"reproduction":false,"priority":["unknown"]},{"reproduction":true,"priority":[]}]:
		var broken: Dictionary=saved.duplicate(true);broken.colony.piles[0].investments=invalid;before=twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==before,"Malformed queue membership/count rejects atomically")
	game=Fixture.new().fixture();game.queue_adaptation("home","lean");saved=snapshot(game);saved.colony.piles[0].erase("investments")
	test.check(twin.restore_snapshot(saved) and twin.run.colony.piles.home.investments.priority==["adaptation"] and not twin.run.colony.piles.home.investments.reproduction,"Old adaptation queues migrate to their existing priority without invented reproduction")
	before=game.run.to_dict()
	for invalid: Variant in [1,"true",null,[]]: test.check(not game.queue_reproduction("home",invalid) and game.run.to_dict()==before,"Invalid reproductive intent rejects without spending or reordering")
	test.check(not game.prioritize_investment("home","reproduction") and not game.queue_reproduction("missing") and game.run.to_dict()==before,"Unknown or unqueued investments cannot steal priority")
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		game=Fixture.new().fixture();game.set_brood_intent("home","grow");game.queue_reproduction("home");game.set_time_scale(scale);game.advance(16.0/scale);game.set_time_scale(1)
		if expected.is_empty(): expected=game.run.to_dict()
		test.check(game.run.to_dict()==expected,"Queued reproductive scheduling is identical at %dx" % scale)
	_check_input(test)
	return true
func _check_input(test: Object) -> void:
	var game: SimulationController=Fixture.new().fixture();var root:=Root.new();root.simulation=game
	var view:=InwardView.new();test.get_root().add_child(view);view.selected_id="queen";view.queen_tab="reproduction"
	view.status_provider=root.focused_inward_status;view.reproduction_command=root.toggle_reproductive_queue;view.investment_priority_command=root.prioritize_investment
	view._process(0);var paid: Dictionary=game.run.colony.piles.home.reproduction.to_dict()
	for pointer: String in ["mouse","touch"]:
		var at: Vector2=view._reproduction_rect().get_center()
		if pointer=="mouse":
			var event:=InputEventMouseButton.new();event.pressed=true;event.button_index=MOUSE_BUTTON_LEFT;event.position=at;view._unhandled_input(event)
		else:
			var event:=InputEventScreenTouch.new();event.pressed=true;event.position=at;view._unhandled_input(event)
		view._process(0)
		test.check(game.run.colony.piles.home.investments.reproduction==(pointer=="mouse") and game.run.colony.piles.home.reproduction.to_dict()==paid,"Queen "+pointer+" toggles only free reproductive intent")
	game.queue_reproduction("home");game.queue_adaptation("home","lean");view._process(0)
	view.activate_at(view._priority_rect("reproduction").get_center());view._process(0)
	test.check(game.run.colony.piles.home.investments.first()=="reproduction","Queen priority action deliberately reorders simultaneous intent")
	view.selected_id="adaptation";view.web_selection="lean";view.activate_at(view._priority_rect("adaptation").get_center())
	test.check(game.run.colony.piles.home.investments.first()=="adaptation","Adaptation priority action can choose the other pending investment")
	var original: Vector2i=test.get_root().size;var scale: Vector2i=test.get_root().content_scale_size;test.get_root().content_scale_size=Vector2i.ZERO
	for size: Vector2i in [Vector2i(1280,720),Vector2i(900,600)]:
		test.get_root().size=size
		var box: Rect2=Rect2(size.x-316,144,292,340)
		test.check(box.encloses(view._reproduction_rect()) and box.encloses(view._priority_rect("reproduction")) and box.end.y<=size.y-112,"Reproductive queue and priority fit above time controls at "+str(size))
	test.get_root().size=original;test.get_root().content_scale_size=scale
	view.free();root.free()
