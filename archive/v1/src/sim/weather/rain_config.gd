class_name RainConfig
extends Resource

@export var duration_seconds: float = 60.0
@export var water_per_second: float = 0.05
@export var exterior_water_source_id: String = "water_01"
@export_range(0.0, 1000000.0) var exterior_water_per_second: float = 0.4
@export_range(0.0, 1000000.0) var exterior_water_capacity: float = 100.0
@export_range(1, 1000000, 1) var dry_interval_ticks: int = 2400
@export var exposed_chemical_half_life_seconds: float = 12.0
@export var minimum_successful_workers: int = 5
@export_range(0.0, 1.0) var sheltered_max_exposure: float = 0.25
@export_range(0.0, 1.0) var exposed_min_exposure: float = 0.75
