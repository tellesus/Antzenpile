class_name FoodExchangeConfig
extends Resource

@export var workers_required: int = 4
@export var carbohydrate_cost: float = 12.0
@export var protein_cost: float = 4.0
@export var water_cost: float = 4.0
@export var build_seconds: float = 60.0
@export var developed_larval_food_multiplier: float = 0.75


func costs() -> Dictionary:
	return {"carbohydrate": carbohydrate_cost, "protein": protein_cost, "water": water_cost}
