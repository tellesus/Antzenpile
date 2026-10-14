class_name SiteCatalog
extends RefCounted
const GENERIC=preload("res://data/sites/generic.tres")
const DEFINITIONS: Dictionary={"loam":preload("res://data/sites/loam.tres"),"root":preload("res://data/sites/root.tres"),"stone":preload("res://data/sites/stone.tres"),"edge":preload("res://data/sites/edge.tres")}
static func accepts(value: Variant, definition: String) -> bool:
	return value is String and (value.is_empty() or definition=="nest_site" and DEFINITIONS.has(value))
static func get_profile(id: String) -> SiteDefinition:
	return DEFINITIONS.get(id,GENERIC)
static func for_pile(pile: PileState) -> SiteDefinition:
	return get_profile(pile.foundation.get("site_profile",""))
