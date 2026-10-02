class_name NurseryDevelopmentConfig
extends Resource

@export var workers_required: int = 4
@export var carbohydrate_cost: float = 18.0
@export var protein_cost: float = 8.0
@export var water_cost: float = 6.0
@export var build_seconds: float = 90.0
@export var expansion_workers: int = 8
@export var expansion_carbohydrate: float = 60.0
@export var expansion_protein: float = 24.0
@export var expansion_water: float = 12.0
@export var expansion_seconds: float = 180.0
@export var expansion_capacity: int = 32
@export var expansion_matured_required: int = 16


func costs() -> Dictionary:
	return {"carbohydrate": carbohydrate_cost, "protein": protein_cost, "water": water_cost}


func expansion_costs() -> Dictionary:
	return {"carbohydrate": expansion_carbohydrate, "protein": expansion_protein, "water": expansion_water}
