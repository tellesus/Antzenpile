class_name RunContinuity
extends RefCounted
## Approved local bodies plus expected returns; never forecasts food or hazards.
static func failed(run: RunState) -> bool:
	# Most ticks have a local mother and living workforce; avoid building a UI DTO.
	for pile: PileState in run.colony.piles.values():
		if (pile.queen.count>0 or pile.reproduction.phase!="none" or pile.queen.replacing()) and pile.workers_total>0:return false
	return snapshot(run).phase=="unrecoverable"
static func snapshot(run: RunState, focus_id: String="home") -> Dictionary:
	var rows: Array[Dictionary]=[]
	var queen: bool=false;var young: bool=false;var workers: bool=false;var pending: bool=false
	var ids: Array=run.colony.piles.keys();ids.sort()
	for id: String in ids:
		var pile: PileState=run.colony.piles[id]
		var expected: int=pile.workers_total+run.pending_for_pile(id)+run.unreported_transfers(id)
		var paid_young: bool=pile.reproduction.phase!="none" or pile.queen.replacing()
		var connections: int=0;var closed: int=0
		for link: ConnectionTrafficState in run.all_connections():
			if id in [link.parent_id,link.child_id]:connections+=1;closed+=int(link.closed)
		if id==focus_id:
			rows.append({"id":id,"local":true,"queen":pile.queen.count>0,"young":paid_young,"workers_expected":expected,
				"free":pile.workers_assignable,"isolated":connections>0 and connections==closed,"relinquished":pile.relinquished})
		else:rows.append({"id":id,"local":false})
		queen=queen or pile.queen.count>0;young=young or paid_young;workers=workers or expected>0
		pending=pending or run.pending_for_pile(id)>0 or run.unreported_transfers(id)>0
	for memory: ScoutMissionMemory in run.scout_missions.values():pending=pending or memory.completed_at()<0
	pending=pending or not run.trails.cohorts.is_empty() or run.journey_response.active()
	for camp: FoundingState in run.all_foundings():
		# The source knows a funded group was sent, not its private landing result.
		if camp.awaiting() or camp.phase=="ready":young=true
		pending=pending or camp.awaiting()
	for link: ConnectionTrafficState in run.all_connections():
		for id: String in [link.parent_id,link.child_id]:
			if link.queens[id].active():queen=true
			if link.royals[id].active():young=true
			pending=pending or link.supplies[id].travelling() or link.migrations[id].active() or link.queens[id].active() or link.broods[id].active() or link.stores[id].travelling() or link.royals[id].active() or link.evacuations[id].active()
	var phase: String="viable" if queen and workers else "queenless" if young and workers else "awaiting" if pending else "unrecoverable"
	return {"phase":phase,"pending":pending,"piles":rows,"accomplishment":run.accomplishment.to_dict()}
