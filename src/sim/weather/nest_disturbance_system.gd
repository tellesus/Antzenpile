class_name NestDisturbanceSystem
extends RefCounted
const BROOD_SYSTEM=preload("res://src/sim/colony/brood_system.gd")
var _run: RunState
func _init(run: RunState) -> void:_run=run
func tick() -> void:
	var state: NestDisturbanceState=_run.nest_disturbance
	var config: NestDisturbanceDefinition=state.definition()
	var phase: String=state.phase(_run.clock.tick_count)
	if phase=="dormant":return
	var ids: Array=_run.colony.piles.keys();ids.sort()
	for id: String in ids:
		var pile: PileState=_run.colony.piles[id]
		if pile.relinquished or pile.position.distance_to(config.position)>config.radius:continue
		if not state.records.has(id):
			if phase=="settled" or pile.workers_total==0 and pile.queen.count==0 and pile.brood_cohorts.is_empty() and pile.reproduction.phase=="none":continue
			state.records[id]={"warned":_run.clock.tick_count,"impacted":0,"settled":0,"workers":0,"brood":0,"royals":0,"queen_injury":0}
		var record: Dictionary=state.records[id]
		if phase=="pressure" and record.impacted==0:_impact(pile,record)
		if phase=="settled" and record.settled==0:
			record.settled=_run.clock.tick_count
			if RefugeSystem.new(_run).state(id).phase!="none":var refuge_released: bool = RefugeSystem.new(_run).order(id,"release"); assert(refuge_released)
	if phase=="pressure" and not state.scent_disturbed:
		for segment: TrailSegmentState in _run.trails.segments.values():
			if segment.distance_to_path(config.position)<=config.radius:segment.decay_chemistry(-log(config.remaining_scent)/log(2.0))
		state.scent_disturbed=true
func _impact(pile: PileState, record: Dictionary) -> void:
	var config: NestDisturbanceDefinition=_run.nest_disturbance.definition()
	record.impacted=_run.clock.tick_count
	var refuge: RefugeState=RefugeSystem.new(_run).state(pile.id)
	var exposure: float=SiteCatalog.for_pile(pile).ground_exposure
	if pile.queen.count>0 and not refuge.protects(pile.queen.queen_id(pile.id)):
		record.queen_injury=roundi(config.queen_injury*exposure);QueenSystem.new(_run).injure(pile.id,record.queen_injury)
	for cohort: BroodCohort in pile.brood_cohorts.duplicate():
		if refuge.protects(cohort.uid(pile.id)):continue
		var losses: int=mini(cohort.count,roundi(cohort.count*config.brood_loss_fraction*exposure))
		for index: int in losses:
			if BROOD_SYSTEM.new(_run).lose_one(pile.id,"",cohort.uid(pile.id)):record.brood+=1
	if not pile.queen.replacement_group.is_empty() and not refuge.protects(ReproductionState.body_identity(pile.queen.replacement_group,pile.id)):
		var replacement_lost: bool = QueenSystem.new(_run).lose_replacement(pile.id); assert(replacement_lost);record.royals+=3
	if pile.reproduction.phase!="none" and not refuge.protects(pile.reproduction.identity(pile.id)):
		var group_lost: bool = ReproductionSystem.new(_run).lose_group(pile.id); assert(group_lost);record.royals+=3
	var workers: int=roundi(pile.workers_available*config.worker_loss_fraction*exposure)
	for index: int in workers:
		var adapted: int=1 if _run.rng.randf()<pile.adaptation_fraction() else 0
		var profile: String=pile.genetics.loss_profile(adapted==1,pile.adaptation_repertoire,pile.workers_total,_run.rng)
		var workers_lost: bool = pile.lose_workers("available",1,adapted,"local ground pressure",profile); assert(workers_lost);record.workers+=1
func summary(pile_id: String) -> Dictionary:
	if not _run.nest_disturbance.records.has(pile_id):return {}
	var record: Dictionary=_run.nest_disturbance.records[pile_id]
	return {"warning_age":(_run.clock.tick_count-record.warned)*SimulationClock.TICK_INTERVAL,"ongoing":record.settled==0,"impact_observed":record.impacted>0,"workers_lost":record.workers,"brood_lost":record.brood,"royals_lost":record.royals,"queen_injury":float(record.queen_injury)/10000.0,"settled_age":(_run.clock.tick_count-record.settled)*SimulationClock.TICK_INTERVAL if record.settled>0 else 0.0}
