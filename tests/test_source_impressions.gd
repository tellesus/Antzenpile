extends RefCounted
const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")
const Root = preload("res://src/core/game_root.gd")
const Identity = preload("res://tests/test_resource_identity.gd")

func run(test: Object) -> bool:
	for type: String in SourceCatalog.PROFILES:
		var signal_data: Dictionary={"source_type":type,"category":SourceCatalog.PROFILES[type].resource_id,"confidence":0.9,"strength":0.7,"age":10.0}
		var frozen: Dictionary=signal_data.duplicate(true)
		var fresh: Dictionary=Cloud.appearance(signal_data,false)
		test.check(fresh.identity==Cloud.SOURCE_FORMS[type] and fresh.recognition>0.99,"Confirmed "+type+" has its supported source impression")
		test.check(Cloud.MASKS.has(fresh.identity) and fresh.impression_tint!=Color.BLACK,"Recognized source uses an authored mask and localized accent")
		test.check(Cloud.appearance(signal_data,true).identity.is_empty() and Cloud.appearance(signal_data,true).level==0,"Reported-empty "+type+" cannot look renewed")
		signal_data.confidence=0.2
		test.check(Cloud.appearance(signal_data,false).identity.is_empty(),"Weak "+type+" remains chemically abstract")
		signal_data.confidence=0.9;signal_data.age=1800.0
		test.check(Cloud.appearance(signal_data,false).identity.is_empty(),"Old "+type+" loses a fresh recognizable form")
		signal_data.age=900.0
		test.check(Cloud.appearance(signal_data,false).recognition<fresh.recognition,"Source form fades with observation age")
		signal_data=frozen.duplicate(true);signal_data.erase("source_type")
		test.check(not Cloud.SOURCE_ACCENTS.has(Cloud.appearance(signal_data,false).identity),"Legacy broad "+type+" cannot gain a guessed type")
		signal_data=frozen.duplicate(true);signal_data.category="threat"
		test.check(Cloud.appearance(signal_data,false).identity.is_empty(),"Wrong category cannot borrow a food/plant form")
		Cloud.appearance(frozen,false)
		test.check(frozen==signal_data.merged({"category":SourceCatalog.PROFILES[type].resource_id},true),"Appearance leaves detached evidence untouched")
	test.check(Cloud.SOURCE_FORMS.insect_remains==Cloud.SOURCE_FORMS.hunted_arthropod,"A hunted source does not invent the killed arthropod's species")
	_check_actual_return(test)
	_check_material_reuse(test)
	return true

func _check_actual_return(test: Object) -> void:
	var root:=Root.new();root.simulation=SimulationController.new(482817)
	var game: SimulationController=root.simulation
	game.advance(0.25)
	var evidence: Observation=Identity.new().sample(game,1,Vector2(11.25,20),game.run.simulation_time)
	assert(Identity.new().archive(game.run.knowledge,evidence,game.run.simulation_time));game.run.next_scout_id=2
	assert(game.create_trail("home","known:carb_sheltered"))
	var captured: bool=false
	for tick: int in 240:
		game.advance(0.25)
		for cohort: TransitCohort in game.run.trails.cohorts.values():
			if cohort.harvest_report!=null:captured=true
		if captured:break
	var signal_data: Dictionary=root.sensory_snapshot("home")[0]
	test.check(captured and signal_data.source_type.is_empty() and Cloud.appearance(signal_data,false).identity.is_empty(),"Actual inbound nectar sample stays abstract before its return")
	for tick: int in 240:
		game.advance(0.25)
		if not game.run.knowledge.nodes["known:carb_sheltered"].source_type.is_empty():break
	signal_data=root.sensory_snapshot("home")[0]
	var fresh: Dictionary=Cloud.appearance(signal_data,false)
	test.check(fresh.identity=="nectar" and fresh.recognition>0,"A surviving harvest return resolves the ordinary source into nectar")
	game.run.world.nodes.carb_sheltered.quantity=0;game.run.world.nodes.carb_sheltered.active=false
	game.run.world.nodes.carb_sheltered.position+=Vector2(2,2)
	test.check(root.sensory_snapshot("home")[0]==signal_data and Cloud.appearance(signal_data,false)==fresh,"Hidden depletion/movement cannot update a remembered source's art")
	root.free()

func _check_material_reuse(test: Object) -> void:
	var cloud:=Cloud.new()
	var signal_data: Dictionary={"source_type":"ripe_fruit","category":"carbohydrate","confidence":0.9,"strength":0.8,"age":0.0}
	var entry: Dictionary={"id":"same-memory","center":Vector2(200,200),"radius":50.0,"signal":signal_data}
	cloud.configure(entry,12.0,false)
	test.check(cloud.cloud_material.get_shader_parameter("impression_mask")==Cloud.MASKS.fruit,"Actual material binds the approved fruit mask")
	signal_data.source_type=""
	cloud.configure(entry,12.0,false)
	test.check(cloud.cloud_material.get_shader_parameter("recognition")==0.0,"Reused generic material drops all previous source recognition")
	signal_data.source_type="dew_drops";signal_data.category="water"
	cloud.configure(entry,12.0,false)
	test.check(cloud.cloud_material.get_shader_parameter("impression_mask")==Cloud.MASKS.dew,"Changing the approved identity replaces the material's mask")
	cloud.configure(entry,12.0,true)
	test.check(not cloud.visible and cloud.cloud_material.get_shader_parameter("recognition")==0.0,"An empty report suppresses a reused recognized cloud")
	cloud.free()
