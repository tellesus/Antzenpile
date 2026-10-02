class_name InwardView
extends Node2D
## Abstract functional network; consumes detached pile summaries only.

const Art = preload("res://src/presentation/sensory_art.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
const Activity = preload("res://src/presentation/inward/colony_activity.gd")
const Pressure = preload("res://src/presentation/colony_pressure.gd")
const NODES: Array[String] = ["queen", "nursery", "food_exchange", "entrance", "adaptation"]
var status_provider: Callable
var mode_command: Callable
var pause_command: Callable
var speed_command: Callable
var develop_command: Callable
var nursery_develop_command: Callable
var nursery_expand_command: Callable
var food_sources_command: Callable
var midden_develop_command: Callable
var sanitation_command: Callable
var humidity_command: Callable
var brood_command: Callable
var brood_intent_command: Callable
var adaptation_command: Callable
var guest_rejection_command: Callable
var honeydew_command: Callable
var input_blocked: Callable
var save_command: Callable
var load_command: Callable
var selected_id: String = ""
var web_selection: String = "foraging"
var web_family: String = "foraging"
var _animation_time: float = 0.0
const FOCUS_SECONDS: float = 0.28
var _focus_gains: Dictionary = {}
var _status: Dictionary = {}
var _font: Font = ThemeDB.fallback_font
var _feedback: String = ""
var _feedback_until: int = 0


func show_feedback(message: String) -> void:
	_feedback = message
	_feedback_until = Time.get_ticks_msec() + 3000


func _process(delta: float) -> void:
	if status_provider.is_valid():
		_status = status_provider.call()
	if not _status.get("paused", false):
		_animation_time = fposmod(_animation_time + minf(delta, 0.1), 3600.0)
	# UI attention remains responsive on pause; gameplay decoration stays frozen.
	for id: String in NODES + ["guest", "midden"]:
		_focus_gains[id] = move_toward(float(_focus_gains.get(id, 0.0)), 1.0 if id == selected_id else 0.0, maxf(delta, 0.0) / FOCUS_SECONDS)
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
	if selected_id == "queen":
		for intent: String in ["manual", "grow"]:
			if _brood_intent_rect(intent).has_point(at):
				if brood_intent_command.is_valid():
					var result: Dictionary = brood_intent_command.call(intent)
					show_feedback(("Growth intent set" if intent == "grow" else "Manual laying selected") if result.get("accepted", false) else result.get("reason", "Intent unavailable"))
				return true
	if selected_id == "food_exchange":
		for resource_id: String in Pressure.food_shortages(_status):
			if _food_source_rect(resource_id).has_point(at):
				if food_sources_command.is_valid():
					var result: Dictionary = food_sources_command.call(resource_id)
					if not result.get("accepted", false): show_feedback(result.get("reason", "Sources unavailable"))
				return true
	if selected_id == "nursery" and _status.get("nursery_expansion", {}).get("state", "") == "available" and _nursery_expand_rect().has_point(at):
		_run_command("expand_nursery")
		return true
	if selected_id == "nursery" and _status.get("nursery_state", "primitive") == "developed":
		for target: int in [0, 1, 2, 4]:
			if _humidity_rect(target).has_point(at):
				_run_command("climate_" + str(target))
				return true
	if selected_id == "midden" and _status.get("midden", {}).get("revealed", false):
		for target: int in [0, 1, 2, 5]:
			if _cleaner_rect(target).has_point(at):
				_run_command("cleanup_" + str(target))
				return true
		if _status.midden.state == "primitive" and _midden_develop_rect().has_point(at):
			_run_command("develop_midden")
			return true
	if selected_id == "adaptation" and _web_back_rect().has_point(at):
		selected_id = ""
		web_selection = "foraging"
		web_family = "foraging"
		queue_redraw()
		return true
	if selected_id == "adaptation" and _status.get("adaptation_options", {}).has("security") and _web_family_rect().has_point(at):
		web_family = "recognition" if web_family == "foraging" else "foraging"
		web_selection = "foraging"
		return true
	if selected_id == "adaptation" and web_selection == "honeydew" and _status.get("honeydew", {}).get("relationship", "unknown") in ["exploited", "tended"] and _honeydew_rect().has_point(at):
		_run_command("honeydew")
		return true
	var guest: Dictionary = _status.get("guest", {})
	if selected_id == "guest" and guest.get("reported_losses", 0) > 0 and guest.get("observation", "") != "purged" and _guest_rect().has_point(at):
		_run_command("guest_rejection")
		return true
	if selected_id == "adaptation" and web_selection in ["lean", "load", "persistent", "security", "tolerance"] and _can_choose_adaptation():
		if _adaptation_rect(web_selection).has_point(at):
			_run_command("adaptation_" + web_selection)
			return true
	if selected_id in ["queen", "nursery"] and _can_lay_brood() and _brood_rect().has_point(at):
		_run_command("lay_brood")
		return true
	if selected_id == "food_exchange" and _status.get("food_exchange_state", "") == "primitive" and _develop_rect().has_point(at):
		_run_command("develop")
		return true
	if selected_id == "nursery" and _status.get("nursery_state", "") == "primitive" and _nursery_develop_rect().has_point(at):
		_run_command("develop_nursery")
		return true
	for command: String in ["outward", "pause", "speed_1", "speed_4", "speed_16", "speed_64", "save", "load"]:
		if _button_rect(command).has_point(at):
			_run_command(command)
			return true
	if selected_id == "adaptation":
		var leaf: String = Web.node_at(at, get_viewport_rect().size, _status, web_family)
		if not leaf.is_empty():
			web_selection = leaf
			queue_redraw()
			return true
		return false
	var picked: String = node_at(at, get_viewport_rect().size, not guest.is_empty(), _status.get("midden", {}).get("revealed", false))
	if not picked.is_empty():
		selected_id = picked
		if picked == "adaptation":
			web_selection = "foraging"
		queue_redraw()
		return true
	return false


func _run_command(command: String) -> void:
	match command:
		"expand_nursery":
			if nursery_expand_command.is_valid():
				var result: Dictionary = nursery_expand_command.call()
				show_feedback("Nursery expansion started" if result.get("accepted", false) else result.get("reason", "Expansion unavailable"))
		"climate_0", "climate_1", "climate_2", "climate_4":
			if humidity_command.is_valid():
				var result: Dictionary = humidity_command.call(int(command.trim_prefix("climate_")))
				show_feedback("Climate carers reassigned" if result.get("accepted", false) else result.get("reason", "Climate care unavailable"))
		"cleanup_0", "cleanup_1", "cleanup_2", "cleanup_5":
			if sanitation_command.is_valid():
				var result: Dictionary = sanitation_command.call(int(command.trim_prefix("cleanup_")))
				show_feedback("Cleanup workers reassigned" if result.get("accepted", false) else result.get("reason", "Cleanup unavailable"))
		"develop_midden":
			if midden_develop_command.is_valid():
				var result: Dictionary = midden_develop_command.call()
				show_feedback("Midden development started" if result.get("accepted", false) else result.get("reason", "Development unavailable"))
		"honeydew":
			if honeydew_command.is_valid():
				var tending: bool = _status.get("honeydew", {}).get("relationship", "unknown") != "tended"
				var result: Dictionary = honeydew_command.call(tending)
				show_feedback(("Protection started" if tending else "Protection withdrawn") if result.get("accepted", false) else result.get("reason", "Relationship unavailable"))
		"guest_rejection":
			if guest_rejection_command.is_valid():
				var enabled: bool = not _status.get("guest", {}).get("rejection_active", false)
				var result: Dictionary = guest_rejection_command.call(enabled)
				show_feedback(("Rejection effort started" if enabled else "Rejection effort stopped") if result.get("accepted", false) else result.get("reason", "Effort unavailable"))
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
		"develop_nursery":
			if nursery_develop_command.is_valid():
				var result: Dictionary = nursery_develop_command.call()
				_feedback = "Nursery development started" if result.get("accepted", false) else result.get("reason", "Requirements unmet")
				_feedback_until = Time.get_ticks_msec() + 3000
		"lay_brood":
			if brood_command.is_valid():
				var result: Dictionary = brood_command.call()
				_feedback = "New brood started" if result.get("accepted", false) else result.get("reason", "Brood unavailable")
				_feedback_until = Time.get_ticks_msec() + 3000
		"adaptation_lean", "adaptation_load", "adaptation_persistent", "adaptation_security", "adaptation_tolerance":
			if adaptation_command.is_valid():
				var result: Dictionary = adaptation_command.call(command.trim_prefix("adaptation_"))
				_feedback = "Adaptation brood started" if result.get("accepted", false) else result.get("reason", "Adaptation unavailable")
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
		"entrance": origin + Vector2(field_width * 0.28, field_height * 0.78),
		"adaptation": origin + Vector2(field_width * 0.5, field_height * 0.52),
		"guest": origin + Vector2(field_width * 0.50, field_height * 0.89),
		"midden": origin + Vector2(field_width * 0.08, field_height * 0.52)}


static func node_at(at: Vector2, size: Vector2, guest_visible: bool = false, midden_visible: bool = false) -> String:
	if midden_visible and at.distance_to(positions(size).midden) <= 44.0:
		return "midden"
	if guest_visible and at.distance_to(positions(size).guest) <= 44.0:
		return "guest"
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


func _cleaner_rect(target: int) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0 + [0, 1, 2, 5].find(target) * 66.0, 300, 62, 44)


func _midden_develop_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 430, 260, 44)


func _brood_rect() -> Rect2:
	var y: float = 494.0 if selected_id == "nursery" and _status.get("nursery_state", "primitive") == "developed" else 438.0 if selected_id == "nursery" else 466.0
	return Rect2(get_viewport_rect().size.x - 300.0, y, 260.0, 44.0)


func _brood_intent_rect(intent: String) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0 + (132 if intent == "grow" else 0), 352, 128, 44)


func _humidity_rect(target: int) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0 + [0, 1, 2, 4].find(target) * 66.0, 398, 62, 44)


func _nursery_develop_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 494.0, 260.0, 44.0)


func _nursery_expand_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 550.0, 260.0, 44.0)


func _food_source_rect(resource_id: String) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0 + ["carbohydrate", "protein", "water"].find(resource_id) * 88, 470, 84, 44)


func _adaptation_rect(_trait_id: String) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 380.0, 260.0, 44.0)


func _guest_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 380.0, 260.0, 44.0)


func _web_back_rect() -> Rect2:
	return Rect2(24, 116, 196, 44)


func _web_family_rect() -> Rect2:
	return Rect2(236, 116, 220, 44)


func _honeydew_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 380.0, 260.0, 44.0)


func _can_choose_adaptation() -> bool:
	return _status.get("adaptation_options", {}).get(web_selection, {}).get("available", _status.get("adaptation_repertoire", "") == "" and _status.get("adaptation_trial", {}).is_empty() and web_selection in ["lean", "load"])


func _can_lay_brood() -> bool:
	return _status.get("queens", 0) > 0 and _status.get("brood", []).size() < _status.get("nursery_brood_capacity", 0) / maxi(1, _status.get("brood_batch_count", 8)) and _status.get("nursery_brood_capacity", 0) - _status.get("nursery_occupied_space", 0) >= _status.get("brood_batch_count", 0) and (_status.get("brood", []).is_empty() or _status.get("nursery_state", "") == "developed")


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("080b10"))
	if selected_id == "adaptation":
		Web.draw_graph(self, size, _status, web_selection, _animation_time, web_family)
		draw_rect(_web_back_rect(), Color("18252b"))
		_label(_web_back_rect().position + Vector2(98, 29), "BACK TO COLONY", Color("d3dcd4"), 14, HORIZONTAL_ALIGNMENT_CENTER)
		if _status.get("adaptation_options", {}).has("security"):
			draw_rect(_web_family_rect(), Color("28212f"))
			_label(_web_family_rect().position + Vector2(110, 29), "OTHER TRAITS" if web_family == "recognition" else "INSPECT RECOGNITION", Color("d3c5df"), 14, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_hud(size)
		_draw_context(size)
		_draw_controls(size)
		return
	var centers: Dictionary = positions(size)
	for pair: Array in [["queen", "nursery"], ["nursery", "food_exchange"], ["food_exchange", "entrance"], ["entrance", "queen"]]:
		_draw_flow(centers[pair[0]], centers[pair[1]], pair[0] == "nursery" or pair[0] == "entrance")
	for id: String in ["queen", "nursery"]:
		draw_line(centers[id], centers["adaptation"], Color(0.43, 0.40, 0.55, 0.20), 1.0, true)
	if _status.get("midden", {}).get("revealed", false):
		_draw_flow(centers.entrance, centers.midden, false)
	if not _status.get("guest", {}).is_empty():
		draw_line(centers.guest, centers.nursery, Color(0.65, 0.53, 0.64, 0.18), 1.0, true)
	_draw_activity(centers)
	for id: String in NODES:
		_draw_node(id, centers[id])
	if _status.get("midden", {}).get("revealed", false):
		_draw_node("midden", centers.midden)
	if not _status.get("guest", {}).is_empty():
		_draw_node("guest", centers.guest)
	_draw_hud(size)
	_draw_context(size)
	_draw_controls(size)


func _draw_flow(start: Vector2, finish: Vector2, _representative: bool) -> void:
	var control: Vector2 = (start + finish) * 0.5 + Vector2(12, -18)
	var points := PackedVector2Array()
	for step: int in 25:
		var t: float = float(step) / 24.0
		points.append(start * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + finish * t * t)
	draw_polyline(points, Color(0.45, 0.59, 0.53, 0.18), 1.0, true)


func _draw_activity(centers: Dictionary) -> void:
	for ant: Dictionary in Activity.representatives(_status, centers, _animation_time):
		var under_label: bool = false
		for center: Vector2 in centers.values():
			under_label = under_label or Rect2(center + Vector2(-90, 40), Vector2(180, 44)).has_point(ant.position)
		if under_label:
			continue
		Art.ant(self, ant.position, ant.direction, Color(ant.color, 0.62), _animation_time, 0.8)
		if ant.role in ["climate", "cleanup"]:
			draw_circle(ant.position + ant.direction.normalized() * 6, 1.6, Color(ant.color, 0.65))


func _draw_node(id: String, at: Vector2) -> void:
	var color: Color = Color("d5c4a1") if id == "queen" else Color("aebdb7") if id == "nursery" else Color("c7af86") if id == "food_exchange" else Color("bba6c8") if id == "adaptation" else Color("bd927a") if id == "midden" else Color("8daeb3")
	var focus: float = smoothstep(0.0, 1.0, float(_focus_gains.get(id, 0.0)))
	var attention: float = lerpf(0.85, 1.0, focus) if not selected_id.is_empty() else 1.0
	var health: float = Activity.health(_status, id)
	var strain: float = 1.0 - health
	var pulse: float = Activity.pulse(health, _animation_time)
	var phase: float = _animation_time * 0.18 + NODES.find(id)
	var radius: float = 34.0 + pulse * (0.8 + strain * 0.8) if id in ["nursery", "midden"] else 34.0
	var outline: PackedVector2Array = Art.membrane(at, radius, phase, 0.86)
	draw_colored_polygon(outline, Color(color, lerpf(0.045, 0.08, focus) * attention))
	var edge: Color = Color(color.lerp(Color("cb927c"), strain * 0.55), lerpf(0.4, 0.7, focus) * attention)
	if strain > 0.0:
		for part: int in 3:
			draw_polyline(outline.slice(1 + part * 9, 8 + part * 9), edge, 1.1, true)
	else:
		draw_polyline(outline.slice(1, 27), edge, 1.1, true)
	match id:
		"midden":
			var burden: float = _status.get("midden", {}).get("burden", 0.0)
			for index: int in mini(6, int(ceil(burden))):
				var fragment: Vector2 = at + Vector2(index % 3 * 9 - 9, index / 3 * 8 - 3) + Vector2.from_angle(index * 2.1) * strain * (3.0 + pulse)
				draw_line(fragment, fragment + Vector2(4, -3), Color("bd765c"), 1.5, true)
		"guest":
			for index: int in 3:
				draw_arc(at + Vector2(index * 5 - 5, index * 3 - 3), 9, 0.4, 4.1, 16, Color(color, 0.45), 1.0, true)
		"nursery":
			if _status.get("nursery_expansion", {}).get("state", "") == "developed":
				draw_polyline(Art.membrane(at, 21, -phase, 0.82).slice(15, 29), Color(color, 0.32), 1.0, true)
			var stages: Array[String] = Activity.brood_stages(_status)
			for index: int in stages.size():
				var seed_at: Vector2 = at + Vector2(index % 3 * 9 - 9, index / 3 * 11 - 5)
				var brood_color: Color = Color(color, (0.55 + health * 0.2 + pulse * 0.025) * attention)
				if stages[index] == "larva":
					draw_arc(seed_at, 3.2, 0.2, 4.8, 12, brood_color, 2.0, true)
				elif stages[index] == "pupa":
					draw_polyline(Art.membrane(seed_at, 4.4, 0, 0.48), brood_color, 1.0, true)
				else:
					draw_circle(seed_at, 2.1, brood_color)
			if _status.get("humidity", {}).get("carers", 0) > 0:
				draw_polyline(Art.membrane(at, 26, -phase, 0.62).slice(3, 14), Color("7fbfcf", 0.4), 1.0, true)
		"adaptation":
			for index: int in 3:
				var seed_at: Vector2 = at + Vector2.from_angle(index * TAU / 3.0 + 0.3) * 13
				draw_line(at, seed_at, Color(color, 0.4), 1.0, true)
				draw_circle(seed_at, 3.2, Color(color, 0.64))
		"food_exchange":
			draw_polyline(Art.membrane(at, 16, -phase, 0.56).slice(3, 22), Color(color, 0.5), 1.2, true)
			if _status.get("food_exchange_state", "") == "developed":
				draw_polyline(Art.membrane(at, 24, phase * 0.5, 0.6).slice(12, 28), Color(color, 0.35), 1.0, true)
				draw_circle(at + Vector2(sin(phase) * 7, cos(phase) * 4), 2.1, Color(color, 0.65))
		"entrance":
			draw_arc(at + Vector2(0, 5), 12, PI, TAU, 20, Color(color, 0.6), 1.5, true)
		"queen":
			draw_circle(at, 5.0, Color(color, 0.65))
			draw_circle(at + Vector2(0, 9), 3.0, Color(color, 0.36))
	if id == "nursery" and _status.get("guest", {}).get("observation", "") == "foreign":
		draw_arc(at, 39.0, 0.3, 1.9, 20, Color("b79eaf"), 1.0, true)
	if focus > 0.0:
		var focus_outline: PackedVector2Array = Art.membrane(at, 43.0, 1.5)
		draw_polyline(focus_outline.slice(1, 8), Color("dce5d9", focus), 1.0, true)
		draw_polyline(focus_outline.slice(17, 24), Color("dce5d9", focus), 1.0, true)
	_label(at + Vector2(0, 52), _title(id), color, 15, HORIZONTAL_ALIGNMENT_CENTER)
	var pressure: String = Activity.pressure(_status, id)
	var progress: float = Activity.project_progress(_status, id)
	if progress >= 0.0:
		draw_arc(at, 39, -PI * 0.5, -PI * 0.5 + TAU * maxf(progress, 0.005), 32, Color("c3b991"), 1.3, true)
	if not pressure.is_empty():
		draw_polyline(Art.membrane(at, 38, -phase).slice(2, 12), Color("cc967a", 0.65), 1.2, true)
		_label(at + Vector2(0, 70), pressure, Color("ccac91"), 11, HORIZONTAL_ALIGNMENT_CENTER)
	elif progress >= 0.0:
		var project_title: String = "EXPANDING" if id == "nursery" and _status.get("nursery_expansion", {}).get("state", "") == "developing" else "DEVELOPING"
		_label(at + Vector2(0, 70), project_title, Color("b0ab8b"), 11, HORIZONTAL_ALIGNMENT_CENTER)
	elif id == "nursery" and _status.get("nursery_expansion", {}).get("state", "") == "available":
		_label(at + Vector2(0, 70), "EXPANSION AVAILABLE", Color("a5b49a"), 11, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_hud(size: Vector2) -> void:
	_label(Vector2(24, 38), "INWARD  /  ADAPTATION WEB" if selected_id == "adaptation" else "INWARD  /  HOME", Color("dad7c8"), 22)
	_label(Vector2(24, 63), "Genes grow through brood; relationships through interaction." if selected_id == "adaptation" else "Tap a function to listen.", Color("82939c"), 13)
	if not _status.is_empty():
		var stores: Dictionary = _status.get("resources", {})
		_label(Vector2(24, 96), "STORES   Carb %.1f   ·   Protein %.1f   ·   Water %.1f" % [stores.get("carbohydrate", 0.0), stores.get("protein", 0.0), stores.get("water", 0.0)], Color("a9b9bc"), 13)
		_label(Vector2(size.x - 24, 36), "%d available" % _status.workers_available, Color("c9d1c5"), 15, HORIZONTAL_ALIGNMENT_RIGHT)
		var pause_word: String = "PAUSED" if _status.paused else "%dx" % _status.time_scale
		_label(Vector2(size.x - 24, 61), "%s  ·  %.0fs" % [pause_word, _status.time], Color("83969d"), 13, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_context(size: Vector2) -> void:
	if selected_id.is_empty() or _status.is_empty():
		return
	var expansion: Dictionary = _status.get("nursery_expansion", {})
	var expansion_action: bool = expansion.get("state", "") == "available"
	var food_attention: bool = selected_id == "food_exchange" and not Pressure.food_shortages(_status).is_empty()
	var box := Rect2(Vector2(size.x - 316, 144), Vector2(292, (466 if expansion_action else 400) if selected_id == "nursery" else 388 if food_attention or selected_id == "queen" else 344 if selected_id == "adaptation" else 340 if selected_id == "midden" else 284))
	var web: bool = selected_id == "adaptation"
	draw_rect(box, Color("17141f") if web else Color("111921"))
	draw_rect(box, Color("786683") if web else Color("41535a"), false, 1.0)
	_label(box.position + Vector2(16, 31), "Adaptation Web" if web else _title(selected_id), Color("decce8") if web else Color("d9d3be"), 20)
	if web and web_selection == "honeydew":
		_draw_relationship_context(box)
		return
	if web and web_selection in ["lean", "load", "persistent", "security", "tolerance"]:
		_draw_genetic_context(box)
		return
	match selected_id:
		"midden":
			var midden: Dictionary = _status.get("midden", {})
			_detail_line(box, 65, "Refuse burden: %.1f" % midden.get("burden", 0.0))
			_detail_line(box, 89, "Developed isolation" if midden.get("state") == "developed" else "Basic refuse isolation")
			_detail_line(box, 113, "Larval growth: %.0f%%" % (midden.get("larval_rate", 1.0) * 100.0))
			_detail_line(box, 137, "Cleanup workers: %d" % midden.get("cleaners", 0))
			for target: int in [0, 1, 2, 5]:
				var button: Rect2 = _cleaner_rect(target)
				draw_rect(button, Color("4b5141") if target == midden.get("cleaners", 0) else Color("263038"))
				_label(button.get_center() + Vector2(0, 6), str(target), Color("dce5d9"), 16, HORIZONTAL_ALIGNMENT_CENTER)
			if midden.get("state") == "primitive":
				_detail_line(box, 218, "Develop for twice the cleanup")
				_detail_line(box, 244, "Needs %.0f carb · %.0f protein" % [midden.costs.carbohydrate, midden.costs.protein])
				_detail_line(box, 266, "%.0f water · %d workers · %.0fs" % [midden.costs.water, midden.build_workers, midden.build_seconds])
				draw_rect(_midden_develop_rect(), Color("35483c"))
				_label(_midden_develop_rect().get_center() + Vector2(0, 6), "DEVELOP MIDDEN", Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)
			elif midden.get("state") == "developing":
				_detail_line(box, 224, "Developing: %.0f%%" % (midden.progress * 100.0))
				_detail_line(box, 246, "%d excavation workers committed" % midden.build_workers)
			else:
				_detail_line(box, 224, "Cleanup efficiency doubled")
				_detail_line(box, 246, "Isolated refuse stays unusable")
		"queen":
			_detail_line(box, 65, "Queens: %d" % _status.queens)
			_detail_line(box, 91, "Living workers: %d" % _status.workers_total)
			_detail_line(box, 117, "Available workers: %d" % _status.workers_available)
			_detail_line(box, 157, "Nursery: %d / %d brood space" % [_status.nursery_occupied_space, _status.nursery_brood_capacity])
			var production: Dictionary = _status.get("brood_production", {"intent":"manual", "waiting":"manual"})
			_label(box.position + Vector2(16, 195), "Brood intent", Color("a9b9bc"), 13)
			for intent: String in ["manual", "grow"]:
				var button: Rect2 = _brood_intent_rect(intent)
				draw_rect(button, Color("354d55") if production.intent == intent else Color("263038"))
				_label(button.get_center() + Vector2(0, 5), intent.to_upper(), Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)
			var waiting_labels: Dictionary = {"manual":"Manual cohorts", "ready":"Ready on next simulation tick", "space":"Waiting for Nursery space", "care":"Waiting for care workers", "queen":"No queen can lay", "population":"Population limit reached", "carbohydrate":"Waiting for carbohydrate reserve", "protein":"Waiting for protein reserve", "water":"Waiting for water reserve"}
			_label(box.position + Vector2(16, 273), waiting_labels.get(production.waiting, ""), Color("a9b9bc"), 13)
			_label(box.position + Vector2(16, 294), "Grow repeats when food/care/space fit.", Color("8fa1a8"), 12)
			_label(box.position + Vector2(16, 313), "Manual laying skips the food check.", Color("8fa1a8"), 12)
			if _can_lay_brood():
				_draw_brood_button()
		"nursery":
			var brood: Array = _status.brood
			var count: int = 0
			for cohort: Dictionary in brood:
				count += cohort.count
			_detail_line(box, 65, "Brood space: %d / %d" % [count, _status.nursery_brood_capacity])
			_detail_line(box, 91, "Care capacity: %d / %d" % [_status.nursery_care_capacity, _status.nursery_max_care_capacity])
			if not brood.is_empty():
				var stages: String = "%s · %.0fs" % [brood[0].stage.capitalize(), brood[0].progress_seconds] if brood.size() == 1 else "2 cohorts: %s / %s" % [brood[0].stage, brood[1].stage]
				if brood.size() > 2:
					var groups: Array[String] = []
					for stage: String in ["egg", "larva", "pupa"]:
						var amount: int = brood.filter(func(cohort): return cohort.stage == stage).size()
						if amount > 0: groups.append("%s×%d" % [stage, amount])
					stages = "%d cohorts: " % brood.size() + " / ".join(groups)
				_label(box.position + Vector2(16, 117), stages, Color("a8b8bd"), 13)
				var food_enough: bool = true
				var care_enough: bool = true
				for cohort: Dictionary in brood:
					food_enough = food_enough and (cohort.care < 1.0 or cohort.nutrition >= 1.0)
					care_enough = care_enough and cohort.care >= 1.0
				var feeding: String = "Last short: " + Pressure.food_names(_status) if not Pressure.food_shortages(_status).is_empty() else "Brood waits for care" if not care_enough and food_enough else "Food %s · care %s" % ["enough" if food_enough else "short", "enough" if care_enough else "short"]
				_label(box.position + Vector2(16, 143), feeding, Color("a9b9bc"), 13)
			_detail_line(box, 181, "%d emerged · %d brood lost" % [_status.brood_matured_total, _status.get("brood_losses", 0)])
			var dirty: bool = _status.get("midden", {}).get("larval_rate", 1.0) < 1.0
			var climate: bool = _status.get("humidity", {}).get("larval_rate", 1.0) < 1.0
			if dirty or climate:
				_detail_line(box, 162, "Climate + sanitation slow larvae" if dirty and climate else "Nest climate slows larvae" if climate else "Sanitation slows larvae · visit Midden")
			if _status.nursery_state == "primitive":
				_detail_line(box, 209, "Develop for %d brood space" % _status.nursery_developed_capacity)
				_detail_line(box, 235, "Needs %.0f carb · %.0f protein" % [_status.nursery_costs.carbohydrate, _status.nursery_costs.protein])
				_detail_line(box, 261, "%.0f water · %d workers · %.0fs" % [_status.nursery_costs.water, _status.nursery_workers_required, _status.nursery_build_duration])
				_draw_nursery_develop_button()
			elif _status.nursery_state == "developing":
				_detail_line(box, 209, "Developing: %.0f / %.0fs" % [_status.nursery_progress, _status.nursery_build_duration])
				_detail_line(box, 235, "%d workers committed" % _status.nursery_workers_required)
			else:
				var humidity: Dictionary = _status.get("humidity", {"moisture": 65.0, "carers": 0, "water_used": 0.0})
				var condition: String = "dry" if humidity.moisture < 45.0 else "damp" if humidity.moisture > 80.0 else "steady"
				_detail_line(box, 209, "Humidity: %.0f%% · %s" % [humidity.moisture, condition])
				_detail_line(box, 235, "Climate carers: %d" % humidity.carers)
				for target: int in [0, 1, 2, 4]:
					var button: Rect2 = _humidity_rect(target)
					draw_rect(button, Color("355059") if target == humidity.carers else Color("263038"))
					_label(button.get_center() + Vector2(0, 6), str(target), Color("dce5d9"), 16, HORIZONTAL_ALIGNMENT_CENTER)
				if expansion.get("state", "") == "available":
					_detail_line(box, 310, "Expansion: %.0f carb · %.0f protein" % [expansion.costs.carbohydrate, expansion.costs.protein])
					_detail_line(box, 332, "%.0f water · %d workers · %.0fs" % [expansion.costs.water, expansion.workers, expansion.duration])
					var button: Rect2 = _nursery_expand_rect()
					draw_rect(button, Color("35483c"))
					_label(button.get_center() + Vector2(0, 6), "EXPAND TO %d BROOD SPACE" % expansion.capacity, Color("dce5d9"), 13, HORIZONTAL_ALIGNMENT_CENTER)
				elif expansion.get("state", "") == "developing":
					_detail_line(box, 310, "Expanding: %.0f / %.0fs" % [expansion.progress_seconds, expansion.duration])
					_detail_line(box, 332, "%d workers · existing space online" % expansion.workers)
				else:
					_detail_line(box, 310, "Humidifying uses stored water")
					_detail_line(box, 332, "%.1f water used · airing uses labor" % humidity.water_used)
			if _can_lay_brood():
				_draw_brood_button()
		"food_exchange":
			if _status.food_exchange_state == "primitive":
				_detail_line(box, 65, "Primitive Food Exchange")
				_detail_line(box, 99, "Needs %.0f carb · %.0f protein" % [_status.food_exchange_costs.carbohydrate, _status.food_exchange_costs.protein])
				_detail_line(box, 125, "%.0f water · %d workers" % [_status.food_exchange_costs.water, _status.food_exchange_workers_required])
				_detail_line(box, 157, "Build: %.0f simulated seconds" % _status.food_exchange_duration)
				draw_rect(_develop_rect(), Color("35483c"))
				_label(_develop_rect().position + Vector2(130, 29), "DEVELOP FOOD EXCHANGE", Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)
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
			if food_attention:
				_label(box.position + Vector2(16, 300), "Last short: " + Pressure.food_names(_status), Color("c7ad98"), 13)
				_label(box.position + Vector2(16, 316), "Browse returned sources", Color("8fa1a8"), 11)
				for resource_id: String in Pressure.food_shortages(_status):
					var button: Rect2 = _food_source_rect(resource_id)
					draw_rect(button, Color("263038"))
					_label(button.get_center() + Vector2(0, 5), "FOOD" if resource_id == "carbohydrate" else resource_id.to_upper(), Color("dce5d9"), 12, HORIZONTAL_ALIGNMENT_CENTER)
		"entrance":
			_detail_line(box, 65, "Available workers: %d" % _status.workers_available)
			_detail_line(box, 91, "Scouts away: %d" % _status.active_scouts)
			_detail_line(box, 117, "Trail workers: %d" % _status.trail_workers)
		"guest":
			var guest: Dictionary = _status.get("guest", {})
			var observation: String = guest.get("observation", "")
			_detail_line(box, 65, "Guest purged" if observation == "purged" else "Internal foreignness · Nursery" if observation == "foreign" else "Nursery losses · cause uncertain" if observation == "loss" else "Guest tolerated at home")
			_detail_line(box, 99, "%d brood lost this encounter" % guest.get("reported_losses", 0) if observation != "tolerated" else "No harmful effect observed")
			if guest.get("rejection_active", false):
				_detail_line(box, 137, "%d workers on rejection effort" % guest.workers_committed)
				_detail_line(box, 163, "Recognition and clearing take time")
			elif observation in ["loss", "foreign"]:
				_detail_line(box, 137, "Commit %d available workers" % guest.workers_required)
				_detail_line(box, 163, "Effort competes with colony care")
			elif observation == "purged":
				_detail_line(box, 137, "Rejection workers released")
			if observation in ["loss", "foreign"]:
				draw_rect(_guest_rect(), Color("39323e"))
				_label(_guest_rect().position + Vector2(130, 29), "STOP REJECTION" if guest.get("rejection_active", false) else "INCREASE REJECTION", Color("d9c9d7"), 14, HORIZONTAL_ALIGNMENT_CENTER)
		"adaptation":
			_detail_line(box, 65, "Security / tolerance · overview" if web_family == "recognition" else "Colony repertoire · overview")
			_detail_line(box, 91, "Select a trait to inspect its tradeoff")
			_detail_line(box, 117, "Start its brood trial in this panel")
			if not _status.adaptation_trial.is_empty():
				_detail_line(box, 163, "%s trial" % str(_status.adaptation_trial.adaptation_id).capitalize())
				_detail_line(box, 189, "Brood stage: %s" % _status.adaptation_trial.stage.capitalize())
				_detail_line(box, 215, "Trait emerges with this brood")
			elif not _status.get("genetic_repertoire", []).is_empty():
				_detail_line(box, 163, "%d inherited traits" % _status.get("genetic_repertoire", []).size())
				_detail_line(box, 189, "Inspect each leaf for adult expression")
				_detail_line(box, 215, "Future brood inherits established traits")
			else:
				_detail_line(box, 163, "One focused brood trial at a time")
				_detail_line(box, 189, "Genes require food, nurses and brood")
				_detail_line(box, 215, "Relationships grow through interaction")
			if _status.get("wet_trail_experience", false) and not _status.get("adaptation_options", {}).has("persistent"):
				_detail_line(box, 249, "Wet journeys weakened scent")
				_detail_line(box, 275, "New brood may reveal variation")
			elif _status.get("recognition_experience", false) and not _status.get("adaptation_options", {}).has("security"):
				_detail_line(box, 249, "Foreign / partner chemistry observed")
				_detail_line(box, 275, "New brood may reveal variation")


func _draw_genetic_context(box: Rect2) -> void:
	_detail_line(box, 65, Web.title(web_selection))
	_detail_line(box, 91, Web.trait_state(_status, web_selection))
	var benefits: String = ""
	var tradeoff: String = ""
	match web_selection:
		"lean":
			benefits = "30% less travel energy"
			tradeoff = "15% less carrying"
		"load":
			benefits = "30% more carrying"
			tradeoff = "20% more travel energy"
		"persistent":
			benefits = "Up to %.0fx scent persistence" % _status.get("chemistry_persistence", 2.0)
			tradeoff = "Up to %.0f%% more trail food" % (_status.get("chemistry_extra_energy", 0.2) * 100)
		"security":
			benefits = "Up to %.0f%% less clearing time" % (_status.get("recognition_clearing_change", 0.4) * 100)
			tradeoff = "Up to %d extra protection workers" % _status.get("recognition_labor_change", 2)
		"tolerance":
			benefits = "Up to %d fewer protection workers" % _status.get("recognition_labor_change", 2)
			tradeoff = "Up to %.0f%% more clearing time" % (_status.get("recognition_clearing_change", 0.4) * 100)
	_detail_line(box, 125, benefits)
	_detail_line(box, 151, tradeoff)
	if _can_choose_adaptation():
		var costs: Dictionary = _status.get("adaptation_options", {}).get(web_selection, {}).get("costs", _status.adaptation_costs)
		_detail_line(box, 185, "Needs %.0f carb · %.0f protein · %.0f water" % [costs.carbohydrate, costs.protein, costs.water])
		_detail_line(box, 211, "%d nurses · %d brood slots" % [_status.adaptation_nurses, _status.brood_batch_count])
		var rect: Rect2 = _adaptation_rect(web_selection)
		draw_rect(rect, Color("28212f"))
		draw_rect(rect, Color("a28aaf"), false, 1.5)
		_label(rect.position + Vector2(130, 29), "START %s BROOD TRIAL" % ("CHEMISTRY" if web_selection == "persistent" else web_selection.to_upper()), Color("e3dbe7"), 13, HORIZONTAL_ALIGNMENT_CENTER)
	elif _status.adaptation_trial.get("adaptation_id", "") == web_selection:
		_detail_line(box, 185, "Stage: " + str(_status.adaptation_trial.stage).capitalize())
		_detail_line(box, 211, "Expresses only with surviving adults")
	elif _status.get("adaptation_options", {}).get(web_selection, {}).get("inherited", _status.adaptation_repertoire == web_selection):
		var expressed: int = _status.get("adaptation_options", {}).get(web_selection, {}).get("expressed", _status.adapted_workers)
		_detail_line(box, 185, "Expressed in %d / %d adults" % [expressed, _status.workers_total])
		_detail_line(box, 211, "Future brood inherits this trait")
	else:
		if not _status.adaptation_trial.is_empty():
			_detail_line(box, 185, "Focused trial already growing")
			_detail_line(box, 211, "New selection waits for emergence")
		else:
			_detail_line(box, 185, "Other recognition choice inherited" if web_selection in ["security", "tolerance"] else "Colony choice: " + ("Lean Foragers" if _status.adaptation_repertoire == "lean" else "Load Bearers"))
			_detail_line(box, 211, "Inherited family choice cannot switch")
	if web_selection in ["security", "tolerance"]:
		_detail_line(box, 302, "Earlier harm association" if web_selection == "security" else "Later harm association")
		_detail_line(box, 326, "Reassign protection for new staffing")


func _draw_relationship_context(box: Rect2) -> void:
	var relationship: Dictionary = _status.get("honeydew", {})
	_detail_line(box, 65, "Honeydew relationship")
	_detail_line(box, 91, "Ecological · learned by interaction")
	var state: String = relationship.get("relationship", "unknown")
	if state == "unknown":
		_detail_line(box, 125, "Producer source observed")
		_detail_line(box, 151, "Harvest it through an OUTWARD trail")
		_detail_line(box, 185, "Protection follows a loaded return")
	else:
		_detail_line(box, 125, "Workers protect producers" if state == "tended" else "Honeydew successfully harvested")
		_detail_line(box, 151, "%d workers committed" % relationship.protection_workers if state == "tended" else "Needs %d available workers" % relationship.required_workers)
		_detail_line(box, 185, "Protection supports the producers")
		_detail_line(box, 211, "No gene trial or research payment")
		draw_rect(_honeydew_rect(), Color("35483c"))
		_label(_honeydew_rect().position + Vector2(130, 29), "WITHDRAW PROTECTION" if state == "tended" else "PROTECT PRODUCERS", Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)


func _detail_line(box: Rect2, y: float, value: String) -> void:
	_label(box.position + Vector2(16, y), value, Color("a9b9bc"), 14)


func _draw_brood_button() -> void:
	draw_rect(_brood_rect(), Color("35483c"))
	_label(_brood_rect().position + Vector2(130, 29), "LAY %d BROOD NOW" % _status.brood_batch_count, Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_nursery_develop_button() -> void:
	draw_rect(_nursery_develop_rect(), Color("35483c"))
	_label(_nursery_develop_rect().position + Vector2(130, 29), "DEVELOP NURSERY", Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)


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
		"adaptation": return "Adaptation"
		"guest": return "Guest"
		"midden": return "Midden"
	return ""


func _label(at: Vector2, value: String, color: Color, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var placed: Vector2 = at
	var width: float = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		placed.x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		placed.x -= width
	draw_string(_font, placed, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
