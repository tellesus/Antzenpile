class_name ScenarioCatalog
extends RefCounted
## Known authored definitions, never a player map or mutable run state.

const IDS: Array[String] = ["backyard_slice", "garden_edge"]
const PATHS: Dictionary = {"backyard_slice": "res://data/scenarios/backyard_slice.tres", "garden_edge": "res://data/scenarios/garden_edge.tres"}

static func path_for(id: String) -> String:
	return PATHS.get(id, "")

static func label_for(id: String) -> String:
	return "Backyard" if id == "backyard_slice" else "Garden Edge" if id == "garden_edge" else "Saved scenario"

static func uses_backyard_ecology(id: String) -> bool:
	return id in IDS
