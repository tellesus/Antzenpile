extends RefCounted
const Fixture=preload("res://tests/test_reproduction.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func snapshot(game: SimulationController) -> Dictionary: return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func run(test: Object) -> bool:
	var gallery: SimulationController=Fixture.new().fixture();var baseline: SimulationController=Fixture.new().fixture()
	gallery.order_chamber("home","ventilation_gallery");gallery.advance(90);baseline.advance(90)
	var improved: PileState=gallery.run.colony.piles.home;var standard: PileState=baseline.run.colony.piles.home
	test.check(improved.chambers.complete("ventilation_gallery") and improved.workers.to_dict()==standard.workers.to_dict() and improved.resources.carbohydrate==standard.resources.carbohydrate-24,"Gallery requires paid construction and releases builders without creating operating staff")
	for pile: PileState in [improved,standard]: pile.temperature.temperature=36000;pile.humidity.moisture=900000;pile.resources.water=100
	var improved_used: int=improved.temperature.water_used_units;var standard_used: int=standard.temperature.water_used_units
	gallery.advance(50);baseline.advance(50)
	test.check(improved.temperature.temperature<standard.temperature.temperature and improved.humidity.moisture<standard.humidity.moisture and improved.humidity.carers==standard.humidity.carers,"Equal climate staffing regulates hot/damp conditions more effectively with Gallery")
	test.check(improved.temperature.water_used_units-improved_used==standard.temperature.water_used_units-standard_used and improved.resources.water<100,"Additional regulation uses actual water, with no duplicated operating debit")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(gallery)),"Completed Gallery and local regulation restore")
	gallery.advance(16);twin.advance(16)
	test.check(gallery.run.to_dict()==twin.run.to_dict(),"Staffed Gallery continues exactly after a save")
	gallery.set_humidity_workers("home",0);baseline.set_humidity_workers("home",0)
	for pile: PileState in [improved,standard]: pile.temperature.temperature=36000;pile.humidity.moisture=300000;pile.resources.water=100
	gallery.advance(1);baseline.advance(1)
	test.check(improved.temperature.temperature==standard.temperature.temperature and improved.humidity.moisture==standard.humidity.moisture,"Unstaffed Gallery supplies no passive weather immunity")
	gallery.set_humidity_workers("home",1);baseline.set_humidity_workers("home",1)
	for pile: PileState in [improved,standard]: pile.temperature.temperature=36000;pile.humidity.moisture=300000;pile.resources.water=0
	gallery.advance(1);baseline.advance(1)
	test.check(improved.temperature.temperature==standard.temperature.temperature and improved.humidity.moisture==standard.humidity.moisture and improved.resources.water==0,"Gallery cannot invent water for cooling or humidifying")
	var expected: Dictionary={}
	var saved: Dictionary=snapshot(gallery)
	for scale: int in [1,4,16,64]:
		var game:=Controller.new();game.restore_snapshot(saved);game.set_time_scale(scale);game.advance(16.0/scale);game.set_time_scale(1)
		if expected.is_empty(): expected=game.run.to_dict()
		test.check(game.run.to_dict()==expected,"Gallery regulation has identical fixed-tick results at %dx" % scale)
	_check_effort(test)
	var game: SimulationController=preload("res://tests/test_daughter_gathering.gd").new().fixture()
	game.set_exploration(6,"satellite_1")
	var root:=Root.new();root.simulation=game
	var before: Dictionary=game.run.to_dict()
	test.check(not root.set_effort("exploration",3).accepted and game.run.to_dict()==before,"Whole exploration still respects the other pile's shared-cap reservation")
	test.check(root.set_effort("exploration",2).accepted and game.run.exploration.target==2,"Remaining two shared standing slots can be committed by Home")
	root.free()
	return true
func _check_effort(test: Object) -> void:
	var game: SimulationController=Fixture.new().fixture();var root:=Root.new();root.simulation=game
	var inward:=InwardView.new();test.get_root().add_child(inward);inward.status_provider=root.focused_inward_status;inward.effort_command=root.set_effort;inward.selected_id="nursery";inward._process(0)
	var before: Dictionary=game.run.to_dict()
	inward.activate_at(inward._effort_link_rect().get_center())
	test.check(inward.effort_draft.opened and game.run.to_dict()==before,"Staffing inspection/editing does not allocate workers or water")
	inward.effort_draft.amount=3
	var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=inward.effort_draft.rect(inward.get_viewport_rect().size,"effort_commit").get_center();inward._unhandled_input(touch);inward._process(0)
	test.check(game.run.colony.piles.home.humidity.carers==3 and not inward.effort_draft.opened,"Touch assigns a three-carer target absent from the quick presets")
	inward.selected_id="midden";inward.activate_at(inward._effort_link_rect().get_center());inward.effort_draft.amount=6
	var mouse:=InputEventMouseButton.new();mouse.pressed=true;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=touch.position;inward._unhandled_input(mouse);inward._process(0)
	test.check(game.run.colony.piles.home.midden.cleaners==6,"Mouse assigns six cleanup workers through the care-protected owner")
	before=game.run.to_dict()
	for request: Array in [["climate",5],["cleanup",9],["exploration",9],["unknown",1],["climate",1.5]]:
		test.check(not root.set_effort(request[0],request[1]).accepted and game.run.to_dict()==before,"Invalid effort rejects atomically")
	var outward:=OutwardView.new();test.get_root().add_child(outward);outward._signals=root.sensory_snapshot("home");outward._status=root.outward_status("home");outward.exploration_open=true;outward.effort_command=root.set_effort
	outward._pointer_press(outward._exploration_rect("exploration_edit").get_center(),"mouse")
	test.check(outward.effort_draft.opened and game.run.to_dict()==before,"Whole standing effort starts as free attention")
	outward.effort_draft.amount=3;outward._pointer_press(outward.effort_draft.rect(outward.get_viewport_rect().size,"effort_commit").get_center(),"touch")
	test.check(game.run.exploration.target==3 and game.scouting.standing_count()==0,"Setting three standing scouts creates intent rather than instant dispatch")
	game.advance(0.25)
	test.check(game.scouting.standing_count()==1,"The existing owner dispatches real individual scouts using normal spacing")
	for size: Vector2 in [Vector2(1280,720),Vector2(900,600)]:
		var box: Rect2=inward.effort_draft.panel(size)
		test.check(box.end.y<=size.y-112,"Effort draft fits above time controls")
		for action: String in ["effort_less","effort_more","effort_suggest","effort_zero","effort_max","effort_commit","effort_back"]:
			var target: Rect2=inward.effort_draft.rect(size,action)
			test.check(box.encloses(target) and target.size.x>=44 and target.size.y>=44,"Effort "+action+" is enclosed and touch-sized")
	inward.free();outward.free();root.free()
