class_name ChamberDefinition
extends Resource
## One immutable organ project; effects remain family-specific typed hooks.
@export var id: String=""
@export var display_name: String=""
@export var description: String=""
@export var workers: int=4
@export var duration_ticks: int=360
@export var carbohydrate: float=24
@export var protein: float=12
@export var water: float=8
@export var reproductive_spaces: int=0
@export var climate_gain_percent: int=100
func costs() -> Dictionary: return {"carbohydrate":carbohydrate,"protein":protein,"water":water}
