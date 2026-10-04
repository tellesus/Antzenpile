class_name SurfaceImpactSystem
extends RefCounted

const CONFIG = SurfaceImpactState.CONFIG
const TRAILS = preload("res://data/trails/default_trails.tres")
var _run: RunState
var _lose: Callable

func _init(run_state: RunState, lose_worker: Callable) -> void:
	_run = run_state; _lose = lose_worker

func tick() -> void:
	var state: SurfaceImpactState = _run.surface_impact
	if not state.enabled: return
	var next: int = SurfaceImpactState.serial_at(_run.clock.tick_count, _run.run_seed)
	if next == state.serial: return
	state.serial = next
	for segment: TrailSegmentState in _run.trails.segments.values():
		if segment.distance_to_path(CONFIG.position) <= CONFIG.radius:
			segment.decay_chemistry(-log(CONFIG.remaining_scent) / log(2.0))
	# Stable cohort order keeps shared genetic casualty randomness reproducible.
	var ids: Array = _run.trails.cohorts.keys(); ids.sort()
	for id: String in ids: encounter(_run.trails.cohorts[id])

func encounter(cohort: TransitCohort) -> void:
	var state: SurfaceImpactState = _run.surface_impact
	if not state.active(_run.clock.tick_count, _run.run_seed) or cohort.worker_count <= 0 or cohort.impact_serial == state.serial or state.kills_total >= WorkerLedger.MAX_COUNT: return
	var route: TrailRouteState = _run.trails.routes[cohort.route_id]
	if route.purpose != "food": return
	var segment: TrailSegmentState = _run.trails.segments[route.segment_id]
	var progress: float = 1.0 - float(cohort.remaining_ticks) / TRAILS.leg_ticks(segment.length())
	if cohort.direction == "inbound": progress = 1.0 - progress
	var point: Vector2 = cohort.detour.position if cohort.detour != null else segment.point_at(progress)
	if not state.disturbed(point): return
	cohort.impact_serial = state.serial
	_lose.call(cohort, route, "impact")
	state.kills_total += 1
	if cohort.worker_count > 0: cohort.impact_witness_at = _run.simulation_time
