class_name SensoryArt
extends RefCounted
## Bounded immediate drawing. All movement is decorative and uses no RNG.

const MAX_MOTES: int = 24
const CONTOUR_STEPS: int = 32


static func color_for(category: String) -> Color:
	match category:
		"carbohydrate": return Color("dcb477")
		"water": return Color("7fbfcf")
		"protein": return Color("b8a1cf")
		"threat": return Color("c58d79")
	return Color("a0b1ae")


static func membrane(center: Vector2, radius: float, phase: float, squash: float = 0.8) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step: int in CONTOUR_STEPS + 1:
		var angle: float = TAU * step / CONTOUR_STEPS
		var r: float = radius * (0.84 + 0.09 * sin(angle * 3.0 + phase) + 0.06 * cos(angle * 5.0 - phase * 0.7))
		points.append(center + Vector2(cos(angle), sin(angle) * squash) * r)
	return points


static func cloud(canvas: Node2D, entry: Dictionary, time: float, empty: bool) -> void:
	var signal_data: Dictionary = entry.signal
	var center: Vector2 = entry.center
	var radius: float = entry.radius
	var color: Color = Color("819092") if empty else color_for(signal_data.category)
	var phase: float = float(abs(str(entry.id).hash()) % 1000) / 71.0
	var strength: float = clampf(float(signal_data.strength), 0.0, 1.0)
	var salience: float = (0.18 if empty else 0.45 + 0.55 * strength)
	var drift: float = time * 0.25 + phase
	if not empty:
		for layer: int in 2:
			var outline: PackedVector2Array = membrane(center + Vector2(sin(drift), cos(drift * 0.7)) * 3.0, radius * (1.0 - layer * 0.25), drift + layer)
			canvas.draw_colored_polygon(outline, Color(color, (0.045 + layer * 0.025) * salience))
	var count: int = 6 if empty else MAX_MOTES
	for index: int in count:
		var angle: float = index * 2.39996 + phase + time * (0.035 if signal_data.category == "water" else 0.06)
		var spread: float = sqrt(float(index + 1) / count) * radius * 0.83
		var at: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.7) * spread + Vector2(sin(drift + index), cos(drift * 0.8 + index)) * 2.5
		var alpha: float = salience * (0.2 + 0.24 * (0.5 + 0.5 * sin(index * 1.7 + drift)))
		canvas.draw_circle(at, 0.8 + (index % 3) * 0.45, Color(color, alpha))
	if signal_data.category == "water" and not empty:
		for index: int in 3:
			var ripple: PackedVector2Array = membrane(center, radius * (0.35 + 0.18 * index), drift * 0.45 + index, 0.43)
			canvas.draw_polyline(ripple.slice(2 + index * 3, 15 + index * 4), Color(color, 0.18 * salience), 1.0, true)
	elif signal_data.category == "protein" and not empty:
		for index: int in 3:
			var fiber: PackedVector2Array = membrane(center + Vector2(index * 7 - 7, 0), radius * 0.55, drift + index, 0.65)
			canvas.draw_polyline(fiber.slice(index * 3, 14 + index * 3), Color(color, 0.16 * salience), 1.0, true)
	if empty:
		var remnant: PackedVector2Array = membrane(center, radius * 0.7, phase)
		canvas.draw_polyline(remnant.slice(2, 8), Color(color, 0.28), 1.0, true)
		canvas.draw_polyline(remnant.slice(18, 23), Color(color, 0.28), 1.0, true)
	if signal_data.get("foreign_contact", false):
		var foreign: PackedVector2Array = membrane(center, radius * 0.96, -phase, 0.72)
		canvas.draw_polyline(foreign.slice(15, 28), Color(0.8, 0.76, 0.67, 0.48), 1.0, true)
		for index: int in 4:
			canvas.draw_circle(foreign[16 + index * 3], 1.4, Color(0.8, 0.76, 0.67, 0.6))
	if signal_data.get("conflict_report", "") == "contested":
		for index: int in 6:
			var at: Vector2 = center + Vector2(sin(time * 1.5 + index * 2.1), cos(time * 1.3 + index)) * radius * 0.6
			canvas.draw_line(at - Vector2(2, 1), at + Vector2(2, 1), Color(0.8, 0.39, 0.27, 0.5), 1.0, true)


static func ant(canvas: Node2D, at: Vector2, direction: Vector2, color: Color, phase: float, scale: float = 1.0) -> void:
	var forward: Vector2 = direction.normalized()
	var side: Vector2 = forward.orthogonal()
	# Six alternating legs and three body segments read at small logical sizes.
	for index: int in 3:
		var joint: Vector2 = at + forward * (index - 1) * 2.1 * scale
		for sign_value: int in [-1, 1]:
			var step: float = sin(phase * 11.0 + index * PI + sign_value) * 1.3
			canvas.draw_line(joint, joint + (side * sign_value * 3.4 + forward * step) * scale, Color(color, color.a * 0.65), 0.75, true)
	canvas.draw_circle(at - forward * 3.0 * scale, 2.3 * scale, color)
	canvas.draw_circle(at, 1.4 * scale, color)
	canvas.draw_circle(at + forward * 2.8 * scale, 1.6 * scale, color)
	for sign_value: int in [-1, 1]:
		canvas.draw_line(at + forward * 3.5 * scale, at + (forward * 5.7 + side * sign_value * 1.8) * scale, Color(color, color.a * 0.7), 0.7, true)
