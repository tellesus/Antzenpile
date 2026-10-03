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
@export var coverage_cell_size: float = 4.0
@export var coverage_half_life: float = 600.0
@export var rain_coverage_half_life: float = 120.0
@export var verification_interval: float = 90.0
@export var novelty_rejection: float = 0.85
@export var coverage_frontier_penalty: float = 3.0
@export var verification_confidence: float = 0.65
@export var need_weight: float = 12.0
@export var trail_exploration_share: float = 0.35
@export var trail_travel_multiplier: float = 1.25
@export var established_trail_familiarity: float = 0.1
@export var sense_radius: float = 4.0
@export var confirmation_radius: float = 1.0
@export var localization_floor: float = 0.25
@export var distance_uncertainty: float = 0.5
@export var departure_scent_half_life: float = 180.0
@export var rain_scent_half_life: float = 12.0
@export var return_grace_seconds: float = 30.0
@export var manual_expectation_seconds: float = 600.0
