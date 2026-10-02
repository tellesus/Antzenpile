class_name ScoutConfig
extends Resource

@export var active_cap: int = 8
@export var speed: float = 1.0
@export var minimum_distance: float = 8.0
@export var maximum_distance: float = 12.0
@export var cone_radians: float = PI / 4.0
@export var target_attempts: int = 16
@export var departure_interval_ticks: int = 8
@export var directional_share: float = 0.6
@export var standing_search_seconds: float = 120.0
@export var cue_extension_seconds: float = 60.0
@export var sense_radius: float = 4.0
@export var confirmation_radius: float = 1.0
@export var localization_floor: float = 0.25
@export var distance_uncertainty: float = 0.5
@export var departure_scent_half_life: float = 180.0
@export var rain_scent_half_life: float = 12.0
