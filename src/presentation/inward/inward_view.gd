class_name InwardView
extends Node2D
## Abstract functional network; consumes detached pile summaries only.

const Art = preload("res://src/presentation/sensory_art.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
const NODES: Array[String] = ["queen", "nursery", "food_exchange", "entrance", "adaptation"]
var status_provider: Callable
var mode_command: Callable
var pause_command: Callable
var speed_command: Callable
var develop_command: Callable
var nursery_develop_command: Callable
var brood_command: Callable
var adaptation_command: Callable
var guest_rejection_command: Callable
var honeydew_command: Callable
var input_blocked: Callable
var save_command: Callable
var load_command: Callable
var selected_id: String = ""
var web_selection: String = "foraging"
var _animation_time: float = 0.0
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
	if selected_id == "adaptation" and _web_back_rect().has_point(at):
		selected_id = ""
		web_selection = "foraging"
		queue_redraw()
		return true
	if selected_id == "adaptation" and web_selection == "honeydew" and _status.get("honeydew", {}).get("relationship", "unknown") in ["exploited", "tended"] and _honeydew_rect().has_point(at):
		_run_command("honeydew")
		return true
	var guest: Dictionary = _status.get("guest", {})
	if selected_id == "guest" and guest.get("reported_losses", 0) > 0 and guest.get("observation", "") != "purged" and _guest_rect().has_point(at):
		_run_command("guest_rejection")
		return true
	if selected_id == "adaptation" and web_selection in ["lean", "load"] and _can_choose_adaptation():
		for trait_id: String in ["lean", "load"]:
			if web_selection in ["lean", "load"] and web_selection != trait_id:
				continue
			if _adaptation_rect(trait_id).has_point(at):
				_run_command("adaptation_" + trait_id)
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
		var leaf: String = Web.node_at(at, get_viewport_rect().size, _status)
		if not leaf.is_empty():
			web_selection = leaf
			queue_redraw()
			return true
		return false
	var picked: String = node_at(at, get_viewport_rect().size, not guest.is_empty())
	if not picked.is_empty():
		selected_id = picked
		if picked == "adaptation":
			web_selection = "foraging"
		queue_redraw()
		return true
	return false


func _run_command(command: String) -> void:
	match command:
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
		"adaptation_lean", "adaptation_load":
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
		"guest": origin + Vector2(field_width * 0.50, field_height * 0.89)}


static func node_at(at: Vector2, size: Vector2, guest_visible: bool = false) -> String:
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


func _brood_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 438.0 if selected_id == "nursery" else 380.0, 260.0, 44.0)


func _nursery_develop_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 494.0, 260.0, 44.0)


func _adaptation_rect(_trait_id: String) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 380.0, 260.0, 44.0)


func _guest_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 380.0, 260.0, 44.0)


func _web_back_rect() -> Rect2:
	return Rect2(24, 116, 196, 44)


func _honeydew_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 380.0, 260.0, 44.0)


func _can_choose_adaptation() -> bool:
	return _status.get("adaptation_repertoire", "") == "" and _status.get("adaptation_trial", {}).is_empty()


func _can_lay_brood() -> bool:
	return _status.get("queens", 0) > 0 and _status.get("nursery_brood_capacity", 0) - _status.get("nursery_occupied_space", 0) >= _status.get("brood_batch_count", 0) and (_status.get("brood", []).is_empty() or _status.get("nursery_state", "") == "developed")


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("080b10"))
	if selected_id == "adaptation":
		Web.draw_graph(self, size, _status, web_selection, _animation_time)
		draw_rect(_web_back_rect(), Color("18252b"))
		_label(_web_back_rect().position + Vector2(98, 29), "BACK TO COLONY", Color("d3dcd4"), 14, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_hud(size)
		_draw_context(size)
		_draw_controls(size)
		return
	var centers: Dictionary = positions(size)
	for pair: Array in [["queen", "nursery"], ["nursery", "food_exchange"], ["food_exchange", "entrance"], ["entrance", "queen"]]:
		_draw_flow(centers[pair[0]], centers[pair[1]], pair[0] == "nursery" or pair[0] == "entrance")
	for id: String in ["queen", "nursery"]:
		draw_line(centers[id], centers["adaptation"], Color(0.43, 0.40, 0.55, 0.20), 1.0, true)
	for id: String in NODES:
		_draw_node(id, centers[id])
	if not _status.get("guest", {}).is_empty():
		draw_line(centers.guest, centers.nursery, Color(0.65, 0.53, 0.64, 0.18), 1.0, true)
		_draw_node("guest", centers.guest)
	_draw_hud(size)
	_draw_context(size)
	_draw_controls(size)


func _draw_flow(start: Vector2, finish: Vector2, representative: bool) -> void:
	var control: Vector2 = (start + finish) * 0.5 + Vector2(12, -18)
	var points := PackedVector2Array()
	for step: int in 25:
		var t: float = float(step) / 24.0
		points.append(start * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + finish * t * t)
	draw_polyline(points, Color(0.45, 0.59, 0.53, 0.18), 1.0, true)
	var activity: int = int(_status.get("nursery_occupied_space", 0)) + int(_status.get("trail_workers", 0))
	if representative and activity > 0:
		for index: int in 2:
			var t: float = fposmod(_animation_time * 0.05 + index * 0.5, 1.0)
			var at: Vector2 = start * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + finish * t * t
			Art.ant(self, at, finish - start, Color(0.76, 0.80, 0.69, 0.36), _animation_time, 0.72)


func _draw_node(id: String, at: Vector2) -> void:
	var color: Color = Color("d5c4a1") if id == "queen" else Color("aebdb7") if id == "nursery" else Color("c7af86") if id == "food_exchange" else Color("bba6c8") if id == "adaptation" else Color("8daeb3")
	var phase: float = _animation_time * 0.18 + NODES.find(id)
	var outline: PackedVector2Array = Art.membrane(at, 34.0, phase, 0.86)
	draw_colored_polygon(outline, Color(color, 0.045))
	draw_polyline(outline.slice(1, 27), Color(color, 0.4), 1.1, true)
	match id:
		"guest":
			for index: int in 3:
				draw_arc(at + Vector2(index * 5 - 5, index * 3 - 3), 9, 0.4, 4.1, 16, Color(color, 0.45), 1.0, true)
		"nursery":
			var occupied: int = int(_status.get("nursery_occupied_space", 0))
			for index: int in mini(6, occupied):
				var seed_at: Vector2 = at + Vector2(index % 3 * 9 - 9, index / 3 * 11 - 5)
				draw_circle(seed_at, 2.9, Color(color, 0.52))
		"adaptation":
			for index: int in 3:
				var seed_at: Vector2 = at + Vector2.from_angle(index * TAU / 3.0 + 0.3) * 13
				draw_line(at, seed_at, Color(color, 0.4), 1.0, true)
				draw_circle(seed_at, 3.2, Color(color, 0.64))
		"food_exchange":
			draw_polyline(Art.membrane(at, 16, -phase, 0.56).slice(3, 22), Color(color, 0.5), 1.2, true)
		"entrance":
			draw_arc(at + Vector2(0, 5), 12, PI, TAU, 20, Color(color, 0.6), 1.5, true)
		"queen":
			draw_circle(at, 5.0, Color(color, 0.65))
			draw_circle(at + Vector2(0, 9), 3.0, Color(color, 0.36))
	if id == "nursery" and _status.get("guest", {}).get("observation", "") == "foreign":
		draw_arc(at, 39.0, 0.3, 1.9, 20, Color("b79eaf"), 1.0, true)
	if id == selected_id:
		var focus: PackedVector2Array = Art.membrane(at, 43.0, 1.5)
		draw_polyline(focus.slice(1, 8), Color("dce5d9"), 1.0, true)
		draw_polyline(focus.slice(17, 24), Color("dce5d9"), 1.0, true)
	_label(at + Vector2(0, 52), _title(id), color, 15, HORIZONTAL_ALIGNMENT_CENTER)


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
	var box := Rect2(Vector2(size.x - 316, 144), Vector2(292, 400 if selected_id == "nursery" else 344 if selected_id == "adaptation" else 284))
	var web: bool = selected_id == "adaptation"
	draw_rect(box, Color("17141f") if web else Color("111921"))
	draw_rect(box, Color("786683") if web else Color("41535a"), false, 1.0)
	_label(box.position + Vector2(16, 31), "Adaptation Web" if web else _title(selected_id), Color("decce8") if web else Color("d9d3be"), 20)
	if web and web_selection == "honeydew":
		_draw_relationship_context(box)
		return
	if web and web_selection in ["lean", "load"]:
		_draw_genetic_context(box)
		return
	match selected_id:
		"queen":
			_detail_line(box, 65, "Queens: %d" % _status.queens)
			_detail_line(box, 91, "Living workers: %d" % _status.workers_total)
			_detail_line(box, 117, "Available workers: %d" % _status.workers_available)
			_detail_line(box, 157, "Nursery: %d / %d brood space" % [_status.nursery_occupied_space, _status.nursery_brood_capacity])
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
				_detail_line(box, 117, stages)
				var food_enough: bool = true
				var care_enough: bool = true
				for cohort: Dictionary in brood:
					food_enough = food_enough and cohort.nutrition >= 1.0
					care_enough = care_enough and cohort.care >= 1.0
				_detail_line(box, 143, "Food %s · care %s" % ["enough" if food_enough else "short", "enough" if care_enough else "short"])
			_detail_line(box, 181, "%d emerged · %d brood lost" % [_status.brood_matured_total, _status.get("brood_losses", 0)])
			if _status.nursery_state == "primitive":
				_detail_line(box, 209, "Develop for %d brood space" % _status.nursery_developed_capacity)
				_detail_line(box, 235, "Needs %.0f carb · %.0f protein" % [_status.nursery_costs.carbohydrate, _status.nursery_costs.protein])
				_detail_line(box, 261, "%.0f water · %d workers · %.0fs" % [_status.nursery_costs.water, _status.nursery_workers_required, _status.nursery_build_duration])
				_draw_nursery_develop_button()
			elif _status.nursery_state == "developing":
				_detail_line(box, 209, "Developing: %.0f / %.0fs" % [_status.nursery_progress, _status.nursery_build_duration])
				_detail_line(box, 235, "%d workers committed" % _status.nursery_workers_required)
			else:
				_detail_line(box, 209, "Developed: room for two cohorts")
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
		"entrance":
			_detail_line(box, 65, "Available workers: %d" % _status.workers_available)
			_detail_line(box, 91, "Scouts away: %d" % _status.active_scouts)
			_detail_line(box, 117, "Trail workers: %d" % _status.trail_workers)
		"guest":
			var guest: Dictionary = _status.get("guest", {})
			var observation: String = guest.get("observation", "")
			_detail_line(box, 65, "Guest purged" if observation == "purged" else "Internal foreignness · Nursery" if observation == "foreign" else "Nursery losses · cause uncertain" if observation == "loss" else "Guest tolerated at home")
			_detail_line(box, 99, "%d brood lost" % guest.get("reported_losses", 0) if observation != "tolerated" else "No harmful effect observed")
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
			_detail_line(box, 65, "Colony repertoire · overview")
			_detail_line(box, 91, "Select a trait to inspect its tradeoff")
			_detail_line(box, 117, "Start its brood trial in this panel")
			if not _status.adaptation_trial.is_empty():
				_detail_line(box, 163, "%s trial" % ("Lean Foragers" if _status.adaptation_trial.adaptation_id == "lean" else "Load Bearers"))
				_detail_line(box, 189, "Brood stage: %s" % _status.adaptation_trial.stage.capitalize())
				_detail_line(box, 215, "Trait emerges with this brood")
			elif _status.adaptation_repertoire != "":
				_detail_line(box, 163, "Chosen: %s" % ("Lean Foragers" if _status.adaptation_repertoire == "lean" else "Load Bearers"))
				_detail_line(box, 189, "Adapted workers: %d / %d" % [_status.adapted_workers, _status.workers_total])
				_detail_line(box, 215, "Future brood inherits this trait")
			else:
				_detail_line(box, 163, "One inherited trait for future brood")
				_detail_line(box, 189, "Genes require food, nurses and brood")
				_detail_line(box, 215, "Relationships grow through interaction")


func _draw_genetic_context(box: Rect2) -> void:
	_detail_line(box, 65, "Lean Foragers" if web_selection == "lean" else "Load Bearers")
	_detail_line(box, 91, Web.trait_state(_status, web_selection))
	_detail_line(box, 125, "30% less travel energy" if web_selection == "lean" else "30% more carrying")
	_detail_line(box, 151, "15% less carrying" if web_selection == "lean" else "20% more travel energy")
	if _can_choose_adaptation():
		_detail_line(box, 185, "Needs %.0f carb · %.0f protein · %.0f water" % [_status.adaptation_costs.carbohydrate, _status.adaptation_costs.protein, _status.adaptation_costs.water])
		_detail_line(box, 211, "%d nurses · %d brood slots" % [_status.adaptation_nurses, _status.brood_batch_count])
		var rect: Rect2 = _adaptation_rect(web_selection)
		draw_rect(rect, Color("28212f"))
		draw_rect(rect, Color("a28aaf"), false, 1.5)
		_label(rect.position + Vector2(130, 29), "START LEAN BROOD TRIAL" if web_selection == "lean" else "START LOAD BROOD TRIAL", Color("e3dbe7"), 13, HORIZONTAL_ALIGNMENT_CENTER)
	elif _status.adaptation_trial.get("adaptation_id", "") == web_selection:
		_detail_line(box, 185, "Stage: " + str(_status.adaptation_trial.stage).capitalize())
		_detail_line(box, 211, "Expresses only with surviving adults")
	else:
		var choice: String = _status.adaptation_repertoire if _status.adaptation_repertoire != "" else _status.adaptation_trial.get("adaptation_id", "")
		_detail_line(box, 185, "Colony choice: " + ("Lean Foragers" if choice == "lean" else "Load Bearers"))
		_detail_line(box, 211, "Choice waits for trial outcome" if not _status.adaptation_trial.is_empty() else "Inherited choice cannot be switched")


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
	_label(_brood_rect().position + Vector2(130, 29), "LAY %d BROOD" % _status.brood_batch_count, Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)


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
	return ""


func _label(at: Vector2, value: String, color: Color, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var placed: Vector2 = at
	var width: float = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		placed.x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		placed.x -= width
	draw_string(_font, placed, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
