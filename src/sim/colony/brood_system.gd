extends RefCounted
## Aggregate brood progression on the run's fixed simulation clock.

const CONFIG = preload("res://data/resources/default_brood.tres")
const FOOD_CONFIG = preload("res://data/resources/default_food_exchange.tres")
var _run: RunState
var last_error: String = ""


func _init(run_state: RunState) -> void:
	_run = run_state


func start(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id):
		last_error = "Unknown pile"
		return false
	var pile: PileState = _run.colony.piles[pile_id]
	if pile.queen_count < 1:
		last_error = "No queen in pile"
		return false
	if pile.nursery_state != "developed" and not pile.brood_cohorts.is_empty():
		last_error = "Nursery already has brood"
		return false
	if pile.nursery_brood_capacity() - pile.nursery_occupied_space() < CONFIG.starting_count:
		last_error = "Nursery lacks brood space"
		return false
	var pending_brood: int = pile.nursery_occupied_space() + CONFIG.starting_count
	if pile.brood_started_total >= WorkerLedger.MAX_COUNT or pile.brood_matured_total > WorkerLedger.MAX_COUNT - pending_brood or pile.workers_total > WorkerLedger.MAX_COUNT - pending_brood:
		last_error = "Population limit reached"
		return false
	var cohort := BroodCohort.new()
	pile.brood_started_total += 1
	cohort.id = "brood_%d" % pile.brood_started_total
	cohort.adaptation_id = pile.adaptation_repertoire
	cohort.inherited_traits = pile.genetics.established.duplicate()
	cohort.rain_comparison = pile.rain_trace_observed and not pile.chemistry_candidate
	cohort.recognition_comparison = pile.recognition_experience and not pile.recognition_candidate
	pile.brood_cohorts.append(cohort)
	last_error = ""
	return true


func lose_one(pile_id: String) -> bool:
	if not _run.colony.piles.has(pile_id):
		return false
	var pile: PileState = _run.colony.piles[pile_id]
	if pile.brood_cohorts.is_empty() or pile.brood_lost_total >= WorkerLedger.MAX_COUNT:
		return false
	# Stable oldest-first choice, no individual brood agents or adult ledger debit.
	var cohort: BroodCohort = pile.brood_cohorts[0]
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
		var occupied: int = pile.nursery_occupied_space()
		var care_fraction: float = minf(1.0, float(pile.nursery_care_capacity()) / occupied) if occupied > 0 else 1.0
		for cohort: BroodCohort in pile.brood_cohorts.duplicate():
			_advance(pile, cohort, delta, care_fraction)


func _advance(pile: PileState, cohort: BroodCohort, delta: float, care_fraction: float) -> void:
	cohort.care = care_fraction
	if cohort.care < 1.0:
		cohort.nutrition = 0.0 if cohort.stage == "larva" else 1.0
		return
	var effective_delta: float = delta * (pile.midden.larval_rate() if cohort.stage == "larva" else 1.0)
	if cohort.stage == "larva":
		var food_multiplier: float = FOOD_CONFIG.developed_larval_food_multiplier if pile.food_exchange_state == "developed" else 1.0
		var costs: Dictionary = {"carbohydrate": cohort.count * CONFIG.carbohydrate_per_larva_second * effective_delta * food_multiplier,
			"protein": cohort.count * CONFIG.protein_per_larva_second * effective_delta * food_multiplier,
			"water": cohort.count * CONFIG.water_per_larva_second * effective_delta * food_multiplier}
		if not pile.consume_resources(costs):
			cohort.nutrition = 0.0
			return
	cohort.nutrition = 1.0
	cohort.progress_seconds += effective_delta
	if cohort.progress_seconds < CONFIG.stage_seconds(cohort.stage):
		return
	cohort.progress_seconds = 0.0
	match cohort.stage:
		"egg": cohort.stage = "larva"
		"larva": cohort.stage = "pupa"
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
