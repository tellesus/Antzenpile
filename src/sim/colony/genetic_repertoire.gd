class_name GeneticRepertoire
extends RefCounted
## Disjoint aggregate adult phenotypes. Empty/baseline workers are inferred from the ledger.
## These are cohort expression bundles, not individually simulated genomes or breeders.

var established: Array[String] = []
var living: Dictionary[String, int] = {}
var lost: Dictionary[String, int] = {}
var imported: Dictionary[String,int] = {}
var exported: Dictionary[String,int] = {}


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


func migration_plan(amount: int, adults: int) -> Dictionary[String,int]:
	var plan: Dictionary[String,int]={}
	if amount<0 or amount>adults: return plan
	var counts: Dictionary[String,int]=living.duplicate()
	if adults>count_profiles(): counts[""]=adults-count_profiles()
	var keys: Array=counts.keys(); keys.sort()
	# Deterministic aggregate sampling; no individual worker identities or new RNG.
	for index: int in amount:
		var best: String=""; var ratio: float=INF
		for key: String in keys:
			if plan.get(key,0)>=counts[key]: continue
			var next: float=float(plan.get(key,0)+1)/counts[key]
			if next<ratio: best=key; ratio=next
		plan[best]=plan.get(best,0)+1
	return plan
func move_profiles_to(destination: GeneticRepertoire, plan: Dictionary[String,int]) -> void:
	for key: String in plan:
		var amount: int=plan[key]
		exported[key]=exported.get(key,0)+amount; destination.imported[key]=destination.imported.get(key,0)+amount
		if key!="":
			living[key]-=amount
			if living[key]==0: living.erase(key)
			destination.living[key]=destination.living.get(key,0)+amount
func migration_count(records: Dictionary[String,int], trait_id: String="*") -> int:
	var total: int=0
	for key: String in records:
		if trait_id=="*" or trait_id in traits_for(key): total+=records[key]
	return total
func to_dict() -> Dictionary:
	var record: Dictionary={"established": established.duplicate(), "living": living.duplicate(), "lost": lost.duplicate()}
	if not imported.is_empty() or not exported.is_empty(): record.imported=imported.duplicate(); record.exported=exported.duplicate()
	return record


func restore(data: Dictionary, adults: int, losses: int, emerged: int, inherited: Array[String]=[]) -> bool:
	if not data.get("imported",{}) is Dictionary or not data.get("exported",{}) is Dictionary: return false
	if not data.has_all(["established", "living", "lost"]) or not data.established is Array or not data.living is Dictionary or not data.lost is Dictionary:
		return false
	var genes: Array[String] = []
	for id: Variant in data.established:
		if not id is String or not AdaptationRules.valid_trait(id) or id in genes:
			return false
		genes.append(id)
	if not AdaptationRules.compatible(genes):
		return false
	var populations: Array[Dictionary] = []
	for records: Dictionary in [data.living, data.lost, data.get("imported",{}), data.get("exported",{})]:
		var parsed: Dictionary[String, int] = {}
		var sum: int=0
		for key: Variant in records:
			if not key is String or (key=="" and populations.size()<2) or not WorkerLedger.valid_count(records[key]) or records[key] < 1:
				return false
			var traits: Array[String] = traits_for(key)
			if profile(traits) != key or not AdaptationRules.compatible(traits):
				return false
			var unique: Array[String] = []
			for id: String in traits:
				if id not in genes or id in unique:
					return false
				unique.append(id)
			if records[key]>WorkerLedger.MAX_COUNT-sum: return false
			sum+=int(records[key])
			parsed[key] = int(records[key])
		populations.append(parsed)
	established = genes
	established.sort()
	living.assign(populations[0])
	lost.assign(populations[1])
	imported.assign(populations[2]); exported.assign(populations[3])
	if count_profiles()>adults or count_profiles(true)>losses: return false
	var born: int=0; var keys: Array=living.keys()
	for records: Dictionary in [lost,imported,exported]:
		for key: String in records:
			if key not in keys: keys.append(key)
	for key: String in keys:
		if key=="": continue
		var local_births: int=living.get(key,0)+lost.get(key,0)+exported.get(key,0)-imported.get(key,0)
		if local_births<0 or local_births>emerged-born: return false
		born+=local_births
	for id: String in established:
		if count_trait(id)+count_trait(id,true)+migration_count(exported,id)<1 and id not in inherited: return false
	return true
