class_name PredatorDefinition
extends Resource

@export var position: Vector2 = Vector2(29, 27)
@export_range(0.1, 100.0) var radius: float = 2.0
@export_range(1, 1000000) var first_tick: int = 1200
@export_range(1, 1000000) var recovery_ticks: int = 120
