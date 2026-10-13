class_name PredatorCatalog
extends RefCounted
## Authored physical archetypes; outline names are presentation-owned.
const DEFINITIONS: Dictionary = {"wolf_spider": preload("res://data/ecology/backyard_predator.tres")}

static func accepts(id: Variant) -> bool:
	return id is String and (id.is_empty() or DEFINITIONS.has(id))

static func definition(id: String) -> PredatorDefinition:
	return DEFINITIONS.get(id, preload("res://data/ecology/backyard_predator.tres"))
