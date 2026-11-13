extends RefCounted
const Fixture=preload("res://tests/test_reproduction.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func ready_game() -> SimulationController:
	var game: SimulationController=Fixture.new().fixture();assert(game.start_reproduction("home"));game.advance(780)
	assert(game.run.colony.piles.home.reproduction.phase=="ready")
	return game
func lost_game() -> SimulationController:
	var game: SimulationController=ready_game();var pile: PileState=game.run.colony.piles.home
	pile.resources.protein=0;pile.queen.condition=100;game.advance(0.25)
	pile.deposit_resource("protein",100)
	return game

func run(test: Object) -> bool:
	_check_condition(test);_check_paid_continuation(test);_check_replacement(test);_check_saves(test);_check_ui(test)
	return true

func _check_condition(test: Object) -> void:
	var game: SimulationController=Fixture.new().fixture();var pile: PileState=game.run.colony.piles.home
	var resources: Dictionary=pile.resources.duplicate();game.queens.tick()
	test.check(pile.queen.condition==1000000 and pile.resources==resources,"Healthy supported queen keeps baseline nutrition behavior")
	pile.resources.protein=0;game.advance(501)
	test.check(pile.queen.condition<800000 and pile.queen_count==1,"Actual unsupported nutrition produces a local warning before death")
	var root:=Root.new();root.simulation=game
	test.check(ColonyPressure.needs(root.inward_status("home"))[0].title=="CHECK QUEEN CONTINUITY","Weak queen is an actionable local need")
	var report: Dictionary={}
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind=="queen" and entry.detail=="weakened":report=entry
	test.check(not report.is_empty() and root.inspect_report(report.id).accepted,"Queen warning is retained and inspectable without a route lookup")
	test.check(game.set_queen_care("home",2) and pile.workers.count("queen_care:home")==2,"Recovery care reserves actual workers")
	var condition: int=pile.queen.condition;game.advance(0.25)
	test.check(pile.queen.condition<condition,"Carers cannot recover without food")
	pile.deposit_resource("protein",100);resources=pile.resources.duplicate();condition=pile.queen.condition
	for tick: int in 4: game.queens.tick()
	test.check(pile.queen.condition==condition+2000 and is_equal_approx(resources.carbohydrate-pile.resources.carbohydrate,0.002) and is_equal_approx(resources.protein-pile.resources.protein,0.0008) and is_equal_approx(resources.water-pile.resources.water,0.002),"Actual paid care restores condition with all three nutrient debits")
	pile.temperature.temperature=35000;condition=pile.queen.condition;game.advance(0.25)
	test.check(pile.queen.condition<condition,"Queen carers cannot cancel severe heat; climate regulation remains necessary")
	test.check(game.set_queen_care("home",0) and pile.workers.count("queen_care:home")==-1,"Stopping care returns the real workers once")
	resources=game.run.to_dict();test.check(not game.set_queen_care("home",3) and game.run.to_dict()==resources,"Invalid care target rejects atomically")
	var held: SimulationController=Fixture.new().fixture();var p: PileState=held.run.colony.piles.home
	held.start_brood("home");held.start_brood("home");p.workers.create_commitment("test:busy","internal","home");p.allocate_workers("test:busy",p.workers_assignable)
	resources=held.run.to_dict()
	test.check(not held.set_queen_care("home",1) and held.run.to_dict()==resources,"Queen care cannot steal the Nursery's last actual carers")
	root.free()

func _check_paid_continuation(test: Object) -> void:
	var game: SimulationController=Fixture.new().fixture();var pile: PileState=game.run.colony.piles.home
	game.start_reproduction("home");game.start_brood("home");game.queue_adaptation("home","lean");game.queue_reproduction("home",true);game.set_queen_care("home",1)
	pile.resources.protein=0;pile.queen.condition=100;var workers: int=pile.workers_total;game.advance(0.25)
	test.check(pile.queen_count==0 and pile.workers_total==workers and pile.brood_cohorts.size()==1 and pile.reproduction.phase=="egg","Queen death conserves workers and already-funded brood")
	test.check(pile.queued_adaptation=="" and pile.investments.priority.is_empty() and not game.run.history.ended,"Death clears unpaid intent without falsely ending a recoverable run")
	test.check(pile.queen.carers==0 and pile.workers.count("queen_care:home")==-1,"Local death releases the former queen's actual carer once")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Queenless paid worker/reproductive brood remains a valid saved recovery path")
	pile.deposit_resource("protein",100);twin.run.colony.piles.home.deposit_resource("protein",100)
	game.advance(780);twin.advance(780)
	test.check(game.run.to_dict()==twin.run.to_dict() and pile.reproduction.phase=="ready" and pile.brood_matured_total==40,"Paid brood progresses to real workers/reproductives after the laying queen dies")
	test.check(not game.start_brood("home") and not game.queue_reproduction("home",true),"A queenless pile cannot create new unpaid laying")

func _check_replacement(test: Object) -> void:
	var game: SimulationController=ready_game();var pile: PileState=game.run.colony.piles.home
	var before: Dictionary=game.run.to_dict()
	test.check(not game.replace_queen("home") and game.run.to_dict()==before,"A living laying queen cannot be gratuitously retired into replacement")
	game=lost_game();pile=game.run.colony.piles.home
	var group: Dictionary=pile.reproduction.to_dict();var stores: Dictionary=pile.resources.duplicate();var workers: int=pile.workers_available
	test.check(game.replace_queen("home") and pile.queen.replacing() and pile.reproduction.phase=="none","Ready reproductive ownership transfers once into paid local establishment")
	test.check(pile.workers_available==workers-2 and pile.resources.carbohydrate==stores.carbohydrate-8 and pile.resources.protein==stores.protein-6 and pile.resources.water==stores.water-4,"Replacement pays once and reserves two real nurses")
	before=game.run.to_dict();test.check(not game.replace_queen("home") and game.run.to_dict()==before,"Duplicate establishment cannot copy a young queen or debit again")
	game.advance(60);stores=pile.resources.duplicate()
	test.check(game.replace_queen("home",true) and pile.reproduction.to_dict()==group and pile.resources==stores and pile.workers_available==workers,"Cancellation physically returns the unused group and nurses without food refund")
	test.check(game.replace_queen("home"),"Returned group can fund another real establishment")
	var saved: Dictionary=snapshot(game);var twin:=Controller.new();test.check(twin.restore_snapshot(saved),"Paid replacement group restores with its exclusive commitment")
	game.advance(120);twin.advance(120)
	test.check(game.run.to_dict()==twin.run.to_dict() and pile.queen_count==1 and pile.queen.generation==1 and pile.queen.condition==1000000 and pile.reproduction.phase=="none" and not pile.queen.replacing(),"One completed funded group becomes one fertile local successor with exact continuation")
	test.check(pile.queen.parent_identity!="" and pile.queen.queen_id("home")!=pile.queen.parent_identity and pile.workers_available==workers,"Succession records identity and releases support without worker birth")
	test.check(game.start_brood("home"),"The established successor resumes actual laying")
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();copy.restore_snapshot(saved);copy.set_time_scale(scale);copy.advance(32.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Paid succession progresses identically at %dx" % scale)
	var pause:=Controller.new();pause.restore_snapshot(saved);pause.toggle_pause();before=pause.run.to_dict();pause.advance(10)
	test.check(pause.run.to_dict()==before,"Paused succession spends no time or resources")

func _check_saves(test: Object) -> void:
	var game: SimulationController=lost_game();game.replace_queen("home");game.advance(1)
	var saved: Dictionary=snapshot(game);var twin:=Controller.new();twin.restore_snapshot(saved)
	for mode: String in ["count","condition","pool","group","progress","future","identity"]:
		var broken: Dictionary=saved.duplicate(true);var pile: Dictionary=broken.colony.piles[0]
		match mode:
			"count":pile.queen.count=1
			"condition":pile.queen.condition=1000001
			"pool":pile.workers.commitments["queen_replacement:home"].count=1
			"group":pile.reproduction=pile.queen.replacement_group.duplicate(true)
			"progress":pile.queen.replacement_progress=480
			"future":pile.queen.replacement_started=2147483647
			"identity":pile.queen.identity="not_a_queen"
		var before: Dictionary=twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==before,"Malformed queen "+mode+" rejects atomically")
	var legacy: SimulationController=Fixture.new().fixture();var old: Dictionary=snapshot(legacy)
	old.colony.piles[0].erase("queen")
	test.check(twin.restore_snapshot(old) and twin.run.colony.piles.home.queen_count==1,"Legacy count acquires a supported queen with no backfilled damage")
	legacy.advance(10);twin.advance(10)
	test.check(legacy.run.to_dict()==twin.run.to_dict(),"Legacy queen migration preserves continuation and resource behavior")

func _check_ui(test: Object) -> void:
	var root:=Root.new();root.simulation=lost_game()
	var view:=InwardView.new();test.get_root().add_child(view);view.status_provider=root.focused_inward_status;view.queen_replacement_command=root.replace_queen;view.queen_care_command=root.set_queen_care;view.selected_id="queen";view._process(0)
	var before: Dictionary=root.simulation.run.to_dict()
	test.check(view.activate_at(view._queen_tab_rect("continuity").get_center()) and view.queen_tab=="continuity" and root.simulation.run.to_dict()==before,"Queen continuity inspection is free and separate from brood/reproduction")
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=view._queen_replace_rect().get_center();view._unhandled_input(touch);view._process(0)
	test.check(root.simulation.run.colony.piles.home.queen.replacing(),"Touch establishes only the inspected real replacement group")
	view.free();root.free()
