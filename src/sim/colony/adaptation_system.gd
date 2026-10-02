extends RefCounted
## Starts one biologically funded trial; brood maturation owns its completion.

const BROOD = preload("res://data/resources/default_brood.tres")
var _run: RunState
var last_error: String = ""


func _init(run_state: RunState) -> void:
	_run = run_state


func start(pile_id: String, trait_id: String) -> bool:
	if not AdaptationRules.valid_trait(trait_id):
		return _reject("Unknown adaptation")
	if not _run.colony.piles.has(pile_id):
		return _reject("Unknown pile")
	var pile: PileState = _run.colony.piles[pile_id]
	if pile.queen_count < 1 or pile.adaptation_repertoire != "" or pile.trial_cohort() != null:
		return _reject("Adaptation already chosen or unavailable")
	if pile.nursery_state != "developed" and not pile.brood_cohorts.is_empty() or pile.nursery_brood_capacity() - pile.nursery_occupied_space() < BROOD.starting_count:
		return _reject("Nursery lacks brood space")
	if pile.workers_available < AdaptationRules.NURSES:
		return _reject("Two available nurses required")
	var pending: int = pile.nursery_occupied_space() + BROOD.starting_count
	if pile.brood_started_total >= WorkerLedger.MAX_COUNT or pile.brood_matured_total > WorkerLedger.MAX_COUNT - pending or pile.workers_total > WorkerLedger.MAX_COUNT - pending:
		return _reject("Population limit reached")
	for resource_id: String in AdaptationRules.COSTS:
		if pile.resources[resource_id] < AdaptationRules.COSTS[resource_id]:
			return _reject("Needs 12 carbohydrate, 12 protein, 6 water")
	var commitment: String = "adaptation:" + pile.id
	if not pile.workers.create_commitment(commitment, "internal", pile.id):
		return _reject("Nurse commitment unavailable")
	if not pile.workers.allocate(commitment, AdaptationRules.NURSES):
		pile.workers.retire_commitment(commitment)
		return _reject("Two available nurses required")
	if not pile.consume_resources(AdaptationRules.COSTS):
		pile.workers.release(commitment, AdaptationRules.NURSES)
		pile.workers.retire_commitment(commitment)
		return _reject("Resources unavailable")
	var cohort := BroodCohort.new()
	pile.brood_started_total += 1
	cohort.id = "brood_%d" % pile.brood_started_total
	cohort.adaptation_id = trait_id
	cohort.adaptation_trial = true
	cohort.inherited_traits = pile.genetics.established.duplicate()
	cohort.inherited_traits.append(trait_id)
	cohort.inherited_traits.sort()
	pile.brood_cohorts.append(cohort)
	last_error = ""
	return true


func _reject(reason: String) -> bool:
	last_error = reason
	return false
