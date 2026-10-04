class_name OutwardView
extends Node2D
## Normal-play sensorium. Providers deliver approved detached values only.

const Panorama = preload("res://src/presentation/outward/outward_projection.gd")
const SWARM_CONFIG = preload("res://data/ecology/default_swarm.tres")
const UIStyle = preload("res://src/presentation/organic_ui.gd")
const Art = preload("res://src/presentation/sensory_art.gd")
const Scent = preload("res://src/presentation/outward/trail_visual.gd")
const ScoutTrace = preload("res://src/presentation/outward/scout_trace_visual.gd")
const LossEvidence = preload("res://src/presentation/returned_loss_evidence.gd")
const Copy = preload("res://src/presentation/interface_text.gd")
const Memories = preload("res://src/presentation/outward/source_memory.gd")
const MEMORY_CATEGORIES: Array[String] = ["carbohydrate", "protein", "water", "nest_site"]
var sources_open: bool = false
var source_category: String = "carbohydrate"
var source_page: int = 0
var signal_provider: Callable
var status_provider: Callable
var dispatch_command: Callable
var scout_recall_command: Callable
var exploration_command: Callable
var exploration_bias_command: Callable
var exploration_open: bool = false
var pause_command: Callable
var speed_command: Callable
var founding_command: Callable
var establish_command: Callable
var pile_command: Callable
var inspect_daughter_command: Callable
var trail_create_command: Callable
var trail_set_command: Callable
var trail_recheck_command: Callable
var investigate_command: Callable
var honeydew_start_command: Callable
var honeydew_stop_command: Callable
var input_blocked: Callable
var mode_command: Callable
var pressure_command: Callable
var save_command: Callable
var load_command: Callable
var facing: float = 0.0
var selected_id: String = ""
var journey_open: bool = false
var journey_command: Callable

var _animation_time: float = 0.0
var _signals: Array[Dictionary] = []
var _signal_labels: Dictionary = {}
var _caption_blocks: Array[Rect2] = []
var _status: Dictionary = {}
var _placed: Array[Dictionary] = []
var _mission_traces: Array[Dictionary] = []
var _seen_missions: Dictionary = {}
var _missions_baselined: bool = false
var _departures: Array[Dictionary] = []
var _font: Font = ThemeDB.fallback_font
var _pointer_kind: String = ""
var _pointer_start: Vector2
var _pointer_last: Vector2
var _dragged: bool = false
var _feedback: String = ""
var _feedback_until: int = 0
var _request_rejected: bool = false
var _request_selection: String = ""


func show_feedback(message: String, rejected: bool = false) -> void:
	_request_rejected = rejected
	_request_selection = selected_id
	_feedback = message
	_feedback_until = Time.get_ticks_msec() + 3000


func _process(delta: float) -> void:
	if signal_provider.is_valid() and status_provider.is_valid():
		_signals = signal_provider.call()
		_status = status_provider.call()
		_placed = Panorama.project(_signals, facing, get_viewport_rect().size)
		_mission_traces = ScoutTrace.traces(_status.get("scout_missions", []), facing, get_viewport_rect().size)
		_sync_departures()
	if not _status.get("paused", false):
		_animation_time = fposmod(_animation_time + minf(delta, 0.1), 3600.0)
		_advance_departures(minf(delta, 0.1))
	queue_redraw()


func reset_mission_visuals() -> void:
	_seen_missions.clear()
	_missions_baselined = false
	_departures.clear()
	_mission_traces.clear()


func _sync_departures() -> void:
	var current: Dictionary = {}
	for mission: Dictionary in _status.get("scout_missions", []):
		current[mission.id] = true
		if _missions_baselined and not _seen_missions.has(mission.id) and mission.returned_at < 0.0 and mission.age < 8.0 and _departures.size() < 3:
			_departures.append({"age": 0.0, "side": -1.0 if int(str(mission.id).trim_prefix("scout_")) % 2 else 1.0})
	_seen_missions = current
	_missions_baselined = true


func _advance_departures(delta: float) -> void:
	for entry: Dictionary in _departures:
		entry.age += delta
	for index: int in range(_departures.size() - 1, -1, -1):
		if _departures[index].age >= ScoutTrace.DEPARTURE_SECONDS:
			_departures.remove_at(index)


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
	cancel_pointer_gesture()
	var command: String = _button_at(at)
	if not command.is_empty():
		_run_command(command)
		return
	if _panel_at(at):
		return
	if _field_rect().has_point(at):
		_pointer_kind = kind
		_pointer_start = at
		_pointer_last = at
		_dragged = false


func cancel_pointer_gesture() -> void:
	_pointer_kind = ""
	_dragged = false


func _panel_at(at: Vector2) -> bool:
	if sources_open and _sources_panel_rect().has_point(at): return true
	if exploration_open and _exploration_panel_rect().has_point(at): return true
	if not _selected_signal().is_empty() or not _selected_mission().is_empty():
		return _context_panel_rect().has_point(at)
	return false


func _sources_panel_rect() -> Rect2:
	return Rect2(24, 148, 332, 442)


func _exploration_panel_rect() -> Rect2:
	return Rect2(24, 148, 308, 330)


func _context_panel_rect() -> Rect2:
	var height: float = 448 if _journey_attention() else 292 if not _selected_mission().is_empty() else 344 + _evidence_offset()
	if _selected_signal().get("category")=="nest_site": height=400
	return Rect2(get_viewport_rect().size.x - 316, 144, 292, height)


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
		var picked: String = Panorama.pick(_placed, at)
		if picked.is_empty():
			for marker: Dictionary in Scent.alarm_markers(_status.get("trails", []), _placed, get_viewport_rect().size):
				if at.distance_to(marker.center) <= 44.0:
					picked = marker.id
					break
		selected_id = picked if not picked.is_empty() else ScoutTrace.pick(_mission_traces, at, selected_id)
		journey_open = false
	_pointer_kind = ""


func turn_pixels(delta_x: float, width: float) -> void:
	if is_finite(delta_x) and is_finite(width) and width > 0:
		facing = fposmod(facing - delta_x * PI / width, TAU)
		_placed = Panorama.project(_signals, facing, get_viewport_rect().size)
		_mission_traces = ScoutTrace.traces(_status.get("scout_missions", []), facing, get_viewport_rect().size)
		queue_redraw()


func _run_command(command: String) -> void:
	if command == "pile":
		if pile_command.is_valid(): pile_command.call(_status.get("other_pile", ""))
		return
	_request_rejected = false
	if command=="establish":
		if establish_command.is_valid():
			var result: Dictionary=establish_command.call(_selected_signal().source_knowledge_id)
			show_feedback("Daughter pile established" if result.get("accepted",false) else result.get("reason","Establishment unavailable"))
		return
	if command=="inspect_daughter":
		if inspect_daughter_command.is_valid(): inspect_daughter_command.call(_camp_summary().daughter_id)
		return
	if command=="founding":
		var selected: Dictionary=_selected_signal()
		if selected.get("category")=="nest_site" and founding_command.is_valid():
			var result: Dictionary=founding_command.call(selected.source_knowledge_id)
			show_feedback("Founding party dispatched · await report" if result.get("accepted",false) else result.get("reason","Founding unavailable"),not result.get("accepted",false))
		return
	if command == "scout_recall":
		var mission: Dictionary = _selected_mission()
		if mission.get("awaiting", mission.get("returned_at", 0.0) < 0.0) and scout_recall_command.is_valid():
			var result: Dictionary = scout_recall_command.call(mission.id)
			show_feedback("Return requested · await arrival" if result.get("accepted", false) else result.get("reason", "Recall unavailable"), not result.get("accepted", false))
		return
	if command == "journey_open": journey_open = true; return
	if command == "journey_close":
		journey_open = false
		var selected: Dictionary = _selected_signal()
		if selected.get("category") == "threat":
			for signal_data: Dictionary in _signals:
				if signal_data.category != "threat" and signal_data.source_knowledge_id == selected.source_knowledge_id: selected_id = signal_data.id; break
		return
	if command in ["journey_investigate","journey_recall","journey_defend","journey_reinforce"]:
		var route: Dictionary = _selected_route(_selected_signal())
		if not route.is_empty() and journey_command.is_valid():
			var result: Dictionary = journey_command.call(command.trim_prefix("journey_"),route.id)
			var message: Dictionary = {"journey_investigate":"Survey dispatched","journey_defend":"Defenders dispatched","journey_reinforce":"Reinforcements dispatched","journey_recall":"Party recalled"}
			show_feedback(message[command] if result.get("accepted",false) else result.get("reason","Response unavailable"), not result.get("accepted", false))
		return
	if command.begins_with("source_filter_"):
		source_category = command.trim_prefix("source_filter_")
		source_page = 0
		return
	if command == "source_page":
		source_page = (source_page + 1) % maxi(1, ceili(_source_entries().size() / 3.0))
		return
	if command.begins_with("source_entry_"):
		journey_open = false
		var entries: Array[Dictionary] = _source_entries()
		var index: int = source_page * 3 + int(command.trim_prefix("source_entry_"))
		if index < entries.size():
			selected_id = entries[index].id
			if entries[index].bearing != null:
				facing = entries[index].bearing
			sources_open = false
			_placed = Panorama.project(_signals, facing, get_viewport_rect().size)
		return
	match command:
		"daughter_pressure":
			if not _status.get("daughter_attention", {}).is_empty() and pressure_command.is_valid():
				var result: Dictionary = pressure_command.call(_status.daughter_attention.get("pile_id","satellite_1"))
				if not result.get("accepted", false): show_feedback(result.get("reason", "Internal attention unavailable"))
		"internal_pressure":
			if not _status.get("internal_attention", {}).is_empty() and pressure_command.is_valid():
				var result: Dictionary = pressure_command.call(_status.get("pile_id","home"))
				if not result.get("accepted", false): _feedback = result.get("reason", "Internal attention unavailable")
		"sources":
			sources_open = not sources_open
			exploration_open = false
		"honeydew_start", "honeydew_stop":
			var signal_data: Dictionary = _selected_signal()
			if signal_data.is_empty() or not _is_honeydew(signal_data):
				return
			var action: Callable = honeydew_start_command if command == "honeydew_start" else honeydew_stop_command
			if not action.is_valid():
				return
			var result: Dictionary = action.call(signal_data.source_knowledge_id)
			_request_rejected = not result.get("accepted", false)
			_request_selection = selected_id
			_feedback = ("Producers tended" if command == "honeydew_start" else "Tending withdrawn") if result.get("accepted", false) else Copy.reason(result.get("reason", "Tending unavailable"))
		"investigate":
			var signal_data: Dictionary = _selected_signal()
			if signal_data.is_empty() or not investigate_command.is_valid():
				return
			var result: Dictionary = investigate_command.call(signal_data.source_knowledge_id)
			_request_rejected = not result.get("accepted", false)
			_request_selection = selected_id
			_feedback = "Scout sent to recheck source" if result.get("accepted", false) else result.get("reason", "Investigation unavailable")
			if result.get("accepted", false) and result.get("standing_priority", false):
				_feedback = "Source recheck priority removed" if not result.enabled else "Priority queued · set Exploration effort" if result.exploration_off else "Source prioritized for scout rechecks"
				if result.get("recovery_watch", false):
					_feedback = "Recovery watch stopped" if not result.enabled else "Watch queued · set Exploration effort" if result.exploration_off else "Watch set · fresh return can resume gathering"
			if signal_data.category == "nest_site" and result.get("accepted", false):
				_feedback = "Scout sent to recheck site"
				if result.get("standing_priority", false):
					_feedback = "Site recheck priority removed" if not result.enabled else "Site queued · set Exploration effort" if result.exploration_off else "Site prioritized for scout rechecks"
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
				var target: int = 0 if command == "trail_cancel" else maxi(0, route.desired_workers - 1) if command == "trail_less" else route.desired_workers + (SWARM_CONFIG.reinforcement_step if route.get("foreign_reports", 0) >= SWARM_CONFIG.reports_to_escalate else 1)
				result = trail_set_command.call(route.id, target)
			_request_rejected = not result.get("accepted", false)
			_request_selection = selected_id
			_feedback = ("Gatherers resumed from returned evidence" if route.get("recovery_ready", false) else "Gatherers sent · availability still uncertain") if command == "trail_recheck" and result.get("accepted", false) else "Trail updated" if result.get("accepted", false) else result.get("reason", "Trail unavailable")
		"scout":
			sources_open = false
			if exploration_command.is_valid():
				exploration_open = not exploration_open
				return
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
			if command.begins_with("explore_") and exploration_command.is_valid():
				var result: Dictionary = exploration_command.call(int(command.trim_prefix("explore_")))
				_feedback = "Exploration effort updated · surplus returns home" if result.get("accepted", false) else result.get("reason", "Exploration unavailable")
			elif command in ["exploration_bias", "exploration_general"] and exploration_bias_command.is_valid():
				var result: Dictionary = exploration_bias_command.call(facing if command == "exploration_bias" else null)
				_feedback = "Exploration attention updated" if result.get("accepted", false) else result.get("reason", "Attention unavailable")
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
		"internal_pressure": return Rect2(264, 100, 300, 44)
		"daughter_pressure": return Rect2(264, 100 if _status.get("internal_attention", {}).is_empty() else 152, 300, 44)
		"pile": return Rect2(24, 152, 220, 44)
		"sources": return Rect2(24, 100, 220, 44)
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
	if not sources_open and not exploration_open and not _status.get("other_pile", "").is_empty() and _button_rect("pile").has_point(at): return "pile"
	if not _status.get("internal_attention", {}).is_empty() and _button_rect("internal_pressure").has_point(at):
		return "internal_pressure"
	if not sources_open and not exploration_open and not _status.get("daughter_attention", {}).is_empty() and _button_rect("daughter_pressure").has_point(at):
		return "daughter_pressure"
	if sources_open and _sources_panel_rect().has_point(at):
		for category: String in MEMORY_CATEGORIES:
			if _source_filter_rect(category).has_point(at):
				return "source_filter_" + category
		var entries: Array[Dictionary] = _source_entries()
		for index: int in 3:
			if source_page * 3 + index < entries.size() and _source_row_rect(index).has_point(at):
				return "source_entry_" + str(index)
		if _source_page_rect().has_point(at):
			return "source_page"
		return "source_panel"
	if exploration_open:
		for command: String in ["explore_0", "explore_2", "explore_5", "explore_8", "exploration_bias", "exploration_general"]:
			if _exploration_rect(command).has_point(at):
				return command
	var mission: Dictionary = _selected_mission()
	if not mission.is_empty() and mission.get("awaiting", mission.get("returned_at", 0.0) < 0.0) and _scout_recall_rect().has_point(at):
		return "scout_recall"
	if not _selected_signal().is_empty():
		var chosen_route: Dictionary = _selected_route(_selected_signal())
		if _selected_signal().category == "nest_site":
			if not _daughter() and _founding_rect().has_point(at):
				var camp_status: String=_camp_summary().get("status","none")
				if camp_status in ["none","failed"]: return "founding"
				if camp_status=="ready": return "establish"
				if camp_status=="established": return "inspect_daughter"
			if _investigate_button_rect().has_point(at): return "investigate"
			if _context_panel_rect().has_point(at): return ""
		if _journey_attention():
			var own_party: bool = _status.get("journey_response",{}).get("away",false) and _status.get("journey_response",{}).get("route_id","") == chosen_route.get("id")
			if _journey_rect("journey_close").has_point(at): return "journey_close"
			if _journey_rect("journey_investigate").has_point(at): return "journey_recall" if own_party else "journey_investigate"
			if _journey_rect("journey_defend").has_point(at):
				var state: Dictionary = _status.get("journey_response",{})
				if own_party and state.get("reinforcement_available",false): return "journey_reinforce"
				if not own_party and _can_mobilize(chosen_route): return "journey_defend"
			if Rect2(get_viewport_rect().size.x - 316,144,292,448).has_point(at): return "journey_panel"
		elif chosen_route.get("reported_losses",0) > 0 and _journey_rect("journey_open").has_point(at): return "journey_open"
		if _journey_attention():
			for command: String in ["scout","pause","speed_1","speed_4","speed_16","speed_64","inward","save","load","sources"]:
				if _button_rect(command).has_point(at): return command
			return ""
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
	for command: String in ["scout", "pause", "speed_1", "speed_4", "speed_16", "speed_64", "inward", "save", "load", "sources"]:
		if _button_rect(command).has_point(at):
			return command
	return ""


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	_prepare_signal_captions(size)
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	_draw_rain(size)
	Art.home_entrance(self,Vector2(size.x*0.5,size.y*0.78))
	_draw_trails(size)
	_draw_scout_traces(size)
	_draw_anchor(size)
	for entry: Dictionary in _placed:
		_draw_signal(entry)
	_draw_hud(size)
	_draw_pressure_attention()
	if exploration_open:
		_draw_exploration()
	_draw_context(size)
	if sources_open:
		_draw_sources()
	_draw_controls(size)


func _draw_pressure_attention() -> void:
	var attention: Dictionary = _status.get("internal_attention", {})
	if not attention.is_empty(): _draw_pressure_badge(_button_rect("internal_pressure"), attention)
	if not sources_open and not exploration_open:
		attention = _status.get("daughter_attention", {})
		if not attention.is_empty(): _draw_pressure_badge(_button_rect("daughter_pressure"), attention)


func _draw_pressure_badge(box: Rect2, attention: Dictionary) -> void:
	UIStyle.surface(self, box, Color("211c1b"))
	draw_line(box.position, box.position + Vector2(0, box.size.y), Color("b58c79"), 1.0, true)
	_label(box.position + Vector2(16, 18), attention.title, Color("d3c3b8"), 12)
	_label(box.position + Vector2(16, 35), Copy.fit_line(" / ".join(attention.causes),_font,11,box.size.x-32), Color("bca08e"), 11)


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
			Art.filament(self, stroke.points, Color(color, 0.16 + 0.20 * strength), 16.0)
			draw_polyline(stroke.points, Color(color.lightened(0.18), 0.16 + 0.5 * strength), 1.1, true)
	for path: Dictionary in Scent.paths(routes, _placed, size):
		if path.ghost:
			continue
		if path.chemical >= 0.45:
			for branch: PackedVector2Array in path.branches:
				draw_polyline(branch.slice(0, 3), Color(Art.color_for(path.category), 0.13 * path.strength), 0.8, true)
				draw_polyline(branch.slice(2, 4), Color(Art.color_for(path.category), 0.045 * path.strength), 0.7, true)
		for index: int in 8:
			var sample: float = fposmod(_animation_time * 0.025 + index / 8.0, 0.96) * Scent.STEPS
			var first: int = int(sample)
			var at: Vector2 = path.points[first].lerp(path.points[first + 1], sample - first)
			at += Vector2(sin(index * 2.7 + _animation_time), cos(index * 1.8 + _animation_time * 0.7)) * 3.5
			draw_circle(at, 0.75, Color(Art.color_for(path.category), 0.12 * path.strength))
	for rep: Dictionary in Scent.representatives(routes, _placed, size, _animation_time):
		var obscured: bool = false
		var ant_bounds := Rect2(rep.position - Vector2(10,10), Vector2(20,20))
		for reserved: Rect2 in _caption_blocks:
			obscured = obscured or reserved.intersects(ant_bounds)
		if obscured: continue
		Art.ant(self, rep.position, rep.direction, Color(Art.color_for(rep.category).lightened(0.25), 0.62), _animation_time, 0.82)
	for marker: Dictionary in Scent.alarm_markers(routes, _placed, size):
		var at: Vector2 = marker.center
		draw_arc(at, 8.0, 0.0, 2.2, 16, Color(0.82, 0.39, 0.27, 0.5), 1.3, true)
		draw_arc(at, 8.0, PI, PI + 1.3, 12, Color(0.82, 0.39, 0.27, 0.4), 1.0, true)
		UIStyle.surface(self,Rect2(at+Vector2(-50,-29),Vector2(100,20)),Color("392723"))
		_label(at + Vector2(0, -14), "JOURNEY ALARM", Color("d3a08b"), 10, HORIZONTAL_ALIGNMENT_CENTER)


func _prepare_signal_captions(size: Vector2) -> void:
	_signal_labels.clear()
	_caption_blocks.clear()
	if not sources_open and not exploration_open and not _status.get("other_pile", "").is_empty(): _caption_blocks.append(_button_rect("pile"))
	for entry: Dictionary in _placed:
		_caption_blocks.append(Rect2(entry.center - Vector2.ONE * entry.radius, Vector2.ONE * entry.radius * 2))
	for marker: Dictionary in Scent.alarm_markers(_status.get("trails", []), _placed, size):
		_caption_blocks.append(Rect2(marker.center + Vector2(-48, -26), Vector2(96, 16)))
	if not _selected_mission().is_empty():
		_caption_blocks.append(Rect2(size.x - 316, 144, 292, 226))
	elif not _selected_signal().is_empty():
		_caption_blocks.append(Rect2(size.x - 316, 144, 292, 400 if _selected_signal().get("category")=="nest_site" else 448 if _journey_attention() else 344 + _evidence_offset()))
	if sources_open: _caption_blocks.append(_sources_panel_rect())
	if exploration_open: _caption_blocks.append(_exploration_panel_rect())
	var ordered: Array[Dictionary] = _placed.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a.id == selected_id) != (b.id == selected_id): return a.id == selected_id
		return a.id < b.id)
	for entry: Dictionary in ordered:
		var text_size: Vector2 = _font.get_string_size(_signal_caption(entry.signal), HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var baseline: Variant = ScoutTrace.caption_at(entry.center + Vector2(0, entry.radius + 35), text_size,
			_caption_blocks, Rect2(24, 148, size.x - 48, size.y - 266), [-13.0, 11.0, 35.0, 59.0, -37.0, -61.0, -85.0])
		if baseline == null: continue
		_signal_labels[entry.id] = baseline
		_caption_blocks.append(Rect2(baseline - Vector2(text_size.x * 0.5, text_size.y), text_size + Vector2(0, 4)))


func _draw_scout_traces(size: Vector2) -> void:
	var captions: Array[Rect2] = _caption_blocks.duplicate()
	for entry: Dictionary in _mission_traces:
		var selected: bool = false
		for mission: Dictionary in entry.missions:
			selected = selected or selected_id == "mission:" + mission.id
		var color := Color("a8b4ad")
		draw_polyline(entry.points, Color(color, 0.30 if selected else 0.16 if entry.stub else 0.13 + 0.10 * entry.scent), 1.0, true)
		# Broken cap means remembered departure, distinct from a resource route.
		draw_arc(entry.center, 6.0, 0.2, 2.4 if entry.stub else 5.8, 16, Color(color, 0.55), 1.0, true)
		if selected:
			draw_arc(entry.center, 15.0, PI, TAU, 20, Color("dce5d9"), 1.0, true)
		var label: String = "NOT RETURNED" if entry.missions[0].get("missing_at", -1.0) >= 0.0 else "OVERDUE" if entry.missions[0].get("overdue", false) else "SCOUT" if entry.missions[0].returned_at < 0.0 else "RETURNED"
		if entry.missions.size() > 1:
			label += " ×%d" % entry.missions.size()
		var text_size: Vector2 = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var baseline: Variant = ScoutTrace.caption_at(entry.center, text_size, captions, Rect2(24, 148, size.x - 364, size.y - 266))
		if baseline != null:
			_label(baseline, label, Color(color, 0.78), 10, HORIZONTAL_ALIGNMENT_CENTER)
			captions.append(Rect2(baseline - Vector2(text_size.x * 0.5, text_size.y), text_size + Vector2(0, 4)))
	var chosen: Dictionary = _selected_mission()
	if chosen.is_empty() or chosen.returned_at < 0.0:
		return
	var previous: Variant = null
	for sample: Dictionary in chosen.course:
		var signals: Array[Dictionary] = [{"id": "course", "bearing": sample.bearing,
			"estimated_distance": sample.estimated_distance, "strength": 0.0, "uncertainty_radius": 0.0}]
		var projected: Array[Dictionary] = Panorama.project(signals, facing, size)
		if projected.is_empty():
			previous = null
			continue
		var at: Vector2 = projected[0].center
		if previous != null:
			draw_line(previous, at, Color(0.65, 0.72, 0.68, 0.15), 1.0, true)
		draw_circle(at, 2.0, Color(0.65, 0.72, 0.68, 0.30))
		previous = at


func _draw_anchor(size: Vector2) -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.78)
	for entry: Dictionary in _departures:
		var rep: Dictionary = ScoutTrace.departure(entry.age, entry.side, size)
		if not rep.is_empty():
			Art.ant(self, rep.position, rep.direction, Color(0.68, 0.61, 0.45, 0.70), _animation_time, 1.15)
	_label(center + Vector2(0, 33), _status.get("pile_name","Home").to_upper(), Color("d8c9ae"), 13, HORIZONTAL_ALIGNMENT_CENTER)


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
	if _signal_labels.has(entry.id):
		_label(_signal_labels[entry.id], _signal_caption(signal_data), color, 13, HORIZONTAL_ALIGNMENT_CENTER)


func _signal_caption(signal_data: Dictionary) -> String:
	if signal_data.category == "threat": return _threat_caption(signal_data)
	var empty: bool = _reported_empty(signal_data)
	var title: String = _signal_title_for(signal_data) + (" · UNCONFIRMED" if signal_data.category == "nest_site" else " · EMPTY") if empty else _signal_title_for(signal_data)
	if not empty and _status.get("temporal_hints", {}).get(signal_data.source_knowledge_id, {}).get("renewed_report", false): title += " · FOUND AGAIN"
	if signal_data.get("foreign_contact", false): title += " · FOREIGN"
	return title


func _draw_hud(size: Vector2) -> void:
	_label(Vector2(24, 38), "OUTWARD  /  " + _status.get("pile_name","Home").to_upper(), Color("dad7c8"), 22)
	_label(Vector2(24, 63), "Drag to turn. Tap a trace to listen.", Color("82939c"), 13)
	if _status.get("rain_phase", "") == "raining":
		_label(Vector2(24, 92), "RAIN / cooled air · scent disturbed", Color("8aadb8"), 13)
	elif not _status.get("home_air", "").is_empty():
		_label(Vector2(24, 92), _status.home_air, Color("b6a286"), 13)
	_label(Vector2(size.x * 0.5, 38), facing_text(facing), Color("a9bbc1"), 14, HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(size.x * 0.5, 53), Vector2(size.x * 0.5, 72), Color("769aa3"), 1.0)
	if not _status.is_empty():
		_label(Vector2(size.x - 24, 36), "%d available  /  shared scouts %d/%d" % [_status.available_workers, _status.active_scouts, _status.scout_cap], Color("c9d1c5"), 15, HORIZONTAL_ALIGNMENT_RIGHT)
		var pause_word: String = "PAUSED" if _status.paused else "%dx" % _status.time_scale
		_label(Vector2(size.x - 24, 61), "%s  ·  %s" % [pause_word, Copy.duration(_status.time)], Color("83969d"), 13, HORIZONTAL_ALIGNMENT_RIGHT)

	if not sources_open and not exploration_open and not _status.get("other_pile", "").is_empty():
		var switch: Rect2 = _button_rect("pile")
		UIStyle.surface(self,switch,Color("26383a"))
		_label(switch.get_center()+Vector2(0,5),"LOOK FROM " + ("HOME" if _daughter() else "DAUGHTER"),Color("dce5d9"),13,HORIZONTAL_ALIGNMENT_CENTER)


func _draw_context(size: Vector2) -> void:
	var mission: Dictionary = _selected_mission()
	if not mission.is_empty():
		_draw_mission_context(mission, size)
		return
	var selected: Dictionary = _selected_signal()
	if selected.is_empty():
		return
	if _journey_attention(): _draw_journey_context(size); return
	var box: Rect2 = _context_panel_rect()
	UIStyle.surface(self, box, Color("111921"))
	UIStyle.surface(self, box, Color("41535a"), true)
	_label(box.position + Vector2(16, 31), Memories.display_name({"knowledge_id": selected.source_knowledge_id, "category": selected.category, "honeydew": _is_honeydew(selected)}), Color("819092") if _reported_empty(selected) else _signal_color(selected.category), 20)
	_label(box.position + Vector2(16, 58), "A %s trace" % selected.confidence_label, Color("d4d8d1"), 15)
	var distance_word: String = "nearby" if selected.estimated_distance < 6.0 else "within reach" if selected.estimated_distance < 14.0 else "distant"
	_label(box.position + Vector2(16, 84), "Feels %s · around %.0f m" % [distance_word, selected.estimated_distance], Color("a8b8bd"), 15)
	_label(box.position + Vector2(16, 109), "Last sensed " + Copy.duration(selected.age) + " ago", Color("8fa1a8"), 15)
	if selected.category == "nest_site":
		_draw_founding_context(box)
		return
	var hint: Dictionary = _status.get("temporal_hints", {}).get(selected.source_knowledge_id, {})
	var loss_route: Dictionary = _selected_route(selected)
	var losses: int = int(loss_route.get("reported_losses", 0))
	var hint_text: String = "%d %s lost · cause uncertain" % [losses, "worker" if losses == 1 else "workers"] if losses > 0 else "Foreign chemistry reported on trail" if loss_route.get("foreign_reports", 0) > 0 else hint.label if not hint.is_empty() else "Risk unknown"
	var conflict: String = str(loss_route.get("conflict_report", ""))
	if conflict != "":
		hint_text = "Contested · +4 reinforces" if conflict == "contested" else "Foreign workers withdrew" if conflict == "secured" else "Workers withdrew" if conflict == "withdrew" else "Contact dispersed"
		if losses > 0:
			hint_text += " · %d lost" % losses

	var evidence: Array[String] = LossEvidence.lines(loss_route, float(_status.get("time", 0.0)))
	if not evidence.is_empty():
		var outcome: Dictionary = _status.get("journey_response", {}).get("outcomes", {}).get(loss_route.get("id"), {})
		if Memories.defense_is_latest(outcome, loss_route):
			_label(box.position + Vector2(16, 137), "Last defense: " + Memories.defense_label(outcome), Color("afbc9b"), 13)
			_label(box.position + Vector2(16, 156), "Returned " + Copy.duration(_status.time - outcome.received_at) + " ago", Color("8fa1a8"), 15)
			_label(box.position + Vector2(16, 175), "Past harvest losses: %d" % losses, Color("8fa1a8"), 15)
		else:
			for index: int in evidence.size():
				_label(box.position + Vector2(16, 137 + index * 19), evidence[index], Color("c48c7c") if index == 0 else Color("8fa1a8"), 15)
	else:
		_label(box.position + Vector2(16, 137), hint_text, Color("8fa1a8"), 15)
	if _is_honeydew(selected):
		_draw_honeydew_context(selected, box)
		_draw_journey_link()
		return
	var body: Rect2 = box
	body.position.y += _evidence_offset()
	var route: Dictionary = _selected_route(selected)
	if route.is_empty() or route.status == "inactive":
		var idle_text: String = "Trail: no workers committed" if route.is_empty() or _scent_label(route) == "absent" and float(route.get("route_familiarity", 0.0)) < 0.1 else "No workers · scent " + _scent_label(route)
		_label(body.position + Vector2(16, 165), idle_text, Color("a8b8bd"), 15)
		_label(body.position + Vector2(16, 187), "%s %s: %.1f" % [_status.get("pile_name","Home"), Copy.resource(selected.category), _status.get("resources", {}).get(selected.category, 0.0)], Color("8fa1a8"), 15)
		_draw_trail_button("trail_create", "ASSIGN 5 GATHERERS")
	elif route.status == "recalling":
		_label(body.position + Vector2(16, 165), "Recalling: %d workers away" % route.active_workers, Color("a8b8bd"), 15)
		_label(body.position + Vector2(16, 187), "Scent %s · Delivered %.1f" % [_scent_label(route), route.delivered_total], Color("8fa1a8"), 15)
		_draw_trail_button("trail_create", "ASSIGN 5 GATHERERS")
	else:
		var route_note: String = "Report renewed · gathering paused" if route.status == "depleted" and route.get("recovery_ready", false) else "Waiting for confirming scout report" if route.status == "depleted" and route.get("resume_on_report", false) else "Source reported empty · scent " + _scent_label(route) if route.status == "depleted" else "Waiting for carbohydrate" if route.get("energy_limited", false) else "Trail scent: " + _scent_label(route)
		_label(body.position + Vector2(16, 165), route_note, Color("a8b8bd"), 15)
		_label(body.position + Vector2(16, 185), "Gatherers: %d target · %d assigned" % [route.desired_workers, route.allocated_workers], Color("8fa1a8"), 15)
		var traffic: String = "%d travelling · %d checking" % [route.active_workers, route.checking_workers] if route.get("checking_workers", 0) > 0 else "%d gatherers away" % route.active_workers
		_label(body.position + Vector2(16, 205), traffic, Color("8fa1a8"), 15)
		_label(body.position + Vector2(16, 225), "Delivered %.1f %s total" % [route.delivered_total, Copy.resource(selected.category)], Color("8fa1a8"), 15)
		if route.status == "depleted":
			if route.active_workers == 0:
				_draw_trail_button("trail_recheck", _recheck_title(route))
		else:
			_draw_trail_button("trail_less", "− 1")
			_draw_trail_button("trail_more", "+ 4" if route.get("foreign_reports", 0) >= SWARM_CONFIG.reports_to_escalate else "+ 1")
		_draw_trail_button("trail_cancel", "RECALL")
	var scout_available: bool = _status.has("exploration") or _status.get("available_workers", 0) > 0 and _status.get("active_scouts", 0) < _status.get("scout_cap", 0)
	var investigate_box: Rect2 = _investigate_button_rect()
	UIStyle.surface(self, investigate_box, Color("27383c") if scout_available else Color("202326"))
	_label(investigate_box.position + Vector2(investigate_box.size.x * 0.5, 29), _investigation_title(selected), Color("d5ded8"), 14, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_journey_link()


func _draw_honeydew_context(selected: Dictionary, box: Rect2) -> void:
	var body: Rect2 = box
	body.position.y += _evidence_offset()
	var relationship: String = _status.get("honeydew", {}).get("relationship", "unknown")
	var required: int = int(_status.get("honeydew", {}).get("required_workers", 0))
	var available: int = int(_status.get("available_workers", 0))
	var relation_text: String = "Workers tending producers" if relationship == "tended" else "Sweet source · tending possible" if relationship == "exploited" else "Sweet source · not yet harvested"
	_label(body.position + Vector2(16, 162), relation_text, Color("d6b98c"), 13)
	var route: Dictionary = _selected_route(selected)
	var route_text: String = "Trail: no workers committed" if route.is_empty() or route.status == "inactive" else "Trail recalling · %d away" % route.active_workers if route.status == "recalling" else "Report renewed · gathering paused" if route.status == "depleted" and route.get("recovery_ready", false) else "Trail: source reported empty" if route.status == "depleted" else "Gatherers: %d assigned · %d away" % [route.allocated_workers, route.active_workers]
	_label(body.position + Vector2(16, 184), route_text, Color("a8b8bd"), 15)
	var labor_text: String = "Tending: %d assigned · %d free" % [int(_status.honeydew.protection_workers), available] if relationship == "tended" else "Tending needs %d · %d available" % [required, available]
	_label(body.position + Vector2(16, 201), labor_text, Color("8fa1a8"), 15)
	if relationship in ["exploited", "tended"]:
		var protect_box: Rect2 = _honeydew_button_rect()
		var can_start: bool = relationship == "tended" or available >= required
		UIStyle.surface(self, protect_box, Color("3d3328") if can_start else Color("202326"))
		_label(protect_box.position + Vector2(protect_box.size.x * 0.5, 29), "WITHDRAW TENDERS" if relationship == "tended" else "TEND PRODUCERS", Color("e1d4ba") if can_start else Color("8c8881"), 13, HORIZONTAL_ALIGNMENT_CENTER)
	if route.is_empty() or route.status in ["inactive", "recalling"]:
		_draw_trail_button("trail_create", "ASSIGN 5 GATHERERS" if route.is_empty() or route.status == "inactive" else "ASSIGN 5 GATHERERS")
	elif route.status == "depleted":
		if route.active_workers == 0:
			_draw_trail_button("trail_recheck", _recheck_title(route))
		_draw_trail_button("trail_cancel", "RECALL")
	else:
		_draw_trail_button("trail_less", "− 1")
		_draw_trail_button("trail_more", "+ 4" if route.get("foreign_reports", 0) >= SWARM_CONFIG.reports_to_escalate else "+ 1")
		_draw_trail_button("trail_cancel", "RECALL")
	var scout_available: bool = _status.has("exploration") or available > 0 and _status.get("active_scouts", 0) < _status.get("scout_cap", 0)
	var investigate_box: Rect2 = _investigate_button_rect()
	UIStyle.surface(self, investigate_box, Color("27383c") if scout_available else Color("202326"))
	_label(investigate_box.position + Vector2(investigate_box.size.x * 0.5, 29), _investigation_title(selected), Color("d5ded8"), 14, HORIZONTAL_ALIGNMENT_CENTER)


func _camp_summary() -> Dictionary:
	return _status.get("founding",{}).get(_selected_signal().get("source_knowledge_id",""),{})
func _founding_rect() -> Rect2: return Rect2(get_viewport_rect().size.x-300,424,260,44)
func _draw_founding_context(box: Rect2) -> void:
	if _daughter():
		_label(box.position+Vector2(16,145),"Shared shelter memory · safety unknown",Color("8fa1a8"),13)
		_label(box.position+Vector2(16,169),"Inspect Home for founding orders",Color("8fa1a8"),13)
		var button: Rect2 = _investigate_button_rect()
		UIStyle.surface(self,button,Color("27383c"))
		_label(button.get_center()+Vector2(0,5),_investigation_title(_selected_signal()),Color("d5ded8"),13,HORIZONTAL_ALIGNMENT_CENTER)
		return
	var camp: Dictionary=_camp_summary()
	var status: String=camp.get("status","none")
	var lines: Array[String]=[]
	if status=="awaiting":
		lines=["Founding party away · 12 workers","Result unknown · awaiting return","Dispatched "+Copy.duration(camp.age)+" ago","Queen and supplies are committed","Home worker brood can continue"]
	elif status=="ready":
		lines=["Founding camp reported","11 settlers · young queen + 2 males","Pack arrived: 6 carbs / 3 protein / 3 water","Occupants and hazards unassessed","Ready to establish a daughter pile"]
	elif status=="established":
		lines=["Daughter pile established","Settlers now belong to the daughter","Separate local stores and worker brood","Home exploration remains shared","Supplies: inspect either Entrance"]
	elif status=="failed":
		lines=["Shelter not confirmed on arrival","Party and reproductives returned","Supplies returned; travel food spent","Return report "+Copy.duration(_status.time-camp.reported_at)+" ago",camp.get("blocker","")]
	else:
		lines=["Commit 12 workers + queen + 2 males","Pack: 6 carbs · 3 protein · 3 water","Travel also spends carbohydrate","Settlers stay; a report returns",camp.get("blocker","Occupants and safety unknown")]
	for index: int in lines.size(): _label(box.position+Vector2(16,145+index*24),lines[index],Color("b9c5a1") if index==0 else Color("8fa1a8"),14 if index==0 else 12)
	if status in ["none","failed"]:
		var available: bool=camp.get("blocker","").is_empty() and not camp.is_empty()
		UIStyle.surface(self,_founding_rect(),Color("354039") if available else Color("202326"))
		_label(_founding_rect().get_center()+Vector2(0,5),"SEND FOUNDING PARTY",Color("d5ded8") if available else Color("929a95"),14,HORIZONTAL_ALIGNMENT_CENTER)
	elif status in ["ready","established"]:
		UIStyle.surface(self,_founding_rect(),Color("354039"))
		_label(_founding_rect().get_center()+Vector2(0,5),"ESTABLISH DAUGHTER PILE" if status=="ready" else "INSPECT DAUGHTER PILE",Color("d5ded8"),14,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_label(box.position+Vector2(16,308),"Founding report stays separate from",Color("8fa1a8"),12)
		_label(box.position+Vector2(16,329),"the dated scout shelter memory.",Color("8fa1a8"),12)
	var recheck: Rect2=_investigate_button_rect()
	UIStyle.surface(self,recheck,Color("27383c"))
	_label(recheck.get_center()+Vector2(0,5),_investigation_title(_selected_signal()),Color("d5ded8"),14,HORIZONTAL_ALIGNMENT_CENTER)


func _investigation_title(selected: Dictionary) -> String:
	if selected.get("category") == "nest_site":
		if not _status.has("exploration"): return "SEND SCOUT TO RECHECK SITE"
		return "STOP SITE RECHECKS" if selected.source_knowledge_id in _status.exploration.get("priorities", []) else "PRIORITIZE SITE RECHECKS"
	if not _status.has("exploration"):
		return "SEND SCOUT TO RECHECK"
	var route: Dictionary = _selected_route(selected)
	if route.get("resume_on_report", false):
		return "STOP RECOVERY WATCH"
	if route.get("status", "") == "depleted":
		return "WATCH AND RESUME GATHERING"
	return "STOP PRIORITY RECHECKS" if selected.source_knowledge_id in _status.exploration.get("priorities", []) else "PRIORITIZE SOURCE RECHECKS"


func _recheck_title(route: Dictionary) -> String:
	return "RESUME GATHERING" if route.get("recovery_ready", false) else "TRY GATHERING"


func _scent_label(route: Dictionary) -> String:
	var strength: float = float(route.get("pheromone_strength", 0.0))
	return "strong" if strength >= 0.7 else "clear" if strength >= 0.45 else "faint" if strength >= 0.1 else "remembered" if float(route.get("route_familiarity", 0.0)) >= 0.1 else "absent"


func _selected_mission() -> Dictionary:
	for mission: Dictionary in _status.get("scout_missions", []):
		if selected_id == "mission:" + mission.id:
			return mission
	return {}


func _draw_mission_context(mission: Dictionary, size: Vector2) -> void:
	var box: Rect2 = _context_panel_rect()
	UIStyle.surface(self, box, Color("111921"))
	UIStyle.surface(self, box, Color("41535a"), true)
	_label(box.position + Vector2(16, 31), "Scout " + str(mission.id).trim_prefix("scout_"), Color("d9d3be"), 20)
	_label(box.position + Vector2(16, 65), "Dispatched %.0f° · %s ago" % [rad_to_deg(mission.bearing), _mission_duration(mission.age)], Color("a9b9bc"), 14)
	var state: String = "Not returned · cause unknown" if mission.get("missing_at", -1.0) >= 0.0 else "Overdue · still awaiting return" if mission.get("overdue", false) else "Awaiting return · away " + _mission_duration(mission.away_seconds) if mission.returned_at < 0.0 else "Returned · journey " + _mission_duration(mission.away_seconds)
	_label(box.position + Vector2(16, 91), state, Color("c7b196") if mission.get("missing_at", -1.0) >= 0.0 else Color("a9b9bc"), 14)
	_label(box.position + Vector2(16, 125), "Departure scent faint" if mission.scent >= 0.1 else "Scent faded · departure remembered", Color("8fa1a8"), 13)
	_label(box.position + Vector2(16, 151), "Course unknown until a report returns" if mission.returned_at < 0.0 else "Coarse remembered course from return", Color("8fa1a8"), 13)
	_label(box.position + Vector2(16, 187), "Tap a grouped trace again to cycle scouts", Color("82939c"), 12)
	if mission.get("awaiting", mission.returned_at < 0.0):
		var recall_box: Rect2 = _scout_recall_rect()
		UIStyle.surface(self, recall_box, Color("293b3b"))
		_label(recall_box.position + Vector2(recall_box.size.x * 0.5, 29), "RECALL SCOUT", Color("d3dcd4"), 14, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_label(box.position + Vector2(16, 239), "Send another scout toward a new direction" if _daughter() else "Change exploration effort or direction", Color("8fa1a8"), 13)


func _scout_recall_rect() -> Rect2:
	return Rect2(_context_panel_rect().position + Vector2(16, 210), Vector2(260, 44))


static func _mission_duration(seconds: float) -> String:
	return "%dm %02ds" % [int(seconds) / 60, int(seconds) % 60]


func _selected_signal() -> Dictionary:
	for signal_data: Dictionary in _signals:
		if signal_data.id == selected_id:
			return signal_data
	return {}


func _selected_route(signal_data: Dictionary) -> Dictionary:
	if signal_data.is_empty():
		return {}
	for route: Dictionary in _status.get("trails", []):
		if route.destination_knowledge_id == signal_data.source_knowledge_id:
			return route
	return {}


func _reported_empty(signal_data: Dictionary) -> bool:
	if signal_data.get("category") == "threat": return false
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
	y += _evidence_offset()
	match command:
		"trail_create": return Rect2(x, y, 260, 44)
		"trail_recheck": return Rect2(x, y, 136, 44)
		"trail_less": return Rect2(x, y, 64, 44)
		"trail_more": return Rect2(x + 72, y, 64, 44)
		"trail_cancel": return Rect2(x + 144, y, 116, 44)
	return Rect2()


func _investigate_button_rect() -> Rect2:
	if _selected_signal().get("category")=="nest_site": return Rect2(get_viewport_rect().size.x-300,488,260,44)
	return Rect2(get_viewport_rect().size.x - 300.0, (444.0 if _is_honeydew(_selected_signal()) else 438.0) + _evidence_offset(), 260.0, 44.0)


func _honeydew_button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 350.0 + _evidence_offset(), 260.0, 44.0)


func _evidence_offset() -> float:
	return 48.0 if _selected_route(_selected_signal()).get("reported_losses", 0) > 0 else 0.0


func _signal_title_for(signal_data: Dictionary) -> String:
	if signal_data.category == "threat": return _threat_caption(signal_data)
	return "Honeydew trace" if _is_honeydew(signal_data) else _signal_title(signal_data.category)


func _draw_trail_button(command: String, title: String) -> void:
	var box: Rect2 = _trail_button_rect(command)
	var detail: String = ""
	if command == "trail_cancel": title = "RECALL"; detail = "gatherers"
	elif command == "trail_less": title = "−1"; detail = "gatherer"
	elif command == "trail_more":
		var contested: bool = _selected_route(_selected_signal()).get("foreign_reports", 0) >= SWARM_CONFIG.reports_to_escalate
		title = "+4" if contested else "+1"
		detail = "contest" if contested else "gatherer"
	elif command == "trail_create": detail = Copy.local_shortage(_status, {}, 5)
	UIStyle.surface(self, box, Color("263b3c"))
	_label(box.position + Vector2(box.size.x * 0.5, 29 if detail.is_empty() else 17), title, Color("d5ded8"), 14, HORIZONTAL_ALIGNMENT_CENTER)
	if not detail.is_empty(): _label(box.position + Vector2(box.size.x * 0.5, 36), detail, Color("a8b8bd"), 13 if command == "trail_create" else 12, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_controls(size: Vector2) -> void:
	for command: String in ["scout", "pause", "speed_1", "speed_4", "speed_16", "speed_64", "inward", "save", "load", "sources"]:
		var box: Rect2 = _button_rect(command)
		var active: bool = command.begins_with("speed_") and not _status.is_empty() and int(command.trim_prefix("speed_")) == _status.time_scale
		var unavailable: bool = command == "scout" and not exploration_command.is_valid() and not _status.is_empty() and (_status.available_workers < 1 or _status.active_scouts >= _status.scout_cap)
		var color: Color = Color("28342f") if command == "scout" else Color("18252b")
		if active:
			color = Color("31505a")
		if unavailable:
			color = Color("202326")
		UIStyle.surface(self, box, color)
		var title: String = "REMEMBERED SOURCES" if command == "sources" else "SEND SCOUT" if command == "scout" else "INWARD" if command == "inward" else "SAVE" if command == "save" else "LOAD" if command == "load" else "RESUME" if command == "pause" and _status.get("paused", false) else "PAUSE" if command == "pause" else command.trim_prefix("speed_") + "x"
		if command == "scout" and exploration_command.is_valid():
			title = "EXPLORATION"
		_label(box.position + Vector2(box.size.x * 0.5, 29 if command == "sources" else 40), title, Color("d3dcd4") if not unavailable else Color("78817e"), 14 if command in ["save", "load", "sources"] else 16, HORIZONTAL_ALIGNMENT_CENTER)
	if not _feedback.is_empty() and (Time.get_ticks_msec() < _feedback_until or _request_rejected and _request_selection == selected_id):
		_label(Vector2(24, size.y - 17), _feedback, Color("b6c8b2"), 13)
	else:
		_label(Vector2(24, size.y - 17), "Space: pause  ·  1–4: time", Color("7e8e94"), 13)


func _signal_color(category: String) -> Color:
	return Art.color_for(category)


func _source_entries() -> Array[Dictionary]:
	return Memories.entries(_signals, _status, source_category)


func _source_filter_rect(category: String) -> Rect2:
	return Rect2(40 + MEMORY_CATEGORIES.find(category) * 76, 190, 72, 44)


func _source_row_rect(index: int) -> Rect2:
	return Rect2(40, 244 + index * 94, 300, 88)


func _source_page_rect() -> Rect2:
	return Rect2(40, 536, 300, 44)


func _draw_sources() -> void:
	UIStyle.surface(self, _sources_panel_rect(), Color("111921"))
	_label(Vector2(40, 177), "Remembered sources", Color("d3dcd4"), 20)
	for category: String in MEMORY_CATEGORIES:
		var button: Rect2 = _source_filter_rect(category)
		UIStyle.surface(self, button, Color("31505a") if category == source_category else Color("18252b"))
		_label(button.get_center() + Vector2(0, 6), "CARBS" if category == "carbohydrate" else "SITES" if category == "nest_site" else category.to_upper(), Art.color_for(category), 13, HORIZONTAL_ALIGNMENT_CENTER)
	var entries: Array[Dictionary] = _source_entries()
	source_page = mini(source_page, maxi(0, ceili(entries.size() / 3.0) - 1))
	for index: int in 3:
		var offset: int = source_page * 3 + index
		if offset >= entries.size():
			break
		var entry: Dictionary = entries[offset]
		var box: Rect2 = _source_row_rect(index)
		UIStyle.surface(self, box, Color("30382f") if entry.id == selected_id else Color("182329"))
		var title: String = Memories.display_name(entry)
		_label(box.position + Vector2(10, 20), "%s · %s ago" % [title, Copy.duration(entry.age)], Color("d4c6a8"), 14)
		_label(box.position + Vector2(10, 42), entry.state if entry.category == "nest_site" else "%s · %d gathering%s" % [entry.state, entry.workers, " · ALARM" if entry.danger else ""], Color("c48c7c") if entry.danger else Color("96aab0"), 14)
		_label(box.position + Vector2(10, 61), Memories.receipt_label(entry, _status.get("time", 0.0), "here" if _daughter() else "home"), Color("96aab0"), 14)
		_label(box.position + Vector2(10, 80), Memories.first_receipt_label(entry, _status.get("time", 0.0)), Color("96aab0"), 14)
	if entries.is_empty():
		_label(Vector2(40, 275), "No returned memory of a nest site" if source_category == "nest_site" else "No returned memory of this resource", Color("96aab0"), 14)
	UIStyle.surface(self, _source_page_rect(), Color("18252b"))
	_label(_source_page_rect().get_center() + Vector2(0, 6), "NEXT PAGE · %d / %d" % [source_page + 1, maxi(1, ceili(entries.size() / 3.0))], Color("d3dcd4"), 13, HORIZONTAL_ALIGNMENT_CENTER)


func _exploration_rect(command: String) -> Rect2:
	var index: int = ["explore_0", "explore_2", "explore_5", "explore_8"].find(command)
	if index >= 0:
		return Rect2(40 + index * 70, 220, 64, 44)
	return Rect2(40, 280 if command == "exploration_bias" else 330, 274, 44)


func _draw_exploration() -> void:
	UIStyle.surface(self, _exploration_panel_rect(), Color("111921"))
	var policy: Dictionary = _status.get("exploration", {"target": 0, "away": 0, "bias": null})
	_label(Vector2(40, 177), "Exploration labor", Color("d3dcd4"), 20)
	_label(Vector2(40, 203), "Target %d scouts · %d currently away" % [policy.target, policy.away], Color("a8b9b6"), 14)
	for target: int in [0, 2, 5, 8]:
		var box: Rect2 = _exploration_rect("explore_%d" % target)
		UIStyle.surface(self, box, Color("202326") if target + policy.get("other_target",0) > _status.get("scout_cap",8) else Color("31505a") if target == policy.target else Color("18252b"))
		_label(box.position + Vector2(32,29), "OFF" if target == 0 else str(target), Color("d3dcd4"), 15, HORIZONTAL_ALIGNMENT_CENTER)
	for command: String in ["exploration_bias", "exploration_general"]:
		var box: Rect2 = _exploration_rect(command)
		UIStyle.surface(self, box, Color("283b3f"))
		var title: String = "FAVOR THIS DIRECTION" if command == "exploration_bias" else "NO DIRECTIONAL BIAS" if policy.bias == null else "CLEAR DIRECTION · %03d°" % roundi(rad_to_deg(policy.bias))
		_label(box.position + Vector2(137,29), title, Color("d3dcd4"), 13, HORIZONTAL_ALIGNMENT_CENTER)
	_label(Vector2(40, 395), "%d source priorities share scout effort" % policy.get("priorities", []).size(), Color("a8b9b6"), 14)
	_label(Vector2(40, 416), "Shared cap %d · other pile effort %d" % [_status.get("scout_cap",8),policy.get("other_target",0)], Color("a8b9b6"), 14)
	_label(Vector2(40, 437), "Not returned: %d · cause unknown" % policy.missing if policy.get("missing", 0) > 0 else "Turning only changes your attention", Color("a8b9b6"), 14)
	if policy.get("cautious_routes", 0) > 0:
		_label(Vector2(40, 459), "General scouts favor safer ground", Color("c7b196"), 14)

func _signal_title(category: String) -> String:
	match category:
		"carbohydrate": return "Carbs trace"
		"protein": return "Protein trace"
		"water": return "Water trace"
		"nest_site": return "Shelter trace"
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


func _daughter() -> bool:
	return _status.get("pile_id","home") != "home"


func _journey_attention() -> bool:
	return journey_open or _selected_signal().get("category") == "threat"

func _journey_rect(command: String) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300,548 if command in ["journey_open","journey_close"] else 494 if command in ["journey_defend","journey_reinforce"] else 446,260,44)

func _draw_journey_link() -> void:
	if _selected_route(_selected_signal()).get("reported_losses",0) <= 0: return
	var box: Rect2 = _journey_rect("journey_open")
	UIStyle.surface(self, box,Color("39302b"))
	_label(box.get_center() + Vector2(0,5),"JOURNEY REPORTS AND RESPONSE",Color("e0c5b7"),13,HORIZONTAL_ALIGNMENT_CENTER)

func _draw_journey_context(_size: Vector2) -> void:
	var box: Rect2 = _context_panel_rect()
	UIStyle.surface(self, box, Color("17171b")); UIStyle.surface(self, box, Color("665047"), true)
	var route: Dictionary = _selected_route(_selected_signal())
	var state: Dictionary = _status.get("journey_response", {})
	var report: Dictionary = state.get("reports", {}).get(route.get("id"), {})
	var outcome: Dictionary = state.get("outcomes", {}).get(route.get("id"), {})
	var own_party: bool = state.get("away", false) and state.get("route_id", "") == route.get("id")
	_detail_journey(box, 31, "Journey response", 20)
	_detail_journey(box, 62, "LAST DEFENSIVE RETURN", 12)
	_detail_journey(box, 85, Memories.defense_label(outcome), 14)
	if not outcome.is_empty():
		_detail_journey(box, 107, "%d returned / %d sent · %s ago" % [outcome.sent - outcome.lost, outcome.sent, Copy.duration(_status.time - outcome.received_at)])
	var pressure: Dictionary = state.get("pressure_reports", {}).get(route.get("id"), {})
	if own_party and not pressure.is_empty():
		_detail_journey(box, 125, "RETURNED PRESSURE · SNAPSHOT", 12)
		_detail_journey(box, 145, "Holding against resistance" if pressure.pressure == "holding" else "Resistance remains strong")
		_detail_journey(box, 165, "Observed %s ago · arrived %s ago" % [Copy.duration(_status.time-pressure.observed_at),Copy.duration(_status.time-pressure.received_at)], 12)
	else:
		_detail_journey(box, 125, "SURVEY HISTORY", 12)
		var finding: String = report.get("finding", "")
		var labels: Dictionary = {"ambush":"Ambusher trace along journey", "foreign":"Foreign traffic along journey", "mixed":"Ambusher + foreign traffic", "inconclusive":"No clear danger found"}
		_detail_journey(box, 145, labels.get(finding, "Cause remains uncertain"))
		if not report.is_empty(): _detail_journey(box, 165, "Reported " + Copy.duration(_status.time - report.received_at) + " ago")
	_detail_journey(box, 191, "HARVEST HISTORY", 12)
	var witnesses: Array[String] = LossEvidence.lines(route, _status.get("time", 0.0))
	_detail_journey(box, 211, witnesses[0] if not witnesses.is_empty() else "No harvest losses reported", 12)
	_detail_journey(box, 233, "%d losses · report %s ago" % [route.get("reported_losses", 0), Copy.duration(_status.time - route.get("last_loss_time", 0))])
	_detail_journey(box, 257, "%d %s assigned · away %s" % [state.workers, "defenders" if state.get("mode") == "defend" else "survey workers", Copy.duration(state.age)] if own_party else "%s carbs: %.1f · %d available" % [_status.get("pile_name","Home"),_status.get("resources", {}).get("carbohydrate", 0), _status.get("available_workers", 0)], 12)
	_detail_journey(box, 279, state.other_party + " party away · one at a time" if state.get("other_party","") != "" else "Messenger returned · still assigned" if own_party and pressure.get("observed_at",0) >= _status.time-state.age else "Reports arrive with returning ants", 12)
	var action: Rect2 = _journey_rect("journey_investigate")
	_draw_journey_action(action, ("RECALL DEFENDERS" if state.get("mode") == "defend" else "RECALL SURVEY PARTY") if own_party else "SURVEY JOURNEY FOR DANGER", "Workers return through travel" if own_party else _party_requirement(3))
	if own_party and state.get("reinforcement_available", false) or not own_party and _can_mobilize(route):
		_draw_journey_action(_journey_rect("journey_defend"), "REQUEST 4 DEFENDERS" if own_party else "SEND 12 DEFENDERS", _party_requirement(4 if own_party else 12))
	if own_party and state.get("reinforcement_pending", false):
		_draw_journey_action(_journey_rect("journey_defend"), "REINFORCEMENTS ALREADY SENT", "Await returning messenger confirmation")
	var back: Rect2 = _journey_rect("journey_close")
	UIStyle.surface(self, back, Color("263038"))
	_label(back.get_center() + Vector2(0, 5), "BACK TO SOURCE", Color("d5ded8"), 13, HORIZONTAL_ALIGNMENT_CENTER)


func _party_requirement(workers: int) -> String:
	var shortage: String = Copy.local_shortage(_status, {}, workers)
	return shortage if not shortage.is_empty() else "%d workers + travel carbs on dispatch" % workers


func _draw_journey_action(box: Rect2, title: String, detail: String) -> void:
	UIStyle.surface(self, box, Color("39302b"))
	_label(box.position + Vector2(130, 17), title, Color("e0c5b7"), 14, HORIZONTAL_ALIGNMENT_CENTER)
	_label(box.position + Vector2(130, 36), detail, Color("c5b8b1"), 13, HORIZONTAL_ALIGNMENT_CENTER)

func _detail_journey(box: Rect2, y: float, text: String, font_size: int = 14) -> void:
	_label(box.position + Vector2(16,y),text,Color("c5b8b1"),font_size)

func _threat_caption(signal_data: Dictionary) -> String:
	var route: Dictionary = _selected_route(signal_data)
	var record: Dictionary = _status.get("journey_response",{}).get("outcomes",{}).get(route.get("id"),{})
	return "Ambush memory" if record.get("outcome","") == "secured" else "Ambush trace"

func _can_mobilize(route: Dictionary) -> bool:
	var state: Dictionary = _status.get("journey_response",{})
	return state.get("reports",{}).get(route.get("id"),{}).get("finding","") in ["ambush","mixed"] and state.get("outcomes",{}).get(route.get("id"),{}).get("outcome","") != "secured"
