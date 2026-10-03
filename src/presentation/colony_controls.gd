class_name ColonyControls
extends Node2D

const UIStyle = preload("res://src/presentation/organic_ui.gd")
## Explicit restart choices, separate from colony actions and save slots.

var seed_provider: Callable
var scenario_provider: Callable
var start_command: Callable
var blocked: Callable
var interaction_started: Callable
var opened: bool = false
var selected_scenario: String = "backyard_slice"
var guide_open: bool = false
var guide_page: int = 0
var _font: Font = ThemeDB.fallback_font
const GUIDE: Array = [
	{"title":"Read what returns", "lines":["OUTWARD is the colony's sensory memory.","Drag to turn; tap a trace to inspect it.","Exploration keeps scouts searching.","Findings become shared only after return.","Departure scents mark who is still away.","Remembered Sources revisits old reports."]},
	{"title":"Commit living workers", "lines":["Gathering commits workers to real journeys.","Returns bring stores and new evidence.","An old source may be empty or changed.","Recovery watches need scouts and fresh returns.","Recall releases workers when they reach home.","Returned alarms give clues, not certainty."]},
	{"title":"Support the inside", "lines":["INWARD shows functions, not a tunnel map.","Expand Nursery for up to four cohorts.","Queen's Auto Brood repeats supported groups.","Climate care: water when dry, air when damp.","Midden cleaners isolate accumulating refuse.","Queued traits lock when their brood is laid."]},
	{"title":"Build a second pile", "lines":["Shelter memories are not safety guarantees.","Queen → Reproduction raises a young queen.","Send Founding Party uses workers and stores.","Its returning messenger reports the camp.","Establish Daughter Pile starts its local jobs.","Inspect or Look From either named pile."]},
	{"title":"Support your network", "lines":["Entrance supplies move food over real trips.","Send 8 Worker Settlers uses 9 Home workers.","Eight stay; one messenger returns a report.","Supplies and settlers share one connection.","Stop supplies; await return to send workers.","Extra workers still need food and brood care."]},
	{"title":"Keep your colony", "lines":["Pause and speed control simulation time.","Sound keeps music and cues independent.","Save keeps one colony; Load restores it.","A new colony retains that saved slot.","Repeat uses the selected setting and seed.","Fresh seed changes behavior, not layout."]}
]

func _process(_delta: float) -> void: queue_redraw()

func button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 436,78,100,64)

func help_button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 544, 78, 100, 64)

func panel_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 432,156,408,390)

func choice_rect(choice: String) -> Rect2:
	return Rect2(panel_rect().position + Vector2(24,148 if choice == "repeat" else 206 if choice == "fresh" else 322 if choice == "guide" else 264),Vector2(360,44))


func guide_rect(command: String) -> Rect2:
	return Rect2(panel_rect().position + Vector2(24 if command != "next" else 210,322 if command == "back" else 264),Vector2(360 if command == "back" else 174,44))


func scenario_rect() -> Rect2:
	return Rect2(panel_rect().position + Vector2(24,94), Vector2(360,44))

func activate_at(at: Vector2) -> bool:
	if blocked.is_valid() and blocked.call(): return false
	if help_button_rect().has_point(at):
		opened = true
		guide_open = true
		guide_page = 0
		return true
	if button_rect().has_point(at):
		opened = not opened
		guide_open = false
		if opened and scenario_provider.is_valid(): selected_scenario = scenario_provider.call()
		return true
	if not opened: return false
	if guide_open:
		if guide_rect("back").has_point(at):
			guide_open = false
			opened = false
		elif guide_rect("previous").has_point(at): guide_page = maxi(0,guide_page - 1)
		elif guide_rect("next").has_point(at): guide_page = (guide_page + 1) % GUIDE.size()
		return true
	if choice_rect("guide").has_point(at):
		guide_open = true
		guide_page = 0
		return true
	if scenario_rect().has_point(at):
		selected_scenario = ScenarioCatalog.IDS[(ScenarioCatalog.IDS.find(selected_scenario) + 1) % ScenarioCatalog.IDS.size()]
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
	if press and activate_at(event.position):
		if interaction_started.is_valid(): interaction_started.call()
		get_viewport().set_input_as_handled()
	elif opened: get_viewport().set_input_as_handled()

func _draw() -> void:
	if blocked.is_valid() and blocked.call(): return
	UIStyle.surface(self, button_rect(),Color("18252b"))
	_label(button_rect().position + Vector2(5,38),"COLONY MENU",13,Color("d3dcd4"))
	UIStyle.surface(self, help_button_rect(), Color("18252b"))
	_label(help_button_rect().position + Vector2(31,38), "HELP", 14, Color("d3dcd4"))
	if not opened: return
	draw_rect(get_viewport_rect(),Color(0.025,0.04,0.06,0.82))
	var panel: Rect2 = panel_rect()
	UIStyle.surface(self, panel,Color("111921"))
	UIStyle.surface(self, panel,Color("41535a"),true)
	if guide_open:
		_draw_guide(panel)
		return
	_label(panel.position+Vector2(24,32),"Start a new colony",22,Color("d9d3be"))
	_label(panel.position+Vector2(24,64),"Unsaved progress will be replaced.",15,Color("ccac91"))
	_label(panel.position+Vector2(24,86),"Saved colony and sound settings stay.",14,Color("a9b9bc"))
	UIStyle.surface(self, scenario_rect(),Color("263038"))
	_label(scenario_rect().position+Vector2(16,28),"SETTING: %s  ·  CHANGE" % ScenarioCatalog.label_for(selected_scenario),14,Color("a9b9bc"))
	for choice: String in ["repeat","fresh","cancel","guide"]:
		UIStyle.surface(self, choice_rect(choice),Color("35483c") if choice in ["repeat","fresh"] else Color("263038"))
		_label(choice_rect(choice).position+Vector2(32,28),"REPEAT THIS SEED" if choice == "repeat" else "START WITH A FRESH SEED" if choice == "fresh" else "HOW TO PLAY" if choice == "guide" else "CANCEL",14,Color("dce5d9"))


func _draw_guide(panel: Rect2) -> void:
	var page: Dictionary = GUIDE[guide_page]
	_label(panel.position + Vector2(24,32),page.title,22,Color("d9d3be"))
	for index: int in page.lines.size():
		_label(panel.position + Vector2(24,72 + index * 28),page.lines[index],15,Color("a9b9bc"))
	_label(panel.position + Vector2(24,244),"HOW TO PLAY  ·  %d / %d" % [guide_page+1,GUIDE.size()],14,Color("82939c"))
	for command: String in ["previous","next","back"]:
		UIStyle.surface(self, guide_rect(command),Color("263038"))
		_label(guide_rect(command).position + Vector2(20,28),"CLOSE HELP" if command == "back" else "PREVIOUS" if command == "previous" else "FIRST PAGE" if guide_page == GUIDE.size()-1 else "NEXT",14,Color("dce5d9"))

func _label(at: Vector2,text: String,size: int,color: Color) -> void:
	draw_string(_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
