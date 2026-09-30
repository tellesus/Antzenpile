class_name OutwardProjection
extends RefCounted
## Bearing-to-screen placement only; never projects hidden world positions.

const Perception = preload("res://src/presentation/perception_model.gd")
const HALF_FIELD: float = PI * 0.5
const HIT_RADIUS: float = 44.0


static func project(signals: Array[Dictionary], facing: float, viewport: Vector2) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	if not is_finite(facing) or not viewport.is_finite() or viewport.x <= 0 or viewport.y <= 0:
		return placed
	for signal_data: Dictionary in signals:
		var relative: Variant = Perception.relative_bearing(signal_data.get("bearing"), facing)
		if relative == null or absf(relative) > HALF_FIELD:
			continue
		var distance: float = maxf(0.0, float(signal_data.estimated_distance))
		var strength: float = clampf(float(signal_data.strength), 0.0, 1.0)
		var uncertainty: float = maxf(0.0, float(signal_data.uncertainty_radius))
		var center := Vector2(viewport.x * 0.5 + float(relative) / HALF_FIELD * (viewport.x * 0.5 - 72.0),
			lerpf(viewport.y * 0.58, viewport.y * 0.30, clampf(distance / 20.0, 0.0, 1.0)))
		var radius: float = clampf(18.0 + 38.0 * strength + 3.0 * uncertainty, 20.0, 64.0)
		placed.append({"id": signal_data.id, "center": center, "radius": radius, "signal": signal_data.duplicate(true)})
	return placed


static func pick(placed: Array[Dictionary], at: Vector2) -> String:
	var selected: String = ""
	var nearest: float = INF
	for entry: Dictionary in placed:
		var distance: float = at.distance_to(entry.center)
		if distance <= maxf(HIT_RADIUS, entry.radius) and distance < nearest:
			selected = entry.id
			nearest = distance
	return selected
