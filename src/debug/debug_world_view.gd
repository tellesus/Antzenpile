extends Node2D

const Model = preload("res://src/debug/debug_world_model.gd")
var model: RefCounted = Model.new()
var snapshot_provider: Callable
var dispatch_command: Callable
var _dispatch_status: String = ""
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	visible = false
	if not Model.allowed(OS.is_debug_build(), DisplayServer.get_name()):
		set_process(false)
		set_process_input(false)


func _process(_delta: float) -> void:
	if model.shown and snapshot_provider.is_valid():
		model.refresh(snapshot_provider.call(), get_viewport_rect().size)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not Model.allowed(OS.is_debug_build(), DisplayServer.get_name()):
		return
	if event.is_action_pressed("debug_world"):
		model.toggle()
		visible = model.shown
		get_viewport().set_input_as_handled()
	elif model.shown:
		if event is InputEventMouseButton and event.is_action_pressed("select"):
			_select_at(event.position)
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch and event.pressed:
			_select_at(event.position)
			get_viewport().set_input_as_handled()


func _select_at(at: Vector2) -> void:
	if _dispatch_rect().has_point(at) and dispatch_command.is_valid():
		var scout_id: String = "scout_%d" % model.snapshot.next_scout_id
		var accepted: bool = dispatch_command.call()
		_dispatch_status = "Scout dispatched" if accepted else "Dispatch rejected (cap, workers, or path)"
		model.selected_id = scout_id if accepted else "home"
	else:
		model.pick(at)


func _dispatch_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size
	return Rect2(Vector2(size.x * 0.64, size.y - 80), Vector2(size.x * 0.34, 34))


func _draw() -> void:
	if model.snapshot.is_empty():
		return
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("080c12"))
	_label(Vector2(24, 34), "DEBUG: WORLD TRUTH", Color("ffd183"), 24)
	var data: Dictionary = model.snapshot
	_label(Vector2(24, 62), "Seed %s  |  time %.2fs  |  %sx  |  paused: %s" % [data.seed, data.clock.time, data.clock.scale, data.clock.paused])
	_label(Vector2(24, 86), "F3 hide  |  select a marker  |  meters: east +x, south +y")
	var carried: int = 0
	for scout: Dictionary in data.scouts:
		carried += scout.observations.size()
	_label(Vector2(size.x * 0.64, 86), "Private: %d  |  Delivered: %d" % [carried, data.delivered_observations.size()])
	var bounds: Array = data.world.bounds
	var origin: Vector2 = model.transform * Vector2(bounds[0], bounds[1])
	var map_size: Vector2 = Vector2(bounds[2], bounds[3]) * model.transform.x.length()
	draw_rect(Rect2(origin, map_size), Color("657488"), false, 1.0)
	for entry: Dictionary in data.colony.piles + data.world.nodes + data.scouts:
		var at: Vector2 = model.transform * Vector2(entry.position[0], entry.position[1])
		var color := Color("eee7d6")
		if entry.has("definition_id"):
			match entry.definition_id:
				"carbohydrate": color = Color("ffc36b")
				"protein": color = Color("c39cff")
				"water": color = Color("74d5f2")
			draw_circle(at, 6, color)
		elif entry.has("phase"):
			color = Color("a6e5a3")
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(6, 6), at + Vector2(-6, 6)]), color)
		else:
			draw_rect(Rect2(at - Vector2(7, 7), Vector2(14, 14)), color, false, 2)
		if entry.id == model.selected_id:
			draw_arc(at, 12, 0, TAU, 32, Color.WHITE, 1.0)
		var label_offset := Vector2(12, -10) if entry.has("definition_id") else Vector2(12, 24)
		if entry.has("phase"):
			label_offset = Vector2(12, -24)
		_label(at + label_offset, "%s (%.1f,%.1f)" % [entry.id, entry.position[0], entry.position[1]], color, 14)
		if entry.has("definition_id"):
			_label(at + Vector2(12, 9), entry.definition_id, color, 13)
		elif entry.has("phase"):
			_label(at + Vector2(12, -7), entry.phase, color, 13)
	_label(origin + Vector2(0, map_size.y + 24), "World bounds (0,0) to (40,40)")
	var detail: Dictionary = model.selected()
	var lines: Array[String] = ["Select home or a resource"]
	if not detail.is_empty():
		lines = ["ID: " + detail.id, "Position: " + str(detail.position)]
		if detail.has("workers"):
			lines.append("Queens: %s" % detail.queen_count)
			lines.append("Workers total: %s" % detail.workers.total)
			lines.append("Available: %s" % detail.workers.available)
			lines.append("Delivered observations: %d" % data.delivered_observations.size())
			lines.append("Commitments: " + ("none" if detail.workers.commitments.is_empty() else ""))
			for id: String in detail.workers.commitments:
				var entry: Dictionary = detail.workers.commitments[id]
				lines.append("%s: %s (%s / %s)" % [id, entry.count, entry.kind, entry.owner_id])
			for observation: Dictionary in data.delivered_observations.slice(0, 4):
				lines.append("%s: uncertainty %.2fm" % [observation.source_node_id, observation.uncertainty_radius])
		elif detail.has("phase"):
			lines.append("Phase: " + detail.phase)
			lines.append("Origin: " + detail.origin_pile)
			lines.append("Exploration time: %.2fs" % detail.elapsed)
			lines.append("Investigating: " + (detail.investigating if not detail.investigating.is_empty() else "none"))
			lines.append("Private observations: %d" % detail.observations.size())
			for observation: Dictionary in detail.observations.slice(0, 4):
				lines.append("%s: %s" % [observation.source_node_id, "close confirmed" if observation.proximity_confirmed else "chemical cue"])
				lines.append("Estimate (%.2f,%.2f), radius %.2fm" % [observation.estimated_position[0], observation.estimated_position[1], observation.uncertainty_radius])
				var estimate: Vector2 = model.transform * Vector2(observation.estimated_position[0], observation.estimated_position[1])
				draw_arc(estimate, observation.uncertainty_radius * model.transform.x.length(), 0, TAU, 48, Color("a6e5a3"), 1.0)
				draw_line(estimate - Vector2(4, 0), estimate + Vector2(4, 0), Color("a6e5a3"))
				draw_line(estimate - Vector2(0, 4), estimate + Vector2(0, 4), Color("a6e5a3"))
		else:
			lines.append("Definition: " + detail.definition_id)
			lines.append("Quantity: %s" % detail.quantity)
			lines.append("Active: %s" % detail.active)
	for index: int in lines.size():
		_label(Vector2(size.x * 0.64, 132 + 26 * index), lines[index])
	draw_rect(_dispatch_rect(), Color("26332b"))
	_label(_dispatch_rect().position + Vector2(10, 23), "DEBUG: Dispatch general scout")
	_label(_dispatch_rect().position + Vector2(0, 58), _dispatch_status, Color("a6e5a3"), 13)


func _label(at: Vector2, text: String, color: Color = Color("bac7d7"), font_size: int = 16) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
