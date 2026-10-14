class_name BroodHealthConfig
extends Resource

@export var maximum: int = 10000
@export var symptom_threshold: int = 1000
@export var severe_threshold: int = 8000
@export var exposure_per_tick: int = 4
@export var damp_extra_per_tick: int = 2
@export var recovery_per_tick: int = 2
@export var loss_ticks: int = 480
@export var strained_rate: float = 0.75
@export var severe_rate: float = 0.5
