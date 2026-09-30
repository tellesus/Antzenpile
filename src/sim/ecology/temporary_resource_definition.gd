class_name TemporaryResourceDefinition
extends Resource

@export var source_id: String = ""
@export_range(1, 1000000, 1) var first_tick: int = 1800
@export_range(1, 1000000, 1) var interval_ticks: int = 2400
@export_range(1, 1000000, 1) var duration_ticks: int = 800
@export_range(0.0, 1000000.0) var quantity: float = 24.0
