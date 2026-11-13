class_name ResidueZoneState
extends RefCounted
## Physical footprint only; historical witnesses belong to actual returning parties.
const CONFIG=preload("res://data/ecology/roadside_residue.tres")
var enabled: bool = false
var definition: ResidueDefinition
func _init(config: ResidueDefinition=CONFIG) -> void:definition=config

func active(tick: int) -> bool:
	return enabled and tick>=definition.first_tick and tick<definition.first_tick+definition.duration_ticks

func contains(point: Vector2, tick: int, extra: float=0.0) -> bool:
	return active(tick) and point.distance_to(definition.position)<=definition.radius+extra

func to_dict() -> Dictionary: return {"enabled":enabled}
func restore(data: Variant, scenario: String) -> bool:
	if not data is Dictionary or data.size()!=1 or not data.has("enabled") or not data.enabled is bool or data.enabled and scenario!="roadside":return false
	enabled=data.enabled;return true

static func contaminated(carbohydrate: float, current_mass: float, config: ResidueDefinition=CONFIG) -> float:
	return minf(carbohydrate,roundf((current_mass+(carbohydrate-current_mass)*config.contact_fraction)*1e8)/1e8)

static func valid_report(data: Variant, time: float, config: ResidueDefinition=CONFIG) -> bool:
	if not data is Dictionary or data.size()!=3 or not data.has_all(["observed_at","received_at","estimated_position"]):return false
	for key: String in ["observed_at","received_at"]:
		if not typeof(data[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])):return false
	if data.observed_at<config.first_tick*SimulationClock.TICK_INTERVAL or data.observed_at>=(config.first_tick+config.duration_ticks)*SimulationClock.TICK_INTERVAL or data.received_at<data.observed_at or data.received_at>time:return false
	if not data.estimated_position is Array or data.estimated_position.size()!=2:return false
	for value: Variant in data.estimated_position:
		if not typeof(value) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return false
	return Vector2(data.estimated_position[0],data.estimated_position[1]).distance_to(config.position)<=config.radius+1
