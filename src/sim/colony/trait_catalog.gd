class_name TraitCatalog
extends RefCounted
const IDS: Array[String]=["lean","load","persistent","security","tolerance","fighter","efficient_nurses","heat_resilience","moisture_resilience","rapid_repair"]
const DEFINITIONS: Dictionary={
	"lean":preload("res://data/adaptation/traits/lean.tres"),
	"load":preload("res://data/adaptation/traits/load.tres"),
	"persistent":preload("res://data/adaptation/traits/persistent.tres"),
	"security":preload("res://data/adaptation/traits/security.tres"),
	"tolerance":preload("res://data/adaptation/traits/tolerance.tres"),
	"fighter":preload("res://data/adaptation/traits/fighter.tres"),
	"efficient_nurses":preload("res://data/adaptation/traits/efficient_nurses.tres"),
	"heat_resilience":preload("res://data/adaptation/traits/heat_resilience.tres"),
	"moisture_resilience":preload("res://data/adaptation/traits/moisture_resilience.tres"),
	"rapid_repair":preload("res://data/adaptation/traits/rapid_repair.tres")}
static func food_multiplier(traits: Array[String]) -> float:
	var result: float=1
	for id: String in traits:
		if DEFINITIONS.has(id): result*=DEFINITIONS[id].larval_food_multiplier
	return result

static func reproductive_food_multiplier(traits: Array[String]) -> float:
	# Retain the legacy reproductive feeding rules for the six existing leaves.
	return DEFINITIONS.efficient_nurses.larval_food_multiplier if "efficient_nurses" in traits else 1.0

static func carbohydrate_multiplier(traits: Array[String]) -> float:
	return DEFINITIONS.moisture_resilience.larval_carbohydrate_multiplier if "moisture_resilience" in traits else 1.0
