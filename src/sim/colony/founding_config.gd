class_name FoundingConfig
extends Resource
@export var workers: int = 12
@export var carbohydrate: float = 6.0
@export var protein: float = 3.0
@export var water: float = 3.0
@export var preparation_ticks: int = 480
func supplies() -> Dictionary: return {"carbohydrate":carbohydrate,"protein":protein,"water":water}
