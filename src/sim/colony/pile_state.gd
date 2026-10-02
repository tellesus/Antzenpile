class_name PileState
extends RefCounted

const Ledger = preload("res://src/sim/colony/worker_ledger.gd")
const Brood = preload("res://src/sim/colony/brood_cohort.gd")
const BROOD_CONFIG = preload("res://data/resources/default_brood.tres")
const FOOD_CONFIG = preload("res://data/resources/default_food_exchange.tres")
const NURSERY_CONFIG = preload("res://data/resources/default_nursery_development.tres")
const RESOURCE_IDS: Array[String] = ["carbohydrate", "protein", "water"]
var id: String = "home"
var position: Vector2 = Vector2(20, 20)
var queen_count: int = 1
var workers: WorkerLedger = Ledger.new()
var resources: Dictionary[String, float] = {"carbohydrate": 0.0, "protein": 0.0, "water": 0.0}
var brood_cohorts: Array[BroodCohort] = []
var brood_matured_total: int = 0
var brood_started_total: int = 1
var brood_lost_total: int = 0
var adaptation_repertoire: String = ""
var adapted_workers_total: int = 0
var adapted_workers_lost: int = 0
var genetics: GeneticRepertoire = GeneticRepertoire.new()
var rain_trace_observed: bool = false
var chemistry_candidate: bool = false
var nursery_state: String = "primitive"
var nursery_progress_seconds: float = 0.0
var food_exchange_state: String = "primitive"
var food_exchange_progress_seconds: float = 0.0
var workers_total: int:
	get: return workers.total
var workers_available: int:
	get: return workers.available


func to_dict() -> Dictionary:
	var brood_records: Array[Dictionary] = []
	for cohort: BroodCohort in brood_cohorts:
		brood_records.append(cohort.to_dict())
	return {"id": id, "position": [position.x, position.y], "queen_count": queen_count,
		"workers": workers.to_dict(), "resources": resources.duplicate(),
		"brood_cohorts": brood_records, "brood_matured_total": brood_matured_total,
		"brood_started_total": brood_started_total, "brood_lost_total": brood_lost_total,
		"adaptation_repertoire": adaptation_repertoire, "adapted_workers_total": adapted_workers_total,
		"adapted_workers_lost": adapted_workers_lost,
		"genetics": genetics.to_dict(),
		"rain_trace_observed": rain_trace_observed, "chemistry_candidate": chemistry_candidate,
		"nursery_state": nursery_state, "nursery_progress_seconds": nursery_progress_seconds,
		"food_exchange_state": food_exchange_state,
		"food_exchange_progress_seconds": food_exchange_progress_seconds}


func nursery_brood_capacity() -> int:
	return BROOD_CONFIG.developed_nursery_brood_capacity if nursery_state == "developed" else BROOD_CONFIG.primitive_nursery_brood_capacity


func nursery_occupied_space() -> int:
	var occupied: int = 0
	for cohort: BroodCohort in brood_cohorts:
		occupied += cohort.count
	return occupied


func nursery_care_capacity() -> int:
	var carers: int = workers_available + (AdaptationRules.NURSES if trial_cohort() != null else 0)
	return mini(nursery_max_care_capacity(), floori(float(carers * BROOD_CONFIG.primitive_nursery_care_capacity) / BROOD_CONFIG.available_carers_required))


func trial_cohort() -> BroodCohort:
	for cohort: BroodCohort in brood_cohorts:
		if cohort.adaptation_trial:
			return cohort
	return null


func adaptation_fraction() -> float:
	return float(adapted_workers_total) / workers_total if workers_total > 0 else 0.0


func chemistry_fraction() -> float:
	return float(genetics.count_trait("persistent")) / workers_total if workers_total > 0 else 0.0


func lose_workers(pool: String, amount: Variant, adapted_amount: Variant, reason: String, exact_profile: Variant = null) -> bool:
	# The commitment owner reconciles its own travelers/jobs in this same event.
	if not Ledger.valid_count(amount) or not Ledger.valid_count(adapted_amount) or adapted_amount > amount:
		return false
	if adapted_amount > adapted_workers_total or amount - adapted_amount > workers_total - adapted_workers_total or adapted_amount > Ledger.MAX_COUNT - adapted_workers_lost:
		return false
	var plan: Dictionary[String, int] = {}
	if exact_profile != null:
		if not exact_profile is String:
			return false
		var available: int = workers_total - genetics.count_profiles() if exact_profile == "" else genetics.living.get(exact_profile, 0)
		var has_foraging: bool = adaptation_repertoire != "" and adaptation_repertoire in GeneticRepertoire.traits_for(exact_profile)
		if amount > available or adapted_amount != (amount if has_foraging else 0):
			return false
		plan[exact_profile] = int(amount)
	else:
		# Compatibility API can remove mixed baseline/foraging adults atomically.
		var keys: Array[String] = [""]
		keys.append_array(genetics.living.keys())
		for category: bool in [false, true]:
			var remaining: int = int(adapted_amount if category else amount - adapted_amount)
			for key: String in keys:
				if (adaptation_repertoire != "" and adaptation_repertoire in GeneticRepertoire.traits_for(key)) != category:
					continue
				var available: int = workers_total - genetics.count_profiles() if key == "" else genetics.living[key]
				var removed: int = mini(remaining, available)
				if removed > 0:
					plan[key] = removed
					remaining -= removed
			if remaining > 0:
				return false
	if not workers.remove_living_workers(pool, amount, reason):
		return false
	for key: String in plan:
		genetics.remove_profile(key, plan[key])
	adapted_workers_total -= int(adapted_amount)
	adapted_workers_lost += int(adapted_amount)
	return true


func register_emergence(cohort: BroodCohort) -> void:
	genetics.emerge(cohort.inherited_traits, cohort.count, cohort.adaptation_id if cohort.adaptation_trial else "")
	if cohort.adaptation_trial and cohort.adaptation_id in ["lean", "load"]:
		adaptation_repertoire = cohort.adaptation_id
	adapted_workers_total = genetics.count_trait(adaptation_repertoire)


func nursery_max_care_capacity() -> int:
	return BROOD_CONFIG.developed_nursery_care_capacity if nursery_state == "developed" else BROOD_CONFIG.primitive_nursery_care_capacity


func deposit_resource(resource_id: String, amount: float) -> bool:
	if not resources.has(resource_id) or not is_finite(amount) or amount < 0.0 or not is_finite(resources[resource_id] + amount):
		return false
	# Fixed-tick rain uses fractional deposits; match the five-decimal debit precision
	# so JSON save/reload preserves exact resource continuation.
	resources[resource_id] = roundf((resources[resource_id] + amount) * 100000.0) / 100000.0
	return true


func consume_resources(costs: Dictionary) -> bool:
	for resource_id: String in costs:
		var amount: Variant = costs[resource_id]
		if not resources.has(resource_id) or not typeof(amount) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(amount)) or amount < 0.0 or resources[resource_id] < amount:
			return false
	for resource_id: String in costs:
		# Authored brood and developed-exchange costs use five decimal places; quantize debits to avoid
		# accumulated binary drift across full-precision JSON continuations.
		resources[resource_id] = maxf(0.0, roundf((resources[resource_id] - float(costs[resource_id])) * 100000.0) / 100000.0)
	return true


func restore(data: Dictionary) -> bool:
	if not data.has_all(["id", "position", "queen_count", "workers", "resources", "brood_cohorts", "brood_matured_total", "food_exchange_state", "food_exchange_progress_seconds"]) or not data.id is String or data.id.is_empty() or not Ledger.valid_count(data.queen_count) or not data.food_exchange_state in ["primitive", "developing", "developed"]:
		return false
	if not typeof(data.food_exchange_progress_seconds) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.food_exchange_progress_seconds)) or data.food_exchange_progress_seconds < 0.0:
		return false
	if not data.position is Array or data.position.size() != 2 or not data.workers is Dictionary:
		return false
	for value: Variant in data.position:
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	var restored := Ledger.new()
	if not restored.restore(data.workers):
		return false
	if not data.resources is Dictionary or data.resources.size() != RESOURCE_IDS.size():
		return false
	var restored_resources: Dictionary[String, float] = {}
	for resource_id: String in RESOURCE_IDS:
		if not data.resources.has(resource_id) or not typeof(data.resources[resource_id]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.resources[resource_id])) or data.resources[resource_id] < 0.0:
			return false
		restored_resources[resource_id] = float(data.resources[resource_id])
	var restored_nursery_state: Variant = data.get("nursery_state", "primitive")
	var restored_nursery_progress: Variant = data.get("nursery_progress_seconds", 0.0)
	if not restored_nursery_state in ["primitive", "developing", "developed"] or not typeof(restored_nursery_progress) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(restored_nursery_progress)) or restored_nursery_progress < 0.0:
		return false
	var max_cohorts: int = 2 if restored_nursery_state == "developed" else 1
	if not data.brood_cohorts is Array or data.brood_cohorts.size() > max_cohorts or not Ledger.valid_count(data.brood_matured_total):
		return false
	var restored_brood: Array[BroodCohort] = []
	for record: Variant in data.brood_cohorts:
		var cohort := Brood.new()
		if not record is Dictionary or not cohort.restore(record):
			return false
		restored_brood.append(cohort)
	var emerged: int = int(data.brood_matured_total)
	var legacy: bool = not data.has("brood_started_total")
	var started: Variant = data.get("brood_started_total", emerged / BROOD_CONFIG.starting_count + restored_brood.size())
	var brood_lost: Variant = data.get("brood_lost_total", 0)
	if not Ledger.valid_count(started) or started < 1 or not Ledger.valid_count(brood_lost) or (legacy and (emerged % BROOD_CONFIG.starting_count != 0 or brood_lost != 0)):
		return false
	var occupied: int = 0
	var cohort_ids: Dictionary[String, bool] = {}
	var total_started: int = int(started)
	var active_losses: int = 0
	for cohort: BroodCohort in restored_brood:
		occupied += cohort.count
		active_losses += cohort.lost_count
		var suffix: String = cohort.id.trim_prefix("brood_")
		if cohort.id != "brood_" + suffix or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 1 or suffix.to_int() > total_started or cohort_ids.has(cohort.id):
			return false
		cohort_ids[cohort.id] = true
	if emerged + int(brood_lost) + occupied != total_started * BROOD_CONFIG.starting_count or active_losses > brood_lost:
		return false
	var brood_limit: int = BROOD_CONFIG.developed_nursery_brood_capacity if restored_nursery_state == "developed" else BROOD_CONFIG.primitive_nursery_brood_capacity
	if occupied > brood_limit:
		return false
	if restored_nursery_state != "developed" and not restored_brood.is_empty() and restored_brood[0].id != "brood_%d" % total_started:
		return false
	var repertoire: Variant = data.get("adaptation_repertoire", "")
	var rain_observed: Variant = data.get("rain_trace_observed", false)
	var candidate: Variant = data.get("chemistry_candidate", false)
	if typeof(rain_observed) != TYPE_BOOL or typeof(candidate) != TYPE_BOOL or (candidate and (not rain_observed or emerged < 1)):
		return false
	var adapted: Variant = data.get("adapted_workers_total", 0)
	var adapted_lost: Variant = data.get("adapted_workers_lost", 0)
	if not repertoire is String or not (repertoire == "" or AdaptationRules.valid_trait(repertoire)) or not Ledger.valid_count(adapted) or not Ledger.valid_count(adapted_lost) or adapted > restored.total or adapted_lost > restored.lost_total or adapted > emerged or adapted_lost > emerged - adapted:
		return false
	var lifetime_adapted: int = int(adapted) + int(adapted_lost)
	if brood_lost == 0 and lifetime_adapted % BROOD_CONFIG.starting_count != 0:
		return false
	if (repertoire == "") != (lifetime_adapted == 0):
		return false
	var genetic_data: Variant = data.get("genetics", {"established": [] if repertoire == "" else [repertoire], "living": {} if adapted == 0 else {repertoire: adapted}, "lost": {} if adapted_lost == 0 else {repertoire: adapted_lost}})
	var restored_genetics := GeneticRepertoire.new()
	if not genetic_data is Dictionary or not restored_genetics.restore(genetic_data, restored.total, restored.lost_total, emerged):
		return false
	if restored_genetics.count_trait(repertoire) != adapted or restored_genetics.count_trait(repertoire, true) != adapted_lost or ("lean" in restored_genetics.established or "load" in restored_genetics.established) != (repertoire != ""):
		return false
	if "persistent" in restored_genetics.established and not candidate:
		return false
	if brood_lost == 0:
		var profiles: Array = restored_genetics.living.keys()
		for key: String in restored_genetics.lost:
			if key not in profiles:
				profiles.append(key)
		for key: String in profiles:
			if (restored_genetics.living.get(key, 0) + restored_genetics.lost.get(key, 0)) % BROOD_CONFIG.starting_count != 0:
				return false
	var trials: int = 0
	for cohort: BroodCohort in restored_brood:
		if cohort.adaptation_trial:
			trials += 1
			if cohort.adaptation_id in restored_genetics.established or (cohort.adaptation_id in ["lean", "load"] and repertoire != ""):
				return false
			if cohort.adaptation_id == "persistent" and not candidate:
				return false
			var trial_traits: Array[String] = restored_genetics.established.duplicate()
			trial_traits.append(cohort.adaptation_id)
			if GeneticRepertoire.profile(cohort.inherited_traits) != GeneticRepertoire.profile(trial_traits):
				return false
		elif cohort.adaptation_id != "" and cohort.adaptation_id != repertoire:
			return false
		for trait_id: String in cohort.inherited_traits:
			if trait_id not in restored_genetics.established and not (cohort.adaptation_trial and trait_id == cohort.adaptation_id):
				return false
		if cohort.rain_comparison and not rain_observed:
			return false
	if trials > 1:
		return false
	var adaptation_commitment: String = "adaptation:" + data.id
	var adaptation_record: Dictionary = restored.to_dict().commitments.get(adaptation_commitment, {})
	if trials == 1:
		if adaptation_record.get("kind") != "internal" or adaptation_record.get("owner_id") != data.id or adaptation_record.get("count") != AdaptationRules.NURSES:
			return false
	elif not adaptation_record.is_empty():
		return false
	var nursery_commitment: String = "nursery:" + data.id
	var nursery_record: Dictionary = restored.to_dict().commitments.get(nursery_commitment, {})
	if restored_nursery_state == "developing":
		if restored_nursery_progress >= NURSERY_CONFIG.build_seconds or nursery_record.get("kind") != "internal" or nursery_record.get("owner_id") != data.id or nursery_record.get("count") != NURSERY_CONFIG.workers_required:
			return false
	elif not nursery_record.is_empty() or restored_nursery_progress != (NURSERY_CONFIG.build_seconds if restored_nursery_state == "developed" else 0.0):
		return false
	var commitment: String = "food_exchange:" + data.id
	var record: Dictionary = restored.to_dict().commitments.get(commitment, {})
	if data.food_exchange_state == "developing":
		if data.food_exchange_progress_seconds >= FOOD_CONFIG.build_seconds or record.get("kind") != "internal" or record.get("owner_id") != data.id or record.get("count") != FOOD_CONFIG.workers_required:
			return false
	elif not record.is_empty() or data.food_exchange_progress_seconds != (FOOD_CONFIG.build_seconds if data.food_exchange_state == "developed" else 0.0):
		return false
	id = data.id
	position = Vector2(data.position[0], data.position[1])
	queen_count = int(data.queen_count)
	workers = restored
	resources = restored_resources
	brood_cohorts = restored_brood
	brood_matured_total = int(data.brood_matured_total)
	brood_started_total = int(started)
	brood_lost_total = int(brood_lost)
	adaptation_repertoire = repertoire
	adapted_workers_total = int(adapted)
	adapted_workers_lost = int(adapted_lost)
	genetics = restored_genetics
	rain_trace_observed = rain_observed
	chemistry_candidate = candidate
	nursery_state = restored_nursery_state
	nursery_progress_seconds = float(restored_nursery_progress)
	food_exchange_state = data.food_exchange_state
	food_exchange_progress_seconds = float(data.food_exchange_progress_seconds)
	return true
