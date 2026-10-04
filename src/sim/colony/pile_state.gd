class_name PileState
extends RefCounted

var midden := SanitationState.new()
var humidity := HumidityState.new()
var food_toxicity := FoodToxicityState.new()
var brood_health := BroodHealthState.new()
var temperature := TemperatureState.new()
var reproduction := ReproductionState.new()

const Ledger = preload("res://src/sim/colony/worker_ledger.gd")
const Brood = preload("res://src/sim/colony/brood_cohort.gd")
const BROOD_CONFIG = preload("res://data/resources/default_brood.tres")
const FOOD_CONFIG = preload("res://data/resources/default_food_exchange.tres")
const NURSERY_CONFIG = preload("res://data/resources/default_nursery_development.tres")
const RESOURCE_IDS: Array[String] = ["carbohydrate", "protein", "water"]
var foundation: Dictionary = {}
var id: String = "home"
var position: Vector2 = Vector2(20, 20)
var queen_count: int = 1
var workers: WorkerLedger = Ledger.new()
var resources: Dictionary[String, float] = {"carbohydrate": 0.0, "protein": 0.0, "water": 0.0}
var brood_cohorts: Array[BroodCohort] = []
var brood_matured_total: int = 0
var brood_started_total: int = 1
var brood_lost_total: int = 0
var brood_intent: String = "manual"
var queued_adaptation: String = ""
var adaptation_repertoire: String = ""
var adapted_workers_total: int = 0
var adapted_workers_lost: int = 0
var genetics: GeneticRepertoire = GeneticRepertoire.new()
var rain_trace_observed: bool = false
var chemistry_candidate: bool = false
var recognition_experience: bool = false
var recognition_candidate: bool = false
var nursery_state: String = "primitive"
var nursery_progress_seconds: float = 0.0
var nursery_expansion_state: String = "latent"
var nursery_expansion_progress: float = 0.0
var food_exchange_state: String = "primitive"
var food_exchange_progress_seconds: float = 0.0
var workers_total: int:
	get: return workers.total
var workers_available: int:
	get: return workers.available
var workers_assignable: int:
	get: return maxi(0, workers_available - brood_care_workers_required())


func brood_care_workers_required(extra_brood: int = 0) -> int:
	var occupied: int = nursery_occupied_space() - reproduction.occupied_space() + extra_brood
	var required: int = ceili(float(occupied * BROOD_CONFIG.available_carers_required) / BROOD_CONFIG.primitive_nursery_care_capacity)
	return maxi(0, required - (AdaptationRules.NURSES if trial_cohort() != null else 0))


func allocate_workers(commitment: String, amount: Variant) -> bool:
	if not Ledger.valid_count(amount) or amount > workers_assignable:
		workers.last_error = "Workers held for brood care" if Ledger.valid_count(amount) and amount <= workers_available else "Insufficient workers"
		return false
	return workers.allocate(commitment, amount)


func to_dict() -> Dictionary:
	var brood_records: Array[Dictionary] = []
	for cohort: BroodCohort in brood_cohorts:
		brood_records.append(cohort.to_dict())
	var record: Dictionary={"id": id, "position": [position.x, position.y], "queen_count": queen_count,
		"workers": workers.to_dict(), "resources": resources.duplicate(),
		"brood_cohorts": brood_records, "brood_matured_total": brood_matured_total,
		"brood_started_total": brood_started_total, "brood_lost_total": brood_lost_total,
		"brood_intent": brood_intent,
		"queued_adaptation": queued_adaptation,
		"adaptation_repertoire": adaptation_repertoire, "adapted_workers_total": adapted_workers_total,
		"adapted_workers_lost": adapted_workers_lost,
		"genetics": genetics.to_dict(),
		"rain_trace_observed": rain_trace_observed, "chemistry_candidate": chemistry_candidate,
		"recognition_experience": recognition_experience, "recognition_candidate": recognition_candidate,
		"nursery_state": nursery_state, "nursery_progress_seconds": nursery_progress_seconds,
		"nursery_expansion": {"state": nursery_expansion_state, "progress_seconds": nursery_expansion_progress},
		"food_exchange_state": food_exchange_state, "food_toxicity": food_toxicity.to_dict(),
		"brood_health": brood_health.to_dict(), "temperature": temperature.to_dict(), "reproduction": reproduction.to_dict(),
		"food_exchange_progress_seconds": food_exchange_progress_seconds, "midden": midden.to_dict(), "humidity": humidity.to_dict()}
	if not foundation.is_empty(): record.foundation=foundation.duplicate(true)
	return record


func offspring_traits() -> Array[String]:
	var result: Array[String]=[]
	result.assign(foundation.queen_traits if not foundation.is_empty() else genetics.established)
	return result


func nursery_brood_capacity() -> int:
	if nursery_expansion_state == "developed": return NURSERY_CONFIG.expansion_capacity
	return BROOD_CONFIG.developed_nursery_brood_capacity if nursery_state == "developed" else BROOD_CONFIG.primitive_nursery_brood_capacity


func nursery_occupied_space() -> int:
	var occupied: int = reproduction.occupied_space()
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


func combat_multiplier() -> float:
	var share: float = float(genetics.count_trait("fighter")) / workers_total if workers_total > 0 else 0.0
	return snappedf(1.0 + AdaptationRules.FIGHTING.extra_combat_weight * share, 0.00001)


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


func move_workers_to(destination: PileState, pool: String, amount: int) -> bool:
	if destination==null or destination==self or amount<=0 or workers.count(pool)<amount: return false
	var plan: Dictionary[String,int]=genetics.migration_plan(amount,workers_total)
	if genetics.migration_count(plan)!=amount: return false
	var combined: Array[String]=destination.genetics.established.duplicate()
	for key: String in plan:
		for trait_id: String in GeneticRepertoire.traits_for(key):
			if trait_id not in combined: combined.append(trait_id)
	if not AdaptationRules.compatible(combined): return false
	if not workers.move_to(destination.workers,pool,"available",amount,"Interpile worker transfer"): return false
	for key: String in plan:
		for trait_id: String in GeneticRepertoire.traits_for(key):
			if trait_id not in destination.genetics.established: destination.genetics.established.append(trait_id)
	destination.genetics.established.sort()
	genetics.move_profiles_to(destination.genetics,plan)
	# Arriving expressed adults retain the earned repertoire prerequisites. Their
	# phenotype does not replace the destination queen's captured lineage.
	if "persistent" in destination.genetics.established:
		destination.rain_trace_observed = destination.rain_trace_observed or rain_trace_observed
		destination.chemistry_candidate = destination.chemistry_candidate or chemistry_candidate
	if "security" in destination.genetics.established or "tolerance" in destination.genetics.established:
		destination.recognition_experience = destination.recognition_experience or recognition_experience
		destination.recognition_candidate = destination.recognition_candidate or recognition_candidate
	for pile: PileState in [self,destination]:
		for trait_id: String in pile.genetics.established:
			if trait_id in ["lean","load"]: pile.adaptation_repertoire=trait_id
		pile.adapted_workers_total=pile.genetics.count_trait(pile.adaptation_repertoire)
	return true


func register_emergence(cohort: BroodCohort) -> void:
	genetics.emerge(cohort.inherited_traits, cohort.count, cohort.adaptation_id if cohort.adaptation_trial else "")
	if cohort.adaptation_trial and cohort.adaptation_id in ["lean", "load"]:
		adaptation_repertoire = cohort.adaptation_id
	adapted_workers_total = genetics.count_trait(adaptation_repertoire)


func nursery_max_care_capacity() -> int:
	if nursery_expansion_state == "developed": return NURSERY_CONFIG.expansion_capacity
	return BROOD_CONFIG.developed_nursery_care_capacity if nursery_state == "developed" else BROOD_CONFIG.primitive_nursery_care_capacity


func deposit_resource(resource_id: String, amount: float, contaminant_mass: float = 0.0) -> bool:
	if not resources.has(resource_id) or not is_finite(amount) or amount < 0.0 or not is_finite(resources[resource_id] + amount):
		return false
	if not is_finite(contaminant_mass) or contaminant_mass < 0 or contaminant_mass > amount or (contaminant_mass > 0 and resource_id != "carbohydrate"): return false
	# Fixed-tick rain uses fractional deposits; match the five-decimal debit precision
	# so JSON save/reload preserves exact resource continuation.
	resources[resource_id] = roundf((resources[resource_id] + amount) * 100000.0) / 100000.0
	if contaminant_mass > 0: food_toxicity.mass = minf(resources.carbohydrate,roundf((food_toxicity.mass + contaminant_mass) * 100000000.0) / 100000000.0)
	return true


func consume_resources(costs: Dictionary) -> bool:
	for resource_id: String in costs:
		var amount: Variant = costs[resource_id]
		if not resources.has(resource_id) or not typeof(amount) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(amount)) or amount < 0.0 or resources[resource_id] < amount:
			return false
	for resource_id: String in costs:
		# Authored brood and developed-exchange costs use five decimal places; quantize debits to avoid
		# accumulated binary drift across full-precision JSON continuations.
		if resource_id == "carbohydrate" and resources.carbohydrate > 0:
			food_toxicity.mass = maxf(0.0,roundf(food_toxicity.mass * (1.0 - float(costs[resource_id]) / resources.carbohydrate) * 100000000.0) / 100000000.0)
		resources[resource_id] = maxf(0.0, roundf((resources[resource_id] - float(costs[resource_id])) * 100000.0) / 100000.0)
		if resource_id == "carbohydrate": food_toxicity.mass = minf(food_toxicity.mass,resources.carbohydrate)
	return true


func restore(data: Dictionary) -> bool:
	if not data.has_all(["id", "position", "queen_count", "workers", "resources", "brood_cohorts", "brood_matured_total", "food_exchange_state", "food_exchange_progress_seconds"]) or not data.id is String or data.id.is_empty() or not Ledger.valid_count(data.queen_count) or not data.food_exchange_state in ["primitive", "developing", "developed"]:
		return false
	if not typeof(data.food_exchange_progress_seconds) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.food_exchange_progress_seconds)) or data.food_exchange_progress_seconds < 0.0:
		return false
	var restored_intent: Variant = data.get("brood_intent", "manual")
	if not restored_intent is String or restored_intent not in ["manual", "grow"]: return false
	if not data.position is Array or data.position.size() != 2 or not data.workers is Dictionary:
		return false
	for value: Variant in data.position:
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	var founding_data: Variant=data.get("foundation",{})
	if not founding_data is Dictionary: return false
	var founder_traits: Array[String]=[]
	if not founding_data.is_empty():
		if data.id!="satellite_1" or founding_data.size()!=4 or not founding_data.has_all(["parent_id","route_id","queen_traits","founded_tick"]) or founding_data.parent_id!="home" or not founding_data.route_id is String or founding_data.route_id.is_empty() or not WorkerLedger.valid_count(founding_data.founded_tick) or not founding_data.queen_traits is Array: return false
		for trait_id: Variant in founding_data.queen_traits:
			if not trait_id is String or not AdaptationRules.valid_trait(trait_id) or trait_id in founder_traits: return false
			founder_traits.append(trait_id)
		if not AdaptationRules.compatible(founder_traits) or data.queen_count!=1: return false
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
	var restored_toxicity := FoodToxicityState.new()
	var toxicity_data: Variant = data.get("food_toxicity",restored_toxicity.to_dict())
	if not toxicity_data is Dictionary or not restored_toxicity.restore(toxicity_data,restored_resources.carbohydrate,restored.lost_total): return false
	var restored_nursery_progress: Variant = data.get("nursery_progress_seconds", 0.0)
	if not restored_nursery_state in ["primitive", "developing", "developed"] or not typeof(restored_nursery_progress) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(restored_nursery_progress)) or restored_nursery_progress < 0.0:
		return false
	var expansion: Variant = data.get("nursery_expansion", {"state": "latent", "progress_seconds": 0.0})
	if not expansion is Dictionary or not expansion.has_all(["state", "progress_seconds"]) or not expansion.state in ["latent", "available", "developing", "developed"]:
		return false
	if not typeof(expansion.progress_seconds) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(expansion.progress_seconds)) or expansion.progress_seconds < 0.0:
		return false
	if expansion.state != "latent" and (restored_nursery_state != "developed" or not Ledger.valid_count(data.brood_matured_total) or data.brood_matured_total < NURSERY_CONFIG.expansion_matured_required):
		return false
	var max_cohorts: int = NURSERY_CONFIG.expansion_capacity / BROOD_CONFIG.starting_count if expansion.state == "developed" else 2 if restored_nursery_state == "developed" else 1
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
	if not Ledger.valid_count(started) or (started < 1 and founding_data.is_empty()) or not Ledger.valid_count(brood_lost) or (legacy and (emerged % BROOD_CONFIG.starting_count != 0 or brood_lost != 0)):
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
	if expansion.state == "developed": brood_limit = NURSERY_CONFIG.expansion_capacity
	if occupied > brood_limit:
		return false
	if restored_nursery_state != "developed" and not restored_brood.is_empty() and restored_brood[0].id != "brood_%d" % total_started:
		return false
	var repertoire: Variant = data.get("adaptation_repertoire", "")
	var rain_observed: Variant = data.get("rain_trace_observed", false)
	var candidate: Variant = data.get("chemistry_candidate", false)
	var recognition_seen: Variant = data.get("recognition_experience", false)
	var recognition_available: Variant = data.get("recognition_candidate", false)
	if typeof(recognition_seen) != TYPE_BOOL or typeof(recognition_available) != TYPE_BOOL or (recognition_available and (not recognition_seen or emerged+restored.transferred_in < 1)):
		return false
	if typeof(rain_observed) != TYPE_BOOL or typeof(candidate) != TYPE_BOOL or (candidate and (not rain_observed or emerged+restored.transferred_in < 1)):
		return false
	var adapted: Variant = data.get("adapted_workers_total", 0)
	var adapted_lost: Variant = data.get("adapted_workers_lost", 0)
	if not repertoire is String or not (repertoire == "" or AdaptationRules.valid_trait(repertoire)) or not Ledger.valid_count(adapted) or not Ledger.valid_count(adapted_lost) or adapted > restored.total or adapted_lost > restored.lost_total or adapted+adapted_lost>emerged+restored.transferred_in:
		return false
	var lifetime_adapted: int = int(adapted) + int(adapted_lost)
	if brood_lost == 0 and restored.transferred_in==0 and restored.transferred_out==0 and lifetime_adapted % BROOD_CONFIG.starting_count != 0:
		return false
	if (repertoire == "") != (lifetime_adapted == 0) and repertoire not in founder_traits and restored.transferred_out==0:
		return false
	var genetic_data: Variant = data.get("genetics", {"established": [] if repertoire == "" else [repertoire], "living": {} if adapted == 0 else {repertoire: adapted}, "lost": {} if adapted_lost == 0 else {repertoire: adapted_lost}})
	var restored_genetics := GeneticRepertoire.new()
	if not genetic_data is Dictionary or not restored_genetics.restore(genetic_data, restored.total, restored.lost_total, emerged, founder_traits):
		return false
	for trait_id: String in founder_traits:
		if trait_id not in restored_genetics.established: return false
	if restored_genetics.migration_count(restored_genetics.imported)!=restored.transferred_in or restored_genetics.migration_count(restored_genetics.exported)!=restored.transferred_out: return false
	if restored_genetics.count_trait(repertoire) != adapted or restored_genetics.count_trait(repertoire, true) != adapted_lost or ("lean" in restored_genetics.established or "load" in restored_genetics.established) != (repertoire != ""):
		return false
	if "persistent" in restored_genetics.established and not candidate:
		return false
	if ("security" in restored_genetics.established or "tolerance" in restored_genetics.established) and not recognition_available:
		return false
	if brood_lost == 0:
		var profiles: Array = restored_genetics.living.keys()
		for key: String in restored_genetics.lost:
			if key not in profiles:
				profiles.append(key)
		for histories: Dictionary in [restored_genetics.imported,restored_genetics.exported]:
			for key: String in histories:
				if key!="" and key not in profiles: profiles.append(key)
		for key: String in profiles:
			if (restored_genetics.living.get(key, 0) + restored_genetics.lost.get(key, 0)+restored_genetics.exported.get(key,0)-restored_genetics.imported.get(key,0)) % BROOD_CONFIG.starting_count != 0:
				return false
	var trials: int = 0
	var locked_trait: String = ""
	for cohort: BroodCohort in restored_brood:
		if cohort.adaptation_trial:
			trials += 1
			locked_trait = cohort.adaptation_id
			if cohort.adaptation_id in restored_genetics.established or (cohort.adaptation_id in ["lean", "load"] and repertoire != ""):
				return false
			if cohort.adaptation_id == "persistent" and not candidate:
				return false
			if cohort.adaptation_id in ["security", "tolerance"] and (not recognition_available or "security" in restored_genetics.established or "tolerance" in restored_genetics.established):
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
		if cohort.recognition_comparison and not recognition_seen:
			return false
	if not founding_data.is_empty():
		if trials>0 or data.get("queued_adaptation", "")!="" or data.get("reproduction", {}).get("phase", "none")!="none": return false
		for cohort: BroodCohort in restored_brood:
			if cohort.inherited_traits!=founder_traits: return false
	if trials > 1:
		return false
	var restored_queue: Variant = data.get("queued_adaptation", "")
	if not restored_queue is String or (restored_queue != "" and not AdaptationRules.queue_eligible(restored_queue, int(data.queen_count), restored_genetics.established, candidate, recognition_available, locked_trait)):
		return false
	var restored_reproduction := ReproductionState.new()
	var reproduction_data: Variant = data.get("reproduction",restored_reproduction.to_dict())
	if not reproduction_data is Dictionary or not restored_reproduction.restore(reproduction_data,restored,data.id,restored_genetics.established,emerged,restored_nursery_state,data.food_exchange_state,int(data.queen_count)): return false
	if occupied+restored_reproduction.occupied_space()>brood_limit: return false
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
	var expansion_commitment: String = "nursery_expansion:" + data.id
	var commitments: Dictionary = restored.to_dict().commitments
	for key: String in commitments:
		if key.begins_with("nursery_expansion:") and key != expansion_commitment: return false
	var expansion_record: Dictionary = commitments.get(expansion_commitment, {})
	if expansion.state == "developing":
		if expansion.progress_seconds >= NURSERY_CONFIG.expansion_seconds or expansion_record.get("kind") != "internal" or expansion_record.get("owner_id") != data.id or expansion_record.get("count") != NURSERY_CONFIG.expansion_workers:
			return false
	elif not expansion_record.is_empty() or expansion.progress_seconds != (NURSERY_CONFIG.expansion_seconds if expansion.state == "developed" else 0.0):
		return false
	var commitment: String = "food_exchange:" + data.id
	var record: Dictionary = restored.to_dict().commitments.get(commitment, {})
	if data.food_exchange_state == "developing":
		if data.food_exchange_progress_seconds >= FOOD_CONFIG.build_seconds or record.get("kind") != "internal" or record.get("owner_id") != data.id or record.get("count") != FOOD_CONFIG.workers_required:
			return false
	elif not record.is_empty() or data.food_exchange_progress_seconds != (FOOD_CONFIG.build_seconds if data.food_exchange_state == "developed" else 0.0):
		return false
	var restored_midden := SanitationState.new()
	var midden_data: Variant = data.get("midden", restored_midden.to_dict())
	if not midden_data is Dictionary or not restored_midden.restore(midden_data, restored, data.id):
		return false
	var restored_humidity := HumidityState.new()
	var humidity_data: Variant = data.get("humidity", restored_humidity.to_dict())
	if not humidity_data is Dictionary or not restored_humidity.restore(humidity_data, restored, data.id, restored_nursery_state):
		return false
	var restored_health := BroodHealthState.new()
	var health_data: Variant = data.get("brood_health", restored_health.to_dict())
	if not health_data is Dictionary or not restored_health.restore(health_data, int(brood_lost)):
		return false
	var restored_temperature := TemperatureState.new()
	var thermal_data: Variant = data.get("temperature", restored_temperature.to_dict())
	if not thermal_data is Dictionary or not restored_temperature.restore(thermal_data, restored_nursery_state): return false
	foundation=founding_data.duplicate(true)
	if not foundation.is_empty(): foundation.queen_traits=founder_traits; foundation.founded_tick=int(foundation.founded_tick)
	temperature = restored_temperature
	reproduction = restored_reproduction
	brood_health = restored_health
	midden = restored_midden
	humidity = restored_humidity
	food_toxicity = restored_toxicity
	id = data.id
	position = Vector2(data.position[0], data.position[1])
	queen_count = int(data.queen_count)
	workers = restored
	resources = restored_resources
	brood_cohorts = restored_brood
	brood_matured_total = int(data.brood_matured_total)
	brood_started_total = int(started)
	brood_lost_total = int(brood_lost)
	brood_intent = restored_intent
	queued_adaptation = restored_queue
	adaptation_repertoire = repertoire
	adapted_workers_total = int(adapted)
	adapted_workers_lost = int(adapted_lost)
	genetics = restored_genetics
	rain_trace_observed = rain_observed
	chemistry_candidate = candidate
	recognition_experience = recognition_seen
	recognition_candidate = recognition_available
	nursery_state = restored_nursery_state
	nursery_expansion_state = expansion.state
	nursery_expansion_progress = float(expansion.progress_seconds)
	nursery_progress_seconds = float(restored_nursery_progress)
	food_exchange_state = data.food_exchange_state
	food_exchange_progress_seconds = float(data.food_exchange_progress_seconds)
	return true
