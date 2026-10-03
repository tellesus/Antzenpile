class_name ReproductionSystem
extends RefCounted

const CONFIG = preload("res://data/resources/default_reproduction.tres")
const BROOD = preload("res://data/resources/default_brood.tres")
const FOOD = preload("res://data/resources/default_food_exchange.tres")
var _run: RunState
var last_error: String = ""
func _init(run_state: RunState) -> void: _run=run_state

func blocker(pile: PileState) -> String:
	if pile.reproduction.phase!="none": return "A reproductive group is already growing or ready"
	if pile.queen_count<1: return "No queen can lay reproductive brood"
	if pile.brood_matured_total<CONFIG.emerged_required: return "Raise %d workers before reproductive brood" % CONFIG.emerged_required
	if pile.nursery_state!="developed" or pile.food_exchange_state!="developed": return "Develop Nursery and Food Exchange first"
	if not pile.queued_adaptation.is_empty(): return "Queued adaptation owns the next brood slot"
	if pile.nursery_brood_capacity()-pile.nursery_occupied_space()<CONFIG.space: return "Need %d free Nursery spaces" % CONFIG.space
	if pile.workers_available<CONFIG.nurses: return "Need %d available reproductive nurses" % CONFIG.nurses
	for id: String in PileState.RESOURCE_IDS:
		if pile.resources[id]<CONFIG.costs()[id]: return "Need %.0f %s for reproductive laying" % [CONFIG.costs()[id],id]
	return ""

func start(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id): last_error="Unknown pile"; return false
	var pile: PileState = _run.colony.piles[pile_id]
	last_error = blocker(pile)
	if not last_error.is_empty(): return false
	var commitment: String = "reproduction:"+pile_id
	if not pile.workers.create_commitment(commitment,"internal",pile_id): last_error="Reproductive nurse assignment unavailable"; return false
	var allocated: bool = pile.workers.allocate(commitment,CONFIG.nurses)
	if not allocated:
		pile.workers.retire_commitment(commitment); last_error="Could not reserve reproductive nurses"; return false
	var paid: bool = pile.consume_resources(CONFIG.costs())
	if not paid:
		pile.workers.release(commitment,CONFIG.nurses); pile.workers.retire_commitment(commitment)
		last_error="Could not fund reproductive laying"; return false
	pile.reproduction.phase="egg"; pile.reproduction.laid_tick=_run.clock.tick_count
	pile.reproduction.inherited_traits=pile.genetics.established.duplicate()
	return true

func tick() -> void:
	var ids: Array = _run.colony.piles.keys(); ids.sort()
	for id: String in ids:
		var pile: PileState = _run.colony.piles[id]
		var state: ReproductionState = pile.reproduction
		if not state.active(): continue
		state.food_shortfalls.clear()
		var quarters: int = 4
		if state.phase=="larva":
			var rate: float = minf(pile.temperature.larval_rate(),minf(pile.brood_health.larval_rate(),minf(pile.midden.larval_rate(),pile.humidity.larval_rate())))
			quarters=roundi(rate*4)
			var seconds: float = SimulationClock.TICK_INTERVAL * quarters / 4.0
			var multiplier: float = FOOD.developed_larval_food_multiplier
			var costs: Dictionary = {"carbohydrate":CONFIG.space*BROOD.carbohydrate_per_larva_second*seconds*multiplier,"protein":CONFIG.space*BROOD.protein_per_larva_second*seconds*multiplier,"water":CONFIG.space*BROOD.water_per_larva_second*seconds*multiplier}
			if not pile.consume_resources(costs):
				for resource: String in PileState.RESOURCE_IDS:
					if pile.resources[resource]<costs[resource]: state.food_shortfalls.append(resource)
				continue
		state.progress_quarters+=quarters
		if state.progress_quarters<CONFIG.stage_ticks(state.phase)*4: continue
		state.progress_quarters=0
		if state.phase=="egg": state.phase="larva"
		elif state.phase=="larva": state.phase="pupa"
		else:
			state.phase="ready"
			var commitment: String = "reproduction:"+id
			var released: bool = pile.workers.release(commitment,CONFIG.nurses); assert(released)
			var retired: bool = pile.workers.retire_commitment(commitment); assert(retired)

func summary(pile_id: String) -> Dictionary:
	if not _run.colony.piles.has(pile_id): return {}
	var pile: PileState = _run.colony.piles[pile_id]
	var state: ReproductionState = pile.reproduction
	return {"phase":state.phase,"progress":float(state.progress_quarters)/maxi(1,CONFIG.stage_ticks(state.phase)*4),"space":CONFIG.space,"occupied_space":state.occupied_space(),"nurses":CONFIG.nurses,"costs":CONFIG.costs(),"emerged_required":CONFIG.emerged_required,"ready_queens":1 if state.phase=="ready" else 0,"ready_males":2 if state.phase=="ready" else 0,"food_shortfalls":state.food_shortfalls.duplicate(),"blocker":blocker(pile)}
