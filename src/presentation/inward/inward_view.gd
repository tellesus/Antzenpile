class_name InwardView
extends Node2D
## Abstract functional network; consumes detached pile summaries only.

const NODES: Array[String] = ["queen", "nursery", "food_exchange", "entrance"]
var status_provider: Callable
var mode_command: Callable
var pause_command: Callable
var speed_command: Callable
var develop_command: Callable
var brood_command: Callable
var input_blocked: Callable
var save_command: Callable
var load_command: Callable
var selected_id: String = ""
var _status: Dictionary = {}
var _font: Font = ThemeDB.fallback_font
var _feedback: String = ""
var _feedback_until: int = 0


func show_feedback(message: String) -> void:
	_feedback = message
	_feedback_until = Time.get_ticks_msec() + 3000


func _process(_delta: float) -> void:
	if status_provider.is_valid():
		_status = status_provider.call()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or input_blocked.is_valid() and input_blocked.call():
		return
	var at: Vector2
	if event is InputEventScreenTouch and event.pressed:
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		at = event.position
	else:
		return
	if activate_at(at):
		get_viewport().set_input_as_handled()


func activate_at(at: Vector2) -> bool:
	if selected_id in ["queen", "nursery"] and _status.get("queens", 0) > 0 and _status.get("brood", []).is_empty() and _status.get("nursery_brood_capacity", 0) - _status.get("nursery_occupied_space", 0) >= _status.get("brood_batch_count", 0) and _brood_rect().has_point(at):
		_run_command("lay_brood")
		return true
	if selected_id == "food_exchange" and _status.get("food_exchange_state", "") == "primitive" and _develop_rect().has_point(at):
		_run_command("develop")
		return true
	for command: String in ["outward", "pause", "speed_1", "speed_4", "speed_16", "speed_64", "save", "load"]:
		if _button_rect(command).has_point(at):
			_run_command(command)
			return true
	var picked: String = node_at(at, get_viewport_rect().size)
	if not picked.is_empty():
		selected_id = picked
		queue_redraw()
		return true
	return false


func _run_command(command: String) -> void:
	match command:
		"outward":
			if mode_command.is_valid():
				mode_command.call()
		"pause":
			if pause_command.is_valid():
				pause_command.call()
		"develop":
			if develop_command.is_valid():
				var result: Dictionary = develop_command.call()
				_feedback = "Development started" if result.get("accepted", false) else result.get("reason", "Requirements unmet")
				_feedback_until = Time.get_ticks_msec() + 3000
		"lay_brood":
			if brood_command.is_valid():
				var result: Dictionary = brood_command.call()
				_feedback = "New brood started" if result.get("accepted", false) else result.get("reason", "Brood unavailable")
				_feedback_until = Time.get_ticks_msec() + 3000
		"save", "load":
			var action: Callable = save_command if command == "save" else load_command
			if action.is_valid():
				var result: Dictionary = action.call()
				_feedback = ("Run saved" if command == "save" else "Run loaded") if result.get("accepted", false) else result.get("reason", "Save unavailable")
				_feedback_until = Time.get_ticks_msec() + 3000
		_:
			if command.begins_with("speed_") and speed_command.is_valid():
				speed_command.call(int(command.trim_prefix("speed_")))


static func positions(size: Vector2) -> Dictionary:
	var field_width: float = minf(size.x * 0.65, size.x - 340.0)
	var field_height: float = maxf(0.0, size.y - 210.0)
	var origin := Vector2(24.0, 90.0)
	return {"queen": origin + Vector2(field_width * 0.28, field_height * 0.25),
		"nursery": origin + Vector2(field_width * 0.72, field_height * 0.32),
		"food_exchange": origin + Vector2(field_width * 0.72, field_height * 0.72),
		"entrance": origin + Vector2(field_width * 0.28, field_height * 0.78)}


static func node_at(at: Vector2, size: Vector2) -> String:
	for id: String in NODES:
		if at.distance_to(positions(size)[id]) <= 44.0:
			return id
	return ""


func _button_rect(command: String) -> Rect2:
	var y: float = get_viewport_rect().size.y - 104.0
	match command:
		"outward": return Rect2(24, y, 148, 64)
		"pause": return Rect2(188, y, 104, 64)
		"speed_1": return Rect2(308, y, 62, 64)
		"speed_4": return Rect2(378, y, 62, 64)
		"speed_16": return Rect2(448, y, 62, 64)
		"speed_64": return Rect2(518, y, 62, 64)
		"save": return Rect2(get_viewport_rect().size.x - 220, 78, 100, 64)
		"load": return Rect2(get_viewport_rect().size.x - 112, 78, 100, 64)
	return Rect2()


func _develop_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 380.0, 260.0, 44.0)


func _brood_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 380.0, 260.0, 44.0)


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("080b10"))
	var centers: Dictionary = positions(size)
	for pair: Array in [["queen", "nursery"], ["nursery", "food_exchange"], ["food_exchange", "entrance"], ["entrance", "queen"]]:
		draw_line(centers[pair[0]], centers[pair[1]], Color(0.33, 0.49, 0.49, 0.20), 1.0, true)
	for id: String in NODES:
		_draw_node(id, centers[id])
	_draw_hud(size)
	_draw_context(size)
	_draw_controls(size)


func _draw_node(id: String, at: Vector2) -> void:
	var color: Color = Color("d5c4a1") if id == "queen" else Color("aebdb7") if id == "nursery" else Color("c7af86") if id == "food_exchange" else Color("8daeb3")
	draw_circle(at, 32.0, Color(color.r, color.g, color.b, 0.035))
	draw_arc(at, 25.0, -0.65, PI * 1.55, 36, Color(color.r, color.g, color.b, 0.55), 1.5, true)
	draw_circle(at, 4.0, Color(color.r, color.g, color.b, 0.65))
	if id == selected_id:
		draw_arc(at, 39.0, 0.0, TAU, 48, Color("dce5d9"), 1.0, true)
	_label(at + Vector2(0, 52), _title(id), color, 15, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_hud(size: Vector2) -> void:
	_label(Vector2(24, 38), "INWARD  /  HOME", Color("dad7c8"), 22)
	_label(Vector2(24, 63), "Tap a function to listen.", Color("82939c"), 13)
	if not _status.is_empty():
		_label(Vector2(size.x - 24, 36), "%d available" % _status.workers_available, Color("c9d1c5"), 15, HORIZONTAL_ALIGNMENT_RIGHT)
		var pause_word: String = "PAUSED" if _status.paused else "%dx" % _status.time_scale
		_label(Vector2(size.x - 24, 61), "%s  ·  %.0fs" % [pause_word, _status.time], Color("83969d"), 13, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_context(size: Vector2) -> void:
	if selected_id.is_empty() or _status.is_empty():
		return
	var box := Rect2(Vector2(size.x - 316, 144), Vector2(292, 284))
	draw_rect(box, Color("111921"))
	draw_rect(box, Color("41535a"), false, 1.0)
	_label(box.position + Vector2(16, 31), _title(selected_id), Color("d9d3be"), 20)
	match selected_id:
		"queen":
			_detail_line(box, 65, "Queens: %d" % _status.queens)
			_detail_line(box, 91, "Living workers: %d" % _status.workers_total)
			_detail_line(box, 117, "Available workers: %d" % _status.workers_available)
			_detail_line(box, 157, "Nursery: %d / %d brood space" % [_status.nursery_occupied_space, _status.nursery_brood_capacity])
			if _status.queens > 0 and _status.brood.is_empty() and _status.nursery_brood_capacity - _status.nursery_occupied_space >= _status.brood_batch_count:
				_draw_brood_button()
		"nursery":
			var brood: Array = _status.brood
			var count: int = 0
			for cohort: Dictionary in brood:
				count += cohort.count
			_detail_line(box, 65, "Brood space: %d / %d" % [count, _status.nursery_brood_capacity])
			_detail_line(box, 91, "Care capacity: %d / %d" % [_status.nursery_care_capacity, _status.nursery_max_care_capacity])
			if not brood.is_empty():
				_detail_line(box, 117, "%s · %.0fs" % [brood[0].stage.capitalize(), brood[0].progress_seconds])
				_detail_line(box, 143, "Food %s · care %s" % ["enough" if brood[0].nutrition >= 1.0 else "short", "enough" if brood[0].care >= 1.0 else "short"])
			_detail_line(box, 181, "Workers emerged: %d" % _status.brood_matured_total)
			if _status.queens > 0 and brood.is_empty() and _status.nursery_brood_capacity - _status.nursery_occupied_space >= _status.brood_batch_count:
				_draw_brood_button()
		"food_exchange":
			if _status.food_exchange_state == "primitive":
				_detail_line(box, 65, "Primitive Food Exchange")
				_detail_line(box, 99, "Needs %.0f carb · %.0f protein" % [_status.food_exchange_costs.carbohydrate, _status.food_exchange_costs.protein])
				_detail_line(box, 125, "%.0f water · %d workers" % [_status.food_exchange_costs.water, _status.food_exchange_workers_required])
				_detail_line(box, 157, "Build: %.0f simulated seconds" % _status.food_exchange_duration)
				_detail_line(box, 185, "Stores: %.1f / %.1f / %.1f" % [_status.resources.carbohydrate, _status.resources.protein, _status.resources.water])
				draw_rect(_develop_rect(), Color("35483c"))
				_label(_develop_rect().position + Vector2(130, 29), "DEVELOP", Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)
			elif _status.food_exchange_state == "developing":
				_detail_line(box, 65, "Developing Food Exchange")
				_detail_line(box, 99, "%.0f / %.0f simulated seconds" % [_status.food_exchange_progress, _status.food_exchange_duration])
				_detail_line(box, 125, "%d workers committed" % _status.food_exchange_workers_required)
				_detail_line(box, 157, "Resources paid at start")
			else:
				_detail_line(box, 65, "Developed Food Exchange")
				_detail_line(box, 99, "Larval food use: %.0f%% less" % [(1.0 - _status.food_exchange_food_multiplier) * 100.0])
				_detail_line(box, 137, "Carbohydrate: %.1f" % _status.resources.carbohydrate)
				_detail_line(box, 163, "Protein: %.1f" % _status.resources.protein)
				_detail_line(box, 189, "Water: %.1f" % _status.resources.water)
		"entrance":
			_detail_line(box, 65, "Available workers: %d" % _status.workers_available)
			_detail_line(box, 91, "Scouts away: %d" % _status.active_scouts)
			_detail_line(box, 117, "Trail workers: %d" % _status.trail_workers)


func _detail_line(box: Rect2, y: float, value: String) -> void:
	_label(box.position + Vector2(16, y), value, Color("a9b9bc"), 14)


func _draw_brood_button() -> void:
	draw_rect(_brood_rect(), Color("35483c"))
	_label(_brood_rect().position + Vector2(130, 29), "LAY %d BROOD" % _status.brood_batch_count, Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_controls(size: Vector2) -> void:
	for command: String in ["outward", "pause", "speed_1", "speed_4", "speed_16", "speed_64", "save", "load"]:
		var box: Rect2 = _button_rect(command)
		var active: bool = command.begins_with("speed_") and not _status.is_empty() and int(command.trim_prefix("speed_")) == _status.time_scale
		draw_rect(box, Color("31505a") if active else Color("18252b"))
		var title: String = "OUTWARD" if command == "outward" else "SAVE" if command == "save" else "LOAD" if command == "load" else "RESUME" if command == "pause" and _status.get("paused", false) else "PAUSE" if command == "pause" else command.trim_prefix("speed_") + "x"
		_label(box.position + Vector2(box.size.x * 0.5, 40), title, Color("d3dcd4"), 14 if command in ["save", "load"] else 16, HORIZONTAL_ALIGNMENT_CENTER)
	var footer: String = _feedback if Time.get_ticks_msec() < _feedback_until else "Tab: switch view  ·  Space: pause  ·  1–4: time"
	_label(Vector2(24, size.y - 17), footer, Color("a9bcad") if footer == _feedback else Color("7e8e94"), 13)


static func _title(id: String) -> String:
	match id:
		"queen": return "Queen"
		"nursery": return "Nursery"
		"food_exchange": return "Food Exchange"
		"entrance": return "Entrance"
	return ""


func _label(at: Vector2, value: String, color: Color, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var placed: Vector2 = at
	var width: float = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		placed.x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		placed.x -= width
	draw_string(_font, placed, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
