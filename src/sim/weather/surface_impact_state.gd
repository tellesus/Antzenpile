class_name SurfaceImpactState
extends RefCounted
## Private physical history. Delivered route evidence owns player knowledge.

const CONFIG = preload("res://data/weather/roadside_surface_impact.tres")
var enabled: bool = false
var serial: int = 0
var kills_total: int = 0

static func first_tick(seed_value: int) -> int:
	return CONFIG.first_tick + posmod(seed_value, CONFIG.seed_window)

static func serial_at(tick: int, seed_value: int) -> int:
	return 0 if tick < first_tick(seed_value) else 1 + (tick - first_tick(seed_value)) / CONFIG.interval_ticks

func active(tick: int, seed_value: int) -> bool:
	return enabled and tick >= first_tick(seed_value) and posmod(tick - first_tick(seed_value), CONFIG.interval_ticks) < CONFIG.duration_ticks

func disturbed(point: Vector2) -> bool:
	return enabled and serial > 0 and point.distance_to(CONFIG.position) <= CONFIG.radius

func to_dict() -> Dictionary:
	return {"enabled": enabled, "serial": serial, "kills_total": kills_total}

func restore(data: Variant, tick: int, seed_value: int, scenario: String) -> bool:
	if not data is Dictionary or data.size() != 3 or not data.has_all(["enabled", "serial", "kills_total"]): return false
	if not data.enabled is bool or not WorkerLedger.valid_count(data.serial) or not WorkerLedger.valid_count(data.kills_total): return false
	if data.enabled and scenario != "roadside": return false
	if data.serial != (serial_at(tick, seed_value) if data.enabled else 0): return false
	if data.serial == 0 and data.kills_total != 0: return false
	enabled = data.enabled; serial = int(data.serial); kills_total = int(data.kills_total)
	return true
