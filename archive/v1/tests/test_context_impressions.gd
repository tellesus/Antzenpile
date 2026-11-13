extends RefCounted
const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")
const Root = preload("res://src/core/game_root.gd")
const Nest = preload("res://tests/test_nest_sites.gd")
const Impact = preload("res://tests/test_surface_disturbance.gd")
const Rival = preload("res://tests/test_rival_counterplay.gd")

func sample(identity: String) -> Dictionary:
	var signal_data: Dictionary={"category":"threat","confidence":0.9,"strength":0.7,"age":5.0}
	if identity.begins_with("site_"):
		signal_data.category="nest_site";signal_data.site_profile=identity.trim_prefix("site_")
	elif identity=="foreign_ants":signal_data.threat_kind="foreign"
	else:signal_data.threat_kind="surface";signal_data.passage_impression=identity
	return signal_data

func foreign_game() -> SimulationController:
	var game: SimulationController=Rival.new().ready_game()
	assert(game.set_trail_workers("route_1",0))
	while game.run.trails.routes.route_1.allocated_workers>0:game.advance(0.25)
	assert(game.journey_response.investigate("route_1"))
	return game

func run(test: Object) -> bool:
	for identity: String in Cloud.CONTEXT_ACCENTS:
		var signal_data: Dictionary=sample(identity)
		var before: Dictionary=signal_data.duplicate(true)
		var fresh: Dictionary=Cloud.appearance(signal_data,false)
		test.check(fresh.identity==identity and fresh.recognition>0.99 and Cloud.MASKS.has(identity),"Supported returned context chooses its authored form: "+identity)
		test.check(fresh.impression_tint==Cloud.CONTEXT_ACCENTS[identity],"Context carries its luminous accent: "+identity)
		test.check(Cloud.appearance(signal_data,true).identity.is_empty() and Cloud.appearance(signal_data,true).level==0,"Empty context cannot look renewed: "+identity)
		signal_data.confidence=0.2
		test.check(Cloud.appearance(signal_data,false).identity.is_empty(),"Weak context remains abstract: "+identity)
		signal_data.confidence=0.9;signal_data.age=1800.0
		test.check(Cloud.appearance(signal_data,false).identity.is_empty(),"Old context cannot appear freshly identified: "+identity)
		signal_data=before.duplicate(true);signal_data.category="protein"
		test.check(Cloud.appearance(signal_data,false).identity.is_empty(),"Wrong category cannot borrow an animal/shelter form: "+identity)
		Cloud.appearance(before,false)
		test.check(before==sample(identity),"Context styling leaves detached evidence unchanged: "+identity)
	test.check(Cloud.appearance({"category":"nest_site","confidence":1.0},false).identity.is_empty(),"An untyped shelter cannot acquire a guessed structure")
	test.check(Cloud.appearance({"category":"threat","threat_kind":"surface","predator_profile":"wolf_spider","confidence":1.0},false).identity.is_empty(),"A generic impact cannot borrow a predator or guessed mammal")
	var view:=OutwardView.new()
	test.check(view._threat_caption(sample("foreign_ants"))=="Foreign ant scent memory","A returned foreign-ant cue is not mislabeled as an ambush")
	view.free()
	_sites(test);_passages(test);_foreign(test)
	return true

func _sites(test: Object) -> void:
	for profile: String in SiteCatalog.DEFINITIONS:
		var game: SimulationController=Nest.new().fixture()
		game.run.world.nodes.nest_site_01.site_profile=profile
		var root:=Root.new();root.simulation=game
		var private_seen: bool=false
		for tick: int in 1200:
			game.advance(0.25)
			if game.run.scouts.is_empty():break
			if game.run.scouts.scout_1.observations.has("nest_site_01"):
				private_seen=true
				test.check(root.sensory_snapshot("home").is_empty(),"Private shelter sampling has no visible form")
		var signals: Array[Dictionary]=root.sensory_snapshot("home")
		test.check(private_seen and signals.size()==1 and Cloud.appearance(signals[0],false).identity=="site_"+profile,"Actual surviving scout resolves returned shelter: "+profile)
		game.run.world.nodes.nest_site_01.site_profile="edge" if profile!="edge" else "root"
		game.run.world.nodes.nest_site_01.active=false
		test.check(root.sensory_snapshot("home")==signals,"Hidden shelter changes cannot alter its remembered art")
		root.free()

func _passages(test: Object) -> void:
	var game: SimulationController=Impact.new().fixture()
	var root:=Root.new();root.simulation=game
	var route: TrailRouteState=game.run.trails.routes.route_1
	for tick: int in 800:
		if route.passage_memory.count>0:break
		game.advance(0.25)
	var signals: Array[Dictionary]=root.sensory_snapshot("home")
	var first: Array[Dictionary]=signals.filter(func(s):return s.category=="threat")
	test.check(first.size()==1 and Cloud.appearance(first[0],false).identity=="large_animal","One actual returned passage resolves only a coarse large-animal form")
	game.set_trail_workers("route_1",0)
	while route.allocated_workers>0:game.advance(0.25)
	var second: float=(SurfaceImpactState.first_tick(game.run.run_seed)+SurfaceImpactState.CONFIG.interval_ticks)*SimulationClock.TICK_INTERVAL
	game.advance(maxf(0,second-game.run.simulation_time))
	assert(game.journey_response.investigate("route_1"))
	var private_seen: bool=false
	for tick: int in 800:
		if not game.run.journey_response.active():break
		game.advance(0.25)
		if game.run.journey_response.passage_witness.active():
			private_seen=true
			for signal_data: Dictionary in root.sensory_snapshot("home"):
				test.check(Cloud.appearance(signal_data,false).identity!="dog_like","A privately carried second passage cannot reveal the dog-like form")
	var returned: Array[Dictionary]=root.sensory_snapshot("home").filter(func(s):return s.category=="threat")
	test.check(private_seen and route.passage_memory.count==2 and returned.size()==1 and Cloud.appearance(returned[0],false).identity=="dog_like","The second distinct actual return resolves the supported dog-like form")
	var remembered: Array[Dictionary]=root.sensory_snapshot("home")
	game.run.surface_impact.serial+=1
	test.check(root.sensory_snapshot("home")==remembered,"An unreported new physical passage cannot refresh remembered anatomy")
	root.free()

func _foreign(test: Object) -> void:
	var game:=foreign_game();var root:=Root.new();root.simulation=game
	var private_seen: bool=false
	for tick: int in 1200:
		if not game.run.journey_response.active():break
		game.advance(0.25)
		if game.run.journey_response.foreign_seen:
			private_seen=true
			for signal_data: Dictionary in root.sensory_snapshot("home"):
				test.check(Cloud.appearance(signal_data,false).identity!="foreign_ants","A foreign sighting remains private until the survey returns")
	var signals: Array[Dictionary]=root.sensory_snapshot("home")
	var threats: Array[Dictionary]=signals.filter(func(s):return s.category=="threat")
	test.check(private_seen and game.run.journey_response.reports.route_1.finding=="foreign" and threats.size()==1 and Cloud.appearance(threats[0],false).identity=="foreign_ants","An actual returned foreign sighting gains a luminous ant impression")
	var segment: TrailSegmentState=game.run.trails.segments[game.run.trails.routes.route_1.segment_id]
	test.check(threats[0].uncertainty_radius>=segment.start.distance_to(segment.end)*0.5,"A foreign report without a captured position remains uncertain over the whole known course")
	game.run.rival.pheromone=0.0;game.run.rival.direction="inbound"
	test.check(root.sensory_snapshot("home")==signals,"Private rival motion/chemistry cannot refresh returned anatomy or position")
	root.free()
