class_name HumidityConfig
extends Resource

@export var starting: int = 650000
@export var dry_ambient: int = 350000
@export var wet_ambient: int = 850000
@export var dry_step: int = 125
@export var wet_step: int = 250
@export var care_step: int = 250
@export var favorable_low: int = 450000
@export var favorable_high: int = 800000
@export var extreme_low: int = 250000
@export var extreme_high: int = 950000
@export var strained_rate: float = 0.75
@export var extreme_rate: float = 0.5
@export var water_units_per_worker_tick: int = 250
@export var care_cap: int = 4
