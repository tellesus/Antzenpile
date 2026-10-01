class_name OutwardView
extends Node2D
## Normal-play sensorium. Providers deliver approved detached values only.

const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const Art = preload("res://src/presentation/sensory_art.gd")
const Scent = preload("res://src/presentation/outward/trail_visual.gd")
var signal_provider: Callable
var status_provider: Callable
var dispatch_command: Callable
var pause_command: Callable
var speed_command: Callable
var trail_create_command: Callable
var trail_set_command: Callable
var trail_recheck_command: Callable
var investigate_command: Callable
var honeydew_start_command: Callable
var honeydew_stop_command: Callable
var input_blocked: Callable
var mode_command: Callable
var save_command: Callable
var load_command: Callable
var facing: float = 0.0
var selected_id: String = ""

var _animation_time: float = 0.0
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


func show_feedback(message: String) -> void:
	_feedback = message
	_feedback_until = Time.get_ticks_msec() + 3000


func _process(delta: float) -> void:
	if signal_provider.is_valid() and status_provider.is_valid():
		_signals = signal_provider.call()
		_status = status_provider.call()
		_placed = Panorama.project(_signals, facing, get_viewport_rect().size)
	if not _status.get("paused", false):
		_animation_time = fposmod(_animation_time + minf(delta, 0.1), 3600.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
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
		"honeydew_start", "honeydew_stop":
			var signal_data: Dictionary = _selected_signal()
			if signal_data.is_empty() or not _is_honeydew(signal_data):
				return
			var action: Callable = honeydew_start_command if command == "honeydew_start" else honeydew_stop_command
			if not action.is_valid():
				return
			var result: Dictionary = action.call(signal_data.source_knowledge_id)
			_feedback = ("Producers protected" if command == "honeydew_start" else "Protection withdrawn") if result.get("accepted", false) else result.get("reason", "Protection unavailable")
		"investigate":
			var signal_data: Dictionary = _selected_signal()
			if signal_data.is_empty() or not investigate_command.is_valid():
				return
			var result: Dictionary = investigate_command.call(signal_data.source_knowledge_id)
			_feedback = "Scout investigating remembered source" if result.get("accepted", false) else result.get("reason", "Investigation unavailable")
		"trail_create", "trail_less", "trail_more", "trail_cancel", "trail_recheck":
			var signal_data: Dictionary = _selected_signal()
			if signal_data.is_empty():
				return
			var route: Dictionary = _selected_route(signal_data)
			var result: Dictionary = {}
			if command == "trail_recheck":
				if route.is_empty() or route.status != "depleted" or not trail_recheck_command.is_valid():
					return
				result = trail_recheck_command.call(route.id)
			elif route.is_empty() or route.status in ["inactive", "recalling"]:
				if command != "trail_create" or not trail_create_command.is_valid():
					return
				result = trail_create_command.call(signal_data.source_knowledge_id)
			else:
				if not trail_set_command.is_valid():
					return
				var target: int = 0 if command == "trail_cancel" else maxi(0, route.desired_workers - 1) if command == "trail_less" else route.desired_workers + 1
				result = trail_set_command.call(route.id, target)
			_feedback = ("Workers sent to recheck" if command == "trail_recheck" else "Trail updated") if result.get("accepted", false) else result.get("reason", "Trail unavailable")
		"scout":
			if not dispatch_command.is_valid() or _status.get("available_workers", 0) < 1 or _status.get("active_scouts", 0) >= _status.get("scout_cap", 0):
				_feedback = "No scout available"
			else:
				_feedback = "Scout sent" if dispatch_command.call(facing) else "Scout path unavailable"
		"pause":
			if pause_command.is_valid():
				pause_command.call()
		"inward":
			if mode_command.is_valid():
				mode_command.call()
		"save", "load":
			var action: Callable = save_command if command == "save" else load_command
			if action.is_valid():
				var result: Dictionary = action.call()
				_feedback = ("Run saved" if command == "save" else "Run loaded") if result.get("accepted", false) else result.get("reason", "Save unavailable")
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
		"inward": return Rect2(get_viewport_rect().size.x - 172, y, 148, 64)
		"save": return Rect2(get_viewport_rect().size.x - 220, 78, 100, 64)
		"load": return Rect2(get_viewport_rect().size.x - 112, 78, 100, 64)
	return Rect2()


func _button_at(at: Vector2) -> String:
	if not _selected_signal().is_empty():
		if _is_honeydew(_selected_signal()):
			var relationship: String = _status.get("honeydew", {}).get("relationship", "unknown")
			var honeydew_command: String = "honeydew_stop" if relationship == "tended" else "honeydew_start" if relationship == "exploited" else ""
			if not honeydew_command.is_empty() and _honeydew_button_rect().has_point(at):
				return honeydew_command
		if _investigate_button_rect().has_point(at):
			return "investigate"
		var route: Dictionary = _selected_route(_selected_signal())
		var contextual: Array[String] = []
		if route.is_empty() or route.status in ["inactive", "recalling"]:
			contextual.append("trail_create")
		elif route.status == "depleted":
			if route.active_workers == 0:
				contextual.append("trail_recheck")
			contextual.append("trail_cancel")
		else:
			contextual.append_array(["trail_less", "trail_more", "trail_cancel"])
		for command: String in contextual:
			if _trail_button_rect(command).has_point(at):
				return command
	for command: String in ["scout", "pause", "speed_1", "speed_4", "speed_16", "speed_64", "inward", "save", "load"]:
		if _button_rect(command).has_point(at):
			return command
	return ""


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("080b10"))
	_draw_rain(size)
	_draw_trails(size)
	_draw_anchor(size)
	for entry: Dictionary in _placed:
		_draw_signal(entry)
	_draw_hud(size)
	_draw_context(size)
	_draw_controls(size)


func _draw_rain(size: Vector2) -> void:
	if _status.get("rain_phase", "") != "raining":
		return
	# Sparse, fixed screen-space interference; it contains no physical map data.
	for index: int in 18:
		var at := Vector2(fmod(float(index * 173 + 41), size.x), fmod(float(index * 97 + 120), size.y - 130.0) + 85.0)
		draw_line(at, at + Vector2(-7, 22), Color(0.48, 0.68, 0.76, 0.10), 1.0, true)


func _draw_trails(size: Vector2) -> void:
	var routes: Array = _status.get("trails", [])
	for stroke: Dictionary in Scent.strokes(routes, _placed, size):
		var strength: float = clampf(stroke.strength, 0.0, 1.0)
		var color: Color = Art.color_for(stroke.category)
		if stroke.ghost:
			draw_polyline(stroke.points, Color(color, 0.06 + 0.05 * strength), 0.85, true)
		else:
			draw_polyline(stroke.points, Color(color, 0.025 + 0.045 * strength), 4.0, true)
			draw_polyline(stroke.points, Color(color.lightened(0.18), 0.16 + 0.5 * strength), 1.1, true)
	for path: Dictionary in Scent.paths(routes, _placed, size):
		if path.ghost:
			continue
		for index: int in 8:
			var sample: float = fposmod(_animation_time * 0.025 + index / 8.0, 0.96) * Scent.STEPS
			var first: int = int(sample)
			var at: Vector2 = path.points[first].lerp(path.points[first + 1], sample - first)
			at += Vector2(sin(index * 2.7 + _animation_time), cos(index * 1.8 + _animation_time * 0.7)) * 3.5
			draw_circle(at, 0.75, Color(Art.color_for(path.category), 0.12 * path.strength))
	for rep: Dictionary in Scent.representatives(routes, _placed, size, _animation_time):
		Art.ant(self, rep.position, rep.direction, Color(Art.color_for(rep.category).lightened(0.25), 0.62), _animation_time, 0.82)


func _draw_anchor(size: Vector2) -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.78)
	draw_circle(center + Vector2(0, 8), 57, Color(0.37, 0.25, 0.13, 0.08))
	draw_arc(center, 52, PI, TAU, 40, Color(0.65, 0.45, 0.26, 0.25), 2.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-30, 17), center + Vector2(-15, -10), center + Vector2(0, -18), center + Vector2(15, -10), center + Vector2(30, 17)]), Color("191815"))
	draw_arc(center + Vector2(0, 12), 14, PI, TAU, 24, Color("9b8d70"), 2.0)
	var traffic: int = int(_status.get("active_scouts", 0))
	for route: Dictionary in _status.get("trails", []):
		traffic += int(route.get("active_workers", 0))
	for index: int in mini(3, traffic):
		var phase: float = fposmod(_animation_time * 0.16 + index * 0.34, 1.0)
		var at: Vector2 = center + Vector2(index * 12 - 12, 15 - phase * 42)
		Art.ant(self, at, Vector2.UP if index % 2 == 0 else Vector2.DOWN, Color(0.68, 0.61, 0.45, 0.58), _animation_time + index)
	_label(center + Vector2(-25, 42), "HOME", Color("8f988e"), 11)


func _draw_signal(entry: Dictionary) -> void:
	var signal_data: Dictionary = entry.signal
	var at: Vector2 = entry.center
	var radius: float = entry.radius
	var reported_empty: bool = _reported_empty(signal_data)
	var color: Color = Color("819092") if reported_empty else Art.color_for(signal_data.category)
	Art.cloud(self, entry, _animation_time, reported_empty)
	if entry.id == selected_id:
		var attention: PackedVector2Array = Art.membrane(at, radius + 8.0, 1.5)
		draw_polyline(attention.slice(1, 7), Color(0.88, 0.91, 0.83, 0.48), 1.2, true)
		draw_polyline(attention.slice(17, 23), Color(0.88, 0.91, 0.83, 0.48), 1.2, true)
	var title: String = _signal_title_for(signal_data) + " · EMPTY" if reported_empty else _signal_title_for(signal_data)
	if signal_data.get("risk") == "reported_loss":
		title += " · ALARM"
	_label(at + Vector2(0, radius + 22), title, color, 13, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_hud(size: Vector2) -> void:
	_label(Vector2(24, 38), "OUTWARD  /  HOME", Color("dad7c8"), 22)
	_label(Vector2(24, 63), "Drag to turn. Tap a trace to listen.", Color("82939c"), 13)
	if _status.get("rain_phase", "") == "raining":
		_label(Vector2(24, 92), "RAIN  /  scent disturbed", Color("8aadb8"), 13)
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
	var box := Rect2(Vector2(size.x - 316, 144), Vector2(292, 344))
	draw_rect(box, Color("111921"))
	draw_rect(box, Color("41535a"), false, 1.0)
	_label(box.position + Vector2(16, 31), _signal_title_for(selected), Color("819092") if _reported_empty(selected) else _signal_color(selected.category), 20)
	_label(box.position + Vector2(16, 58), "A %s trace" % selected.confidence_label, Color("d4d8d1"), 15)
	var distance_word: String = "nearby" if selected.estimated_distance < 6.0 else "within reach" if selected.estimated_distance < 14.0 else "distant"
	_label(box.position + Vector2(16, 84), "Feels %s · around %.0f m" % [distance_word, selected.estimated_distance], Color("a8b8bd"), 14)
	_label(box.position + Vector2(16, 109), "Last sensed %.0f s ago" % selected.age, Color("8fa1a8"), 13)
	var hint: Dictionary = _status.get("temporal_hints", {}).get(selected.source_knowledge_id, {})
	var loss_route: Dictionary = _selected_route(selected)
	var losses: int = int(loss_route.get("reported_losses", 0))
	var hint_text: String = "%d %s lost · cause uncertain" % [losses, "worker" if losses == 1 else "workers"] if losses > 0 else hint.label if not hint.is_empty() else "Risk unknown"
	_label(box.position + Vector2(16, 137), hint_text, Color("c48c7c") if losses > 0 else Color("8fa1a8"), 13)
	if _is_honeydew(selected):
		_draw_honeydew_context(selected, box)
		return
	var route: Dictionary = _selected_route(selected)
	if route.is_empty() or route.status == "inactive":
		var idle_text: String = "Trail: no workers committed" if route.is_empty() or _scent_label(route) == "absent" and float(route.get("route_familiarity", 0.0)) < 0.1 else "No workers · scent " + _scent_label(route)
		_label(box.position + Vector2(16, 165), idle_text, Color("a8b8bd"), 13)
		_label(box.position + Vector2(16, 187), "Home stores: %.1f" % _status.get("resources", {}).get(selected.category, 0.0), Color("8fa1a8"), 13)
		_draw_trail_button("trail_create", "INVEST 5 WORKERS")
	elif route.status == "recalling":
		_label(box.position + Vector2(16, 165), "Recalling: %d workers away" % route.active_workers, Color("a8b8bd"), 13)
		_label(box.position + Vector2(16, 187), "Scent %s · Delivered %.1f" % [_scent_label(route), route.delivered_total], Color("8fa1a8"), 13)
		_draw_trail_button("trail_create", "REINVEST 5 WORKERS")
	else:
		var route_note: String = "Source unavailable · scent " + _scent_label(route) if route.status == "depleted" else "Waiting for carbohydrate" if route.get("energy_limited", false) else "Trail scent: " + _scent_label(route)
		_label(box.position + Vector2(16, 165), route_note, Color("a8b8bd"), 14)
		_label(box.position + Vector2(16, 185), "Wanted %d · Committed %d" % [route.desired_workers, route.allocated_workers], Color("8fa1a8"), 14)
		var traffic: String = "%d travelling · %d checking" % [route.active_workers, route.checking_workers] if route.get("checking_workers", 0) > 0 else "%d workers travelling" % route.active_workers
		_label(box.position + Vector2(16, 205), traffic, Color("8fa1a8"), 14)
		_label(box.position + Vector2(16, 225), "Returned %.1f · Home %.1f" % [route.delivered_total, _status.get("resources", {}).get(selected.category, 0.0)], Color("8fa1a8"), 14)
		if route.status == "depleted":
			if route.active_workers == 0:
				_draw_trail_button("trail_recheck", "RECHECK")
		else:
			_draw_trail_button("trail_less", "− 1")
			_draw_trail_button("trail_more", "+ 1")
		_draw_trail_button("trail_cancel", "STOP TRAFFIC" if route.get("reported_losses", 0) > 0 else "CANCEL")
	var scout_available: bool = _status.get("available_workers", 0) > 0 and _status.get("active_scouts", 0) < _status.get("scout_cap", 0)
	var investigate_box: Rect2 = _investigate_button_rect()
	draw_rect(investigate_box, Color("27383c") if scout_available else Color("202326"))
	_label(investigate_box.position + Vector2(investigate_box.size.x * 0.5, 29), "INVESTIGATE SOURCE", Color("d5ded8"), 13, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_honeydew_context(selected: Dictionary, box: Rect2) -> void:
	var relationship: String = _status.get("honeydew", {}).get("relationship", "unknown")
	var required: int = int(_status.get("honeydew", {}).get("required_workers", 0))
	var available: int = int(_status.get("available_workers", 0))
	var relation_text: String = "Workers protecting producers" if relationship == "tended" else "Sweet source · protection possible" if relationship == "exploited" else "Sweet source · not yet harvested"
	_label(box.position + Vector2(16, 162), relation_text, Color("d6b98c"), 13)
	var route: Dictionary = _selected_route(selected)
	var route_text: String = "Trail: no workers committed" if route.is_empty() or route.status == "inactive" else "Trail recalling · %d away" % route.active_workers if route.status == "recalling" else "Trail: source reported empty" if route.status == "depleted" else "Trail: %d committed · %d moving" % [route.allocated_workers, route.active_workers]
	_label(box.position + Vector2(16, 184), route_text, Color("a8b8bd"), 12)
	var labor_text: String = "Protection: %d committed · %d available" % [int(_status.honeydew.protection_workers), available] if relationship == "tended" else "Protection needs %d · %d available" % [required, available]
	_label(box.position + Vector2(16, 201), labor_text, Color("8fa1a8"), 12)
	if relationship in ["exploited", "tended"]:
		var protect_box: Rect2 = _honeydew_button_rect()
		var can_start: bool = relationship == "tended" or available >= required
		draw_rect(protect_box, Color("3d3328") if can_start else Color("202326"))
		_label(protect_box.position + Vector2(protect_box.size.x * 0.5, 29), "WITHDRAW PROTECTION" if relationship == "tended" else "PROTECT PRODUCERS", Color("e1d4ba") if can_start else Color("8c8881"), 13, HORIZONTAL_ALIGNMENT_CENTER)
	if route.is_empty() or route.status in ["inactive", "recalling"]:
		_draw_trail_button("trail_create", "INVEST 5 WORKERS" if route.is_empty() or route.status == "inactive" else "REINVEST 5 WORKERS")
	elif route.status == "depleted":
		if route.active_workers == 0:
			_draw_trail_button("trail_recheck", "RECHECK")
		_draw_trail_button("trail_cancel", "STOP TRAFFIC" if route.get("reported_losses", 0) > 0 else "CANCEL")
	else:
		_draw_trail_button("trail_less", "− 1")
		_draw_trail_button("trail_more", "+ 1")
		_draw_trail_button("trail_cancel", "STOP TRAFFIC" if route.get("reported_losses", 0) > 0 else "CANCEL")
	var scout_available: bool = available > 0 and _status.get("active_scouts", 0) < _status.get("scout_cap", 0)
	var investigate_box: Rect2 = _investigate_button_rect()
	draw_rect(investigate_box, Color("27383c") if scout_available else Color("202326"))
	_label(investigate_box.position + Vector2(investigate_box.size.x * 0.5, 29), "INVESTIGATE SOURCE", Color("d5ded8"), 13, HORIZONTAL_ALIGNMENT_CENTER)


func _scent_label(route: Dictionary) -> String:
	var strength: float = float(route.get("pheromone_strength", 0.0))
	return "strong" if strength >= 0.7 else "clear" if strength >= 0.45 else "faint" if strength >= 0.1 else "remembered" if float(route.get("route_familiarity", 0.0)) >= 0.1 else "absent"


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


func _reported_empty(signal_data: Dictionary) -> bool:
	var hint: Dictionary = _status.get("temporal_hints", {}).get(signal_data.source_knowledge_id, {})
	if hint.get("has_report", false):
		return hint.get("last_return_empty", false)
	var route: Dictionary = _selected_route(signal_data)
	return route.get("status", "") == "depleted"


func _is_honeydew(signal_data: Dictionary) -> bool:
	return not _status.get("honeydew", {}).is_empty() and signal_data.get("source_knowledge_id", "") == _status.honeydew.knowledge_id


func _trail_button_rect(command: String) -> Rect2:
	var x: float = get_viewport_rect().size.x - 300.0
	var y: float = 398.0 if _is_honeydew(_selected_signal()) else 380.0
	match command:
		"trail_create": return Rect2(x, y, 260, 44)
		"trail_recheck": return Rect2(x, y, 136, 44)
		"trail_less": return Rect2(x, y, 64, 44)
		"trail_more": return Rect2(x + 72, y, 64, 44)
		"trail_cancel": return Rect2(x + 144, y, 116, 44)
	return Rect2()


func _investigate_button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 444.0 if _is_honeydew(_selected_signal()) else 438.0, 260.0, 44.0)


func _honeydew_button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 350.0, 260.0, 44.0)


func _signal_title_for(signal_data: Dictionary) -> String:
	return "Honeydew trace" if _is_honeydew(signal_data) else _signal_title(signal_data.category)


func _draw_trail_button(command: String, title: String) -> void:
	var box: Rect2 = _trail_button_rect(command)
	draw_rect(box, Color("263b3c"))
	_label(box.position + Vector2(box.size.x * 0.5, 29), title, Color("d5ded8"), 13, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_controls(size: Vector2) -> void:
	for command: String in ["scout", "pause", "speed_1", "speed_4", "speed_16", "speed_64", "inward", "save", "load"]:
		var box: Rect2 = _button_rect(command)
		var active: bool = command.begins_with("speed_") and not _status.is_empty() and int(command.trim_prefix("speed_")) == _status.time_scale
		var unavailable: bool = command == "scout" and not _status.is_empty() and (_status.available_workers < 1 or _status.active_scouts >= _status.scout_cap)
		var color: Color = Color("28342f") if command == "scout" else Color("18252b")
		if active:
			color = Color("31505a")
		if unavailable:
			color = Color("202326")
		draw_rect(box, color)
		var title: String = "SEND SCOUT" if command == "scout" else "INWARD" if command == "inward" else "SAVE" if command == "save" else "LOAD" if command == "load" else "RESUME" if command == "pause" and _status.get("paused", false) else "PAUSE" if command == "pause" else command.trim_prefix("speed_") + "x"
		_label(box.position + Vector2(box.size.x * 0.5, 40), title, Color("d3dcd4") if not unavailable else Color("78817e"), 14 if command in ["save", "load"] else 16, HORIZONTAL_ALIGNMENT_CENTER)
	if not _feedback.is_empty() and Time.get_ticks_msec() < _feedback_until:
		_label(Vector2(24, size.y - 17), _feedback, Color("b6c8b2"), 13)
	else:
		_label(Vector2(24, size.y - 17), "Space: pause  ·  1–4: time", Color("7e8e94"), 13)


func _signal_color(category: String) -> Color:
	return Art.color_for(category)

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
