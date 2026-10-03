class_name ReproductionConfig
extends Resource

@export var emerged_required: int = 32
@export var space: int = 8
@export var nurses: int = 4
@export var carbohydrate_cost: float = 12.0
@export var protein_cost: float = 12.0
@export var water_cost: float = 8.0
@export var egg_ticks: int = 720
@export var larva_ticks: int = 1920
@export var pupa_ticks: int = 480

func stage_ticks(stage: String) -> int:
	return egg_ticks if stage == "egg" else larva_ticks if stage == "larva" else pupa_ticks if stage == "pupa" else 0

func costs() -> Dictionary:
	return {"carbohydrate":carbohydrate_cost,"protein":protein_cost,"water":water_cost}
