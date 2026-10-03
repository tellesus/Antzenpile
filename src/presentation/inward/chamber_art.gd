class_name ChamberArt
extends RefCounted
## Art stages depend exclusively on detached, locally known functional state.

const QUEEN = [preload("res://assets/graphics/colony/material/queen_rear.png"), preload("res://assets/graphics/colony/material/queen_body.png"), preload("res://assets/graphics/colony/material/queen_front.png")]
const NURSERY_PRIMITIVE = [preload("res://assets/graphics/colony/material/nursery_primitive_rear.png"), preload("res://assets/graphics/colony/material/nursery_primitive_body.png"), preload("res://assets/graphics/colony/material/nursery_primitive_front.png")]
const NURSERY_DEVELOPED = [preload("res://assets/graphics/colony/material/nursery_developed_rear.png"), preload("res://assets/graphics/colony/material/nursery_developed_body.png"), preload("res://assets/graphics/colony/material/nursery_developed_front.png")]
const ENTRANCE = [preload("res://assets/graphics/colony/material/entrance_rear.png"), preload("res://assets/graphics/colony/material/entrance_body.png"), preload("res://assets/graphics/colony/material/entrance_front.png")]
const AUXILIARY = QUEEN # Shared material; known organ color/footprint/contents give its function.
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
	if id in ["midden", "guest"]: base = Vector2(164, 137)
	if id == "entrance": return Vector2(306, 255)
	return base * lerpf(0.84, 1.0, maturity(status, id))

static func label_offset(id: String) -> float:
	return 67.0 if id in ["midden", "guest"] else 86.0 if id == "adaptation" else 111.0 if id == "entrance" else 120.0

static func label_position(id: String, at: Vector2) -> Vector2:
	return at+Vector2(102,92) if id == "food_exchange" else at+Vector2(0,label_offset(id))

static func hit_radii(id: String) -> Vector2:
	# Fixed targets contain the developed silhouette; focus/maturity never moves them.
	if id in ["midden", "guest"]: return Vector2(65, 49)
	if id == "adaptation": return Vector2(84, 63)
	return Vector2(133, 93) if id == "queen" else Vector2(123, 86)

static func lobe_offset() -> Vector2:
	return Vector2(-47,-114)

static func rear(canvas: Node2D, status: Dictionary, id: String, at: Vector2, focus: float) -> void:
	_layer(canvas,status,id,at,focus,0)

static func shell(canvas: Node2D, status: Dictionary, id: String, at: Vector2, focus: float) -> void:
	_layer(canvas,status,id,at,focus,1)

static func front(canvas: Node2D, status: Dictionary, id: String, at: Vector2, focus: float) -> void:
	_layer(canvas,status,id,at,focus,2)
	if focus > 0.0:
		var size: Vector2 = extent(status,id)
		var ring: PackedVector2Array = Art.membrane(at,size.x*0.43,1.5,size.y/size.x)
		canvas.draw_polyline(ring.slice(1,5),Color("ead4a8",focus*0.65),1.0,true)
		canvas.draw_polyline(ring.slice(18,21),Color("ead4a8",focus*0.65),1.0,true)

static func _layer(canvas: Node2D, status: Dictionary, id: String, at: Vector2, focus: float, layer: int) -> void:
	var size: Vector2 = extent(status,id)
	var developed: float = maturity(status,id)
	var tint := Color.WHITE
	if id in ["adaptation","guest"]: tint = Color(0.79,0.63,1.12)
	if id == "midden": tint = Color(0.75,0.65,0.58)
	tint = tint.lerp(Color(0.76,0.51,0.40),(1.0-Activity.health(status,id))*0.22)
	tint.a = lerpf(0.88,1.0,focus)
	var area := Rect2(at-size*0.5,size)
	var growth: float = lobe_gain(status) if id == "nursery" else 0.0
	if growth > 0.0:
		var lobe: Vector2 = Vector2(166,138)*lerpf(0.5,1.0,growth)
		canvas.draw_texture_rect(NURSERY_DEVELOPED[layer],Rect2(at+lobe_offset()-lobe*0.5,lobe),false,Color(tint,tint.a*growth))
	match id:
		"queen":
			canvas.draw_texture_rect(QUEEN[layer],area,false,tint)
			if status.get("reproduction",{}).get("phase","none") in ["egg","larva","pupa","ready"]:
				var support_size := Vector2(126,105)
				canvas.draw_texture_rect(NURSERY_DEVELOPED[layer],Rect2(at+Vector2(54,-49)-support_size*0.5,support_size),false,Color(tint,tint.a*0.9))
		"entrance": canvas.draw_texture_rect(ENTRANCE[layer],area,false,tint)
		"nursery":
			# Aligned cavities: development adds protected lining and ridge depth.
			canvas.draw_texture_rect(NURSERY_PRIMITIVE[layer],area,false,tint)
			if developed > 0.0: canvas.draw_texture_rect(NURSERY_DEVELOPED[layer],area,false,Color(tint,tint.a*developed))
		_: canvas.draw_texture_rect(AUXILIARY[layer],area,false,tint)
