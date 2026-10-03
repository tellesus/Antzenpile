class_name ChamberArt
extends RefCounted
## Art stages depend exclusively on detached, locally known functional state.

const SHELL = preload("res://assets/graphics/colony/chamber.png")
const QUEEN = preload("res://assets/graphics/colony/returned/queen_shell.png")
const NURSERY_PRIMITIVE = preload("res://assets/graphics/colony/returned/nursery_primitive.png")
const NURSERY_DEVELOPED = preload("res://assets/graphics/colony/returned/nursery_developed.png")
const NURSERY_LOBE = preload("res://assets/graphics/colony/returned/nursery_expansion_lobe.png")
const ENTRANCE = preload("res://assets/graphics/colony/returned/entrance_shell.png")
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
	var base := Vector2(202, 172)
	if id == "adaptation": return Vector2(156, 130)
	if id in ["midden", "guest"]: base = Vector2(140, 118)
	if id == "entrance": return Vector2(186, 150)
	return base * lerpf(0.79, 1.08, maturity(status, id))

static func label_offset(id: String) -> float:
	return 66.0 if id in ["midden", "guest", "adaptation"] else 96.0

static func shell(canvas: Node2D, status: Dictionary, id: String, at: Vector2, focus: float) -> void:
	var size: Vector2 = extent(status, id)
	var developed: float = maturity(status, id)
	var tint := Color(1.0, 0.93, 0.79)
	# Returned color art already carries its lighting; do not recolor cyan as amber.
	if id in ["queen", "nursery", "entrance"]: tint = Color.WHITE
	if id == "adaptation" or id == "guest": tint = Color(0.88, 0.58, 1.32)
	if id == "midden": tint = Color(0.78, 0.55, 0.42)
	var health: float = Activity.health(status, id)
	tint = tint.lerp(Color(0.76, 0.45, 0.32), (1.0-health)*0.3)
	tint.a = lerpf(0.67, 0.98, developed) * lerpf(0.90, 1.0, focus)
	# The second lobe represents completed capacity, never a hidden chamber.
	var growth: float = lobe_gain(status) if id == "nursery" else 0.0
	if growth > 0.0:
		var lobe: Vector2 = Vector2(126, 102) * lerpf(0.45,1.0,growth)
		canvas.draw_texture_rect(NURSERY_LOBE, Rect2(at + Vector2(64,-43) - lobe*0.5, lobe), false, Color(tint, tint.a*0.84*growth))
	var area := Rect2(at-size*0.5, size)
	match id:
		"queen": canvas.draw_texture_rect(QUEEN, area, false, tint)
		"entrance": canvas.draw_texture_rect(ENTRANCE, area, false, tint)
		"nursery":
			# Primitive remains a simpler, quieter material; both layers share the
			# same cavity center. Only approved construction changes the blend.
			if developed < 1.0:
				canvas.draw_texture_rect(NURSERY_PRIMITIVE, area, false, Color(tint * Color(0.72,0.69,0.65), tint.a))
			if developed > 0.0:
				canvas.draw_texture_rect(NURSERY_DEVELOPED, area, false, Color(tint, tint.a*developed))
		_: canvas.draw_texture_rect(SHELL, area, false, tint)
	if focus > 0.0:
		var ring: PackedVector2Array = Art.membrane(at, size.x*0.54, 1.5, size.y/size.x)
		canvas.draw_polyline(ring.slice(1,8), Color("ead4a8",focus*0.8), 1.0, true)
		canvas.draw_polyline(ring.slice(17,24), Color("ead4a8",focus*0.8), 1.0, true)
