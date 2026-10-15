class_name ChamberArt
extends RefCounted
## Art stages depend exclusively on detached, locally known functional state.

const Art = preload("res://src/presentation/sensory_art.gd")
const Activity = preload("res://src/presentation/inward/colony_activity.gd")

static func maturity(status: Dictionary, id: String) -> float:
	if id not in ["nursery", "food_exchange", "midden"]: return 1.0
	var state: String = status.get("midden", {}).get("state", "primitive") if id == "midden" else status.get(id + "_state", "primitive")
	if state == "developed": return 1.0
	if state == "developing": return lerpf(0.0, 1.0, maxf(0.0, Activity.project_progress(status, id)))
	return 0.0

static func expanded(status: Dictionary) -> bool:
	return status.get("nursery_expansion", {}).get("state", "") == "developed"

static func lobe_gain(status: Dictionary) -> float:
	if expanded(status): return 1.0
	var project: Dictionary = status.get("nursery_expansion", {})
	if project.get("state", "") != "developing": return 0.0
	return clampf(float(project.get("progress_seconds",0.0))/maxf(0.001,float(project.get("duration",1.0))),0.0,1.0)

static func extent(status: Dictionary, id: String) -> Vector2:
	var base := Vector2(328, 273)
	if id == "queen": return Vector2(350, 292)
	if id == "adaptation": return Vector2(210, 175)
	if id in ["midden", "guest", "refuge"]: base = Vector2(164, 137)
	if id == "entrance": return Vector2(306, 255)
	return base * lerpf(0.84, 1.0, maturity(status, id))

static func label_offset(id: String) -> float:
	return 67.0 if id in ["midden", "guest", "refuge"] else 86.0 if id == "adaptation" else 111.0 if id == "entrance" else 120.0

static func label_position(id: String, at: Vector2, scale: float = 1.0) -> Vector2:
	return at+Vector2(0,label_offset(id) * scale)

static func hit_radii(id: String) -> Vector2:
	# Fixed targets contain the developed silhouette; focus/maturity never moves them.
	if id in ["midden", "guest", "refuge"]: return Vector2(65, 49)
	if id == "adaptation": return Vector2(84, 63)
	return Vector2(133, 93) if id == "queen" else Vector2(123, 86)

static func lobe_offset() -> Vector2:
	return Vector2(-47,-114)

static func tone(id: String) -> Color:
	match id:
		"queen": return Color("ffba53")
		"nursery": return Color("58eed2")
		"food_exchange": return Color("b9ed68")
		"adaptation", "guest": return Color("b37bff")
		"midden": return Color("fa8b83")
		"refuge": return Color("8bffd1")
	return Color("51dcff")

static func rear(canvas: Node2D, status: Dictionary, id: String, at: Vector2, focus: float, time: float = 0.0, scale: float = 1.0) -> void:
	_layer(canvas,status,id,at,focus,0,time,scale)

static func shell(canvas: Node2D, status: Dictionary, id: String, at: Vector2, focus: float, time: float = 0.0, scale: float = 1.0) -> void:
	_layer(canvas,status,id,at,focus,1,time,scale)

static func front(canvas: Node2D, status: Dictionary, id: String, at: Vector2, focus: float, time: float = 0.0, scale: float = 1.0) -> void:
	if focus > 0.0:
		var size: Vector2 = extent(status,id) * scale
		var ring: PackedVector2Array = Art.membrane(at,size.x*0.43,1.5,size.y/size.x)
		canvas.draw_polyline(ring.slice(1,5),Color("ead4a8",focus*0.65),1.0,true)
		canvas.draw_polyline(ring.slice(18,21),Color("ead4a8",focus*0.65),1.0,true)

static func _organ(canvas: Node2D, at: Vector2, size: Vector2, color: Color, rotation: float = 0.0) -> void:
	canvas.draw_set_transform(at, rotation)
	canvas.draw_texture_rect(Art.ORGAN, Rect2(-size * 0.5, size), false, color)
	canvas.draw_set_transform(Vector2.ZERO)

static func _layer(canvas: Node2D, status: Dictionary, id: String, at: Vector2, focus: float, layer: int, time: float, scale: float) -> void:
	var health: float = Activity.health(status, id)
	var pulse: float = Activity.pulse(health, time)
	var size: Vector2 = extent(status,id) * scale * (1.0 + pulse * 0.012)
	var tint: Color = tone(id).lerp(Color("e78c9c"), (1.0 - health) * 0.22)
	var phase: float = float(abs(id.hash()) % 100) / 15.0
	if layer == 0:
		canvas.draw_set_transform(at, phase + sin(time * 0.12) * 0.04)
		canvas.draw_texture_rect(Art.CLOUD, Rect2(-size * 0.64, size * 1.28), false, Color(tint, 0.13 + focus * 0.04))
		canvas.draw_set_transform(Vector2.ZERO)
		return
	tint.a = 0.80 + focus * 0.16
	if id == "adaptation":
		for arm: int in 3:
			var angle: float = arm * TAU / 3.0 - PI * 0.5
			var end: Vector2 = at + Vector2.from_angle(angle) * 58.0 * scale
			var points := Art.membrane(at.lerp(end, 0.5), 35.0 * scale, phase + time * 0.07, 0.55)
			canvas.draw_polyline(points.slice(0, 17), Color(tint, 0.55), 1.4, true)
			_organ(canvas, end, Vector2(54, 62) * scale, Color(tint, 0.82), angle)
		return
	if id == "food_exchange":
		for petal: int in 3:
			var color: Color = Art.color_for(["carbohydrate", "water", "protein"][petal])
			var offset: Vector2 = Vector2.from_angle(petal * TAU / 3.0 - PI * 0.5) * 29.0 * scale
			_organ(canvas, at + offset, size * Vector2(0.57, 0.65), Color(color, 0.68), petal * 0.40)
	elif id == "nursery":
		_organ(canvas, at + Vector2(-35, 0) * scale, size * Vector2(0.66, 0.80), tint, -0.12)
		_organ(canvas, at + Vector2(39, 8) * scale, size * Vector2(0.58, 0.70), Color(tint, 0.66), 0.25)
	else:
		_organ(canvas, at, size * (Vector2(1.0, 0.70) if id == "entrance" else Vector2.ONE), tint, 0.025 * sin(time * 0.18 + phase))
	var growth: float = lobe_gain(status) if id == "nursery" else 0.0
	if growth > 0.0:
		_organ(canvas, at + lobe_offset() * scale, Vector2(166,138) * scale * lerpf(0.5,1.0,growth), Color(tint,growth*0.72), 0.3)
