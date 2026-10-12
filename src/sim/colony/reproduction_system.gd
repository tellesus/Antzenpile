class_name ReproductionSystem
extends RefCounted

const CONFIG = preload("res://data/resources/default_reproduction.tres")
const BROOD = preload("res://data/resources/default_brood.tres")
const FOOD = preload("res://data/resources/default_food_exchange.tres")
var _run: RunState
var last_error: String = ""
func _init(run_state: RunState) -> void: _run=run_state

func structural_blocker(pile: PileState) -> String:
	if pile.id=="home" and _run.founding.phase not in ["none","failed","established"]: return "Founding group is committed away from Home"
	if pile.reproduction.phase!="none": return "A reproductive group is already growing or ready"
	if pile.queen_count<1: return "No queen can lay reproductive brood"
	if pile.brood_matured_total<CONFIG.emerged_required: return "Raise %d workers before reproductive brood" % CONFIG.emerged_required
	if pile.nursery_state!="developed" or pile.food_exchange_state!="developed": return "Develop Nursery and Food Exchange first"
	return ""

func blocker(pile: PileState, respect_priority: bool=true) -> String:
	var structural: String=structural_blocker(pile)
	if not structural.is_empty(): return structural
	if respect_priority and not pile.queued_adaptation.is_empty() and pile.investments.first()!="reproduction": return "Queued adaptation owns the next brood slot"
	if pile.free_reproductive_space()<CONFIG.space: return "Need %d free Nursery spaces" % CONFIG.space
	if pile.workers_assignable<CONFIG.nurses: return "Need %d available reproductive nurses" % CONFIG.nurses
	for id: String in PileState.RESOURCE_IDS:
		if pile.resources[id]<CONFIG.costs()[id]: return "Need %.0f %s for reproductive laying" % [CONFIG.costs()[id],id]
	return ""

func start(pile_id: String, respect_priority: bool=true, scheduled: bool=false) -> bool:
	if not _run.colony.piles.has(pile_id): last_error="Unknown pile"; return false
	var pile: PileState = _run.colony.piles[pile_id]
	last_error = blocker(pile,respect_priority)
	if not last_error.is_empty(): return false
	var commitment: String = "reproduction:"+pile_id
	if not pile.workers.create_commitment(commitment,"internal",pile_id): last_error="Reproductive nurse assignment unavailable"; return false
	var allocated: bool = pile.allocate_workers(commitment,CONFIG.nurses)
	if not allocated:
		pile.workers.retire_commitment(commitment); last_error="Could not reserve reproductive nurses"; return false
	var paid: bool = pile.consume_resources(CONFIG.costs())
	if not paid:
		pile.workers.release(commitment,CONFIG.nurses); pile.workers.retire_commitment(commitment)
		last_error="Could not fund reproductive laying"; return false
	# Scheduled laying happens at the start of this fixed interval, before its aging.
	pile.reproduction.phase="egg"; pile.reproduction.laid_tick=maxi(0,_run.clock.tick_count-(1 if scheduled else 0))
	pile.reproduction.parent_queen_id=pile.queen.queen_id(pile_id);pile.reproduction.parent_generation=pile.queen.generation
	pile.reproduction.inherited_traits=pile.offspring_traits()
	pile.reproduction.repair_comparison=pile.repair_experience and not pile.repair_candidate
	pile.investments.reproduction=false;pile.investments.remove("reproduction")
	return true

func tick() -> void:
	var ids: Array = _run.colony.piles.keys(); ids.sort()
	for id: String in ids:
		var pile: PileState = _run.colony.piles[id]
		var state: ReproductionState = pile.reproduction
		if not state.active(): continue
		state.food_shortfalls.clear()
		var units: int = 80
		if state.phase=="larva":
			pile.environment.observe(pile,state.environment_exposure)
			var rate: float = BroodEnvironment.larval_rate(pile,state.inherited_traits)
			units=roundi(rate*80)
			var seconds: float = SimulationClock.TICK_INTERVAL * units / 80.0
			var multiplier: float = FOOD.developed_larval_food_multiplier*TraitCatalog.reproductive_food_multiplier(state.inherited_traits)
			var costs: Dictionary = {"carbohydrate":CONFIG.space*BROOD.carbohydrate_per_larva_second*seconds*multiplier*TraitCatalog.carbohydrate_multiplier(state.inherited_traits),"protein":CONFIG.space*BROOD.protein_per_larva_second*seconds*multiplier,"water":CONFIG.space*BROOD.water_per_larva_second*seconds*multiplier}
			if not pile.consume_resources(costs):
				for resource: String in PileState.RESOURCE_IDS:
					if pile.resources[resource]<costs[resource]: state.food_shortfalls.append(resource)
				continue
		var accumulated: int = state.progress_quarters*20+state.progress_remainder+units
		state.progress_quarters=accumulated/20
		state.progress_remainder=accumulated%20
		if state.progress_quarters<CONFIG.stage_ticks(state.phase)*4: continue
		state.progress_quarters=0; state.progress_remainder=0
		if state.phase=="egg": state.phase="larva"
		elif state.phase=="larva":
			state.phase="pupa"
			pile.environment.survived(state.environment_exposure)
			if state.repair_comparison: pile.repair_candidate=true
		else:
			state.phase="ready"
			var commitment: String = "reproduction:"+id
			var released: bool = pile.workers.release(commitment,CONFIG.nurses); assert(released)
			var retired: bool = pile.workers.retire_commitment(commitment); assert(retired)

func summary(pile_id: String) -> Dictionary:
	if not _run.colony.piles.has(pile_id): return {}
	var pile: PileState = _run.colony.piles[pile_id]
	var state: ReproductionState = pile.reproduction
	return {"phase":"departed" if pile_id=="home" and _run.founding.phase not in ["none","failed","established"] else state.phase,"progress":state.progress_ticks()/maxi(1,CONFIG.stage_ticks(state.phase)),"space":CONFIG.space,"occupied_space":state.occupied_space(),"nurses":CONFIG.nurses,"costs":CONFIG.costs(),"emerged_required":CONFIG.emerged_required,"ready_queens":1 if state.phase=="ready" else 0,"ready_males":2 if state.phase=="ready" else 0,"food_shortfalls":state.food_shortfalls.duplicate(),"blocker":blocker(pile)}
