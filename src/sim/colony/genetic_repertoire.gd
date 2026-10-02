class_name GeneticRepertoire
extends RefCounted
## Disjoint aggregate adult phenotypes. Empty/baseline workers are inferred from the ledger.
## These are cohort expression bundles, not individually simulated genomes or breeders.

var established: Array[String] = []
var living: Dictionary[String, int] = {}
var lost: Dictionary[String, int] = {}


static func profile(traits: Array[String]) -> String:
	var sorted: Array[String] = traits.duplicate()
	sorted.sort()
	return "+".join(sorted)


static func traits_for(key: String) -> Array[String]:
	var result: Array[String] = []
	if key != "":
		for id: String in key.split("+"):
			result.append(id)
	return result


func count_trait(id: String, dead: bool = false) -> int:
	var total: int = 0
	var records: Dictionary[String, int] = lost if dead else living
	for key: String in records:
		if id in traits_for(key):
			total += records[key]
	return total


func count_profiles(dead: bool = false) -> int:
	var total: int = 0
	for count: int in (lost if dead else living).values():
		total += count
	return total


func emerge(traits: Array[String], count: int, trial_id: String) -> void:
	if trial_id != "" and trial_id not in established:
		established.append(trial_id)
		established.sort()
	var key: String = profile(traits)
	if key != "":
		living[key] = living.get(key, 0) + count


func loss_profile(adapted: bool, foraging_id: String, total: int, rng: RandomNumberGenerator = null) -> String:
	# Preserve the existing foraging mortality draw; only draw again for mixed bundles.
	var choices: Array[String] = []
	var weights: Array[int] = []
	if not adapted and total > count_profiles():
		choices.append("")
		weights.append(total - count_profiles())
	for key: String in living:
		if living[key] > 0 and (foraging_id != "" and foraging_id in traits_for(key)) == adapted:
			choices.append(key)
			weights.append(living[key])
	if choices.is_empty():
		return ""
	if rng == null or choices.size() == 1:
		return choices[0]
	var total_weight: int = 0
	for weight: int in weights:
		total_weight += weight
	var roll: int = rng.randi_range(1, total_weight)
	for index: int in choices.size():
		roll -= weights[index]
		if roll <= 0:
			return choices[index]
	return choices.back()


func remove_profile(key: String, amount: int) -> void:
	if key == "":
		return
	living[key] -= amount
	lost[key] = lost.get(key, 0) + amount
	if living[key] == 0:
		living.erase(key)


func to_dict() -> Dictionary:
	return {"established": established.duplicate(), "living": living.duplicate(), "lost": lost.duplicate()}


func restore(data: Dictionary, adults: int, losses: int, emerged: int) -> bool:
	if not data.has_all(["established", "living", "lost"]) or not data.established is Array or not data.living is Dictionary or not data.lost is Dictionary:
		return false
	var genes: Array[String] = []
	for id: Variant in data.established:
		if not id is String or not AdaptationRules.valid_trait(id) or id in genes:
			return false
		genes.append(id)
	if "lean" in genes and "load" in genes:
		return false
	var populations: Array[Dictionary] = []
	for records: Dictionary in [data.living, data.lost]:
		var parsed: Dictionary[String, int] = {}
		for key: Variant in records:
			if not key is String or key == "" or not WorkerLedger.valid_count(records[key]) or records[key] < 1:
				return false
			var traits: Array[String] = traits_for(key)
			if profile(traits) != key or ("lean" in traits and "load" in traits):
				return false
			var unique: Array[String] = []
			for id: String in traits:
				if id not in genes or id in unique:
					return false
				unique.append(id)
			parsed[key] = int(records[key])
		populations.append(parsed)
	established = genes
	established.sort()
	living.assign(populations[0])
	lost.assign(populations[1])
	if count_profiles() > adults or count_profiles(true) > losses or count_profiles() + count_profiles(true) > emerged:
		return false
	for id: String in established:
		if count_trait(id) + count_trait(id, true) < 1:
			return false
	return true
