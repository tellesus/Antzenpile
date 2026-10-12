class_name TraitCatalog
extends RefCounted
const IDS: Array[String]=["lean","load","persistent","security","tolerance","fighter","efficient_nurses"]
const DEFINITIONS: Dictionary={
	"lean":preload("res://data/adaptation/traits/lean.tres"),
	"load":preload("res://data/adaptation/traits/load.tres"),
	"persistent":preload("res://data/adaptation/traits/persistent.tres"),
	"security":preload("res://data/adaptation/traits/security.tres"),
	"tolerance":preload("res://data/adaptation/traits/tolerance.tres"),
	"fighter":preload("res://data/adaptation/traits/fighter.tres"),
	"efficient_nurses":preload("res://data/adaptation/traits/efficient_nurses.tres")}
static func food_multiplier(traits: Array[String]) -> float:
	var result: float=1
	for id: String in traits:
		if DEFINITIONS.has(id): result*=DEFINITIONS[id].larval_food_multiplier
	return result

static func reproductive_food_multiplier(traits: Array[String]) -> float:
	# Retain the legacy reproductive feeding rules for the six existing leaves.
	return DEFINITIONS.efficient_nurses.larval_food_multiplier if "efficient_nurses" in traits else 1.0
