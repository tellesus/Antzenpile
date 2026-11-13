class_name SanitationConfig
extends Resource
@export var units_per_quantity: int = 100000
@export var worker_quarters_per_tick: int = 25
@export var brood_quarters_per_tick: int = 8
@export var reveal_units: int = 400000
@export var strain_units: int = 1800000
@export var heavy_units: int = 3600000
@export var strained_larval_rate: float = 0.75
@export var heavy_larval_rate: float = 0.5
@export var removal_units_per_worker_tick: int = 500
@export var developed_multiplier: int = 2
@export var cleaner_cap: int = 8
@export var build_workers: int = 4
@export var build_ticks: int = 360
@export var carbohydrate_cost: float = 24.0
@export var protein_cost: float = 12.0
@export var water_cost: float = 6.0
func costs() -> Dictionary:
	return {"carbohydrate": carbohydrate_cost, "protein": protein_cost, "water": water_cost}
