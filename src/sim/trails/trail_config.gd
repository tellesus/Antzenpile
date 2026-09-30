class_name TrailConfig
extends Resource

@export var initial_workers: int = 5
@export var travel_speed: float = 1.0
@export var carry_per_worker: float = 1.0
@export var departure_interval_ticks: int = 8
@export var workers_per_cohort: int = 8
@export var max_cohorts_per_route: int = 8
@export var interaction_radius: float = 2.0
@export var pheromone_half_life_seconds: float = 90.0
@export var pheromone_per_returning_worker: float = 0.035


func leg_ticks(length: float) -> int:
	return maxi(1, ceili(length / travel_speed / SimulationClock.TICK_INTERVAL))
