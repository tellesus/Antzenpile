class_name RecognitionDefinition
extends Resource
## A bounded security/tolerance axis; values are provisional balance data.

@export var carbohydrate_cost: float = 14.0
@export var protein_cost: float = 16.0
@export var water_cost: float = 8.0
@export var variation_chance: float = 0.65
@export var clearing_change: float = 0.40
@export var protection_worker_change: int = 2
@export var security_losses: int = 1
@export var tolerance_losses: int = 3


func costs() -> Dictionary:
	return {"carbohydrate": carbohydrate_cost, "protein": protein_cost, "water": water_cost}
