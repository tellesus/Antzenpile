class_name FoodToxicityConfig
extends Resource
@export var half_life_seconds: float = 180.0
@export var dose_threshold_units: int = 1200000
@export var dose_scale: int = 100000
@export var recovery_per_second: float = 0.02
@export var minimum_mixing_pool: float = 1.0
@export var recent_evidence_seconds: float = 300.0
