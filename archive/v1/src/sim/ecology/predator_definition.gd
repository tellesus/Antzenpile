class_name PredatorDefinition
extends Resource

@export var profile_id: String = ""
@export var position: Vector2 = Vector2(29, 27)
@export_range(0.1, 100.0) var radius: float = 2.0
@export_range(1, 1000000) var first_tick: int = 1200
@export_range(1, 1000000) var recovery_ticks: int = 120
@export var patrol_end: Vector2 = Vector2.ZERO
@export var retreat_position: Vector2 = Vector2.ZERO
@export_range(0.0, 10.0) var speed: float = 0.0
@export_range(1, 1000000) var pause_ticks: int = 80
@export_range(0.1, 20.0) var feeding_radius: float = 6.0
