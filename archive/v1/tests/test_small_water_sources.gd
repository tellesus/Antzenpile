extends RefCounted
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
const Senses=preload("res://src/sim/scouting/scout_senses.gd")
const CONFIG=preload("res://data/scouting/default_scouts.tres")
const Memory=preload("res://src/presentation/outward/source_memory.gd")
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))
func copy_of(game: SimulationController, test: Object) -> SimulationController:
	var copy:=Controller.new();test.check(copy.restore_snapshot(snapshot(game)),"Small-water physical state restores");return copy
func sample(game: SimulationController, node_id: String, id: int) -> Observation:
	var agent:=ScoutAgent.new();agent.id="scout_%d" % id;agent.origin_pile="home";agent.position=game.run.world.nodes[node_id].position
	Senses.sample(agent,game.run.world,CONFIG,game.run.rng,game.run.simulation_time);return agent.observations[node_id].detached_copy()
func remember(game: SimulationController, node_id: String, id: int=1) -> void:
	var evidence: Observation=sample(game,node_id,id);var inbox: Dictionary[String,Observation]={evidence.id:evidence}
	assert(game.run.knowledge.consume(inbox,game.run.simulation_time));game.run.next_scout_id=maxi(game.run.next_scout_id,id+1)
func run(test: Object) -> bool:
	_profiles(test);_physics(test);_harvest(test);_knowledge(test);_saves(test);return true
func _profiles(test: Object) -> void:
	test.check(SourceCatalog.PROFILES.size()==10 and SourceCatalog.PROFILES.dew_drops is WaterSourceProfile and SourceCatalog.PROFILES.sheltered_seep is WaterSourceProfile,"Ten concrete source profiles include two typed small-water availability entries")
	for scenario: String in ScenarioCatalog.IDS:
		var game:=Controller.new(482817,scenario);var dew: WorldNodeState=game.run.world.nodes.water_dew;var seep: WorldNodeState=game.run.world.nodes.water_seep
		test.check(dew.source_type=="dew_drops" and dew.quantity==2 and seep.source_type=="sheltered_seep" and seep.quantity==4,"Fresh "+scenario+" has real bounded dew and seep instances")
		test.check(game.run.world.home_position.distance_to(dew.position)<game.run.world.home_position.distance_to(seep.position) and TrailSegmentState.exposure_for(game.run.world,game.run.world.home_position,seep.position)<TrailSegmentState.exposure_for(game.run.world,game.run.world.home_position,dew.position),"Nearby exposed droplets and farther sheltered seep form distinct actual approaches")
		test.check(SourceCatalog.nutrients(dew.source_type,"water")=={"water":1.0} and SourceCatalog.nutrients(seep.source_type,"water")=={"water":1.0},"Both water profiles use the existing once-only nutrient store/cargo family")
func _physics(test: Object) -> void:
	var game:=Controller.new();var dew: WorldNodeState=game.run.world.nodes.water_dew;var seep: WorldNodeState=game.run.world.nodes.water_seep
	var water:=WaterSourceSystem.new(game.run);water.tick(10,0)
	test.check(dew.quantity==1.9 and seep.quantity==4.25,"Dry droplets evaporate while the sheltered seep renews slowly")
	dew.quantity=0;dew.active=false;seep.quantity=0;seep.active=false;water.tick(10,10)
	test.check(dew.quantity==0.8 and seep.quantity==0.25 and dew.active and seep.active,"Actual wet production/slow flow reactivate depleted water without editing memory")
	water.tick(1000,1000);test.check(dew.quantity==3 and seep.quantity==8,"Wetness and renewal cannot exceed authored capacities")
	water.tick(400,0);test.check(dew.quantity==0 and not dew.active and seep.quantity==8,"Exposed droplets can vanish while a sheltered source remains bounded")
	game.run.clock._tick_count=HeatSystem.CONFIG.first_tick+HeatSystem.CONFIG.ramp_ticks
	dew.quantity=2;seep.quantity=0;water.tick(10,0)
	test.check(HeatSystem.hot_dry(game.run) and dew.quantity==1.8 and seep.quantity==0.125,"Severe dry pressure speeds droplet loss and halves sheltered seep output")
	# The final rainy interval still wets droplets despite the front becoming finished.
	game=Controller.new();game.run.rain.phase="raining";game.run.rain.elapsed_seconds=RainSystem.CONFIG.duration_seconds-0.25
	var seconds: float=game.rain.tick(0.25);dew=game.run.world.nodes.water_dew;dew.quantity=0
	WaterSourceSystem.new(game.run).tick(0.25,seconds)
	test.check(seconds==0.25 and game.run.rain.phase=="finished" and dew.quantity==0.02,"The actual final rain interval feeds droplets exactly once")
func _harvest(test: Object) -> void:
	for id: String in ["water_dew","water_seep"]:
		var game:=Controller.new();game.advance(0.25);remember(game,id)
		var home: PileState=game.run.colony.piles.home;var before: float=home.resources.water
		assert(game.create_trail(home.id,"known:"+id));var route: TrailRouteState=game.run.trails.find_route(home.id,"known:"+id)
		var captured: bool=false
		for tick: int in 800:
			game.advance(0.25)
			for cohort: TransitCohort in game.run.trails.cohorts.values():
				if cohort.route_id==route.id and cohort.payload>0:captured=true;break
			if captured:break
		test.check(captured and route.delivered_total==0 and home.resources.water==before,"Real "+id+" harvest stays in transit before water intake")
		game.set_trail_workers(route.id,0);var copy: SimulationController=copy_of(game,test)
		game.advance(100);copy.advance(100)
		test.check(game.run.to_dict()==copy.run.to_dict() and route.delivered_total>0 and home.resources.water>=before+route.delivered_total and route.allocated_workers==0,"Captured "+id+" water arrives once and real recalled workers release")
		var delivered: float=route.delivered_total;game.advance(10);test.check(route.delivered_total==delivered,"Stopped small-water gathering neither duplicates cargo nor silently repeats")
func _knowledge(test: Object) -> void:
	var game:=Controller.new();game.advance(0.25);var root:=Root.new();root.simulation=game
	var evidence: Observation=sample(game,"water_dew",1)
	test.check(evidence.source_type=="dew_drops" and root.sensory_snapshot("home").is_empty(),"A private close plant-water sample cannot identify dew at the colony")
	remember(game,"water_dew");var signals: Array[Dictionary]=root.sensory_snapshot("home")
	test.check(signals.any(func(entry: Dictionary)->bool:return entry.source_type=="dew_drops") and Memory.display_name(signals[0]).begins_with("Dew drops "),"Actual returned plant evidence gives a stable dew identity")
	var remembered: Array[Dictionary]=root.sensory_snapshot("home");WaterSourceSystem.new(game.run).tick(400,0)
	test.check(root.sensory_snapshot("home")==remembered,"Hidden evaporation cannot replace remembered water type, direction or availability")
	var known: KnownNode=game.run.knowledge.nodes["known:water_dew"]
	test.check(not known.to_dict().has("quantity") and not known.to_dict().has("renewal_per_second") and not known.to_dict().has("next_refill"),"Approved source knowledge contains no live quantity or renewal timetable")
	root.free()
func _saves(test: Object) -> void:
	var game:=Controller.new();var copy: SimulationController=copy_of(game,test);game.advance(240);copy.advance(240)
	test.check(game.run.to_dict()==copy.run.to_dict() and game.run.world.nodes.water_dew.quantity==0,"Natural evaporation and slow renewal continue exactly through save/load")
	var saved: Dictionary=snapshot(game);var expected: Dictionary={}
	for scale: int in [1,4,16,64]:
		copy=Controller.new();assert(copy.restore_snapshot(saved));copy.set_time_scale(scale);copy.advance(80.0/scale);copy.set_time_scale(1)
		if expected.is_empty():expected=copy.run.to_dict()
		test.check(copy.run.to_dict()==expected,"Small-water lifecycle is equal at %dx" % scale)
	game.toggle_pause();var before: Dictionary=game.run.to_dict();game.advance(100);test.check(before==game.run.to_dict(),"Pause cannot renew or evaporate physical water")
	for mode: String in ["capacity","type","duplicate"]:
		var bad: Dictionary=saved.duplicate(true)
		for node: Dictionary in bad.world.nodes:
			if node.id!="water_dew":continue
			match mode:
				"capacity":node.quantity=3.01
				"type":node.source_type="sheltered_seep";node.definition_id="protein"
				"duplicate":bad.world.nodes.append(node.duplicate(true))
			break
		copy=Controller.new();before=copy.run.to_dict();test.check(not copy.restore_snapshot(bad) and before==copy.run.to_dict(),"Counterfeit small-water "+mode+" rejects atomically")
	var legacy: Dictionary=saved.duplicate(true);legacy.world.nodes=legacy.world.nodes.filter(func(node: Dictionary)->bool:return node.id not in ["water_dew","water_seep"])
	copy=Controller.new();test.check(copy.restore_snapshot(legacy) and not copy.run.world.nodes.has("water_dew") and not copy.run.world.nodes.has("water_seep"),"Old worlds receive no fabricated water objects or labels")
