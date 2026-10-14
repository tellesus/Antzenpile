extends RefCounted
## Purposeful test strategies. Only returned memories/local jobs drive decisions;
## no workers, stores, ready bodies, discoveries or development are injected.
const Controller=preload("res://src/core/simulation_controller.gd")
const ORIGINAL=["known:carb_sheltered","known:carb_exposed","known:protein_01","known:water_01","known:protein_picnic"]
const ALTERNATIVES=["known:aphid_01","known:carb_spill","known:seed_01","known:ambusher_carcass"]
var game: SimulationController
var events: Dictionary={}
var trial: bool=false
var reproductive: bool=false
var funded_site: String=""
var migrated: bool=false
var rescued: bool=false
var saved_twin: bool=false
var save_ok: bool=false
var adaptive: bool=true
var network: bool=false
var rescue: bool=false

func play(scenario: String, policy: String="adaptive", horizon: int=3600) -> Dictionary:
	adaptive=policy!="original";network=policy=="network";rescue=policy=="rescue";trial=rescue
	game=Controller.new(3030,scenario)
	game.set_brood_intent("home","grow");game.set_exploration(2)
	var bearings: Array=[0.0,PI,2.0,-PI/2]
	if rescue:bearings.append_array([-3*PI/4,PI/4])
	for bearing: float in bearings:game.dispatch_scout("home",bearing)
	while game.run.simulation_time<horizon:
		game.advance(2)
		if game.run.clock.tick_count%40!=8:continue
		_step()
		_observe()
		if not saved_twin and game.run.colony.piles.home.reproduction.phase=="egg":
			saved_twin=true
			var twin:=Controller.new()
			save_ok=twin.restore_snapshot(JSON.parse_string(JSON.stringify(game.run.to_dict(),"",true,true)))
			if save_ok:
				game.advance(60);twin.advance(60);save_ok=game.run.to_dict()==twin.run.to_dict()
		var complete: bool=game.run.colony.piles.size()>=3 if network else game.run.accomplishment.generation>0
		if complete:break
	return {"game":game,"events":events.duplicate(),"save_ok":save_ok,"rescued":rescued}

func _step() -> void:
	var pile: PileState=game.run.colony.piles.home
	for known: KnownNode in game.run.knowledge.nodes.values():_home_source(known)
	if pile.food_exchange_state=="primitive":game.start_food_exchange("home")
	if pile.nursery_state=="primitive":game.start_nursery_development("home")
	if pile.midden.revealed:game.set_sanitation_workers("home",2)
	if pile.resources.water>2:game.set_humidity_workers("home",1)
	if rescue:
		if pile.nursery_state=="developed":game.start_nursery_expansion("home")
		if game.run.guest.observation in ["loss","foreign"]:game.start_guest_rejection()
		if pile.queen.condition<800000 and pile.queen.count>0:game.set_queen_care("home",2)
	if pile.brood_matured_total>=8 and not trial:trial=game.queue_adaptation("home","lean")
	if pile.brood_matured_total>=32:
		game.set_brood_intent("home","manual")
		if not reproductive:reproductive=game.queue_reproduction("home",true)
	if game.run.scenario_id=="roadside" and not rescue:
		if pile.nursery_state=="developed":game.order_chamber("home","refuge_chamber")
		if NestDisturbanceSystem.new(game.run).summary("home").get("ongoing",false):RefugeSystem.new(game.run).order("home","prepare")
	if pile.reproduction.phase=="ready" and game.run.founding.phase=="none":
		for known: KnownNode in game.run.knowledge.nodes.values():
			if (known.id=="known:nest_site_01" if rescue else known.definition_id=="nest_site") and game.start_founding(known.id):funded_site=known.id;break
	if game.run.founding.phase=="ready":game.establish_daughter(funded_site)
	if game.run.colony.piles.has("satellite_1"):_daughter()

func _home_source(known: KnownNode) -> void:
	if known.id not in ORIGINAL+(ALTERNATIVES if adaptive else []):return
	var pile: PileState=game.run.colony.piles.home
	var route: TrailRouteState=game.run.trails.find_route("home",known.id)
	if route==null:
		if game.create_trail("home",known.id):game.set_trail_workers(game.run.trails.find_route("home",known.id).id,3)
		return
	if not adaptive:
		if route.reported_losses>0 or route.status=="depleted":game.set_trail_workers(route.id,0)
		return
	var outcome: Dictionary=game.run.journey_response.defense.outcomes.get(route.id,{})
	if route.last_loss_time>outcome.get("received_at",0):
		game.set_trail_workers(route.id,0)
		var report: Dictionary=game.run.journey_response.reports.get(route.id,{})
		if report.get("finding","") in ["ambush","mixed"] and report.get("received_at",0)>outcome.get("received_at",0):game.journey_response.commit_force(route.id,"hunt",13)
		elif report.is_empty() or route.last_loss_time>report.get("received_at",0):game.journey_response.investigate(route.id)
		return
	var hint: Dictionary=game.run.knowledge.temporal_hint(known.id)
	if route.status=="depleted" and hint.get("last_return_empty",false):
		game.set_trail_workers(route.id,0)
		if pile.resources.get(known.definition_id,0)<25 and (not network or known.source_type not in ["insect_remains","predator_carcass","ripe_fruit","cracked_seeds"]):game.investigate_known_source("home",known.id)
	elif known.id=="known:aphid_01" or known.definition_id=="carbohydrate":
		game.set_trail_workers(route.id,3);game.set_honeydew_target("home",6)
	elif known.definition_id in ["water","protein"]:game.set_trail_workers(route.id,0 if pile.resources[known.definition_id]>50 else 3)

func _daughter() -> void:
	var home: PileState=game.run.colony.piles.home
	var daughter: PileState=game.run.colony.piles.satellite_1
	var link: ConnectionTrafficState=game.run.all_connections()[0]
	if rescue:
		if not rescued and home.brood_cohorts.is_empty():game.start_brood("home")
		if NestDisturbanceSystem.new(game.run).summary("home").get("ongoing",false) and not rescued:
			for cohort: BroodCohort in home.brood_cohorts:
				if game.connection_order(link.route_id,"home","rescue_brood",8,cohort.uid("home")).accepted:rescued=true;break
	var receiving_ready: bool=not rescue or rescued and not link.broods.home.last_report().is_empty()
	if receiving_ready and not migrated:migrated=game.connection_order(link.route_id,"home","migrate",8).accepted
	if migrated:
		if network and daughter.resources.carbohydrate<20 and home.resources.protein<10:
			game.connection_order(link.route_id,"home","stop_supply")
			# The order's number is packet amount; staff are the fixed real crew.
			if not link.busy():game.connection_order(link.route_id,"home","rescue_stores",6,"carbohydrate")
		elif not link.busy():game.connection_order(link.route_id,"home","supply")
	if receiving_ready:game.set_brood_intent("satellite_1","grow")
	for known: KnownNode in game.run.knowledge.nodes.values():
		if known.id not in ORIGINAL.slice(0,4):continue
		if game.run.trails.find_route("satellite_1",known.id)==null and game.create_trail("satellite_1",known.id):game.set_trail_workers(game.run.trails.find_route("satellite_1",known.id).id,3)
	if daughter.resources.water>2:game.set_humidity_workers("satellite_1",1)
	if not network:return
	if daughter.food_exchange_state=="primitive":game.start_food_exchange("satellite_1")
	if daughter.nursery_state=="primitive":game.start_nursery_development("satellite_1")
	if daughter.midden.revealed:game.set_sanitation_workers("satellite_1",2)
	if daughter.brood_matured_total>=32:
		game.set_brood_intent("satellite_1","manual");game.queue_reproduction("satellite_1",true)
	if daughter.reproduction.phase=="ready":
		for known: KnownNode in game.run.knowledge.nodes.values():
			if known.definition_id=="nest_site":game.start_founding(known.id,"satellite_1")
	for camp: FoundingState in game.run.all_foundings():
		if camp.origin_pile=="satellite_1" and camp.phase=="ready":
			for known: KnownNode in game.run.knowledge.nodes.values():
				if known.definition_id=="nest_site":game.establish_daughter(known.id,"satellite_1")

func _observe() -> void:
	var pile: PileState=game.run.colony.piles.home
	var conditions: Dictionary={"growth":pile.brood_matured_total>=8,"organs":pile.nursery_state=="developed" and pile.food_exchange_state=="developed","trial":pile.genetics.count_trait("lean")>0,"reproductives":pile.reproduction.phase=="ready" or game.run.founding.phase!="none","daughter":game.run.colony.piles.size()>1,"continuity":game.run.accomplishment.generation>0,"network":game.run.colony.piles.size()>2}
	for marker: String in conditions:
		if conditions[marker] and not events.has(marker):events[marker]=game.run.simulation_time
