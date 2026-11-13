extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const View=preload("res://src/presentation/outward/outward_view.gd")
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))

func fixture() -> SimulationController:
	var game:=Controller.new(80,"roadside")
	game.dispatch_scout("home",0)
	for tick: int in 3000:
		if game.run.knowledge.nodes.has("known:carb_exposed"):break
		game.advance(0.25)
	assert(game.run.knowledge.nodes.has("known:carb_exposed"))
	game.advance(maxf(0,600-game.run.simulation_time))
	assert(game.create_trail("home","known:carb_exposed"))
	return game

func run(test: Object) -> bool:
	var zone:=ResidueZoneState.new();zone.enabled=true
	test.check(not zone.contains(zone.CONFIG.position,zone.CONFIG.first_tick-1) and zone.contains(zone.CONFIG.position,zone.CONFIG.first_tick) and not zone.active(zone.CONFIG.first_tick+zone.CONFIG.duration_ticks),"Ground exposure uses actual bounded interval with exact endpoints")
	test.check(not zone.contains(Vector2.ZERO,zone.CONFIG.first_tick) and zone.contains(zone.CONFIG.position+Vector2(zone.CONFIG.radius,0),zone.CONFIG.first_tick),"Only actual footprint contact captures material")
	test.check(ResidueZoneState.contaminated(4,2)==2.5 and ResidueZoneState.contaminated(0,0)==0,"Original and ground residue combine once within real carbohydrate mass")
	var game:=fixture();var root:=Root.new();root.simulation=game
	var route: TrailRouteState=game.run.trails.routes.route_1
	for tick: int in 1000:
		if game.run.trails.cohorts.values().any(func(c: TransitCohort)->bool:return c.residue_contact.active()):break
		game.advance(0.25)
	var coated: TransitCohort=game.run.trails.cohorts.values().filter(func(c: TransitCohort)->bool:return c.residue_contact.active())[0]
	test.check(coated.direction=="outbound" and coated.payload==0 and coated.contaminant_mass==0,"Outbound ants can capture a ground contact before carrying food")
	test.check(route.residue_report.is_empty() and game.run.colony.piles.home.food_toxicity.mass==0 and not JSON.stringify(root.sensory_snapshot("home")).contains("residue"),"Private contact neither contaminates home nor publishes a ground cue")
	var private_contact: Dictionary=snapshot(game);var twin:=Controller.new()
	test.check(twin.restore_snapshot(private_contact) and twin.run.to_dict()==game.run.to_dict(),"Private outbound contact saves exactly")
	while coated.direction=="outbound":game.advance(0.25)
	test.check(coated.payload>0 and coated.contaminant_mass>0 and coated.contaminant_mass<=coated.payload,"Real harvest carries bounded residue from the already coated party")
	var initial_mass: float=coated.contaminant_mass;game.advance(0.25)
	test.check(coated.contaminant_mass==initial_mass,"Repeated ticks in or near the zone do not multiply the same contact dose")
	var inbound: Dictionary=snapshot(game)
	test.check(twin.restore_snapshot(inbound),"Actual inbound residue/carbohydrate restores")
	game.set_trail_workers("route_1",0)
	while route.allocated_workers>0:game.advance(0.25)
	test.check(not route.residue_report.is_empty() and game.run.colony.piles.home.food_toxicity.mass>0 and route.delivered_total>0,"Recall retains physical cargo and surviving return delivers its historical cue")
	var status: Dictionary=root.outward_status("home");var known_route: Dictionary=root.trail_summaries("home")[0]
	test.check(known_route.surface_warning and known_route.warning_kind=="residue" and not JSON.stringify(status).contains("contaminant_mass") and not status.has("residue"),"Normal controls receive only dated strange ground, without chemistry or timetable")
	var popover:=ConflictPopover.new();test.check(popover._identity(known_route,status)=="Strange ground residue" and popover.reason("conflict_send",known_route,status)!="" and popover.reason("conflict_survey",known_route,status)=="","Returned ground supports investigation/avoidance and refuses a fighting force")
	var unchanged: Dictionary=game.run.to_dict()
	test.check(not game.journey_response.defend("route_1") and not game.journey_response.set_goal("route_1","hunt") and game.run.to_dict()==unchanged,"Unassailable residue cannot spend ants on Clear/Hunt")
	test.check(game.journey_response.investigate("route_1"),"A paid ground survey can be sent from the delivered cue")
	while game.run.journey_response.active():game.advance(0.25)
	test.check(game.run.journey_response.reports.route_1.finding=="residue" and twin.restore_snapshot(snapshot(game)),"Actual recheck witnesses strange residue and restores its returned report")
	test.check(game.journey_response.investigate_approach("route_1"),"Another approach funds real cautious travel")
	while game.run.journey_response.active():game.advance(0.25)
	test.check(game.run.journey_response.approach.reports.route_1.outcome=="danger" and route.foreign_reports>0 and twin.restore_snapshot(snapshot(game)),"A bypass can discover foreign traffic instead; surviving contacts remain owned through a rejected approach")
	var mass: float=game.run.colony.piles.home.food_toxicity.mass
	game.advance(400)
	test.check(game.run.colony.piles.home.food_toxicity.mass<mass and route.allocated_workers==0 and game.run.colony.piles.home.workers.invariant_holds(),"Stopped intake permits gradual real chemistry recovery and conserves labor")
	var journal_found: bool=false
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind=="ground":journal_found=ReportCopy.title(entry,root.outward_status("home")).contains("Strange residue")
	test.check(journal_found,"Retained Reports preserves the observed ground cue")
	for speed: int in [1,4,16,64]:
		var paced:=Controller.new();var reference:=Controller.new();paced.restore_snapshot(inbound);reference.restore_snapshot(inbound)
		paced.set_time_scale(speed);paced.advance(50.0/speed);paced.set_time_scale(1);reference.advance(50)
		test.check(paced.run.to_dict()==reference.run.to_dict(),"Captured dose/return follows fixed ticks at "+str(speed))
	game.toggle_pause();unchanged=game.run.to_dict();game.advance(100)
	test.check(game.run.to_dict()==unchanged,"Pause freezes footprint, cargo and local recovery")
	game.toggle_pause()
	test.check(game.dispatch_scout("home",PI),"Recall/avoidance leaves actual local labor for a safer-food search")
	for tick: int in 1200:
		if game.run.knowledge.nodes.has("known:carb_sheltered"):break
		game.advance(0.25)
	test.check(game.run.knowledge.nodes.has("known:carb_sheltered") and game.create_trail("home","known:carb_sheltered"),"A physical returned scout supports the sheltered food alternative")
	game.advance(100)
	var alternative: TrailRouteState=game.run.trails.routes.route_2
	test.check(alternative.delivered_total>0 and alternative.residue_report.is_empty() and route.allocated_workers==0,"Safer-course gathering delivers food without adopting the old residue cue")
	for field: String in ["disabled","future","outside","missing_dose","forged_report"]:
		var invalid: Dictionary=inbound.duplicate(true)
		match field:
			"disabled":invalid.residue.enabled=false
			"future":invalid.trails.cohorts[0].residue_contact.observed_tick=99999
			"outside":invalid.trails.cohorts[0].residue_contact.position=[0,0]
			"missing_dose":invalid.trails.cohorts[0].contaminant_mass=0
			"forged_report":invalid.trails.routes[0].residue_report={"observed_at":1,"received_at":2,"estimated_position":[26,20]}
		unchanged=twin.run.to_dict()
		test.check(not twin.restore_snapshot(invalid) and twin.run.to_dict()==unchanged,"Malformed ground/contact/receipt rejects atomically: "+field)
	var old:=Controller.new(80,"roadside");var legacy: Dictionary=snapshot(old);legacy.erase("residue")
	test.check(twin.restore_snapshot(legacy) and not twin.run.residue.enabled,"Old physical worlds gain no residue zone")
	var view:=View.new();test.get_root().add_child(view);root._outward_view=view
	view.status_provider=root.focused_outward_status;view.signal_provider=root.focused_outward_signals;view.journey_command=root.respond_to_journey
	view._process(0);view.selected_id="threat:route_1"
	for pointer: String in ["mouse","touch"]:
		view.conflict.reset();view._pointer_press(view._conflict_rect("conflict_reports").get_center(),pointer)
		test.check(view.conflict.history_open,"Ground history opens through shared "+pointer+" controls")
	view.free();root.free();return true
