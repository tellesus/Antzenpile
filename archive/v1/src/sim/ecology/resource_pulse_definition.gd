class_name ResourcePulseDefinition
extends Resource

@export var source_id: String = ""
@export_range(1, 1000000, 1) var first_tick: int = 1200
@export_range(1, 1000000, 1) var interval_ticks: int = 1200
@export_range(0.0, 1000000.0) var quantity: float = 12.0
@export_range(0.0, 1000000.0) var capacity: float = 100.0
