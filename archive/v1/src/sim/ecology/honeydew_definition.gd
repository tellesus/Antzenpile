class_name HoneydewDefinition
extends Resource

@export var source_id: String = "aphid_01"
@export_range(1, 1000000, 1) var interval_ticks: int = 120
@export_range(0.0, 1000000.0) var untended_output: float = 3.0
@export_range(0.0, 1000000.0) var tended_output: float = 8.0
@export_range(0.0, 1000000.0) var source_capacity: float = 40.0
@export_range(0, 1000000, 1) var protection_workers: int = 6
@export_range(0.0, 100.0) var initial_condition: float = 75.0
@export_range(0.0, 100.0) var minimum_condition: float = 50.0
@export_range(0.0, 100.0) var pressure_loss_per_interval: float = 2.0
@export_range(0.0, 100.0) var protected_gain_per_interval: float = 1.0
