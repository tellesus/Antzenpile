extends RefCounted
const Impact=preload("res://tests/test_surface_disturbance.gd")
const Controller=preload("res://src/core/simulation_controller.gd")
const Root=preload("res://src/core/game_root.gd")
func snapshot(game: SimulationController) -> Dictionary:return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))

func run(test: Object) -> bool:
	var game: SimulationController=Impact.new().fixture()
	var root:=Root.new();root.simulation=game
	var route: TrailRouteState=game.run.trails.routes.route_1
	test.check(game.run.surface_impact.profile_id=="dog_passage" and route.passage_memory.count==0,"Fresh Roadside authors a passage archetype without initial colony recognition")
	for tick: int in 400:
		if game.run.trails.cohorts.values().any(func(c: TransitCohort)->bool:return c.passage_witness.active()):break
		game.advance(0.25)
	test.check(game.run.trails.cohorts.values().any(func(c: TransitCohort)->bool:return c.passage_witness.active()) and route.passage_memory.count==0,"Actual close footprint/odor evidence remains privately carried")
	test.check(not JSON.stringify(root.sensory_snapshot("home")).contains("large_animal") and not JSON.stringify(root.sensory_snapshot("home")).contains("dog_like"),"Private or unexplained impacts reveal no animal identity")
	var private_save: Dictionary=snapshot(game);var twin:=Controller.new()
	test.check(twin.restore_snapshot(private_save) and twin.run.to_dict()==game.run.to_dict(),"Private supported passage evidence restores exactly")
	for tick: int in 400:
		if route.passage_memory.count>0:break
		game.advance(0.25);twin.advance(0.25)
	test.check(game.run.to_dict()==twin.run.to_dict() and route.passage_memory.impression()=="large_animal","Only a real surviving return establishes large-animal evidence")
	game.set_trail_workers("route_1",0)
	while route.allocated_workers>0:game.advance(0.25)
	test.check(route.passage_memory.count==1,"Several witnesses of the same passage cannot upgrade recognition")
	var known: Dictionary=root.trail_summaries("home")[0]
	var popover:=ConflictPopover.new()
	test.check(popover._identity(known,root.outward_status("home"))=="Large animal passage" and popover.reason("conflict_send",known,root.outward_status("home"))!="","A supported large-animal trace offers avoidance, not a fighting force")
	var second: float=(SurfaceImpactState.first_tick(game.run.run_seed)+SurfaceImpactState.CONFIG.interval_ticks)*SimulationClock.TICK_INTERVAL
	game.advance(maxf(0,second-game.run.simulation_time))
	test.check(game.run.surface_impact.serial>=2 and route.passage_memory.count==1 and popover._identity(root.trail_summaries("home")[0],root.outward_status("home"))=="Large animal passage","An unseen new passage and elapsed time do not identify a dog")
	test.check(game.journey_response.investigate("route_1"),"The player funds a real new passage recheck")
	for tick: int in 400:
		if game.run.journey_response.passage_witness.active():break
		game.advance(0.25)
	test.check(game.run.journey_response.passage_witness.serial==2 and route.passage_memory.count==1,"New close survey captures a distinct physical passage privately")
	test.check(twin.restore_snapshot(snapshot(game)),"Private cautious passage survey restores")
	while game.run.journey_response.active():game.advance(0.25)
	test.check(route.passage_memory.count==2 and route.passage_memory.impression()=="dog_like" and popover._identity(root.trail_summaries("home")[0],root.outward_status("home"))=="Dog-like passage","Two actually returned distinct passages support the finer impression")
	test.check(twin.restore_snapshot(snapshot(game)),"Delivered recognition and dated history restore")
	var records: Array[String]=[]
	for entry: Dictionary in game.run.reports.entries:
		if entry.kind=="passage":records.append(entry.detail)
	test.check("large_animal" in records and "dog_like" in records,"Reports retains the original coarse and later supported impressions")
	var before: Dictionary=game.run.to_dict()
	test.check(not game.journey_response.commit_force("route_1","hunt",24) and game.run.to_dict()==before,"A dog-like interpretation still cannot fund inappropriate hunting")
	for speed: int in [1,4,16,64]:
		var paced:=Controller.new();var reference:=Controller.new();paced.restore_snapshot(private_save);reference.restore_snapshot(private_save)
		paced.set_time_scale(speed);paced.advance(40.0/speed);paced.set_time_scale(1);reference.advance(40)
		test.check(paced.run.to_dict()==reference.run.to_dict(),"Witness/recognition follows fixed ticks at "+str(speed))
	game.toggle_pause();before=game.run.to_dict();game.advance(100)
	test.check(game.run.to_dict()==before,"Pause freezes physical passages and knowledge delivery")
	var delivered: Dictionary=snapshot(game)
	for field: String in ["generic","count","serial","position","receipt","profile"]:
		var invalid: Dictionary=delivered.duplicate(true)
		match field:
			"generic":invalid.surface_impact.profile_id=""
			"count":invalid.trails.routes[0].passage_memory.count=3
			"serial":invalid.trails.routes[0].passage_memory.serial=99999
			"position":invalid.trails.routes[0].passage_memory.estimate=[0,0]
			"receipt":invalid.trails.routes[0].passage_memory.received_at=99999
			"profile":invalid.surface_impact.profile_id="unwitnessed_monster"
		before=twin.run.to_dict()
		test.check(not twin.restore_snapshot(invalid) and twin.run.to_dict()==before,"Malformed/unsupported passage rejects atomically: "+field)
	var old: SimulationController=Impact.new().fixture();var legacy: Dictionary=snapshot(old);legacy.surface_impact.erase("profile_id")
	test.check(twin.restore_snapshot(legacy) and twin.run.surface_impact.profile_id=="","Old generic worlds do not gain dog identity")
	twin.advance(100)
	test.check(twin.run.trails.routes.route_1.passage_memory.count==0,"Real returns in a generic old world remain generic")
	var lost: SimulationController=Impact.new().returned()
	var lost_route: TrailRouteState=lost.run.trails.routes.route_1
	for tick: int in 200:
		if lost_route.passage_memory.count>0:break
		lost.advance(0.25)
	lost.set_trail_workers("route_1",0)
	while lost_route.allocated_workers>0:lost.advance(0.25)
	var later: float=(SurfaceImpactState.first_tick(lost.run.run_seed)+SurfaceImpactState.CONFIG.interval_ticks)*SimulationClock.TICK_INTERVAL
	lost.advance(maxf(0,later-5-lost.run.simulation_time));lost.set_trail_workers("route_1",1);lost.advance(5)
	test.check(lost.run.trails.cohorts.values().any(func(c: TransitCohort)->bool:return c.worker_count==0 and c.passage_witness.active()) and twin.restore_snapshot(snapshot(lost)),"An actual last-worker impact can lose its privately captured witness without a ghost reporter")
	lost.advance(50)
	test.check(lost_route.passage_memory.count==1,"A lost second-passage witness cannot upgrade colony recognition")
	root.free();return true
