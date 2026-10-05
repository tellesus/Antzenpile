extends RefCounted
const Controller = preload("res://src/core/simulation_controller.gd")
const Root = preload("res://src/core/game_root.gd")
const Senses = preload("res://src/sim/scouting/scout_senses.gd")
const Config = preload("res://data/scouting/default_scouts.tres")
const Memory = preload("res://src/presentation/outward/source_memory.gd")
const Perception = preload("res://src/presentation/perception_model.gd")
const View = preload("res://src/presentation/outward/outward_view.gd")

func sample(game: SimulationController, id: int, at: Vector2, time: float) -> Observation:
	var agent := ScoutAgent.new(); agent.id="scout_%d" % id; agent.origin_pile="home"; agent.position=at
	Senses.sample(agent,game.run.world,Config,game.run.rng,time)
	return agent.observations["carb_sheltered"].detached_copy()

func archive(knowledge: KnowledgeBase, evidence: Observation, time: float) -> bool:
	var inbox: Dictionary[String,Observation]={evidence.id:evidence}
	return knowledge.consume(inbox,time)

func snapshot(game: SimulationController) -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true))

func run(test: Object) -> bool:
	var game := Controller.new(482817)
	var knowledge := KnowledgeBase.new()
	var broad: Observation=sample(game,1,Vector2(14,20),1)
	test.check(broad.source_type.is_empty() and not broad.proximity_confirmed and archive(knowledge,broad,2),"Broad sensing reports a nutrient cue without identifying its physical producer")
	var label: int=knowledge.nodes["known:carb_sheltered"].label_index
	var signal_data: Dictionary=Perception.new().project(knowledge.nodes.values(),Vector2(20,20),2)[0].to_dict()
	test.check(signal_data.source_type.is_empty() and Memory.display_name(signal_data)=="Sweet trace A","Unidentified sources use stable plain colony labels instead of hidden kind/hash names")
	var close: Observation=sample(game,2,Vector2(10,20),3)
	test.check(close.source_type=="flower_nectar" and knowledge.nodes["known:carb_sheltered"].source_type.is_empty(),"A close unreturned sample cannot update the colony's identity")
	test.check(archive(knowledge,close,4) and knowledge.nodes["known:carb_sheltered"].source_type=="flower_nectar","A returning close sample identifies flower nectar")
	broad=sample(game,3,Vector2(14,20),5)
	test.check(archive(knowledge,broad,6) and knowledge.nodes["known:carb_sheltered"].source_type=="flower_nectar" and knowledge.nodes["known:carb_sheltered"].label_index==label,"A newer broad report changes location confidence without erasing established identity/label")
	var old_name: String=Memory.display_name(Perception.new().project(knowledge.nodes.values(),Vector2(20,20),6)[0].to_dict())
	game.run.world.nodes.carb_sheltered.quantity=0; game.run.world.nodes.carb_sheltered.active=false
	test.check(Memory.display_name(Perception.new().project(knowledge.nodes.values(),Vector2(20,20),6)[0].to_dict())==old_name,"Hidden depletion cannot change remembered type or name")
	test.check(SourceCatalog.label(1)=="A" and SourceCatalog.label(26)=="Z" and SourceCatalog.label(27)=="AA","Colony labels continue deterministically beyond one alphabet")
	_check_harvest(test)
	return true

func _check_harvest(test: Object) -> void:
	var game := Controller.new(482817); game.advance(0.25)
	var broad: Observation=sample(game,1,Vector2(11.25,20),game.run.simulation_time)
	assert(archive(game.run.knowledge,broad,game.run.simulation_time)); game.run.next_scout_id=2
	test.check(broad.source_type.is_empty() and game.create_trail("home","known:carb_sheltered"),"A partial but actionable memory starts real ordinary gathering")
	var captured: bool=false
	for i: int in 240:
		game.advance(0.25)
		for cohort: TransitCohort in game.run.trails.cohorts.values():
			if cohort.harvest_report != null:
				captured=true; break
		if captured: break
	test.check(captured and game.run.knowledge.nodes["known:carb_sheltered"].source_type.is_empty(),"Food sampling stays private throughout actual inbound travel")
	var twin := Controller.new()
	test.check(twin.restore_snapshot(snapshot(game)),"Inbound captured food identity restores with its owning route/worker commitment")
	for i: int in 240:
		game.advance(0.25); twin.advance(0.25)
		if i%25==0: test.check(game.run.to_dict()==twin.run.to_dict(),"Saved food samples and real return continue exactly")
		if not game.run.knowledge.nodes["known:carb_sheltered"].source_type.is_empty(): break
	test.check(game.run.knowledge.nodes["known:carb_sheltered"].source_type=="flower_nectar" and game.run.colony.piles.home.workers.invariant_holds(),"The carried sample identifies nectar only after workers actually return")
	var root := Root.new(); root.simulation=game
	var entries: Array[Dictionary]=Memory.entries(root.sensory_snapshot("home"),root.outward_status("home"),"carbohydrate")
	test.check(entries.size()>0 and Memory.display_name(entries[0]).begins_with("Flower nectar "),"The source browser receives the same approved concrete identity")
	var view := View.new(); test.get_root().add_child(view)
	view.signal_provider=root.sensory_snapshot.bind("home"); view.status_provider=root.outward_status.bind("home"); view._process(0)
	var before: Dictionary=game.run.to_dict()
	view._pointer_press(view._button_rect("sources").get_center(),"touch")
	test.check(view.activation.expires_at>Time.get_ticks_msec() and game.run.to_dict()==before,"A neutral control activation cue does not dispatch workers or mutate the run")
	var saved: Dictionary=snapshot(game)
	for gate: String in ["type","knowledge","label","fraction"]:
		var broken: Dictionary=saved.duplicate(true)
		match gate:
			"type":
				for node: Dictionary in broken.world.nodes:
					if node.id=="carb_sheltered": node.source_type="rain_puddle"
			"knowledge": broken.knowledge.nodes[0].source_type="aphid_honeydew"
			"label": broken.knowledge.nodes[0].label_index=0
			"fraction": broken.knowledge.nodes[0].label_index=1.5
		var frozen: Dictionary=twin.run.to_dict()
		test.check(not twin.restore_snapshot(broken) and twin.run.to_dict()==frozen,"Malformed source identity/label "+gate+" rejects atomically")
	var legacy: Dictionary=saved.duplicate(true)
	legacy.erase("reports")
	for node: Dictionary in legacy.world.nodes: node.erase("source_type")
	for node: Dictionary in legacy.knowledge.nodes: node.erase("source_type"); node.erase("label_index")
	for record: Dictionary in legacy.knowledge.observations: record.evidence.erase("source_type")
	for evidence: Dictionary in legacy.delivered_observations: evidence.erase("source_type")
	for cohort: Dictionary in legacy.trails.cohorts: cohort.erase("harvest_report")
	test.check(twin.restore_snapshot(legacy) and twin.run.knowledge.nodes["known:carb_sheltered"].source_type.is_empty() and twin.run.world.nodes.carb_sheltered.source_type.is_empty(),"Old generic saved worlds and reports stay generic rather than gaining invented identity")
	view.free(); root.free()
