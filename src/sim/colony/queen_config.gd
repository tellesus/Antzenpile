class_name QueenConfig
extends Resource
@export var maximum_condition: int = 1000000
@export var warning_condition: int = 800000
@export var strain_per_tick: int = 100
@export var recovery_per_carer_tick: int = 250
@export var care_cap: int = 2
@export var care_carbohydrate: float = 0.00025
@export var care_protein: float = 0.00010
@export var care_water: float = 0.00025
@export var replacement_nurses: int = 2
@export var replacement_ticks: int = 480
@export var replacement_carbohydrate: float = 8
@export var replacement_protein: float = 6
@export var replacement_water: float = 4

func care_costs(workers: int) -> Dictionary:
	return {"carbohydrate":care_carbohydrate*workers,"protein":care_protein*workers,"water":care_water*workers}
func replacement_costs() -> Dictionary:
	return {"carbohydrate":replacement_carbohydrate,"protein":replacement_protein,"water":replacement_water}
