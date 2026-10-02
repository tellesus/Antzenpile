class_name ColonyControls
extends Node2D
## Explicit restart choices, separate from colony actions and save slots.

var seed_provider: Callable
var scenario_provider: Callable
var start_command: Callable
var blocked: Callable
var opened: bool = false
var selected_scenario: String = "backyard_slice"
var _font: Font = ThemeDB.fallback_font

func _process(_delta: float) -> void: queue_redraw()

func button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 436,78,100,64)

func panel_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 432,156,408,332)

func choice_rect(choice: String) -> Rect2:
	return Rect2(panel_rect().position + Vector2(24,148 if choice == "repeat" else 206 if choice == "fresh" else 264),Vector2(360,44))


func scenario_rect() -> Rect2:
	return Rect2(panel_rect().position + Vector2(24,94), Vector2(360,44))

func activate_at(at: Vector2) -> bool:
	if blocked.is_valid() and blocked.call(): return false
	if button_rect().has_point(at):
		opened = not opened
		if opened and scenario_provider.is_valid(): selected_scenario = scenario_provider.call()
		return true
	if not opened: return false
	if scenario_rect().has_point(at):
		selected_scenario = "garden_edge" if selected_scenario == "backyard_slice" else "backyard_slice"
		return true
	if choice_rect("cancel").has_point(at):
		opened = false
		return true
	for choice: String in ["repeat", "fresh"]:
		if choice_rect(choice).has_point(at) and start_command.is_valid() and seed_provider.is_valid():
			var seed_value: int = seed_provider.call()
			if choice == "fresh":
				seed_value = int(Time.get_ticks_usec() % 2147483646) + 1
				if seed_value == seed_provider.call(): seed_value = seed_value % 2147483646 + 1
			var result: Dictionary = start_command.call(seed_value, selected_scenario)
			if result.get("accepted",false): opened = false
	return true

func _input(event: InputEvent) -> void:
	if blocked.is_valid() and blocked.call(): return
	if opened and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		opened = false
		get_viewport().set_input_as_handled()
		return
	var press: bool = event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if press and activate_at(event.position): get_viewport().set_input_as_handled()
	elif opened: get_viewport().set_input_as_handled()

func _draw() -> void:
	if blocked.is_valid() and blocked.call(): return
	draw_rect(button_rect(),Color("18252b"))
	_label(button_rect().position + Vector2(21,38),"COLONY",14,Color("d3dcd4"))
	if not opened: return
	draw_rect(get_viewport_rect(),Color(0.025,0.04,0.06,0.82))
	var panel: Rect2 = panel_rect()
	draw_rect(panel,Color("111921"))
	draw_rect(panel,Color("41535a"),false)
	_label(panel.position+Vector2(24,32),"Start a new colony",22,Color("d9d3be"))
	_label(panel.position+Vector2(24,64),"Unsaved progress will be replaced.",15,Color("ccac91"))
	_label(panel.position+Vector2(24,86),"Saved colony and sound settings stay.",14,Color("a9b9bc"))
	draw_rect(scenario_rect(),Color("263038"))
	_label(scenario_rect().position+Vector2(16,28),"SETTING: %s  ·  CHANGE" % ScenarioCatalog.label_for(selected_scenario),14,Color("a9b9bc"))
	for choice: String in ["repeat","fresh","cancel"]:
		draw_rect(choice_rect(choice),Color("35483c") if choice != "cancel" else Color("263038"))
		_label(choice_rect(choice).position+Vector2(32,28),"REPEAT THIS SEED" if choice == "repeat" else "START WITH A FRESH SEED" if choice == "fresh" else "CANCEL",14,Color("dce5d9"))

func _label(at: Vector2,text: String,size: int,color: Color) -> void:
	draw_string(_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
