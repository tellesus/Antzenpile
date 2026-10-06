class_name SourceCatalog
extends RefCounted
const PROFILES: Dictionary = {
	"flower_nectar":preload("res://data/sources/flower_nectar.tres"),
	"aphid_honeydew":preload("res://data/sources/aphid_honeydew.tres"),
	"insect_remains":preload("res://data/sources/insect_remains.tres"),
	"hunted_arthropod":preload("res://data/sources/hunted_arthropod.tres"),
	"rain_puddle":preload("res://data/sources/rain_puddle.tres"),
	"ripe_fruit":preload("res://data/sources/ripe_fruit.tres"),
	"cracked_seeds":preload("res://data/sources/cracked_seeds.tres"),
	"picnic_crumbs":preload("res://data/sources/picnic_crumbs.tres")}

static func accepts(id: Variant, resource_id: String) -> bool:
	return id is String and (id.is_empty() or PROFILES.has(id) and PROFILES[id].resource_id == resource_id)

static func label(index: int) -> String:
	var result: String = ""
	while index > 0:
		index -= 1; result = String.chr(65 + index % 26) + result; index /= 26
	return result

static func nutrients(id: String, primary: String) -> Dictionary:
	return PROFILES[id].yields.duplicate() if PROFILES.has(id) and not PROFILES[id].yields.is_empty() else {primary:1.0}

static func roles(id: String, primary: String) -> Array:
	return nutrients(id,primary).keys()
