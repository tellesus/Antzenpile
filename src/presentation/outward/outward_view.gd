class_name OutwardView
extends Node2D
## Normal-play sensorium. Providers deliver approved detached values only.

const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
var signal_provider: Callable
var status_provider: Callable
var dispatch_command: Callable
var pause_command: Callable
var speed_command: Callable
var trail_create_command: Callable
var trail_set_command: Callable
var input_blocked: Callable
var facing: float = 0.0
var selected_id: String = ""

var _signals: Array[Dictionary] = []
var _status: Dictionary = {}
var _placed: Array[Dictionary] = []
var _font: Font = ThemeDB.fallback_font
var _pointer_kind: String = ""
var _pointer_start: Vector2
var _pointer_last: Vector2
var _dragged: bool = false
var _feedback: String = ""
var _feedback_until: int = 0


func _process(_delta: float) -> void:
	if signal_provider.is_valid() and status_provider.is_valid():
		_signals = signal_provider.call()
		_status = status_provider.call()
		_placed = Panorama.project(_signals, facing, get_viewport_rect().size)
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if input_blocked.is_valid() and input_blocked.call():
		_pointer_kind = ""
		return
	if event.is_action_pressed("pause"):
		_run_command("pause")
		get_viewport().set_input_as_handled()
		return
	for index: int in range(4):
		if event.is_action_pressed("time_%d" % [1, 4, 16, 64][index]):
			_run_command("speed_%d" % [1, 4, 16, 64][index])
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pointer_press(event.position, "touch")
		else:
			_pointer_release(event.position, "touch")
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _pointer_kind == "touch":
		_pointer_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _pointer_kind != "touch":
		if event.pressed:
			_pointer_press(event.position, "mouse")
		else:
			_pointer_release(event.position, "mouse")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer_kind == "mouse":
		_pointer_drag(event.position)
		get_viewport().set_input_as_handled()


func _pointer_press(at: Vector2, kind: String) -> void:
	var command: String = _button_at(at)
	if not command.is_empty():
		_run_command(command)
		return
	if _field_rect().has_point(at):
		_pointer_kind = kind
		_pointer_start = at
		_pointer_last = at
		_dragged = false


func _pointer_drag(at: Vector2) -> void:
	if _pointer_kind.is_empty():
		return
	if at.distance_to(_pointer_start) > 8.0:
		_dragged = true
	if _dragged:
		turn_pixels(at.x - _pointer_last.x, get_viewport_rect().size.x)
	_pointer_last = at


func _pointer_release(at: Vector2, kind: String) -> void:
	if _pointer_kind != kind:
		return
	if not _dragged and at.distance_to(_pointer_start) <= 8.0:
		selected_id = Panorama.pick(_placed, at)
	_pointer_kind = ""


func turn_pixels(delta_x: float, width: float) -> void:
	if is_finite(delta_x) and is_finite(width) and width > 0:
		facing = fposmod(facing - delta_x * PI / width, TAU)
		_placed = Panorama.project(_signals, facing, get_viewport_rect().size)
		queue_redraw()


func _run_command(command: String) -> void:
	match command:
		"trail_create", "trail_less", "trail_more", "trail_cancel":
			var signal_data: Dictionary = _selected_signal()
			if signal_data.is_empty():
				return
			var route: Dictionary = _selected_route(signal_data)
			var result: Dictionary = {}
			if route.is_empty() or route.status == "inactive":
				if command != "trail_create" or not trail_create_command.is_valid():
					return
				result = trail_create_command.call(signal_data.source_knowledge_id)
			else:
				if not trail_set_command.is_valid():
					return
				var target: int = 0 if command == "trail_cancel" else maxi(0, route.desired_workers - 1) if command == "trail_less" else route.desired_workers + 1
				result = trail_set_command.call(route.id, target)
			_feedback = "Trail updated" if result.get("accepted", false) else result.get("reason", "Trail unavailable")
		"scout":
			if not dispatch_command.is_valid() or _status.get("available_workers", 0) < 1 or _status.get("active_scouts", 0) >= _status.get("scout_cap", 0):
				_feedback = "No scout available"
			else:
				_feedback = "Scout sent" if dispatch_command.call(facing) else "Scout path unavailable"
		"pause":
			if pause_command.is_valid():
				pause_command.call()
		_:
			if command.begins_with("speed_") and speed_command.is_valid():
				speed_command.call(int(command.trim_prefix("speed_")))
	if not _feedback.is_empty():
		_feedback_until = Time.get_ticks_msec() + 3000


func _field_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size
	return Rect2(Vector2(0, 98), Vector2(size.x, maxf(0.0, size.y - 198)))


func _button_rect(command: String) -> Rect2:
	var y: float = get_viewport_rect().size.y - 104.0
	match command:
		"scout": return Rect2(24, y, 148, 64)
		"pause": return Rect2(188, y, 104, 64)
		"speed_1": return Rect2(308, y, 62, 64)
		"speed_4": return Rect2(378, y, 62, 64)
		"speed_16": return Rect2(448, y, 62, 64)
		"speed_64": return Rect2(518, y, 62, 64)
	return Rect2()


func _button_at(at: Vector2) -> String:
	if not _selected_signal().is_empty():
		var route: Dictionary = _selected_route(_selected_signal())
		var contextual: Array[String] = []
		if route.is_empty() or route.status == "inactive":
			contextual.append("trail_create")
		else:
			contextual.append_array(["trail_less", "trail_more", "trail_cancel"])
		for command: String in contextual:
			if _trail_button_rect(command).has_point(at):
				return command
	for command: String in ["scout", "pause", "speed_1", "speed_4", "speed_16", "speed_64"]:
		if _button_rect(command).has_point(at):
			return command
	return ""


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("080b10"))
	_draw_anchor(size)
	for entry: Dictionary in _placed:
		_draw_signal(entry)
	_draw_hud(size)
	_draw_context(size)
	_draw_controls(size)


func _draw_anchor(size: Vector2) -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.78)
	draw_circle(center + Vector2(0, 8), 57, Color(0.37, 0.25, 0.13, 0.08))
	draw_arc(center, 52, PI, TAU, 40, Color(0.65, 0.45, 0.26, 0.25), 2.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-30, 17), center + Vector2(-15, -10), center + Vector2(0, -18), center + Vector2(15, -10), center + Vector2(30, 17)]), Color("191815"))
	draw_arc(center + Vector2(0, 12), 14, PI, TAU, 24, Color("9b8d70"), 2.0)
	_label(center + Vector2(-25, 42), "HOME", Color("8f988e"), 11)


func _draw_signal(entry: Dictionary) -> void:
	var signal_data: Dictionary = entry.signal
	var at: Vector2 = entry.center
	var radius: float = entry.radius
	var color: Color = _signal_color(signal_data.category)
	for index: int in range(3):
		var halo: Color = color
		halo.a = (0.035 + 0.015 * index) * maxf(0.2, signal_data.strength)
		draw_circle(at + Vector2(index * 4 - 4, (index - 1) * 3), radius * (1.4 - index * 0.28), halo)
	var line: Color = color
	line.a = clampf(signal_data.strength * 0.85 + 0.1, 0.1, 0.8)
	draw_arc(at, radius * 0.66, -1.1, 1.5, 28, line, 2.0)
	if signal_data.category == "water":
		draw_arc(at, radius * 0.43, 0.45, 2.6, 24, line, 1.5)
	if entry.id == selected_id:
		draw_arc(at, radius + 7, 0, TAU, 48, Color(0.89, 0.91, 0.84, 0.48), 1.5)
	_label(at + Vector2(0, radius + 22), _signal_title(signal_data.category), color, 13, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_hud(size: Vector2) -> void:
	_label(Vector2(24, 38), "OUTWARD  /  HOME", Color("dad7c8"), 22)
	_label(Vector2(24, 63), "Drag to turn. Tap a trace to listen.", Color("82939c"), 13)
	_label(Vector2(size.x * 0.5, 38), facing_text(facing), Color("a9bbc1"), 14, HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(size.x * 0.5, 53), Vector2(size.x * 0.5, 72), Color("769aa3"), 1.0)
	if not _status.is_empty():
		_label(Vector2(size.x - 24, 36), "%d available  /  scouts %d/%d" % [_status.available_workers, _status.active_scouts, _status.scout_cap], Color("c9d1c5"), 15, HORIZONTAL_ALIGNMENT_RIGHT)
		var pause_word: String = "PAUSED" if _status.paused else "%dx" % _status.time_scale
		_label(Vector2(size.x - 24, 61), "%s  ·  %.0fs" % [pause_word, _status.time], Color("83969d"), 13, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_context(size: Vector2) -> void:
	var selected: Dictionary = _selected_signal()
	if selected.is_empty():
		return
	var box := Rect2(Vector2(size.x - 316, 144), Vector2(292, 246))
	draw_rect(box, Color("111921"))
	draw_rect(box, Color("41535a"), false, 1.0)
	_label(box.position + Vector2(16, 31), _signal_title(selected.category), _signal_color(selected.category), 20)
	_label(box.position + Vector2(16, 58), "A %s trace" % selected.confidence_label, Color("d4d8d1"), 15)
	var distance_word: String = "nearby" if selected.estimated_distance < 6.0 else "within reach" if selected.estimated_distance < 14.0 else "distant"
	_label(box.position + Vector2(16, 84), "Feels %s · around %.0f m" % [distance_word, selected.estimated_distance], Color("a8b8bd"), 14)
	_label(box.position + Vector2(16, 109), "Last sensed %.0f s ago" % selected.age, Color("8fa1a8"), 13)
	_label(box.position + Vector2(16, 137), "Risk unknown", Color("8fa1a8"), 13)
	var route: Dictionary = _selected_route(selected)
	if route.is_empty() or route.status == "inactive":
		_label(box.position + Vector2(16, 165), "Trail: no workers committed", Color("a8b8bd"), 13)
		_draw_trail_button("trail_create", "INVEST 5 WORKERS")
	else:
		_label(box.position + Vector2(16, 165), "Trail: %d desired / %d allocated" % [route.desired_workers, route.allocated_workers], Color("a8b8bd"), 13)
		_label(box.position + Vector2(16, 183), "Workers in transit: %d" % route.active_workers, Color("8fa1a8"), 12)
		_draw_trail_button("trail_less", "− 1")
		_draw_trail_button("trail_more", "+ 1")
		_draw_trail_button("trail_cancel", "CANCEL")


func _selected_signal() -> Dictionary:
	for signal_data: Dictionary in _signals:
		if signal_data.id == selected_id:
			return signal_data
	return {}


func _selected_route(signal_data: Dictionary) -> Dictionary:
	for route: Dictionary in _status.get("trails", []):
		if route.destination_knowledge_id == signal_data.source_knowledge_id:
			return route
	return {}


func _trail_button_rect(command: String) -> Rect2:
	var x: float = get_viewport_rect().size.x - 300.0
	match command:
		"trail_create": return Rect2(x, 342, 260, 44)
		"trail_less": return Rect2(x, 342, 64, 44)
		"trail_more": return Rect2(x + 72, 342, 64, 44)
		"trail_cancel": return Rect2(x + 144, 342, 116, 44)
	return Rect2()


func _draw_trail_button(command: String, title: String) -> void:
	var box: Rect2 = _trail_button_rect(command)
	draw_rect(box, Color("263b3c"))
	_label(box.position + Vector2(box.size.x * 0.5, 29), title, Color("d5ded8"), 13, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_controls(size: Vector2) -> void:
	for command: String in ["scout", "pause", "speed_1", "speed_4", "speed_16", "speed_64"]:
		var box: Rect2 = _button_rect(command)
		var active: bool = command.begins_with("speed_") and not _status.is_empty() and int(command.trim_prefix("speed_")) == _status.time_scale
		var unavailable: bool = command == "scout" and not _status.is_empty() and (_status.available_workers < 1 or _status.active_scouts >= _status.scout_cap)
		var color: Color = Color("28342f") if command == "scout" else Color("18252b")
		if active:
			color = Color("31505a")
		if unavailable:
			color = Color("202326")
		draw_rect(box, color)
		var title: String = "SEND SCOUT" if command == "scout" else "RESUME" if command == "pause" and _status.get("paused", false) else "PAUSE" if command == "pause" else command.trim_prefix("speed_") + "x"
		_label(box.position + Vector2(box.size.x * 0.5, 40), title, Color("d3dcd4") if not unavailable else Color("78817e"), 16, HORIZONTAL_ALIGNMENT_CENTER)
	if not _feedback.is_empty() and Time.get_ticks_msec() < _feedback_until:
		_label(Vector2(24, size.y - 17), _feedback, Color("b6c8b2"), 13)
	else:
		_label(Vector2(24, size.y - 17), "Space: pause  ·  1–4: time", Color("7e8e94"), 13)


func _signal_color(category: String) -> Color:
	match category:
		"carbohydrate": return Color("e9ae63")
		"protein": return Color("bd9ad9")
		"water": return Color("77cddd")
	return Color("b2b9b8")


func _signal_title(category: String) -> String:
	match category:
		"carbohydrate": return "Food trace"
		"protein": return "Protein trace"
		"water": return "Water trace"
	return "Unknown trace"


static func facing_text(angle: float) -> String:
	return "FACING  %03d°" % (roundi(rad_to_deg(angle)) % 360)


func _label(at: Vector2, value: String, color: Color, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var placed: Vector2 = at
	var width: float = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		placed.x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		placed.x -= width
	draw_string(_font, placed, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
