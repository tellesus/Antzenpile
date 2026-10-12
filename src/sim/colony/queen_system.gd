class_name QueenSystem
extends RefCounted
const CONFIG = preload("res://data/resources/default_queen.tres")
var _run: RunState
var last_error: String = ""
func _init(run: RunState) -> void: _run=run

func set_care(pile_id: String, target: Variant) -> bool:
	if not _run.colony.piles.has(pile_id) or not WorkerLedger.valid_count(target) or target>CONFIG.care_cap: return _reject("Choose zero to two queen carers")
	var pile: PileState=_run.colony.piles[pile_id];var state: QueenState=pile.queen
	if target>0 and state.count==0: return _reject("No living queen to support")
	var delta: int=int(target)-state.carers;var commitment: String="queen_care:"+pile_id
	if delta>pile.workers_assignable: return _reject("Workers held for brood care or other work")
	if delta>0:
		if state.carers==0 and not pile.workers.create_commitment(commitment,"internal",pile_id): return _reject("Queen care commitment unavailable")
		var assigned: bool=pile.allocate_workers(commitment,delta);assert(assigned)
	elif delta<0:
		var released: bool=pile.workers.release(commitment,-delta);assert(released)
		if target==0: var retired: bool=pile.workers.retire_commitment(commitment);assert(retired)
	state.carers=int(target);last_error="";return true

func causes(pile: PileState) -> Array[String]:
	var result: Array[String]=[]
	for id: String in PileState.RESOURCE_IDS:
		if pile.resources[id]<CONFIG.care_costs(1)[id]: result.append(id)
	if pile.temperature.temperature>pile.temperature.CONFIG.extreme_high: result.append("severe heat")
	if pile.brood_health.burden>=pile.brood_health.CONFIG.severe_threshold: result.append("severe local strain")
	return result

func replacement_blocker(pile: PileState) -> String:
	if pile.queen.count>0: return "Support the living laying queen"
	if pile.queen.replacing(): return "Replacement group is already committed"
	if pile.reproduction.phase!="ready": return "A raised young queen and two males are required"
	if pile.queen.generation>=WorkerLedger.MAX_COUNT: return "Generation limit reached"
	if pile.workers_assignable<CONFIG.replacement_nurses: return "Need two available replacement nurses"
	for id: String in PileState.RESOURCE_IDS:
		if pile.resources[id]<CONFIG.replacement_costs()[id]: return "Need %.0f %s for replacement" % [CONFIG.replacement_costs()[id],id]
	return ""

func start_replacement(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id): return _reject("Unknown pile")
	var pile: PileState=_run.colony.piles[pile_id]
	last_error=replacement_blocker(pile)
	if not last_error.is_empty(): return false
	var commitment: String="queen_replacement:"+pile_id
	if not pile.workers.create_commitment(commitment,"internal",pile_id): return _reject("Replacement support unavailable")
	var assigned: bool=pile.allocate_workers(commitment,CONFIG.replacement_nurses);assert(assigned)
	var paid: bool=pile.consume_resources(CONFIG.replacement_costs());assert(paid)
	pile.queen.replacement_group=pile.reproduction.to_dict();pile.reproduction=ReproductionState.new()
	pile.queen.replacement_started=_run.clock.tick_count
	last_error="";return true

func cancel_replacement(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id) or not _run.colony.piles[pile_id].queen.replacing(): return _reject("No replacement group is committed")
	var pile: PileState=_run.colony.piles[pile_id]
	var returned:=ReproductionState.new()
	var valid: bool=returned.restore(pile.queen.replacement_group,WorkerLedger.new(),pile_id,pile.genetics.established,pile.brood_matured_total,pile.nursery_state,pile.food_exchange_state,0);assert(valid)
	pile.reproduction=returned;_release_replacement(pile)
	last_error="";return true

func _release_replacement(pile: PileState) -> void:
	var commitment: String="queen_replacement:"+pile.id
	var released: bool=pile.workers.release(commitment,CONFIG.replacement_nurses);assert(released)
	var retired: bool=pile.workers.retire_commitment(commitment);assert(retired)
	pile.queen.replacement_group={};pile.queen.replacement_progress=0;pile.queen.replacement_started=0

func tick() -> void:
	var ids: Array=_run.colony.piles.keys();ids.sort()
	for id: String in ids:
		var pile: PileState=_run.colony.piles[id];var state: QueenState=pile.queen
		if state.replacing():
			state.replacement_progress+=1
			if state.replacement_progress>=CONFIG.replacement_ticks:
				state.parent_identity=state.queen_id(id);state.generation+=1
				state.identity="queen:"+id+":raised:"+str(state.replacement_group.laid_tick)
				state.inherited_traits.assign(state.replacement_group.inherited_traits)
				state.count=1;state.condition=CONFIG.maximum_condition
				_release_replacement(pile)
			continue
		if state.count==0: continue
		var strain: Array[String]=causes(pile)
		if not strain.is_empty(): state.condition=maxi(0,state.condition-CONFIG.strain_per_tick)
		if strain.is_empty() and state.condition>0 and state.condition<CONFIG.maximum_condition and state.carers>0 and pile.consume_resources(CONFIG.care_costs(state.carers)):
			state.condition=mini(CONFIG.maximum_condition,state.condition+CONFIG.recovery_per_carer_tick*state.carers)
		if state.condition==0:
			state.count=0
			var released: bool=set_care(id,0);assert(released)
			pile.queued_adaptation="";pile.investments=InvestmentIntent.new()

func summary(pile_id: String) -> Dictionary:
	var pile: PileState=_run.colony.piles[pile_id];var state: QueenState=pile.queen
	return {"identity":state.queen_id(pile_id),"generation":state.generation,"condition":state.condition/10000.0,"carers":state.carers,"causes":causes(pile),"status":"replacing" if state.replacing() else "lost" if state.count==0 else "weakened" if state.condition<CONFIG.warning_condition else "supported" if state.carers>0 else "steady","replacement_progress":float(state.replacement_progress)/CONFIG.replacement_ticks,"replacement_costs":CONFIG.replacement_costs(),"replacement_nurses":CONFIG.replacement_nurses,"replacement_blocker":replacement_blocker(pile),"captured_traits":state.inherited_traits.duplicate()}
func _reject(reason: String) -> bool: last_error=reason;return false
