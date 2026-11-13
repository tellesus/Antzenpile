class_name ConflictImpression
extends Control
## A clipped memory portrait. The field's approved projection owns its identity.

const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")
var cloud: ChemicalCloud = Cloud.new()


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cloud)
	hide()


static func evidence(route: Dictionary, signals: Array[Dictionary]) -> Dictionary:
	for signal_data: Dictionary in signals:
		if signal_data.get("id", "") == "threat:" + str(route.get("id", "")) and signal_data.get("category", "") == "threat":
			return signal_data
	# Loss/foreign-contact inspection can exist without a projected species report.
	return {"category":"threat", "confidence":0.0, "strength":0.1, "age":1800.0}


func sync(route: Dictionary, signals: Array[Dictionary], box: Rect2, visual_time: float, active: bool) -> void:
	visible = active
	position = box.position
	size = box.size
	cloud.configure({"id":"inspection:" + str(route.get("id", "")), "center":size * 0.5,
		"radius":minf(size.y * 0.43, 32.0), "signal":evidence(route, signals) if active else {}}, visual_time, not active)
