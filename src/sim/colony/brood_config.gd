class_name BroodConfig
extends Resource

@export var starting_count: int = 8
@export var egg_seconds: float = 180.0
@export var larva_seconds: float = 120.0
@export var pupa_seconds: float = 60.0
@export var available_carers_required: int = 2
@export var carbohydrate_per_larva_second: float = 0.015
@export var protein_per_larva_second: float = 0.0045
@export var water_per_larva_second: float = 0.0075


func stage_seconds(stage: String) -> float:
	match stage:
		"egg": return egg_seconds
		"larva": return larva_seconds
		"pupa": return pupa_seconds
	return 0.0
