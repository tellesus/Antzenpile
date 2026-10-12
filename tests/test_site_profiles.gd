extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Founding=preload("res://tests/test_founding.gd")
const Nest=preload("res://tests/test_nest_sites.gd")
const Fixture=preload("res://tests/test_reproduction.gd")
const Root=preload("res://src/core/game_root.gd")
const SITE=Founding.SITE

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func profile_game(profile: String="root", unidentified: bool=false) -> SimulationController:
	var game: SimulationController=Founding.new().fixture();var node: WorldNodeState=game.run.world.nodes.nest_site_01
	node.site_profile=profile
	# Controlled historical evidence before typed identification, or a confirmed report.
	for evidence: Observation in game.run.knowledge.observations.values():
		if evidence.source_node_id==node.id:evidence.site_profile="" if unidentified else profile
	game.run.knowledge._rebuild_node(node.id)
	return game
func settle(game: SimulationController) -> bool:
	for tick: int in 3000:
		game.advance(0.25)
		if game.run.founding.phase=="ready": return true
	return false

func run(test: Object) -> bool:
	_check_return(test);_check_cost_and_settlement(test);_check_unknown(test);_check_climate(test);_check_saves(test);_check_choices(test)
	return true

func _check_return(test: Object) -> void:
	var game: SimulationController=Nest.new().fixture();game.run.world.nodes.nest_site_01.site_profile="stone"
	var root:=Root.new();root.simulation=game
	var saw_private: bool=false
	for tick: int in 1200:
		game.advance(0.25)
		if not game.run.scouts.is_empty():
			var agent: ScoutAgent=game.run.scouts.values()[0]
			if agent.observations.has("nest_site_01") and not agent.observations.nest_site_01.site_profile.is_empty():
				saw_private=true;test.check(root.sensory_snapshot("home").is_empty(),"Confirmed shelter identity stays private before the real scout return")
		else:break
	test.check(saw_private and game.run.knowledge.nodes[SITE].site_profile=="stone","Returned confirmation identifies the authored cavity profile")
	var signals: Array[Dictionary]=root.sensory_snapshot("home")
	test.check(signals[0].site_profile=="stone" and SourceMemory.display_name(signals[0]).begins_with("Under-stone cavity"),"Only approved memory supplies the site name/cues")
	game.run.world.nodes.nest_site_01.active=false
	test.check(root.sensory_snapshot("home")==signals,"Hidden site availability cannot rewrite its remembered profile")
	root.free()

func _check_cost_and_settlement(test: Object) -> void:
	for id: String in SiteCatalog.DEFINITIONS:
		var game: SimulationController=profile_game(id);var pile: PileState=game.run.colony.piles.home
		var endpoint: Vector2=game.run.knowledge.nodes[SITE].estimated_position
		var baseline: Dictionary=game.founding._costs(endpoint)
		var before: float=pile.resources.carbohydrate;var total: int=game.run.colony.workers_total
		test.check(game.start_founding(SITE),"Observed profile funds a real founding party: "+id)
		var state: FoundingState=game.run.founding
		test.check(absf(before-pile.resources.carbohydrate-baseline.carbohydrate-SiteCatalog.get_profile(id).extra_carbohydrate)<0.00001 and state.preparation_ticks==SiteCatalog.get_profile(id).preparation_ticks,"Profile preparation pays once and captures its authored duration: "+id)
		var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Paid typed camp restores: "+id)
		var elapsed: int=2*state.leg_ticks+state.preparation_ticks
		game.advance(elapsed*0.25);twin.advance(elapsed*0.25)
		test.check(state.phase=="ready" and state.reported_tick-state.departed_tick==elapsed and game.run.to_dict()==twin.run.to_dict(),"Real travel/preparation/report duration and saved continuation match: "+id)
		test.check(game.establish_daughter(SITE) and game.run.colony.piles.satellite_1.foundation.site_profile==id and game.run.colony.workers_total==total,"Actual settlement captures the occupied profile and transfers existing workers: "+id)
		test.check(game.run.colony.piles.satellite_1.resources.carbohydrate==6,"Quoted preparation never consumes the separate delivered pack: "+id)

func _check_unknown(test: Object) -> void:
	var game: SimulationController=profile_game("root",true);var pile: PileState=game.run.colony.piles.home
	pile.food_toxicity.mass=3.33333333
	var quoted: Dictionary=game.founding.summary(SITE);var before: float=pile.resources.carbohydrate
	var base: Dictionary=game.founding._costs(game.run.knowledge.nodes[SITE].estimated_position)
	test.check(quoted.site_profile=="" and game.start_founding(SITE) and absf(before-pile.resources.carbohydrate-base.carbohydrate)<0.00001,"Unidentified site has no hidden quote or extra Home debit")
	var state: FoundingState=game.run.founding;game.advance(state.leg_ticks*0.25)
	test.check(state.phase=="settling" and state.site_profile=="root" and state.site_report!=null and game.run.knowledge.nodes[SITE].site_profile=="" and game.founding.summary(SITE).site_profile=="","Physical campers learn the root site without remotely revealing it")
	test.check(state.preparation_from_pack and state.carried_supplies().carbohydrate==4,"Unknown preparation spends only actual carried food")
	var twin:=Controller.new();test.check(twin.restore_snapshot(snapshot(game)),"Private camp observation and reduced pack/dose save exactly")
	game.advance((state.preparation_ticks+state.leg_ticks)*0.25);twin.advance((state.preparation_ticks+state.leg_ticks)*0.25)
	test.check(state.phase=="ready" and game.founding.summary(SITE).site_profile=="root" and game.run.to_dict()==twin.run.to_dict(),"Only the real messenger return exposes the prepared site and remaining pack")
	game.advance(0.25);twin.advance(0.25)
	test.check(game.run.knowledge.nodes[SITE].site_profile=="root" and game.run.to_dict()==twin.run.to_dict(),"Camp report enters historical knowledge through the existing delivery boundary")
	test.check(game.establish_daughter(SITE) and game.run.colony.piles.satellite_1.resources.carbohydrate==4 and game.run.colony.piles.satellite_1.food_toxicity.mass==state.contaminant_mass,"Settlement delivers the reduced physical pack and proportional captured dose once")

func _check_climate(test: Object) -> void:
	var temperatures: Dictionary={};var moisture: Dictionary={}
	for id: String in ["","loam","root","stone","edge"]:
		var game: SimulationController=Fixture.new().fixture();var pile: PileState=game.run.colony.piles.home
		# Isolate existing climate owners with a controlled occupied profile.
		pile.foundation={"site_profile":id};game.set_humidity_workers("home",0)
		var clock: Dictionary=game.run.clock.to_dict();var ticks: int=game.heat.CONFIG.first_tick+game.heat.CONFIG.ramp_ticks
		clock.ticks=str(ticks);clock.time=ticks*SimulationClock.TICK_INTERVAL
		test.check(game.run.clock.restore(clock),"Site climate comparison uses the actual warm-front clock")
		for tick: int in 1200:game.heat.tick()
		temperatures[id]=pile.temperature.temperature
		game.run.rain.phase="raining";var water: float=pile.resources.water
		for tick: int in 1600:game.humidity.tick()
		moisture[id]=pile.humidity.moisture
		test.check(pile.resources.water==water and pile.temperature.larval_rate()<1,"Site shelter grants neither free water nor full hot-brood immunity: "+id)
	test.check(temperatures.stone<temperatures.root and temperatures.root<temperatures.loam and temperatures.loam<temperatures.edge and temperatures.edge==temperatures[""],"Covered sites have a useful bounded heat advantage under the same physical air")
	test.check(moisture.root>moisture.stone and moisture.stone>moisture.loam and moisture.loam==moisture.edge,"Root/stone cover trades against higher actual wet-period moisture pressure")

func _check_saves(test: Object) -> void:
	var game: SimulationController=profile_game("stone");game.start_founding(SITE)
	var saved: Dictionary=snapshot(game);var twin:=Controller.new();twin.restore_snapshot(saved)
	for mode: String in ["profile","time","quote","pack","world","evidence"]:
		var bad: Dictionary=saved.duplicate(true)
		match mode:
			"profile":bad.founding.site_profile="unknown"
			"time":bad.founding.preparation_ticks=480
			"quote":bad.founding.quoted_site_profile="root"
			"pack":bad.founding.preparation_from_pack=true
			"world":bad.world.nodes[0].site_profile="unknown"
			"evidence":bad.knowledge.observations[0].evidence.site_profile="unknown"
		var before: Dictionary=twin.run.to_dict()
		test.check(not twin.restore_snapshot(bad) and twin.run.to_dict()==before,"Malformed site "+mode+" rejects atomically")
	var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		var copy:=Controller.new();copy.restore_snapshot(saved);copy.set_time_scale(scale);copy.advance(16.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Site-funded travel/preparation matches at %dx" % scale)
	var legacy: SimulationController=profile_game("",true);var old: Dictionary=snapshot(legacy)
	for node: Dictionary in old.world.nodes:node.erase("site_profile")
	for record: Dictionary in old.knowledge.observations:record.evidence.erase("site_profile")
	for node: Dictionary in old.knowledge.nodes:node.erase("site_profile")
	for field: String in ["site_profile","preparation_ticks","quoted_site_profile","preparation_from_pack","site_report"]:old.founding.erase(field)
	test.check(twin.restore_snapshot(old) and twin.run.knowledge.nodes[SITE].site_profile=="","Old generic world/memory acquires no fabricated profile")
	legacy.start_founding(SITE);twin.start_founding(SITE);legacy.advance(200);twin.advance(200)
	test.check(legacy.run.to_dict()==twin.run.to_dict(),"Generic legacy camp retains original pack/preparation/climate continuation")

func _check_choices(test: Object) -> void:
	for scenario: String in ScenarioCatalog.IDS:
		var game:=Controller.new(102,scenario);var sites: int=0
		for node: WorldNodeState in game.run.world.nodes.values():
			if node.definition_id=="nest_site":sites+=1;test.check(SiteCatalog.DEFINITIONS.has(node.site_profile),"New scenario authors a real site profile: "+scenario)
		test.check(sites>=2,"Each new setting offers alternative physical nest sites: "+scenario)
	var root:=Root.new();root.simulation=profile_game("stone")
	var view:=OutwardView.new();test.get_root().add_child(view);view._signals=root.sensory_snapshot("home");view._status=root.outward_status("home");view.sources_open=true;view.source_category="nest_site"
	var before: Dictionary=root.simulation.run.to_dict();view._pointer_press(view._source_row_rect(0).get_center(),"touch")
	test.check(view.selected_id==view._signals[0].id and root.simulation.run.to_dict()==before,"Returned site inspection remains a free touch action")
	test.check(SourceMemory.description(view._signals[0])==SiteCatalog.DEFINITIONS.stone.cues and SourceMemory.receipt_label(view._source_entries()[0],root.simulation.run.simulation_time)=="Occupants and safety unknown","Concrete site cues never claim current safety or unseen supplies")
	view.free();root.free()
