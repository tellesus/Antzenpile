extends RefCounted
## Aggregate brood progression on the run's fixed simulation clock.

const CONFIG = preload("res://data/resources/default_brood.tres")
const FOOD_CONFIG = preload("res://data/resources/default_food_exchange.tres")
const Adaptation = preload("res://src/sim/colony/adaptation_system.gd")
var _run: RunState
var _adaptation: RefCounted
var _investments: RefCounted
var last_error: String = ""


func _init(run_state: RunState, adaptation_system: RefCounted = null, investment_system: RefCounted=null) -> void:
	_run = run_state
	_adaptation = adaptation_system if adaptation_system != null else Adaptation.new(_run)
	_investments=investment_system if investment_system!=null else preload("res://src/sim/colony/investment_system.gd").new(_run,_adaptation,ReproductionSystem.new(_run))


func start(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id):
		last_error = "Unknown pile"
		return false
	var pile: PileState = _run.colony.piles[pile_id]
	if not pile.investments.priority.is_empty():
		var accepted: bool = _investments.start_next(pile_id)
		last_error = _investments.last_error
		return accepted
	return _start_ordinary(pile_id)

func _start_ordinary(pile_id: String) -> bool:
	var pile: PileState=_run.colony.piles[pile_id]
	if pile.queen_count < 1:
		last_error = "No queen in pile"
		return false
	if pile.nursery_state != "developed" and not pile.brood_cohorts.is_empty():
		last_error = "Nursery already has brood"
		return false
	if pile.brood_cohorts.size() >= pile.nursery_brood_capacity() / CONFIG.starting_count or pile.free_worker_brood_space() < CONFIG.starting_count:
		last_error = "Nursery lacks brood space"
		return false
	var pending_brood: int = pile.nursery_occupied_space() + CONFIG.starting_count
	if pile.brood_started_total >= WorkerLedger.MAX_COUNT or pile.brood_matured_total > WorkerLedger.MAX_COUNT - pending_brood or pile.workers_total > WorkerLedger.MAX_COUNT - pending_brood:
		last_error = "Population limit reached"
		return false
	if pile.workers_available < pile.brood_care_workers_required(CONFIG.starting_count):
		last_error = "More workers at home required for brood care"
		return false
	var cohort := BroodCohort.new()
	pile.brood_started_total += 1
	cohort.id = "brood_%d" % pile.brood_started_total
	cohort.parent_queen_id=pile.queen.queen_id(pile.id);cohort.parent_generation=pile.queen.generation
	cohort.inherited_traits = pile.offspring_traits()
	cohort.adaptation_id = "lean" if "lean" in cohort.inherited_traits else "load" if "load" in cohort.inherited_traits else ""
	cohort.repair_comparison = pile.repair_experience and not pile.repair_candidate
	cohort.rain_comparison = pile.rain_trace_observed and not pile.chemistry_candidate
	cohort.recognition_comparison = pile.recognition_experience and not pile.recognition_candidate
	pile.brood_cohorts.append(cohort)
	last_error = ""
	return true


func set_intent(pile_id: String, intent: Variant) -> bool:
	if not _run.colony.piles.has(pile_id) or not intent is String or intent not in ["manual", "grow"]:
		last_error = "Unknown pile or brood intent"
		return false
	_run.colony.piles[pile_id].brood_intent = intent
	last_error = ""
	return true


func production_status(pile_id: String) -> Dictionary:
	if not _run.colony.piles.has(pile_id): return {}
	var pile: PileState = _run.colony.piles[pile_id]
	var waiting: String = "ready"
	var pending: int = pile.nursery_occupied_space() + CONFIG.starting_count
	var special: String=_investments.next_eligible(pile)
	if not special.is_empty(): waiting = special
	elif pile.brood_intent == "manual": waiting = "manual"
	elif pile.queen_count < 1: waiting = "queen"
	elif pile.brood_cohorts.size() >= pile.nursery_brood_capacity() / CONFIG.starting_count or pile.free_worker_brood_space()<CONFIG.starting_count: waiting = "space"
	elif pending-pile.reproduction.occupied_space() > pile.nursery_care_capacity(): waiting = "care"
	elif pile.brood_started_total >= WorkerLedger.MAX_COUNT or pile.brood_matured_total > WorkerLedger.MAX_COUNT - pending or pile.workers_total > WorkerLedger.MAX_COUNT - pending: waiting = "population"
	else:
		var reserve: Dictionary = remaining_food_reserve(pile)
		for resource_id: String in PileState.RESOURCE_IDS:
			if pile.resources[resource_id] < reserve[resource_id]:
				waiting = resource_id
				break
	return {"intent": pile.brood_intent, "waiting": waiting}


func remaining_food_reserve(pile: PileState) -> Dictionary:
	# Intrinsic remaining larval demand, not a forecast of routes/weather/deliveries.
	var ant_seconds: float = CONFIG.starting_count * CONFIG.larva_seconds * TraitCatalog.food_multiplier(pile.offspring_traits())
	var carb_seconds: float = ant_seconds * TraitCatalog.carbohydrate_multiplier(pile.offspring_traits())
	for cohort: BroodCohort in pile.brood_cohorts:
		var feeding: float = TraitCatalog.food_multiplier(cohort.inherited_traits)
		var demand: float = cohort.count * (CONFIG.larva_seconds if cohort.stage=="egg" else CONFIG.larva_seconds-cohort.progress_seconds if cohort.stage=="larva" else 0.0) * feeding
		ant_seconds += demand
		carb_seconds += demand * TraitCatalog.carbohydrate_multiplier(cohort.inherited_traits)
	var reproductive: ReproductionState = pile.reproduction
	var reproductive_demand: float = 0.0
	if reproductive.phase=="egg": reproductive_demand=reproductive.CONFIG.space*reproductive.CONFIG.larva_ticks*SimulationClock.TICK_INTERVAL*TraitCatalog.reproductive_food_multiplier(reproductive.inherited_traits)
	elif reproductive.phase=="larva": reproductive_demand=reproductive.CONFIG.space*(reproductive.CONFIG.larva_ticks-reproductive.progress_ticks())*SimulationClock.TICK_INTERVAL*TraitCatalog.reproductive_food_multiplier(reproductive.inherited_traits)
	ant_seconds += reproductive_demand
	carb_seconds += reproductive_demand * TraitCatalog.carbohydrate_multiplier(reproductive.inherited_traits)
	var multiplier: float = FOOD_CONFIG.developed_larval_food_multiplier if pile.food_exchange_state == "developed" else 1.0
	return {"carbohydrate": carb_seconds * CONFIG.carbohydrate_per_larva_second * multiplier,
		"protein": ant_seconds * CONFIG.protein_per_larva_second * multiplier,
		"water": ant_seconds * CONFIG.water_per_larva_second * multiplier}


func lose_one(pile_id: String, stage: String = "") -> bool:
	if not _run.colony.piles.has(pile_id):
		return false
	var pile: PileState = _run.colony.piles[pile_id]
	if pile.brood_cohorts.is_empty() or pile.brood_lost_total >= WorkerLedger.MAX_COUNT:
		return false
	# Stable oldest-first choice, no individual brood agents or adult ledger debit.
	var candidates: Array[BroodCohort] = pile.brood_cohorts.filter(func(item): return stage.is_empty() or item.stage == stage)
	if candidates.is_empty(): return false
	var cohort: BroodCohort = candidates[0]
	cohort.count -= 1
	cohort.lost_count += 1
	pile.brood_lost_total += 1
	if cohort.count == 0:
		if cohort.adaptation_trial:
			var commitment: String = "adaptation:" + pile.id
			var released: bool = pile.workers.release(commitment, AdaptationRules.NURSES)
			assert(released)
			var retired: bool = pile.workers.retire_commitment(commitment)
			assert(retired)
		pile.brood_cohorts.erase(cohort)
	return true


func tick(delta: float) -> void:
	var ids: Array = _run.colony.piles.keys()
	ids.sort()
	for id: String in ids:
		var pile: PileState = _run.colony.piles[id]
		# Dedicated reproductive nurses support their own equivalent-space group.
		var occupied: int = pile.nursery_occupied_space()-pile.reproduction.occupied_space()
		var care_fraction: float = minf(1.0, float(pile.nursery_care_capacity()) / occupied) if occupied > 0 else 1.0
		if occupied>=CONFIG.starting_count*2 or occupied>0 and care_fraction<1: pile.care_pressure_seen=true
		for cohort: BroodCohort in pile.brood_cohorts.duplicate():
			_advance(pile, cohort, delta, care_fraction)
		if not _investments.next_eligible(pile).is_empty():
			_investments.start_next(id,true)
		elif pile.brood_intent == "grow" and production_status(id).waiting == "ready":
			_start_ordinary(id)


func _advance(pile: PileState, cohort: BroodCohort, delta: float, care_fraction: float) -> void:
	cohort.nutrition_shortfalls.clear()
	cohort.care = care_fraction
	if cohort.stage == "larva": pile.environment.observe(pile,cohort.environment_exposure)
	if cohort.care < 1.0:
		cohort.nutrition = 0.0 if cohort.stage == "larva" else 1.0
		return
	var environment_rate: float = BroodEnvironment.larval_rate(pile,cohort.inherited_traits)
	var effective_delta: float = delta * (environment_rate if cohort.stage == "larva" else 1.0)
	if cohort.stage == "larva":
		var food_multiplier: float = FOOD_CONFIG.developed_larval_food_multiplier if pile.food_exchange_state == "developed" else 1.0
		food_multiplier*=TraitCatalog.food_multiplier(cohort.inherited_traits)
		var costs: Dictionary = {"carbohydrate": cohort.count * CONFIG.carbohydrate_per_larva_second * effective_delta * food_multiplier * TraitCatalog.carbohydrate_multiplier(cohort.inherited_traits),
			"protein": cohort.count * CONFIG.protein_per_larva_second * effective_delta * food_multiplier,
			"water": cohort.count * CONFIG.water_per_larva_second * effective_delta * food_multiplier}
		if not pile.consume_resources(costs):
			for resource_id: String in BroodCohort.RESOURCE_IDS:
				if pile.resources[resource_id] < costs[resource_id]: cohort.nutrition_shortfalls.append(resource_id)
			cohort.nutrition = 0.0
			return
	cohort.nutrition = 1.0
	cohort.progress_seconds += effective_delta
	if cohort.progress_seconds < CONFIG.stage_seconds(cohort.stage):
		return
	cohort.progress_seconds = 0.0
	match cohort.stage:
		"egg": cohort.stage = "larva"
		"larva":
			cohort.stage = "pupa"
			pile.environment.survived(cohort.environment_exposure)
			if cohort.repair_comparison: pile.repair_candidate=true
		"pupa":
			if pile.workers.add_living_workers("available", cohort.count, "Brood emerged at " + pile.id):
				if cohort.adaptation_trial:
					var commitment: String = "adaptation:" + pile.id
					var released: bool = pile.workers.release(commitment, AdaptationRules.NURSES)
					assert(released)
					var retired: bool = pile.workers.retire_commitment(commitment)
					assert(retired)
				pile.register_emergence(cohort)
				if cohort.rain_comparison and not pile.chemistry_candidate:
					var chance: float = AdaptationRules.CHEMISTRY.variation_chance * float(cohort.count) / CONFIG.starting_count
					pile.chemistry_candidate = _run.genetic_rng.randf() < chance
				if cohort.recognition_comparison and not pile.recognition_candidate:
					var chance: float = AdaptationRules.RECOGNITION.variation_chance * float(cohort.count) / CONFIG.starting_count
					pile.recognition_candidate = _run.genetic_rng.randf() < chance
				pile.brood_matured_total += cohort.count
				pile.brood_cohorts.erase(cohort)
			else:
				cohort.progress_seconds = CONFIG.pupa_seconds - delta
