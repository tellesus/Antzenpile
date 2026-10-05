class_name SourceCatalog
extends RefCounted
const PROFILES: Dictionary = {
	"flower_nectar":preload("res://data/sources/flower_nectar.tres"),
	"aphid_honeydew":preload("res://data/sources/aphid_honeydew.tres"),
	"insect_remains":preload("res://data/sources/insect_remains.tres"),
	"hunted_arthropod":preload("res://data/sources/hunted_arthropod.tres"),
	"rain_puddle":preload("res://data/sources/rain_puddle.tres")}

static func accepts(id: Variant, resource_id: String) -> bool:
	return id is String and (id.is_empty() or PROFILES.has(id) and PROFILES[id].resource_id == resource_id)

static func label(index: int) -> String:
	var result: String = ""
	while index > 0:
		index -= 1; result = String.chr(65 + index % 26) + result; index /= 26
	return result
