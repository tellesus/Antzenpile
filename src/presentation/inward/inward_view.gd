class_name InwardView
extends Node2D
## Abstract functional network; consumes detached pile summaries only.

const Copy = preload("res://src/presentation/interface_text.gd")
const UIStyle = preload("res://src/presentation/organic_ui.gd")
const Art = preload("res://src/presentation/sensory_art.gd")
const Web = preload("res://src/presentation/inward/adaptation_web.gd")
const Contents = preload("res://src/presentation/inward/chamber_contents.gd")
const Chambers = preload("res://src/presentation/inward/chamber_art.gd")
const Activity = preload("res://src/presentation/inward/colony_activity.gd")
const TISSUE = preload("res://assets/graphics/colony/material/bridge.png")
const SUBSTRATE = preload("res://assets/graphics/colony/material/substrate.png")
const Pressure = preload("res://src/presentation/colony_pressure.gd")
const NODES: Array[String] = ["queen", "nursery", "food_exchange", "entrance", "adaptation"]
var status_provider: Callable
var pile_command: Callable
var pressure_command: Callable
var supply_command: Callable
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
var reproduction_command: Callable
var queen_tab: String = "workers"
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
	if selected_id=="entrance" and not _status.get("supply",{}).is_empty() and _supply_rect().has_point(at):
		if supply_command.is_valid():
			var enable: bool=not _status.supply.enabled
			var result: Dictionary=supply_command.call(enable)
			show_feedback(("Supply workers assigned" if enable else "Stop after current trip requested" if _status.supply.status=="away" else "Idle supply workers released") if result.get("accepted",false) else result.get("reason","Supply unavailable"))
		return true
	if selected_id=="food_exchange" and _status.get("daughter",false) and not Pressure.food_sources_needed(_status).is_empty() and _supply_link_rect().has_point(at):
		selected_id="entrance"; queue_redraw(); return true
	if _status.get("daughter_available",false) and _pile_rect().has_point(at):
		var target: String = "home" if _status.get("daughter",false) else "satellite_1"
		if not _status.get("other_pile_attention", {}).is_empty() and pressure_command.is_valid():
			var result: Dictionary = pressure_command.call(target)
			if not result.get("accepted",false): show_feedback(result.get("reason", "Internal attention unavailable"))
		elif pile_command.is_valid(): pile_command.call(target)
		return true
	if selected_id == "queen":
		for tab: String in (["workers"] if _status.get("daughter",false) else ["workers","reproduction"]):
			if _queen_tab_rect(tab).has_point(at):
				queen_tab=tab; queue_redraw(); return true
		if queen_tab=="reproduction":
			if _reproduction_rect().has_point(at) and _status.get("reproduction",{}).get("phase","none")=="none":
				if reproduction_command.is_valid():
					var result: Dictionary = reproduction_command.call()
					show_feedback("Reproductive brood laid · keep food available" if result.get("accepted",false) else Copy.reason(result.get("reason","Reproduction unavailable")))
				return true
			if Rect2(get_viewport_rect().size.x-316,144,292,388).has_point(at): return true
		for intent: String in ["manual", "grow"]:
			if _brood_intent_rect(intent).has_point(at):
				if brood_intent_command.is_valid():
					var result: Dictionary = brood_intent_command.call(intent)
					show_feedback(("Growth intent set" if intent == "grow" else "Manual laying selected") if result.get("accepted", false) else result.get("reason", "Intent unavailable"))
				return true
	if selected_id == "food_exchange":
		for resource_id: String in ([] if _status.get("daughter",false) else Pressure.food_sources_needed(_status)):
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
			_run_command("cancel_adaptation" if _queued_trait() == web_selection else "adaptation_" + web_selection)
			return true
	if selected_id == "adaptation" and web_selection == "foraging" and not _queued_trait().is_empty() and _adaptation_rect("").has_point(at):
		_run_command("cancel_adaptation")
		return true
	if (selected_id == "nursery" or selected_id == "queen" and queen_tab=="workers") and _brood_rect().has_point(at):
		if _can_lay_brood(): _run_command("lay_brood")
		else: show_feedback(_brood_block_reason())
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
	var picked: String = node_at(at, get_viewport_rect().size, not guest.is_empty(), _status.get("midden", {}).get("revealed", false), Chambers.lobe_gain(_status) > 0.0, _status.get("daughter",false))
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
				show_feedback(("Tending started" if tending else "Tending withdrawn") if result.get("accepted", false) else Copy.reason(result.get("reason", "Relationship unavailable")))
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
		"adaptation_lean", "adaptation_load", "adaptation_persistent", "adaptation_security", "adaptation_tolerance", "cancel_adaptation":
			if adaptation_command.is_valid():
				var result: Dictionary = adaptation_command.call("" if command == "cancel_adaptation" else command.trim_prefix("adaptation_"))
				_feedback = ("Queued adaptation cleared" if command == "cancel_adaptation" else "Next brood choice saved · changeable until laid") if result.get("accepted", false) else result.get("reason", "Adaptation unavailable")
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
	var origin := Vector2(24.0, 94.0)
	return {"queen": origin + Vector2(field_width * 0.48, field_height * 0.24),
		"nursery": origin + Vector2(field_width * 0.21, field_height * 0.45),
		"food_exchange": origin + Vector2(field_width * 0.78, field_height * 0.58),
		"entrance": origin + Vector2(field_width * 0.42, field_height * 0.79),
		"adaptation": origin + Vector2(field_width * 0.77, field_height * 0.27),
		"guest": origin + Vector2(field_width * 0.75, field_height * 0.83),
		"midden": origin + Vector2(field_width * 0.11, field_height * 0.76)}


static func node_at(at: Vector2, size: Vector2, guest_visible: bool = false, midden_visible: bool = false, nursery_lobe_visible: bool = false, daughter: bool = false) -> String:
	if nursery_lobe_visible and _organ_hit(at, positions(size).nursery + Chambers.lobe_offset(), Vector2(64,48)):
		return "nursery"
	if midden_visible and _organ_hit(at, positions(size).midden, Vector2(66,54)):
		return "midden"
	if guest_visible and _organ_hit(at, positions(size).guest, Vector2(66,54)):
		return "guest"
	for id: String in NODES:
		if daughter and id=="adaptation": continue
		if _organ_hit(at, positions(size)[id], Chambers.hit_radii(id)):
			return id
	return ""


static func _organ_hit(at: Vector2, center: Vector2, radii: Vector2) -> bool:
	return ((at-center)/radii).length_squared() <= 1.0


func _supply_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x-300,430,260,44)


func _supply_link_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x-300,470,260,44)


func _pile_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x-316, get_viewport_rect().size.y-104,292,64)


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


func _queen_tab_rect(tab: String) -> Rect2:
	return Rect2(get_viewport_rect().size.x-300+(132 if tab=="reproduction" else 0),190,128,44)


func _reproduction_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x-300,466,260,44)


func _brood_intent_rect(intent: String) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0 + (132 if intent == "grow" else 0), 352, 128, 44)


func _humidity_rect(target: int) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0 + [0, 1, 2, 4].find(target) * 66.0, 384, 62, 44)


func _nursery_develop_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 494.0, 260.0, 44.0)


func _nursery_expand_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0, 550.0, 260.0, 44.0)


func _food_source_rect(resource_id: String) -> Rect2:
	return Rect2(get_viewport_rect().size.x - 300.0 + ["carbohydrate", "protein", "water"].find(resource_id) * 88, 550 if _status.get("food_sharing",{}).get("recent",false) and _status.get("food_exchange_state", "") != "developed" else 470, 84, 44)


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


func _queued_trait() -> String:
	return _status.get("adaptation_queue", {}).get("trait_id", "")


func _can_lay_brood() -> bool:
	if not _queued_trait().is_empty(): return _status.get("adaptation_queue", {}).get("waiting", "") == "ready"
	return _status.get("queens", 0) > 0 and _status.get("brood", []).size() < _status.get("nursery_brood_capacity", 0) / maxi(1, _status.get("brood_batch_count", 8)) and _status.get("nursery_brood_capacity", 0) - _status.get("nursery_occupied_space", 0) >= _status.get("brood_batch_count", 0) and (_status.get("brood", []).is_empty() or _status.get("nursery_state", "") == "developed")


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if selected_id == "adaptation":
		Web.draw_graph(self, size, _status, web_selection, _animation_time, web_family)
		UIStyle.surface(self, _web_back_rect(), Color("18252b"))
		_label(_web_back_rect().position + Vector2(98, 29), "COLONY NETWORK", Color("d3dcd4"), 14, HORIZONTAL_ALIGNMENT_CENTER)
		if _status.get("adaptation_options", {}).has("security"):
			UIStyle.surface(self, _web_family_rect(), Color("28212f"))
			_label(_web_family_rect().position + Vector2(110, 29), "OTHER TRAITS" if web_family == "recognition" else "INSPECT RECOGNITION", Color("d3c5df"), 14, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_hud(size)
		_draw_context(size)
		_draw_controls(size)
		return
	var centers: Dictionary = positions(size)
	# One dark continuous material field, with no baked organs or inhabitants.
	var field := Rect2(Vector2(12,110),Vector2(minf(size.x*0.68,size.x-324.0),size.y-212.0))
	draw_texture_rect(SUBSTRATE,field,false,Color(1,1,1,0.80))
	for pair: Array in [["queen", "nursery"], ["nursery", "food_exchange"], ["food_exchange", "entrance"], ["entrance", "queen"]]:
		_draw_flow(centers[pair[0]], centers[pair[1]], pair[0] == "nursery" or pair[0] == "entrance")
	for id: String in ([] if _status.get("daughter",false) else ["queen", "nursery"]):
		_draw_flow(centers[id], centers["adaptation"], false, Color("b79bcc"))
	if _status.get("midden", {}).get("revealed", false):
		_draw_flow(centers.entrance, centers.midden, false)
	if not _status.get("guest", {}).is_empty():
		_draw_flow(centers.guest, centers.nursery, false, Color("b79bcc"))

	var visible_ids: Array[String] = NODES.duplicate()
	if _status.get("daughter",false): visible_ids.erase("adaptation")
	if _status.get("midden", {}).get("revealed", false): visible_ids.append("midden")
	if not _status.get("guest", {}).is_empty(): visible_ids.append("guest")
	for id: String in visible_ids:
		Chambers.rear(self,_status,id,centers[id],float(_focus_gains.get(id,0.0)))
	for id: String in visible_ids:
		_draw_node(id,centers[id])
	_draw_activity(centers)
	# Live contents and ants share depth: lips occlude them before text/UI.
	for id: String in visible_ids:
		Chambers.front(self,_status,id,centers[id],float(_focus_gains.get(id,0.0)))
	for id: String in visible_ids:
		_draw_node_labels(id,centers[id])
	_draw_hud(size)
	_draw_context(size)
	_draw_controls(size)


func _draw_flow(start: Vector2, finish: Vector2, representative: bool, tint: Color = Color("dcb477")) -> void:
	var control: Vector2 = (start + finish) * 0.5 + Vector2(12, -18)
	var points := PackedVector2Array()
	for step: int in 25:
		var t: float = float(step) / 24.0
		points.append(start * (1.0 - t) * (1.0 - t) + control * 2.0 * (1.0 - t) * t + finish * t * t)
	# Substantial baked earthen/resin tissue, with flared joins under the organs.
	var edges := PackedVector2Array()
	var uv := PackedVector2Array()
	for side: int in [1,-1]:
		for offset: int in points.size():
			var index: int = offset if side == 1 else points.size()-1-offset
			var t: float = float(index)/(points.size()-1)
			var tangent: Vector2 = points[mini(index+1,points.size()-1)]-points[maxi(0,index-1)]
			var width: float = 68.0+34.0*pow(absf(t*2.0-1.0),2.0)
			edges.append(points[index]+tangent.normalized().orthogonal()*width*0.5*side)
			uv.append(Vector2(t,0.0 if side == 1 else 1.0))
	var tissue_tint: Color = Color(0.86,0.88,0.95) if representative else Color.WHITE.lerp(tint,0.22)
	draw_polygon(edges,PackedColorArray([tissue_tint]),uv,TISSUE)


func _draw_activity(centers: Dictionary) -> void:
	for ant: Dictionary in Activity.representatives(_status, centers, _animation_time):
		var under_label: bool = false
		for id: String in centers:
			var center: Vector2 = centers[id]
			under_label = under_label or Rect2(Chambers.label_position(id,center)+Vector2(-90,-17), Vector2(180, 42)).grow(20.0).has_point(ant.position)
		if under_label:
			continue
		Art.ant(self, ant.position, ant.direction, Color(ant.color, 0.62), _animation_time, 1.25, true)
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
	Chambers.shell(self, _status, id, at, focus)
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
			var stages: Array[String] = Activity.brood_stages(_status)
			for index: int in stages.size():
				var seed_at: Vector2 = at + Vector2(index % 3 * 25 - 25, index / 3 * 26 + 16)
				Contents.brood(self, seed_at, stages[index], health*attention)
		"adaptation":
			for index: int in 3:
				var seed_at: Vector2 = at + Vector2.from_angle(index * TAU / 3.0 + 0.3) * 13
				draw_line(at, seed_at, Color(color, 0.4), 1.0, true)
				draw_circle(seed_at, 3.2, Color(color, 0.64))
		"food_exchange":
			var stores: Dictionary = _status.get("resources", {})
			for resource: int in 3:
				var key: String = ["carbohydrate","protein","water"][resource]
				var amount: float = float(stores.get(key,0.0))
				for index: int in 3:
					if amount >= [0.001,4.0,12.0][index]:
						Contents.brood(self, at+Vector2(resource*25-25,index*17+5), "egg",attention,Art.color_for(key))
		"entrance":
			draw_arc(at+Vector2(0,8),20,PI,TAU,24,Color("b0d9df",0.55),1.0,true)
		"queen":
			if _status.get("queens",0) > 0: Contents.queen(self, at+Vector2(0,22),_animation_time)
			var reproductive: Dictionary = _status.get("reproduction",{})
			if reproductive.get("phase","none") in ["egg","larva","pupa"]:
				for index: int in 3:
					Contents.brood(self,at+Vector2(54+index*17-17,-49),reproductive.phase,1.0 if reproductive.get("food_shortfalls",[]).is_empty() else 0.5,Color("d9c9a7"))
			elif reproductive.get("phase")=="ready":
				Contents.queen(self,at+Vector2(54,-49),_animation_time,0.52)
	if id == "nursery" and _status.get("guest", {}).get("observation", "") == "foreign":
		draw_arc(at, 39.0, 0.3, 1.9, 20, Color("b79eaf"), 1.0, true)


func _draw_node_labels(id: String, at: Vector2) -> void:
	var color: Color = Color("d5c4a1") if id == "queen" else Color("aebdb7") if id == "nursery" else Color("c7af86") if id == "food_exchange" else Color("bba6c8") if id == "adaptation" else Color("bd927a") if id == "midden" else Color("8daeb3")
	var phase: float = _animation_time*0.18+NODES.find(id)
	var label_at: Vector2 = Chambers.label_position(id,at)
	_label(label_at, _title(id), color, 16, HORIZONTAL_ALIGNMENT_CENTER)
	var pressure: String = Activity.pressure(_status, id)
	var progress: float = Activity.project_progress(_status, id)
	if progress >= 0.0:
		draw_arc(at, 65, -PI * 0.5, -PI * 0.5 + TAU * maxf(progress, 0.005), 32, Color("c3b991"), 1.3, true)
	if not pressure.is_empty():
		draw_polyline(Art.membrane(at, 38, -phase).slice(2, 12), Color("cc967a", 0.65), 1.2, true)
		_label(label_at+Vector2(0,19), pressure, Color("ccac91"), 11, HORIZONTAL_ALIGNMENT_CENTER)
	elif progress >= 0.0:
		var project_title: String = "EXPANDING" if id == "nursery" and _status.get("nursery_expansion", {}).get("state", "") == "developing" else "DEVELOPING"
		_label(label_at+Vector2(0,19), project_title, Color("b0ab8b"), 11, HORIZONTAL_ALIGNMENT_CENTER)
	elif id == "nursery" and _status.get("nursery_expansion", {}).get("state", "") == "available":
		_label(label_at+Vector2(0,19), "EXPANSION AVAILABLE", Color("a5b49a"), 11, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_hud(size: Vector2) -> void:
	_label(Vector2(24, 38), "INWARD  /  ADAPTATION WEB" if selected_id == "adaptation" else "INWARD  /  DAUGHTER" if _status.get("daughter",false) else "INWARD  /  HOME", Color("dad7c8"), 22)
	var web_hint: String = "Next brood: %s · change until eggs are laid" % Web.short_title(_queued_trait()) if not _queued_trait().is_empty() else "Inspect a trait, then queue it for the next brood."
	_label(Vector2(24, 63), web_hint if selected_id == "adaptation" else "Local workers and stores · Home exploration shared" if _status.get("daughter",false) else "Tap a function to inspect it.", Color("82939c"), 13)
	if not _status.is_empty():
		var stores: Dictionary = _status.get("resources", {})
		_label(Vector2(24, 96), "STORES   Carbs %.1f   ·   Protein %.1f   ·   Water %.1f" % [stores.get("carbohydrate", 0.0), stores.get("protein", 0.0), stores.get("water", 0.0)], Color("a9b9bc"), 13)
		_label(Vector2(size.x - 24, 36), "%d available" % _status.workers_available, Color("c9d1c5"), 15, HORIZONTAL_ALIGNMENT_RIGHT)
		var pause_word: String = "PAUSED" if _status.paused else "%dx" % _status.time_scale
		_label(Vector2(size.x - 24, 61), "%s  ·  %s" % [pause_word, Copy.duration(_status.time)], Color("83969d"), 13, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_context(size: Vector2) -> void:
	if selected_id.is_empty() or _status.is_empty():
		return
	var expansion: Dictionary = _status.get("nursery_expansion", {})
	var expansion_action: bool = expansion.get("state", "") == "available"
	var food_attention: bool = selected_id == "food_exchange" and not Pressure.food_sources_needed(_status).is_empty()
	var food_losses: Dictionary = _status.get("food_sharing",{})
	var recent_food_losses: bool = food_losses.get("recent",false)
	var box := Rect2(Vector2(size.x - 316, 144), Vector2(292, (466 if expansion_action else 400) if selected_id == "nursery" else 466 if selected_id == "food_exchange" and recent_food_losses and _status.food_exchange_state != "developed" else 388 if food_attention or selected_id == "queen" or selected_id=="entrance" and not _status.get("supply",{}).is_empty() else 344 if selected_id == "adaptation" else 340 if selected_id == "midden" else 284))
	var web: bool = selected_id == "adaptation"
	UIStyle.surface(self, box, Color("17141f") if web else Color("111921"))
	UIStyle.surface(self, box, Color("786683") if web else Color("41535a"), true)
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
			_detail_line(box, 113, "Brood recovering · keep cleaning" if _status.get("brood_health", {}).get("condition", "stable") == "recovering" else "Unhealthy brood · isolate refuse" if _status.get("brood_health", {}).get("condition", "stable") != "stable" else "Larval growth: %.0f%%" % (midden.get("larval_rate", 1.0) * 100.0))
			_detail_line(box, 137, "Cleanup workers: %d" % midden.get("cleaners", 0))
			for target: int in [0, 1, 2, 5]:
				var button: Rect2 = _cleaner_rect(target)
				UIStyle.surface(self, button, Color("4b5141") if target == midden.get("cleaners", 0) else Color("263038"))
				_label(button.get_center() + Vector2(0, 6), str(target), Color("dce5d9"), 16, HORIZONTAL_ALIGNMENT_CENTER)
			if midden.get("state") == "primitive":
				_detail_line(box, 218, "Develop for twice the cleanup")
				_detail_line(box, 244, "Needs %.0f carbs · %.0f protein" % [midden.costs.carbohydrate, midden.costs.protein])
				_detail_line(box, 266, "%.0f water · %d workers · %.0fs" % [midden.costs.water, midden.build_workers, midden.build_seconds])
				_draw_action(_midden_develop_rect(), "DEVELOP MIDDEN", Copy.local_shortage(_status, midden.costs, midden.build_workers))
			elif midden.get("state") == "developing":
				_detail_line(box, 224, "Developing: %.0f%%" % (midden.progress * 100.0))
				_detail_line(box, 246, "%d excavation workers committed" % midden.build_workers)
			else:
				_detail_line(box, 224, "Cleanup efficiency doubled")
				_detail_line(box, 246, "Isolated refuse stays unusable")
		"queen":
			for tab: String in (["workers"] if _status.get("daughter",false) else ["workers","reproduction"]):
				var button: Rect2 = _queen_tab_rect(tab)
				UIStyle.surface(self,button,Color("354d55") if queen_tab==tab else Color("263038"))
				_label(button.get_center()+Vector2(0,5),"WORKER BROOD" if tab=="workers" else "REPRODUCTION",Color("dce5d9"),12,HORIZONTAL_ALIGNMENT_CENTER)
			if queen_tab=="reproduction":
				_draw_reproduction_context(box)
				return
			_detail_line(box, 111, "Queens: %d · Local workers: %d" % [_status.queens,_status.workers_total])
			_detail_line(box, 137, "Available workers: %d" % _status.workers_available)
			_detail_line(box, 157, "Nursery: %d / %d brood space" % [_status.nursery_occupied_space, _status.nursery_brood_capacity])
			var production: Dictionary = _status.get("brood_production", {"intent":"manual", "waiting":"manual"})
			_label(box.position + Vector2(16, 195), "Brood laying", Color("a9b9bc"), 15)
			for intent: String in ["manual", "grow"]:
				var button: Rect2 = _brood_intent_rect(intent)
				UIStyle.surface(self, button, Color("354d55") if production.intent == intent else Color("263038"))
				_label(button.get_center() + Vector2(0, 5), ("MANUAL" if intent == "manual" else "AUTO BROOD"), Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)
			var waiting_labels: Dictionary = {"manual":"Automatic laying is off", "ready":"Ready on next simulation tick", "space":"Waiting for Nursery space", "care":"Waiting for care workers", "queen":"No queen can lay", "population":"Population limit reached", "carbohydrate":"Waiting for carbs reserve", "protein":"Waiting for protein reserve", "water":"Waiting for water reserve"}
			var wait_text: String = waiting_labels.get(production.waiting, "")
			if production.waiting in ["carbohydrate", "protein", "water"]:
				var needed: float = _status.get("brood_reserve", {}).get(production.waiting, 0.0)
				wait_text = "Auto needs %.1f %s; have %.1f" % [needed, Copy.resource(production.waiting), _status.resources.get(production.waiting, 0.0)]
			_label(box.position + Vector2(16, 273), wait_text, Color("a9b9bc"), 15)
			if production.waiting == "adaptation":
				_label(box.position + Vector2(16, 273), "Next: " + Web.short_title(_queued_trait()), Color("d9c5a5"), 15)
			_label(box.position + Vector2(16, 294), Web.queue_wait(_status) if production.waiting == "adaptation" else "Auto checks food, care and space.", Color("8fa1a8"), 15)
			_label(box.position + Vector2(16, 313), "Queued trial has priority." if production.waiting == "adaptation" else "Brood inherits the founding queen." if _status.get("daughter",false) else "Manual brood still needs feeding.", Color("8fa1a8"), 15)
			_draw_brood_button()
		"nursery":
			var brood: Array = _status.brood
			var count: int = 0
			for cohort: Dictionary in brood:
				count += cohort.count
			count += _status.get("reproduction",{}).get("occupied_space",0)
			var reproductive_space: int = _status.get("reproduction",{}).get("occupied_space",0)
			_detail_line(box, 65, "Space: %d / %d · %d reproductive" % [count,_status.nursery_brood_capacity,reproductive_space] if reproductive_space>0 else "Brood space: %d / %d" % [count, _status.nursery_brood_capacity])
			_detail_line(box, 91, "Worker care: %d / %d brood" % [_status.nursery_care_capacity,_status.nursery_max_care_capacity] if reproductive_space>0 else "Care supports %d / %d brood" % [_status.nursery_care_capacity, _status.nursery_max_care_capacity])
			if not brood.is_empty():
				var stages: String = "%s · %.0fs" % [brood[0].stage.capitalize(), brood[0].progress_seconds] if brood.size() == 1 else "2 cohorts: %s / %s" % [brood[0].stage, brood[1].stage]
				if brood.size() > 2:
					var groups: Array[String] = []
					for stage: String in ["egg", "larva", "pupa"]:
						var amount: int = brood.filter(func(cohort): return cohort.stage == stage).size()
						if amount > 0: groups.append("%s×%d" % [stage, amount])
					stages = "%d groups: " % brood.size() + " / ".join(groups)
				_label(box.position + Vector2(16, 117), stages, Color("a8b8bd"), 15)
				var food_enough: bool = true
				var care_enough: bool = true
				for cohort: Dictionary in brood:
					food_enough = food_enough and (cohort.care < 1.0 or cohort.nutrition >= 1.0)
					care_enough = care_enough and cohort.care >= 1.0
				var feeding: String = "Last short: " + Pressure.food_names(_status) if not Pressure.food_shortages(_status).is_empty() else "Brood waits for care" if not care_enough and food_enough else "Food %s · care %s" % ["enough" if food_enough else "short", "enough" if care_enough else "short"]
				_label(box.position + Vector2(16, 143), feeding, Color("a9b9bc"), 15)
			elif reproductive_space>0:
				_detail_line(box,117,"Reproductive brood · inspect Queen")
				_detail_line(box,143,"Last short: "+Pressure.food_names(_status) if not Pressure.food_shortages(_status).is_empty() else "Four reproductive nurses committed")
			_detail_line(box, 181, "%d emerged · %d brood lost" % [_status.brood_matured_total, _status.get("brood_losses", 0)] if _status.get("brood_health", {}).get("losses", 0) == 0 else "%d lost · %d during health strain" % [_status.get("brood_losses", 0), _status.brood_health.losses])
			var dirty: bool = _status.get("midden", {}).get("larval_rate", 1.0) < 1.0
			var climate: bool = _status.get("humidity", {}).get("larval_rate", 1.0) < 1.0
			var health: Dictionary = _status.get("brood_health", {})
			if health.get("condition", "stable") != "stable":
				_detail_line(box, 162, "Brood recovering · keep Midden clean" if health.condition == "recovering" else "Brood failing · clean Midden" if health.condition == "severe" else "Unhealthy brood · clean Midden")
			elif _status.get("temperature", {}).get("larval_rate", 1.0) < 1.0:
				_detail_line(box, 162, "Heat strain · climate care uses water")
			elif dirty or climate:
				_detail_line(box, 162, "Climate + sanitation slow larvae" if dirty and climate else "Nest climate slows larvae" if climate else "Sanitation slows larvae · visit Midden")
			if _status.nursery_state == "primitive":
				_detail_line(box, 209, "Develop for %d brood space" % _status.nursery_developed_capacity)
				_detail_line(box, 235, "Needs %.0f carbs · %.0f protein" % [_status.nursery_costs.carbohydrate, _status.nursery_costs.protein])
				_detail_line(box, 261, "%.0f water · %d workers · %.0fs" % [_status.nursery_costs.water, _status.nursery_workers_required, _status.nursery_build_duration])
				_draw_nursery_develop_button()
			elif _status.nursery_state == "developing":
				_detail_line(box, 209, "Developing: %.0f / %.0fs" % [_status.nursery_progress, _status.nursery_build_duration])
				_detail_line(box, 235, "%d workers committed" % _status.nursery_workers_required)
			else:
				var humidity: Dictionary = _status.get("humidity", {"moisture": 65.0, "carers": 0, "water_used": 0.0})
				var condition: String = "dry" if humidity.moisture < 45.0 else "damp" if humidity.moisture > 80.0 else "steady"
				_detail_line(box, 209, "Humidity: %.0f%% · %s" % [humidity.moisture, condition])
				_detail_line(box, 235, "Temp: %s · climate workers: %d" % [_status.get("temperature", {}).get("condition", "steady"), humidity.carers])
				for target: int in [0, 1, 2, 4]:
					var button: Rect2 = _humidity_rect(target)
					UIStyle.surface(self, button, Color("355059") if target == humidity.carers else Color("263038"))
					_label(button.get_center() + Vector2(0, 6), str(target), Color("dce5d9"), 16, HORIZONTAL_ALIGNMENT_CENTER)
				if expansion.get("state", "") == "available":
					_detail_line(box, 306, "Expansion: %.0f carbs · %.0f protein" % [expansion.costs.carbohydrate, expansion.costs.protein])
					_detail_line(box, 330, "%.0f water · %d workers · %.0fs" % [expansion.costs.water, expansion.workers, expansion.duration])
					var button: Rect2 = _nursery_expand_rect()
					_draw_action(button, "EXPAND TO %d BROOD SPACE" % expansion.capacity, Copy.local_shortage(_status, expansion.costs, expansion.workers))
				elif expansion.get("state", "") == "developing":
					_detail_line(box, 306, "Expanding: %.0f / %.0fs" % [expansion.progress_seconds, expansion.duration])
					_detail_line(box, 330, "%d workers · existing space online" % expansion.workers)
				else:
					_detail_line(box, 306, "Climate workers humidify / cool")
					_detail_line(box, 330, "%.1f water used · damp brood aired" % humidity.water_used)
			_draw_brood_button()
		"food_exchange":
			if _status.food_exchange_state == "primitive":
				_detail_line(box, 65, "Primitive Food Exchange")
				_detail_line(box, 99, "Needs %.0f carbs · %.0f protein" % [_status.food_exchange_costs.carbohydrate, _status.food_exchange_costs.protein])
				_detail_line(box, 125, "%.0f water · %d workers" % [_status.food_exchange_costs.water, _status.food_exchange_workers_required])
				_detail_line(box, 157, "Build: %.0f simulated seconds" % _status.food_exchange_duration)
				_draw_action(_develop_rect(), "DEVELOP FOOD EXCHANGE", Copy.local_shortage(_status, _status.food_exchange_costs, _status.food_exchange_workers_required))
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
				if recent_food_losses:
					var base: float = 230 if _status.food_exchange_state == "developed" else 300
					_label(box.position + Vector2(16, base), "Workers lost after food sharing", Color("c7ad98"), 15)
					_label(box.position + Vector2(16, base + 24), "%d lost locally · %s ago" % [food_losses.losses, Copy.duration(food_losses.age)], Color("a9b9bc"), 15)
					_label(box.position + Vector2(16, base + 48), "Cause remains uncertain", Color("8fa1a8"), 15)
					_label(box.position + Vector2(16, base + 74), "Review returned food supplies", Color("8fa1a8"), 15)
				else:
					_label(box.position + Vector2(16, 300), "Last short: " + Pressure.food_names(_status), Color("c7ad98"), 15)
					_label(box.position + Vector2(16, 316), "Needs supplies from Home" if _status.get("daughter",false) else "Browse returned sources", Color("8fa1a8"), 15)
				if _status.get("daughter",false):
					_draw_action(_supply_link_rect(),"SUPPLY CONNECTION")
				for resource_id: String in ([] if _status.get("daughter",false) else Pressure.food_sources_needed(_status)):
					var button: Rect2 = _food_source_rect(resource_id)
					UIStyle.surface(self, button, Color("263038"))
					_label(button.get_center() + Vector2(0, 5), "CARBS" if resource_id == "carbohydrate" else resource_id.to_upper(), Color("dce5d9"), 12, HORIZONTAL_ALIGNMENT_CENTER)
			elif food_losses.get("losses",0) > 0:
				_label(box.position + Vector2(16, 213), "Local losses: %d · last %.0fs ago" % [food_losses.losses,food_losses.age], Color("8fa1a8"), 15)
		"entrance":
			_detail_line(box, 65, "Available workers: %d" % _status.workers_available)
			_detail_line(box, 91, "Scouts away: %d" % _status.active_scouts)
			_detail_line(box, 117, "Trail workers: %d" % _status.trail_workers)
			if not _status.get("supply",{}).is_empty(): _draw_supply_context(box)
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
				_draw_action(_guest_rect(), "STOP REJECTION" if guest.get("rejection_active", false) else "ASSIGN %d TO REJECTION" % guest.workers_required, "" if guest.get("rejection_active", false) else Copy.local_shortage(_status, {}, guest.workers_required), Color("39323e"))
		"adaptation":
			_detail_line(box, 65, "Security / tolerance · overview" if web_family == "recognition" else "Colony repertoire · overview")
			_detail_line(box, 91, "Select a trait to inspect its tradeoff")
			_detail_line(box, 117, "Queue its next brood in this panel")
			if not _status.adaptation_trial.is_empty():
				_detail_line(box, 163, "Laid: " + Web.short_title(_status.adaptation_trial.adaptation_id))
				_detail_line(box, 189, "Locked · %s brood" % _status.adaptation_trial.stage.capitalize())
				_detail_line(box, 215, "Surviving adults express the trait")
			elif not _status.get("genetic_repertoire", []).is_empty():
				_detail_line(box, 163, "%d inherited traits" % _status.get("genetic_repertoire", []).size())
				_detail_line(box, 189, "Inspect each leaf for adult expression")
				_detail_line(box, 215, "Future brood inherits established traits")
			else:
				_detail_line(box, 163, "One focused brood trial at a time")
				_detail_line(box, 189, "Genes require food, nurses and brood")
				_detail_line(box, 215, "Relationships grow through interaction")
			if not _queued_trait().is_empty():
				_draw_action(_adaptation_rect(""), "CANCEL QUEUED CHOICE", "", Color("28212f"))
				_detail_line(box, 302, "Next: " + Web.short_title(_queued_trait()))
				_detail_line(box, 326, Web.queue_wait(_status))
			elif _status.get("wet_trail_experience", false) and not _status.get("adaptation_options", {}).has("persistent"):
				_detail_line(box, 249, "Wet journeys weakened scent")
				_detail_line(box, 275, "New brood may reveal variation")
			elif _status.get("recognition_experience", false) and not _status.get("adaptation_options", {}).has("security"):
				_detail_line(box, 249, "Foreign / partner chemistry observed")
				_detail_line(box, 275, "New brood may reveal variation")


func _draw_supply_context(box: Rect2) -> void:
	var supply: Dictionary=_status.supply
	_detail_line(box,145,"Home → Daughter supplies")
	_detail_line(box,173,"%d Home workers assigned" % supply.workers if supply.workers>0 else "Assign %d Home workers" % supply.workers_required)
	var message: String="Deliveries are off" if supply.status=="none" else "Waiting at Home" if supply.status=="waiting" else "Party away · "+Copy.duration(supply.age)
	_detail_line(box,197,message)
	_label(box.position+Vector2(16,219),"Current trip finishes before release" if not supply.enabled and supply.status=="away" else supply.get("blocker","") if not supply.get("blocker","").is_empty() else "Pack: 4 carbs / 2 protein / 2 water + traits",Color("8fa1a8"),12)
	_label(box.position+Vector2(16,249),"Reports: %d · last %s ago" % [supply.trips_reported,Copy.duration(supply.report_age)] if supply.trips_reported>0 else "No delivery report yet",Color("a9b9bc"),14)
	if supply.trips_reported>0:
		var packet: Dictionary=supply.last_payload
		_label(box.position+Vector2(16,273),"Last: %.1f carbs / %.1f protein / %.1f water" % [packet.carbohydrate,packet.protein,packet.water],Color("8fa1a8"),12)
	_draw_action(_supply_rect(),"STOP AFTER TRIP" if supply.enabled else "RESUME SUPPLIES" if supply.status=="away" else "ASSIGN 8 SUPPLY WORKERS",supply.get("blocker","") if supply.status=="none" else "")


func _draw_reproduction_context(box: Rect2) -> void:
	var state: Dictionary = _status.get("reproduction",{})
	var phase: String = state.get("phase","none")
	if phase=="departed":
		_detail_line(box,111,"Reproductives committed away")
		_detail_line(box,139,"Inspect Shelter in OUTWARD")
		_detail_line(box,179,"Active laying queens: %d" % _status.queens)
		_detail_line(box,207,"Home worker brood can continue")
		return
	if phase=="ready":
		_detail_line(box,111,"1 young queen · 2 supporting males")
		_detail_line(box,139,"Ready for a founding expedition")
		_detail_line(box,179,"Active laying queens: %d" % _status.queens)
		_detail_line(box,207,"Reproductives are not workers")
		_detail_line(box,253,"Workers and food must travel")
		_detail_line(box,279,"to a remembered nest site.")
		return
	if phase in ["egg","larva","pupa"]:
		_detail_line(box,111,"Reproductive %s · %.0f%%" % [phase,state.get("progress",0.0)*100])
		_detail_line(box,139,"%d spaces · %d nurses committed" % [state.space,state.nurses])
		_detail_line(box,179,"1 young queen + 2 males developing")
		var missing: Array = state.get("food_shortfalls",[])
		var names: Array[String] = []
		for id: String in missing: names.append(Copy.resource(id))
		_detail_line(box,207,"Waiting for "+" / ".join(names) if not names.is_empty() else "Fed from on-hand stores" if phase=="larva" else "Development continues with care")
		_detail_line(box,253,"Four nurses support this group")
		_detail_line(box,279,"Worker brood and trials still compete")
		_detail_line(box,301,"for food and free Nursery space.")
		return
	_detail_line(box,111,"Raise 1 young queen + 2 males")
	_detail_line(box,139,"Needs %d emerged workers" % state.get("emerged_required",32))
	_detail_line(box,167,"Developed Nursery + Food Exchange")
	_detail_line(box,199,"%d free spaces · %d nurses" % [state.get("space",8),state.get("nurses",4)])
	var costs: Dictionary = state.get("costs",{})
	_detail_line(box,225,"Lay: %.0f carbs · %.0f protein · %.0f water" % [costs.get("carbohydrate",12),costs.get("protein",12),costs.get("water",8)])
	_detail_line(box,253,"Larvae also need sustained feeding")
	_detail_line(box,279,"Brood develops into reproductives")
	_draw_action(_reproduction_rect(),"LAY REPRODUCTIVE BROOD",Copy.reason(state.get("blocker","Requirements unavailable")))


func _draw_genetic_context(box: Rect2) -> void:
	_detail_line(box, 65, Web.title(web_selection))
	_detail_line(box, 91, Web.trait_state(_status, web_selection))
	var benefits: String = ""
	var tradeoff: String = ""
	match web_selection:
		"lean":
			benefits = "Up to 30% less travel energy"
			tradeoff = "Up to 15% less carrying"
		"load":
			benefits = "Up to 30% more carrying"
			tradeoff = "Up to 20% more travel energy"
		"persistent":
			benefits = "Up to %.0fx scent persistence" % _status.get("chemistry_persistence", 2.0)
			tradeoff = "Up to %.0f%% more trail food" % (_status.get("chemistry_extra_energy", 0.2) * 100)
		"security":
			benefits = "Up to %.0f%% less clearing time" % (_status.get("recognition_clearing_change", 0.4) * 100)
			tradeoff = "Up to %d extra tending workers" % _status.get("recognition_labor_change", 2)
		"tolerance":
			benefits = "Up to %d fewer tending workers" % _status.get("recognition_labor_change", 2)
			tradeoff = "Up to %.0f%% more clearing time" % (_status.get("recognition_clearing_change", 0.4) * 100)
	_detail_line(box, 125, benefits)
	_detail_line(box, 151, tradeoff)
	if _can_choose_adaptation():
		var costs: Dictionary = _status.get("adaptation_options", {}).get(web_selection, {}).get("costs", _status.adaptation_costs)
		_detail_line(box, 185, "%.0f carbs · %.0f protein · %.0f water" % [costs.carbohydrate, costs.protein, costs.water])
		_detail_line(box, 211, "%d nurses · %d brood slots" % [_status.adaptation_nurses, _status.brood_batch_count])
		var rect: Rect2 = _adaptation_rect(web_selection)
		var queued: bool = _queued_trait() == web_selection
		_draw_action(rect, "CANCEL QUEUED CHOICE" if queued else "REPLACE QUEUED CHOICE" if not _queued_trait().is_empty() else "QUEUE FOR NEXT BROOD", "", Color("28212f"))
		UIStyle.surface(self, rect, Color("a28aaf"), true)
		_detail_line(box, 302, Web.queue_wait(_status) if queued else "Paid only when eggs are laid")
		_detail_line(box, 326, "Change choice until eggs are laid" if queued else "Replaces choice; no waiting list")
	elif _status.adaptation_trial.get("adaptation_id", "") == web_selection:
		_detail_line(box, 185, "Locked · " + str(_status.adaptation_trial.stage).capitalize())
		_detail_line(box, 211, "Expresses only with surviving adults")
		if not _queued_trait().is_empty():
			_detail_line(box, 247, "Next: " + Web.short_title(_queued_trait()))
			_detail_line(box, 273, "This brood's trait stays locked")
	elif _status.get("adaptation_options", {}).get(web_selection, {}).get("inherited", _status.adaptation_repertoire == web_selection):
		var expressed: int = _status.get("adaptation_options", {}).get(web_selection, {}).get("expressed", _status.adapted_workers)
		_detail_line(box, 185, "%d / %d adults carry this trait" % [expressed, _status.workers_total])
		_detail_line(box, 211, "Future brood inherits this trait")
		_detail_line(box, 247, "Effects scale with adult carriers")
	else:
		_detail_line(box, 185, "Exclusive branch already chosen" if Web.trait_state(_status, web_selection) == "Other branch chosen" else "Trait not available")
		_detail_line(box, 211, "Laid and inherited traits stay fixed")
	if web_selection in ["security", "tolerance"] and not _can_choose_adaptation():
		_detail_line(box, 302, "Associates Nursery harm sooner" if web_selection == "security" else "Associates Nursery harm later")
		_detail_line(box, 326, "Reassign tenders for new staffing")


func _draw_relationship_context(box: Rect2) -> void:
	var relationship: Dictionary = _status.get("honeydew", {})
	_detail_line(box, 65, "Honeydew relationship")
	_detail_line(box, 91, "Ecological · learned by interaction")
	var state: String = relationship.get("relationship", "unknown")
	if state == "unknown":
		_detail_line(box, 125, "Producer source observed")
		_detail_line(box, 151, "Harvest it through an OUTWARD trail")
		_detail_line(box, 185, "Tending follows a loaded return")
	else:
		_detail_line(box, 125, "Workers tend producers" if state == "tended" else "Honeydew successfully harvested")
		_detail_line(box, 151, "%d workers committed" % relationship.protection_workers if state == "tended" else "Needs %d available workers" % relationship.required_workers)
		_detail_line(box, 185, "Tending supports production")
		_detail_line(box, 211, "Journey defense is a separate job")
		_draw_action(_honeydew_rect(), "WITHDRAW TENDERS" if state == "tended" else "TEND PRODUCERS", "" if state == "tended" else Copy.local_shortage(_status, {}, relationship.required_workers))


func _detail_line(box: Rect2, y: float, value: String) -> void:
	_label(box.position + Vector2(16, y), value, Color("a9b9bc"), 15)


func _brood_block_reason() -> String:
	if not _queued_trait().is_empty():
		return Web.queue_wait(_status) if _status.get("adaptation_queue", {}).get("waiting", "") != "ready" else ""
	if _status.get("queens", 0) < 1: return "No queen available"
	if _status.get("nursery_state", "") != "developed" and not _status.get("brood", []).is_empty(): return "Nursery already has a brood group"
	if not _can_lay_brood(): return "Nursery needs %d free brood slots" % _status.get("brood_batch_count", 8)
	return ""


func _draw_action(box: Rect2, title: String, shortage: String = "", color: Color = Color("35483c")) -> void:
	UIStyle.surface(self, box, color if shortage.is_empty() else Color("24272b"))
	_label(box.position + Vector2(box.size.x * 0.5, 29 if shortage.is_empty() else 17), title, Color("dce5d9"), 14, HORIZONTAL_ALIGNMENT_CENTER)
	if not shortage.is_empty():
		_label(box.position + Vector2(box.size.x * 0.5, 36), shortage, Color("ccac91"), 13, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_brood_button() -> void:
	_draw_action(_brood_rect(), "LAY QUEUED TRIAL NOW" if not _queued_trait().is_empty() else "LAY %d BROOD NOW" % _status.brood_batch_count, _brood_block_reason())


func _draw_nursery_develop_button() -> void:
	_draw_action(_nursery_develop_rect(), "DEVELOP NURSERY", Copy.local_shortage(_status, _status.nursery_costs, _status.nursery_workers_required))


func _draw_controls(size: Vector2) -> void:
	if _status.get("daughter_available",false):
		UIStyle.surface(self,_pile_rect(),Color("29392f"))
		var attention: Dictionary = _status.get("other_pile_attention", {})
		var title: String = attention.get("title", "INSPECT HOME" if _status.get("daughter",false) else "INSPECT DAUGHTER")
		_label(_pile_rect().get_center()+Vector2(0,-4 if not attention.is_empty() else 6),title,Color("d3dcd4"),14 if not attention.is_empty() else 16,HORIZONTAL_ALIGNMENT_CENTER)
		if not attention.is_empty():
			_label(_pile_rect().get_center()+Vector2(0,17),Copy.fit_line(" / ".join(attention.causes),_font,12,_pile_rect().size.x-24),Color("c4ac95"),12,HORIZONTAL_ALIGNMENT_CENTER)
	for command: String in ["outward", "pause", "speed_1", "speed_4", "speed_16", "speed_64", "save", "load"]:
		var box: Rect2 = _button_rect(command)
		var active: bool = command.begins_with("speed_") and not _status.is_empty() and int(command.trim_prefix("speed_")) == _status.time_scale
		UIStyle.surface(self, box, Color("31505a") if active else Color("18252b"))
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
	draw_string_outline(_font,placed,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color(0,0,0,0.82))
	draw_string(_font, placed, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
