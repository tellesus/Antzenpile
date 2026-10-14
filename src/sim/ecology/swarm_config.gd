class_name SwarmConfig
extends Resource

@export var reports_to_escalate: int = 2
@export var round_ticks: int = 16
@export var cooldown_ticks: int = 240
@export var retreat_ratio: float = 0.35
@export var rival_retreat_count: int = 2
@export var reinforcement_step: int = 4
@export var rival_reinforcement_workers: int = 4
@export var max_rival_mobilizations: int = 3
@export var pressure_every_rounds: int = 3
@export var max_pressure_reports: int = 3
