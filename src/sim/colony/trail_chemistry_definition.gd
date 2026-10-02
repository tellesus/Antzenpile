class_name TrailChemistryDefinition
extends Resource
## Authored provisional biological investment and ongoing secretion cost.

@export var carbohydrate_cost: float = 14.0
@export var protein_cost: float = 16.0
@export var water_cost: float = 8.0
@export var variation_chance: float = 0.65
@export var persistence_multiplier: float = 2.0
@export var extra_travel_energy: float = 0.20


func costs() -> Dictionary:
	return {"carbohydrate": carbohydrate_cost, "protein": protein_cost, "water": water_cost}
