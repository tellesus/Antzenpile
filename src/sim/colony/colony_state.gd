class_name ColonyState
extends RefCounted

const Pile = preload("res://src/sim/colony/pile_state.gd")
const Brood = preload("res://src/sim/colony/brood_cohort.gd")
const STORAGE = preload("res://data/resources/default_storage.tres")
const INITIAL_HOME_WORKERS: int = 40
var piles: Dictionary[String, PileState] = {}
var workers_total: int:
	get:
		var result: int = 0
		for pile: PileState in piles.values():
			result += pile.workers_total
		return result


func initialize_home(position: Vector2) -> void:
	assert(piles.is_empty())
	var home := Pile.new()
	home.position = position
	home.workers.add_living_workers("available", INITIAL_HOME_WORKERS, "Initial fixture population")
	home.resources = {"carbohydrate": STORAGE.initial_carbohydrate,
		"protein": STORAGE.initial_protein, "water": STORAGE.initial_water}
	home.brood_cohorts.append(Brood.new())
	piles[home.id] = home


func to_dict() -> Dictionary:
	var records: Array[Dictionary] = []
	var ids: Array = piles.keys()
	ids.sort()
	for id: String in ids:
		records.append(piles[id].to_dict())
	return {"piles": records}


func restore(data: Dictionary, bounds: Rect2, home_position: Vector2) -> bool:
	if not data.has("piles") or not data.piles is Array:
		return false
	var restored: Dictionary[String, PileState] = {}
	for value: Variant in data.piles:
		var pile := Pile.new()
		if not value is Dictionary or not pile.restore(value) or restored.has(pile.id) or not bounds.has_point(pile.position):
			return false
		restored[pile.id] = pile
	if not restored.has("home") or restored.home.position != home_position:
		return false
	# This slice has no worker-loss mechanic; reported emergences must exist in the ledger.
	if restored.home.workers_total < INITIAL_HOME_WORKERS + restored.home.brood_matured_total:
		return false
	for pile: PileState in restored.values():
		for commitment_id: String in pile.workers.to_dict().commitments:
			if commitment_id.begins_with("food_exchange:") and commitment_id != "food_exchange:" + pile.id:
				return false
	piles = restored
	return true
