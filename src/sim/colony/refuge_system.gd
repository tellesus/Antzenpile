class_name RefugeSystem
extends RefCounted
var _run: RunState
var last_error: String=""
func _init(run: RunState) -> void:_run=run
func state(pile_id: String) -> RefugeState:return _run.refuges.get(pile_id,RefugeState.new())
func candidates(pile: PileState) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if pile.queen.count>0:result.append({"kind":"queen","uid":pile.queen.queen_id(pile.id),"space":1})
	var royals: Array[Dictionary]=[];var brood: Array[Dictionary]=[]
	if not pile.queen.replacement_group.is_empty():royals.append({"kind":"royal","uid":ReproductionState.body_identity(pile.queen.replacement_group,pile.id),"space":8})
	if pile.reproduction.phase!="none":royals.append({"kind":"royal","uid":pile.reproduction.identity(pile.id),"space":8})
	for cohort: BroodCohort in pile.brood_cohorts:
		if cohort.count>0:brood.append({"kind":"brood","uid":cohort.uid(pile.id),"space":cohort.count})
	var ordered: Array[Dictionary]=royals+brood if state(pile.id).priority=="royals" else brood+royals
	var space: int=1 if not result.is_empty() else 0
	for target: Dictionary in ordered:
		if space+int(target.space)<=RefugeState.CAPACITY:result.append(target);space+=int(target.space)
	return result
func blocker(pile_id: String) -> String:
	if not _run.colony.piles.has(pile_id):return "Unknown pile"
	var pile: PileState=_run.colony.piles[pile_id]
	if pile.relinquished:return "Nest relinquished"
	if not pile.chambers.complete("refuge_chamber"):return "Build Refuge Chamber first"
	if state(pile_id).phase!="none":return "Shelter already preparing or held"
	if candidates(pile).is_empty():return "No local dependents to shelter"
	if pile.workers_assignable<RefugeState.WORKERS:return "Need four additional carers; existing brood care held"
	for id: String in RefugeState.COSTS:
		if pile.resources[id]<RefugeState.COSTS[id]:return "Need preparation food and water"
	return ""
func order(pile_id: String, action: String) -> bool:
	if not _run.colony.piles.has(pile_id):return _reject("Unknown pile")
	var pile: PileState=_run.colony.piles[pile_id];var refuge: RefugeState=state(pile_id)
	if action in ["royals","workers"]:
		if refuge.phase!="none":return _reject("Stand down before changing the held targets")
		refuge.priority=action;_run.refuges[pile_id]=refuge;last_error="";return true
	if action=="release":
		if refuge.phase=="none":return _reject("No shelter carers are held")
		assert(pile.workers.release("refuge:"+pile_id,RefugeState.WORKERS));assert(pile.workers.retire_commitment("refuge:"+pile_id))
		var empty:=RefugeState.new();empty.priority=refuge.priority;_run.refuges[pile_id]=empty;last_error="";return true
	if action!="prepare":return _reject("Unknown shelter action")
	last_error=blocker(pile_id)
	if not last_error.is_empty():return false
	if not pile.workers.create_commitment("refuge:"+pile_id,"internal",pile_id):return _reject("Shelter commitment unavailable")
	assert(pile.allocate_workers("refuge:"+pile_id,RefugeState.WORKERS));assert(pile.consume_resources(RefugeState.COSTS))
	refuge.targets=candidates(pile);refuge.phase="preparing";refuge.started_tick=_run.clock.tick_count;_run.refuges[pile_id]=refuge;last_error="";return true
func tick() -> void:
	for refuge: RefugeState in _run.refuges.values():
		if refuge.phase=="preparing":
			refuge.progress_ticks+=1
			if refuge.progress_ticks>=RefugeState.PREPARATION_TICKS:refuge.phase="ready"
func summary(pile_id: String) -> Dictionary:
	var pile: PileState=_run.colony.piles[pile_id];var refuge: RefugeState=state(pile_id)
	var targets: Array[Dictionary]=refuge.targets.duplicate(true) if refuge.phase!="none" else candidates(pile)
	var labels: Array[String]=[]
	for target: Dictionary in targets:
		var label: String="Mother · one protected space" if target.kind=="queen" else "Young queen and males · eight spaces" if target.kind=="royal" else "Worker brood · %d held spaces" % target.space
		if target.kind=="brood":
			var found: bool=false
			for cohort: BroodCohort in pile.brood_cohorts:
				if cohort.uid(pile.id)==target.uid:label="%d %s brood · %d held spaces" % [cohort.count,cohort.stage,target.space];found=true
			if not found:label="Held brood slots · emerged or moved"
		if target.kind=="queen" and (pile.queen.count==0 or pile.queen.queen_id(pile.id)!=target.uid):label="Held mother slot · mother no longer here"
		labels.append(label)
	return {"built":pile.chambers.complete("refuge_chamber"),"priority":refuge.priority,"phase":refuge.phase,"progress":float(refuge.progress_ticks)/RefugeState.PREPARATION_TICKS,"targets":labels,"capacity":RefugeState.CAPACITY,"reserved":refuge.reserved_space(),"workers":RefugeState.WORKERS if refuge.phase!="none" else 0,"costs":RefugeState.COSTS.duplicate(),"duration":RefugeState.PREPARATION_TICKS*SimulationClock.TICK_INTERVAL,"blocker":blocker(pile_id)}
func _reject(reason: String) -> bool:last_error=reason;return false
