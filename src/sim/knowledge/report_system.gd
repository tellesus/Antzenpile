class_name ReportSystem
extends RefCounted
## Observe only delivered route/knowledge records and visible local progress.
var _run: RunState
func _init(run: RunState) -> void: _run=run

func prime() -> void:
	if _run.reports.initialized: return
	_run.reports.since=_run.simulation_time
	capture(false);_run.reports.initialized=true

func capture(recording: bool = true) -> void:
	var journal: ReportJournal=_run.reports;var time: float=_run.simulation_time
	var source_ids: Array=_run.knowledge.nodes.keys();source_ids.sort()
	for source_id: String in source_ids:
		var node: KnownNode=_run.knowledge.nodes[source_id]
		if journal.changed("source/"+node.id,node.last_delivered_at):
			var delivery: Dictionary=_run.knowledge.latest_delivery(node.id)
			if delivery.is_empty(): continue
			journal.add("source",delivery.evidence.origin_pile,node.id,delivery.evidence.observed_at,delivery.received_at,node.source_type,0 if _run.knowledge.temporal_hint(node.id).get("last_return_empty",false) else 1,0,recording)
	var route_ids: Array=_run.trails.routes.keys();route_ids.sort()
	for route_id: String in route_ids:
		var route: TrailRouteState=_run.trails.routes[route_id]
		if route.purpose=="food" and journal.changed("gathering/"+route.id,route.desired_workers): journal.add("gathering",route.origin_pile,route.id,time,time,"target",route.desired_workers,0,recording)
		if not route.receipt.is_empty() and journal.changed("intake/"+route.id,route.receipt.last_at) and route.purpose=="food":
			journal.add("intake",route.origin_pile,route.id,route.receipt.last_at,route.receipt.last_at,_run.knowledge.nodes[route.destination_knowledge_id].definition_id,route.receipt.last_amount,route.receipt.last_amount,recording)
		var previous: int=int(journal.seen.get("loss/"+route.id,0))
		if journal.changed("loss/"+route.id,route.reported_losses) and route.reported_losses>previous:
			journal.add("loss",route.origin_pile,route.id,route.last_loss_time,route.last_loss_time,"reported",route.reported_losses-previous,route.reported_losses,recording)
		if not route.conflict_report.is_empty() and journal.changed("conflict/"+route.id,route.conflict_received_at):
			journal.add("conflict",route.origin_pile,route.id,route.conflict_observed_at,route.conflict_received_at,route.conflict_report,0,0,recording)
	var response: JourneyResponseState=_run.journey_response
	for kind: String in ["survey","pressure","defense","approach"]:
		var records: Dictionary=response.reports if kind=="survey" else response.pressure.reports if kind=="pressure" else response.defense.outcomes if kind=="defense" else response.approach.reports
		var record_ids: Array=records.keys();record_ids.sort()
		for id: String in record_ids:
			var report: Dictionary=records[id]
			if not journal.changed(kind+"/"+id,report.received_at): continue
			var detail: String=report.finding if kind=="survey" else report.pressure if kind=="pressure" else report.get("goal","clear")+":"+report.outcome if kind=="defense" else report.outcome
			journal.add(kind,_run.trails.routes[id].origin_pile,id,report.get("observed_at",report.received_at),report.received_at,detail,report.get("lost",report.get("acknowledged_sent",report.get("length",0))),report.get("sent",0),recording)
	var order_ids: Array=response.orders.targets.keys();order_ids.sort()
	for id: String in order_ids:
		var target: int=response.orders.targets[id];var goal: String=response.orders.goals.get(id,"clear")
		if journal.changed("order/"+id,str(target)+":"+goal): journal.add("order",_run.trails.routes[id].origin_pile,id,time,time,goal,target,0,recording)
	if response.active() and journal.changed("dispatch/"+response.route_id,str(response.departed_at)+":"+str(response.defense.sent)):
		journal.add("dispatch",response.origin_id(_run.trails),response.route_id,time,time,response.defense.mode,response.defense.sent,0,recording)
	var pile_ids: Array=_run.colony.piles.keys();pile_ids.sort()
	for pile_id: String in pile_ids:
		var pile: PileState=_run.colony.piles[pile_id]
		if journal.changed("investment/"+pile.id,",".join(pile.investments.priority)+"/"+pile.queued_adaptation): journal.add("investment",pile.id,pile.id,time,time,pile.investments.first() if not pile.investments.priority.is_empty() else "none",pile.investments.priority.size(),0,recording)
		if pile.reproduction.phase!="none" and journal.changed("investment/"+pile.id+"/laid",pile.reproduction.laid_tick): journal.add("investment",pile.id,pile.id,time,time,"reproduction_laid",0,0,recording)
		var trial: BroodCohort=pile.trial_cohort()
		if trial!=null and journal.changed("investment/"+pile.id+"/trial",trial.id): journal.add("investment",pile.id,pile.id,time,time,"adaptation_laid",0,0,recording)
		for detail: String in ["emerged","lost"]:
			var value: int=pile.brood_matured_total if detail=="emerged" else pile.brood_lost_total
			var key: String="brood/"+pile.id+"/"+detail;var before: int=int(journal.seen.get(key,0))
			if journal.changed(key,value) and value>before: journal.add("brood",pile.id,pile.id,time,time,detail,value-before,value,recording)
		var trait_ids: Array=pile.genetics.established.duplicate();trait_ids.sort()
		for trait_id: String in trait_ids:
			if journal.changed("trait/"+pile.id+"/"+trait_id,1): journal.add("trait",pile.id,trait_id,time,time,"established",0,0,recording)
		_project(pile.id,"nursery",pile.nursery_state,"developed",time,recording)
		_project(pile.id,"expansion",pile.nursery_expansion_state,"developed",time,recording)
		_project(pile.id,"exchange",pile.food_exchange_state,"developed",time,recording)
		_project(pile.id,"midden",pile.midden.state,"developed",time,recording)
		_project(pile.id,"reproduction",pile.reproduction.phase,"ready",time,recording)
	if _run.founding.reported_tick>0:
		var received: float=_run.founding.reported_tick*SimulationClock.TICK_INTERVAL
		if _run.founding.phase in ["ready","failed","established"] and journal.changed("camp/"+_run.founding.route_id,str(received)+":"+_run.founding.phase): journal.add("camp","home",_run.founding.route_id,received,received,_run.founding.phase,0,0,recording)
	for origin: String in ["home","satellite_1"]:
		var supply: InterpileSupplyState=_run.supply if origin=="home" else _run.daughter_supply
		if supply.trips_reported>0 and journal.changed("supplies/"+origin,supply.last_reported_tick):
			var received: float=supply.last_reported_tick*SimulationClock.TICK_INTERVAL
			journal.add("supplies",origin,"satellite_1" if origin=="home" else "home",received,received,"returned",supply.receipt().last_amount,0,recording)

func _project(pile: String, key: String, value: String, complete: String, time: float, recording: bool) -> void:
	if _run.reports.changed(key+"/"+pile,value) and value==complete:
		_run.reports.add("project",pile,"nursery" if key in ["nursery","expansion"] else "food_exchange" if key=="exchange" else "queen" if key=="reproduction" else key,time,time,"expanded" if key=="expansion" else complete,0,0,recording)
