class_name NurseryDevelopmentConfig
extends Resource

@export var workers_required: int = 4
@export var carbohydrate_cost: float = 18.0
@export var protein_cost: float = 8.0
@export var water_cost: float = 6.0
@export var build_seconds: float = 90.0


func costs() -> Dictionary:
	return {"carbohydrate": carbohydrate_cost, "protein": protein_cost, "water": water_cost}
