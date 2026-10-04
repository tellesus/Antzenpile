class_name FightingTraitConfig
extends Resource

@export var carbohydrate_cost: float = 16.0
@export var protein_cost: float = 20.0
@export var water_cost: float = 8.0
@export var extra_combat_weight: float = 1.0
@export var extra_larval_food: float = 0.4

func costs() -> Dictionary:
	return {"carbohydrate":carbohydrate_cost,"protein":protein_cost,"water":water_cost}
