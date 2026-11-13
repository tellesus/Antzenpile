class_name JourneyResponseConfig
extends Resource
@export var investigation_workers: int = 3
@export var survey_radius: float = 1.5
@export var defense_workers: int = 12
@export var reinforcement_workers: int = 4
@export var dispatched_cap: int = 24 # Legacy authored field; recruitment now uses the known local workforce.
@export var resistance: int = 6
@export var round_ticks: int = 16
@export var retreat_workers: int = 3
@export var max_rounds: int = 48
@export var pressure_every_rounds: int = 3
@export var max_messengers: int = 3
@export var hunt_resistance: int = 6
@export var hunt_health: int = 3
@export var carcass_protein: float = 24.0
@export var bypass_offset: float = 8.0
