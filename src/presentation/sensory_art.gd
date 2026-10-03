class_name SensoryArt
extends RefCounted
## Bounded immediate drawing. All movement is decorative and uses no RNG.

const MAX_MOTES: int = 12
const CONTOUR_STEPS: int = 32
const CLOUD = preload("res://assets/graphics/colony/material/scent_smoke.png")
const WATER = preload("res://assets/graphics/proof/water_impression.svg")
const WORKER = preload("res://assets/graphics/proof/worker_walk.png")
const SCENT_WORKER = preload("res://assets/graphics/proof/worker_scent.png")
const EARTH = preload("res://assets/graphics/proof/nursery_earth.svg")
const FILAMENT = preload("res://assets/graphics/colony/chemical_cloud.png")
const ENTRANCE = preload("res://assets/graphics/colony/material/local_home.png")
const WALK_FRAMES: int = 12
const WALK_CELL: int = 128


static func impression_gain(signal_data: Dictionary, empty: bool) -> float:
	# Only approved category/confidence. Age is already incorporated by perception.
	if empty or signal_data.get("category", "unknown") != "water": return 0.0
	return smoothstep(0.25, 0.75, clampf(float(signal_data.get("confidence", 0.0)), 0.0, 1.0))


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
	var recognition: float = smoothstep(0.25, 0.75, clampf(float(signal_data.get("confidence", 0.0)), 0.0, 1.0))
	if not empty:
		# Neutral baked density carries no object identity. Bounded drift exposes
		# smoke-like structure, never hidden reality or simulation randomness.
		for layer: int in 3:
			var offset := Vector2(sin(drift+layer*2.1),cos(drift*0.7+layer))*radius*0.09
			var extent := Vector2.ONE*radius*(2.6-layer*0.18)
			var rotation: float = float(layer)*0.7+0.17*sin(drift*0.27+layer)
			canvas.draw_set_transform(center+offset,rotation)
			canvas.draw_texture_rect(CLOUD,Rect2(-extent*0.5,extent),false,Color(color,salience*[0.42,0.30,0.20][layer]))
			canvas.draw_set_transform(Vector2.ZERO)
		var gain: float = impression_gain(signal_data, empty)
		if gain > 0.0:
			var extent := Vector2.ONE * radius * 2.0
			canvas.draw_texture_rect(WATER, Rect2(center - extent * 0.5, extent), false, Color(color.lightened(0.15), gain * salience))
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
			canvas.draw_polyline(ripple.slice(2 + index * 3, 15 + index * 4), Color(color, 0.18 * salience * recognition), 1.0, true)
	elif signal_data.category == "protein" and not empty:
		for index: int in 3:
			var fiber: PackedVector2Array = membrane(center + Vector2(index * 7 - 7, 0), radius * 0.55, drift + index, 0.65)
			canvas.draw_polyline(fiber.slice(index * 3, 14 + index * 3), Color(color, 0.16 * salience * recognition), 1.0, true)
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


static func ant(canvas: Node2D, at: Vector2, direction: Vector2, color: Color, phase: float, scale: float = 1.0, interior: bool = false) -> void:
	var frame: int = posmod(int(floor(phase * 18.0)), WALK_FRAMES)
	var source := Rect2(Vector2(frame % 6, frame / 6) * WALK_CELL, Vector2.ONE * WALK_CELL)
	var extent: float = (30.0 if interior else 24.0) * scale
	canvas.draw_set_transform(at, direction.angle() + PI * 0.5)
	if interior:
		var tint: Color = Color(1.0, 0.95, 0.86, 0.95).lerp(color, 0.08)
		canvas.draw_texture_rect_region(WORKER, Rect2(Vector2.ONE * -extent * 0.5, Vector2.ONE * extent), source, tint)
	else:
		canvas.draw_texture_rect_region(SCENT_WORKER, Rect2(Vector2.ONE * -extent * 0.58, Vector2.ONE * extent * 1.16), source, Color(color, color.a * 0.10))
		canvas.draw_texture_rect_region(SCENT_WORKER, Rect2(Vector2.ONE * -extent * 0.5, Vector2.ONE * extent), source, color)
	canvas.draw_set_transform(Vector2.ZERO)


static func nursery_earth(canvas: Node2D, at: Vector2, focus: float) -> void:
	canvas.draw_texture_rect(EARTH, Rect2(at + Vector2(-48,-34), Vector2(96,68)), false, Color(1,1,1,lerpf(0.72,1.0,focus)))


static func filament(canvas: Node2D, points: PackedVector2Array, color: Color, width: float, texture: Texture2D = FILAMENT) -> void:
	if points.size() < 2: return
	var edges := PackedVector2Array()
	var uv := PackedVector2Array()
	for side: int in [1,-1]:
		for offset: int in points.size():
			var index: int = offset if side == 1 else points.size()-1-offset
			var tangent: Vector2 = points[mini(index+1,points.size()-1)] - points[maxi(0,index-1)]
			edges.append(points[index] + tangent.normalized().orthogonal()*width*0.5*side)
			uv.append(Vector2(float(index)/(points.size()-1), 0.0 if side == 1 else 1.0))
	canvas.draw_polygon(edges, PackedColorArray([color]), uv, texture)
	canvas.draw_polyline(points, Color(color.lightened(0.3),color.a*0.85), 0.8, true)


static func home_entrance(canvas: Node2D, center: Vector2) -> void:
	# Only immediate home substrate; no remote landscape or world coordinates.
	# Broad immediate Home field. Its opening aligns with the existing sensory
	# anchor; transparent upper space cannot introduce remote scenery.
	canvas.draw_texture_rect(ENTRANCE,Rect2(center-Vector2(640,204),Vector2(1280,336)),false)
