class_name ColonyState
extends RefCounted

const Pile = preload("res://src/sim/colony/pile_state.gd")
const STORAGE = preload("res://data/resources/default_storage.tres")
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
	home.workers.add_living_workers("available", 40, "Initial fixture population")
	home.resources = {"carbohydrate": STORAGE.initial_carbohydrate,
		"protein": STORAGE.initial_protein, "water": STORAGE.initial_water}
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
	piles = restored
	return true
