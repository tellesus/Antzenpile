class_name PerceptionModel
extends RefCounted
## Pure projection of colony memory. No world, run, scout or RNG access.

const SignalData = preload("res://src/presentation/perceived_signal.gd")
const CONFIG = preload("res://data/signals/default_perception.tres")


func project(known_nodes: Array[KnownNode], origin: Vector2, time: float) -> Array[PerceivedSignal]:
	var signals: Array[PerceivedSignal] = []
	if not origin.is_finite() or not is_finite(time) or time < 0:
		return signals
	for known: KnownNode in known_nodes:
		var signal_data := SignalData.new()
		signal_data.id = "signal:" + known.id
		signal_data.source_knowledge_id = known.id
		signal_data.category = CONFIG.categories.get(known.definition_id, "unknown")
		var offset: Vector2 = known.estimated_position - origin
		signal_data.estimated_distance = offset.length()
		if offset != Vector2.ZERO:
			signal_data.bearing = fposmod(offset.angle(), TAU)
		signal_data.uncertainty_radius = known.uncertainty_radius
		signal_data.age = known.age_at(time)
		signal_data.confidence = known.confidence_at(time)
		signal_data.confidence_label = confidence_label(signal_data.confidence)
		signal_data.strength = clampf(signal_data.confidence / (1.0 + signal_data.estimated_distance / CONFIG.distance_scale), 0.0, 1.0)
		signals.append(signal_data)
	# Sorting the new output cannot reorder an authoritative input collection.
	signals.sort_custom(func(a: PerceivedSignal, b: PerceivedSignal) -> bool: return a.source_knowledge_id < b.source_knowledge_id)
	return signals


static func relative_bearing(bearing: Variant, facing: float) -> Variant:
	if not typeof(bearing) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(bearing)) or not is_finite(facing):
		return null
	return wrapf(float(bearing) - facing, -PI, PI)


static func confidence_label(value: float) -> String:
	if value < CONFIG.likely_threshold:
		return "uncertain"
	if value < CONFIG.clear_threshold:
		return "likely"
	return "clear"
