extends RefCounted
## Starts one biologically funded trial; brood maturation owns its completion.

const BROOD = preload("res://data/resources/default_brood.tres")
var _run: RunState
var last_error: String = ""


func _init(run_state: RunState) -> void:
	_run = run_state


func queue_choice(pile_id: String, trait_id: Variant) -> bool:
	if not _run.colony.piles.has(pile_id) or not trait_id is String:
		return _reject("Unknown pile or adaptation")
	var pile: PileState = _run.colony.piles[pile_id]
	if not pile.foundation.is_empty(): return _reject("Daughter lineage selection is not yet available")
	if trait_id != "" and not AdaptationRules.can_queue(pile, trait_id):
		return _reject("Adaptation already locked, inherited or unavailable")
	pile.queued_adaptation = trait_id
	if trait_id.is_empty(): pile.investments.remove("adaptation")
	else: pile.investments.add("adaptation")
	last_error = ""
	return true


func start_queued(pile_id: String, respect_priority: bool=true) -> bool:
	if not _run.colony.piles.has(pile_id): return _reject("Unknown pile")
	var pile: PileState = _run.colony.piles[pile_id]
	if not pile.foundation.is_empty(): return _reject("Daughter lineage selection is not yet available")
	if pile.queued_adaptation.is_empty(): return _reject("No adaptation queued")
	if not start(pile_id, pile.queued_adaptation,respect_priority): return false
	pile.queued_adaptation = ""
	pile.investments.remove("adaptation")
	return true


func queued_status(pile_id: String) -> Dictionary:
	if not _run.colony.piles.has(pile_id): return {}
	var pile: PileState = _run.colony.piles[pile_id]
	return {"trait_id": pile.queued_adaptation,
		"waiting": "priority" if not pile.queued_adaptation.is_empty() and pile.investments.first()=="reproduction" and ReproductionSystem.new(_run).structural_blocker(pile).is_empty() else laying_blocker(pile, pile.queued_adaptation) if not pile.queued_adaptation.is_empty() else "none"}


func laying_blocker(pile: PileState, trait_id: String) -> String:
	if not AdaptationRules.can_select(pile, trait_id): return "trial" if pile.trial_cohort() != null else "unavailable"
	if pile.nursery_state != "developed" and not pile.brood_cohorts.is_empty() or pile.brood_cohorts.size() >= pile.nursery_brood_capacity() / BROOD.starting_count or pile.free_worker_brood_space() < BROOD.starting_count:
		return "space"
	if pile.workers_assignable < AdaptationRules.NURSES: return "nurses"
	var pending: int = pile.nursery_occupied_space() + BROOD.starting_count
	if pile.brood_started_total >= WorkerLedger.MAX_COUNT or pile.brood_matured_total > WorkerLedger.MAX_COUNT - pending or pile.workers_total > WorkerLedger.MAX_COUNT - pending:
		return "population"
	var costs: Dictionary = AdaptationRules.costs(trait_id)
	for resource_id: String in PileState.RESOURCE_IDS:
		if pile.resources[resource_id] < costs[resource_id]: return resource_id
	return "ready"


func start(pile_id: String, trait_id: String, respect_priority: bool=true) -> bool:
	if not AdaptationRules.valid_trait(trait_id):
		return _reject("Unknown adaptation")
	if not _run.colony.piles.has(pile_id):
		return _reject("Unknown pile")
	var pile: PileState = _run.colony.piles[pile_id]
	if not pile.foundation.is_empty(): return _reject("Daughter lineage selection is not yet available")
	if respect_priority and pile.investments.first()=="reproduction": return _reject("Queued reproduction has priority")
	if not pile.queued_adaptation.is_empty() and pile.queued_adaptation != trait_id:
		return _reject("Another adaptation is queued for the next brood")
	var blocker: String = laying_blocker(pile, trait_id)
	if blocker in ["unavailable", "trial"]:
		return _reject("Adaptation already chosen or unavailable")
	if blocker == "space":
		return _reject("Nursery lacks brood space")
	if blocker == "nurses":
		return _reject("Two available nurses required")
	if blocker == "population":
		return _reject("Population limit reached")
	var costs: Dictionary = AdaptationRules.costs(trait_id)
	if blocker != "ready":
		return _reject("Needs %.0f carbohydrate, %.0f protein, %.0f water" % [costs.carbohydrate, costs.protein, costs.water])
	var commitment: String = "adaptation:" + pile.id
	if not pile.workers.create_commitment(commitment, "internal", pile.id):
		return _reject("Nurse commitment unavailable")
	if not pile.allocate_workers(commitment, AdaptationRules.NURSES):
		pile.workers.retire_commitment(commitment)
		return _reject("Two available nurses required")
	if not pile.consume_resources(costs):
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
	cohort.rain_comparison = pile.rain_trace_observed and not pile.chemistry_candidate
	cohort.recognition_comparison = pile.recognition_experience and not pile.recognition_candidate
	pile.brood_cohorts.append(cohort)
	pile.queued_adaptation = ""
	pile.investments.remove("adaptation")
	last_error = ""
	return true


func _reject(reason: String) -> bool:
	last_error = reason
	return false
