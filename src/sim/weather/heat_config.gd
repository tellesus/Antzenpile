class_name HeatConfig
extends Resource
@export var first_tick: int = 14400
@export var interval_ticks: int = 12000
@export var duration_ticks: int = 2400
@export var ramp_ticks: int = 480
@export var baseline: int = 26000
@export var peak: int = 36000
@export var rain_cooling: int = 4000
@export var drift_per_tick: int = 10
@export var care_step: int = 15
@export var water_units_per_worker_tick: int = 100
@export var dry_water_units_per_tick: int = 250
@export var dry_producer_multiplier: float = 0.75
@export var favorable_low: int = 22000
@export var favorable_high: int = 30000
@export var extreme_high: int = 34000
@export var strained_rate: float = 0.75
@export var severe_rate: float = 0.5
