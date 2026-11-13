class_name ChemicalField
extends Node2D
## Background and material quads sit behind the parent's trails, labels and UI.

const Cloud = preload("res://src/presentation/outward/chemical_cloud.gd")
var clouds: Dictionary = {}
var viewport_size := Vector2.ZERO


func _init() -> void:
	show_behind_parent = true


func sync(entries: Array[Dictionary], empty_ids: Dictionary, visual_time: float, size: Vector2) -> void:
	viewport_size = size
	var present: Dictionary = {}
	for entry: Dictionary in entries:
		present[entry.id] = true
		if not clouds.has(entry.id):
			var cloud := Cloud.new()
			clouds[entry.id] = cloud
			add_child(cloud)
		clouds[entry.id].configure(entry, visual_time, empty_ids.get(entry.id, false))
		clouds[entry.id].modulate=Color(1,1,1,entry.signal.get("memory_alpha",1.0))
	for id: String in clouds.keys():
		if not present.has(id):
			clouds[id].free()
			clouds.erase(id)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color.BLACK)
