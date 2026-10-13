extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Queen=preload("res://tests/test_queen_continuity.gd")
const Relocation=preload("res://tests/test_queen_relocation.gd")
const Connections=preload("res://tests/test_connection_transport.gd")
const Missing=preload("res://tests/test_scout_survival.gd")
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func status(game: SimulationController, focus: String="home") -> Dictionary:return RunContinuity.snapshot(game.run,focus)
func run(test: Object) -> bool:
	_paths(test);_journeys(test);_private_loss(test);_accomplishment(test);_interface(test)
	return true
func _paths(test: Object) -> void:
	var game:=Controller.new();var pile: PileState=game.run.colony.piles.home
	test.check(status(game).phase=="viable" and not RunContinuity.failed(game.run),"A local mother and living labor offer supported continuity")
	assert(pile.workers.create_commitment("test:busy","internal","home"));assert(pile.allocate_workers("test:busy",pile.workers_assignable))
	test.check(status(game).phase=="viable" and status(game).piles[0].free==0,"All assignable ants working elsewhere is a labor stall, not extinction")
	game=Queen.new().lost_game()
	test.check(status(game).phase=="queenless" and not game.run.history.ended,"An actual paid ready group survives local mother loss without ending the run")
	game=preload("res://tests/test_reproduction.gd").new().fixture()
	assert(game.queue_reproduction("home",true));game.queens.injure("home",1000000)
	test.check(status(game).phase=="unrecoverable" and not game.run.history.ended,"An unpaid reproductive wish is not a living young queen; failure never forces reveal")
	game=Controller.new();pile=game.run.colony.piles.home
	assert(pile.lose_workers("available",40,0,"Fixture no remaining local adults"))
	pile.brood_cohorts[0].stage="pupa"
	test.check(status(game).phase=="unrecoverable" and pile.nursery_care_capacity()==0,"Pupae without any actual carers or returning labor cannot magically emerge")
	game=Connections.new().fixture()
	for link: ConnectionTrafficState in game.run.all_connections():assert(game.connection_order(link.route_id,link.parent_id,"close").accepted)
	game.queens.injure("home",1000000)
	var known: Dictionary=status(game,"satellite_1")
	test.check(known.phase=="viable" and known.piles[1].isolated,"A viable closed daughter preserves the lineage after Home loses its mother")
	test.check(not known.piles[0].has("workers_expected") and not known.piles[0].has("queen"),"Other nests require local inspection rather than leaking their live body counts")
func _journeys(test: Object) -> void:
	var game: SimulationController=Relocation.new().fixture()
	var link: ConnectionTrafficState=game.run.all_connections()[0]
	assert(game.connection_order(link.route_id,"satellite_1","relocate_queen",8).accepted)
	var source: Dictionary=status(game,"satellite_1")
	test.check(source.phase=="viable" and source.pending,"A real traveling mother remains supported through its sending commitment")
	for tick: int in 1000:
		game.advance(0.25)
		if link.queens.satellite_1.movement.phase=="returning":break
	var after: Dictionary=status(game,"satellite_1")
	test.check(after.phase==source.phase and after.pending and not after.piles[0].has("queen") and not after.piles[1].queen,"Private mother landing does not reveal arrival in the sending nest's status")
	test.check(status(game,"home").piles[0].queen,"The actual receiving nest can observe its own local mother")
	var copy:=Controller.new();test.check(copy.restore_snapshot(snapshot(game)),"Pending mother receipt and continuity restore exactly")
	while link.queens.satellite_1.active():game.advance(0.25);copy.advance(0.25)
	test.check(game.run.to_dict()==copy.run.to_dict() and status(game).phase=="viable","Actual mother settlement preserves saved continuity")
	game=preload("res://tests/test_royal_rescue.gd").new().fixture()
	link=game.run.all_connections()[0]
	assert(game.connection_order(link.route_id,"satellite_1","rescue_royals",8).accepted)
	for pile: PileState in game.run.colony.piles.values():game.queens.injure(pile.id,1000000)
	test.check(status(game).phase=="queenless" and status(game).pending,"Actual paid reproductive custody counts across the whole network")
	game=preload("res://tests/test_brood_rescue.gd").new().fixture()
	link=game.run.all_connections()[0]
	var uid: String=game.run.colony.piles.satellite_1.brood_cohorts[0].uid("satellite_1")
	assert(game.connection_order(link.route_id,"satellite_1","rescue_brood",8,uid).accepted)
	test.check(status(game).phase=="viable" and status(game).pending,"Real brood/carrier rescue cannot create a false labor extinction")
	game=preload("res://tests/test_founding.gd").new().fixture()
	assert(game.start_founding("known:nest_site_01"));game.queens.injure("home",1000000)
	test.check(status(game).phase=="queenless" and status(game).pending,"A paid real founding group remains a reproductive continuation after Home mother loss")
	game=preload("res://tests/test_final_departure.gd").new().fixture()
	link=game.run.all_connections()[0]
	assert(game.connection_order(link.route_id,"home","final_departure").accepted)
	test.check(status(game).phase=="viable" and status(game).pending,"A relinquished source and whole-workforce journey do not extinguish its living daughter")
func _private_loss(test: Object) -> void:
	var game: SimulationController=Missing.fixture()
	var pile: PileState=game.run.colony.piles.home
	assert(pile.lose_workers("available",pile.workers_available,0,"Fixture only scout remains"))
	var before: Dictionary=status(game)
	Missing.until_loss(game)
	var after: Dictionary=status(game)
	test.check(before==after and after.phase=="viable" and pile.workers_total==0,"The last scout's private casualty cannot change normal expected continuity")
	var copy:=Controller.new();test.check(copy.restore_snapshot(snapshot(game)),"Unresolved final labor saves without early extinction notification")
	var expected: int=game.run.scouts.scout_1.expected_tick
	while game.run.clock.tick_count<=expected:game.advance(0.25);copy.advance(0.25)
	test.check(status(game).phase=="unrecoverable" and game.run.to_dict()==copy.run.to_dict(),"Existing absence settlement confirms genuine labor failure, with exact continuation")
	test.check(game.run.reports.entries.any(func(entry: Dictionary)->bool:return entry.kind=="continuity") and not game.run.history.ended,"Confirmed failure produces an inspectable local notice; review remains voluntary")
func accomplished() -> SimulationController:
	var game: SimulationController=Queen.new().lost_game()
	assert(game.replace_queen("home"));game.advance(120)
	for id: String in PileState.RESOURCE_IDS:game.run.colony.piles.home.deposit_resource(id,100)
	assert(game.start_brood("home"))
	for tick: int in 3000:
		game.advance(0.25)
		if game.run.accomplishment.generation>0:break
	return game
func _accomplishment(test: Object) -> void:
	var game: SimulationController=accomplished();var receipt: Dictionary=game.run.accomplishment.to_dict()
	test.check(receipt.generation==1 and receipt.count>0 and receipt.count+game.run.colony.piles.home.brood_lost_total==8 and receipt.parent_id==game.run.colony.piles.home.queen.queen_id("home") and receipt.tick==game.run.clock.tick_count,"Actual surviving successor offspring emergence earns a dated biological accomplishment")
	test.check(game.run.reports.entries.any(func(entry: Dictionary)->bool:return entry.kind=="lineage") and not game.run.history.ended,"A later generation is announced without stopping play or revealing hidden reality")
	var saved: Dictionary=snapshot(game);var copy:=Controller.new()
	test.check(copy.restore_snapshot(saved) and copy.run.to_dict()==game.run.to_dict(),"Highest-generation receipt and its local report save exactly")
	var old: Dictionary=saved.duplicate(true);old.erase("accomplishment")
	old.reports.records=old.reports.records.filter(func(record: String)->bool:return JSON.parse_string(record).kind!="lineage")
	test.check(copy.restore_snapshot(old) and copy.run.accomplishment.generation==0,"Old worlds do not gain a fabricated retrospective accomplishment")
	for field: String in ["generation","tick","parent","pile","count","report"]:
		var bad: Dictionary=saved.duplicate(true)
		match field:
			"generation":bad.accomplishment.generation=2
			"tick":bad.accomplishment.tick+=1
			"parent":bad.accomplishment.parent_id="queen:invented:founder"
			"pile":bad.accomplishment.pile_id="absent"
			"count":bad.accomplishment.count=9
			"report":
				for index: int in bad.reports.records.size():
					var entry: Dictionary=JSON.parse_string(bad.reports.records[index])
					if entry.kind=="lineage":entry.amount=99;bad.reports.records[index]=JSON.stringify(entry,"",true,true)
		var fresh:=Controller.new();var before: Dictionary=fresh.run.to_dict()
		test.check(not fresh.restore_snapshot(bad) and fresh.run.to_dict()==before,"Corrupt accomplishment rejects atomically: "+field)
	game.toggle_pause();var paused: Dictionary=game.run.to_dict();game.advance(20)
	test.check(game.run.to_dict()==paused,"Pause cannot create another lineage receipt")
	for speed: int in [1,4,16,64]:
		var twin:=Controller.new();assert(twin.restore_snapshot(saved));twin.set_time_scale(speed);twin.advance(20.0/speed);twin.set_time_scale(1)
		var ordinary:=Controller.new();assert(ordinary.restore_snapshot(saved));ordinary.advance(20)
		test.check(twin.run.to_dict()==ordinary.run.to_dict(),"Accomplishment continuation matches speed "+str(speed))
func _interface(test: Object) -> void:
	var root:=Root.new();root.simulation=accomplished()
	var panel:=preload("res://src/presentation/colony_controls.gd").new();test.get_root().add_child(panel)
	root._colony_controls=panel;panel.status_provider=root.colony_status;panel.end_command=root.end_run_review
	panel.opened=true
	var before: Dictionary=root.simulation.run.to_dict()
	test.check(panel.activate_at(panel.choice_rect("guide").get_center()) and panel.status_open and root.simulation.run.to_dict()==before,"Free colony status inspection issues no order or irreversible reveal")
	for method: String in ["mouse","touch"]:
		var event: InputEvent=InputEventMouseButton.new() if method=="mouse" else InputEventScreenTouch.new()
		event.pressed=true;event.position=panel.choice_rect("cancel").get_center()
		if method=="mouse":event.button_index=MOUSE_BUTTON_LEFT
		panel._input(event)
		test.check(not panel.opened and root.simulation.run.to_dict()==before,method+" keeps playing through the shared status path")
		panel.opened=true;panel.status_open=true
	var id: int=0
	for entry: Dictionary in root.simulation.run.reports.entries:
		if entry.kind=="lineage":id=entry.id
	test.check(root.inspect_report(id).accepted and panel.status_open,"The dated accomplishment report opens free colony status")
	test.check(panel.activate_at(panel.choice_rect("end").get_center()) and panel.confirm_end and not root.simulation.run.history.ended,"Status review access first requires the existing explicit confirmation")
	test.check(panel.activate_at(panel.choice_rect("repeat").get_center()) and root.simulation.run.history.ended and root.simulation.run.clock.paused,"Explicit confirmed review ends and pauses the actual run")
	var review: Dictionary=root.simulation.review_snapshot();root.simulation.advance(20)
	test.check(not review.is_empty() and review.accomplishment.generation==1 and not root.simulation.start_brood("home") and root.simulation.review_snapshot()==review,"Physical reveal retains accomplishment and cannot drive or resume ordinary play")
	panel.free();root.free()
