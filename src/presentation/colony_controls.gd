class_name ColonyControls
extends Node2D
var activation:=preload("res://src/presentation/activation_feedback.gd").new()

const UIStyle = preload("res://src/presentation/organic_ui.gd")
## Explicit restart choices, separate from colony actions and save slots.

var seed_provider: Callable
var scenario_provider: Callable
var start_command: Callable
var end_command: Callable
var status_provider: Callable
var status_open: bool=false
var confirm_end: bool = false
var blocked: Callable
var interaction_started: Callable
var opened: bool = false
var utility_command: Callable
var escape_context: Callable
var feedback: String = ""
var selected_scenario: String = "backyard_slice"
var guide_open: bool = false
var guide_page: int = 0
var _font: Font = ThemeDB.fallback_font
const GUIDE: Array = [
	{"title":"Read what returns", "lines":["OUTWARD is the colony's sensory memory.","Drag to turn; tap a trace to inspect it.","Exploration keeps scouts searching.","Findings become shared only after return.","Departure scents mark who is still away.","Remembered Sources revisits old reports."]},
	{"title":"Commit living workers", "lines":["Plan Gathering edits a target for free.","Send / Order / Queue commits that target.","Assigned and waiting ants are different.","Recall frees travelers only after return.","Carried cargo still arrives with them.","Danger needs deliberate gathering resume."]},
	{"title":"Manage returned threats", "lines":["A returned loss enables Search & Defend.","A three-ant survey is optional.","Choose a force, then commit the main order.","Hunt needs a returned predator report.","Ground hazards need avoidance.","Identity and results arrive with survivors."]},
	{"title":"Recruit a response", "lines":["Borrow workers from other jobs starts OFF.","OFF keeps other jobs running.","ON may reduce gathering, cleaning or climate.","Care and ongoing construction stay protected.","Recalled ants reach home before joining.","Restart reduced jobs deliberately."]},
	{"title":"Choose another approach", "lines":["Another Approach tests a longer course.","Withdraw gatherers and wait for their return.","Three paid workers make the survey trip.","Only their return establishes the course.","Resume gathering with a deliberate order.","More distance costs more travel food."]},
	{"title":"Support the inside", "lines":["INWARD shows functions, not a tunnel map.","Expand Nursery for up to four cohorts.","Queen's Auto Brood repeats supported groups.","Climate care: water when dry, air when damp.","Midden cleaners isolate accumulating refuse.","Queued traits lock when their brood is laid."]},
	{"title":"Build a second pile", "lines":["Shelter memories are not safety guarantees.","Queen → Reproduction raises a young queen.","Send Founding Party uses workers and stores.","Its returning messenger reports the camp.","Establish Daughter Pile starts its local jobs.","Inspect or Look From either named pile."]},
	{"title":"Support your network", "lines":["Entrance → Manage Connections chooses a nest.","Pick purpose and count; ORDER commits.","Worker settlers stay; one messenger reports.","Each connection has one shared traffic slot.","Stop supplies; await return before switching.","New workers still need food and brood care."]},
	{"title":"Keep your colony", "lines":["Save / Load uses this build only.","Start a new colony after changing builds.","Save keeps one unrevealed colony.","End Run reveals history; the saved slot stays.","Load restores that saved colony.","Sound keeps music and cues independent."]},
	{"title":"Keep brood care available", "lines":["Available means free to take another job.","Existing brood keeps its carers at home.","Queen and Entrance show held care workers.","If growth stalls, inspect Nursery.","Its named release or recall restores care.","Traveling workers must reach home first."]},
	{"title":"Gather aphid honeydew", "lines":["Aphids are small insects that feed on plants.","They produce sugary droplets called honeydew.","Gatherers carry those carbohydrates home.","After harvesting, assign aphid attendants.","Attendants improve output; they do not gather.","They do not defend the journey from predators."]}
]

func _ready() -> void:
	activation.attach(self,func() -> bool: return blocked.is_valid() and blocked.call())

func _process(_delta: float) -> void: queue_redraw()

func button_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 100,78,76,44)

func help_button_rect() -> Rect2:
	return utility_rect("help")

func panel_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size
	return Rect2((size - Vector2(728,470)) * 0.5, Vector2(728,470))

func choice_rect(choice: String) -> Rect2:
	return Rect2(panel_rect().position + Vector2(24,148 if choice == "repeat" else 200 if choice == "fresh" else 356 if choice == "guide" else 304 if choice == "end" else 252),Vector2(328,44))

func utility_rect(action: String) -> Rect2:
	return Rect2(panel_rect().position + Vector2(376,94 + ["save", "load", "sound", "help", "pause"].find(action) * 54), Vector2(328,44))

func open_menu() -> void:
	opened = true
	confirm_end = false
	guide_open = false
	status_open = false
	feedback = ""
	if scenario_provider.is_valid(): selected_scenario = scenario_provider.call()
	if interaction_started.is_valid(): interaction_started.call()


func guide_rect(command: String) -> Rect2:
	return Rect2(panel_rect().position + Vector2(24 if command != "next" else 210,322 if command == "back" else 264),Vector2(360 if command == "back" else 174,44))


func scenario_rect() -> Rect2:
	return Rect2(panel_rect().position + Vector2(24,94), Vector2(328,44))

func activate_at(at: Vector2) -> bool:
	if blocked.is_valid() and blocked.call(): return false
	if opened and not confirm_end and not status_open and not guide_open and help_button_rect().has_point(at):
		opened = true
		guide_open = true
		status_open=false
		guide_page = 0
		return true
	if button_rect().has_point(at):
		if opened: opened = false
		else: open_menu()
		return true
	if not opened: return false
	if confirm_end:
		if choice_rect("repeat").has_point(at) and end_command.is_valid():
			if end_command.call(): opened=false; confirm_end=false
		elif choice_rect("cancel").has_point(at): confirm_end=false
		return true
	if status_open:
		if choice_rect("cancel").has_point(at):status_open=false;opened=false
		elif choice_rect("end").has_point(at):confirm_end=true
		elif choice_rect("guide").has_point(at):status_open=false;guide_open=true;guide_page=0
		return true
	if guide_open:
		if guide_rect("back").has_point(at):
			guide_open = false
			opened = false
		elif guide_rect("previous").has_point(at): guide_page = maxi(0,guide_page - 1)
		elif guide_rect("next").has_point(at): guide_page = (guide_page + 1) % GUIDE.size()
		return true
	for action: String in ["save", "load", "sound", "pause"]:
		if utility_rect(action).has_point(at):
			if utility_command.is_valid():
				var result: Dictionary = utility_command.call(action)
				feedback = result.get("reason", "")
				activation.outcome(result)
			return true
	if choice_rect("end").has_point(at): confirm_end=true; return true
	if choice_rect("guide").has_point(at):
		status_open = true
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
			activation.outcome(result)
			if result.get("accepted",false): opened = false
	return true

func _input(event: InputEvent) -> void:
	if blocked.is_valid() and blocked.call(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if opened: opened = false
		elif escape_context.is_valid() and escape_context.call(): pass
		else: open_menu()
		get_viewport().set_input_as_handled()
		return
	var press: bool = event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if press: activation.begin()
	if press and activate_at(event.position):
		activation.tap(event.position)
		if interaction_started.is_valid(): interaction_started.call()
		get_viewport().set_input_as_handled()
	elif opened: get_viewport().set_input_as_handled()

func _draw() -> void:
	if blocked.is_valid() and blocked.call(): return
	UIStyle.surface(self, button_rect(),Color("18252b"))
	_label(button_rect().position + Vector2(13,28),"ESC  ≡",13,Color("c8e1e7"))
	if not opened: return
	draw_rect(get_viewport_rect(),Color(0.025,0.04,0.06,0.82))
	var panel: Rect2 = panel_rect()
	UIStyle.surface(self, panel,Color("111921"))
	UIStyle.surface(self, panel,Color("41535a"),true)
	_label(panel.position+Vector2(376,440),build_caption(),11,Color("78949e"))
	if confirm_end:
		_label(panel.position+Vector2(24,32),"End this run and reveal its world?",20,Color("e4d4b8"))
		_label(panel.position+Vector2(24,69),"This colony cannot resume after the reveal.",15,Color("dbb19a"))
		_label(panel.position+Vector2(24,96),"Your existing saved slot will be kept.",15,Color("b4c3bd"))
		for choice: String in ["repeat","cancel"]:
			UIStyle.surface(self,choice_rect(choice),Color("35483c"))
			_label(choice_rect(choice).position+Vector2(24,28),"END RUN AND REVIEW" if choice=="repeat" else "KEEP PLAYING",14,Color("e1d7bf"))
		return
	if guide_open:
		_draw_guide(panel)
		return
	if status_open:
		_draw_status(panel)
		return
	UIStyle.heading(self, panel.position+Vector2(24,40),"COLONY", "Menu")
	_label(panel.position+Vector2(24,73),"New colonies replace unsaved progress.",13,Color("a7b7bf"))
	UIStyle.surface(self, scenario_rect(),Color("263038"))
	_label(scenario_rect().position+Vector2(16,28),"SETTING: %s  ·  CHANGE" % ScenarioCatalog.label_for(selected_scenario),14,Color("a9b9bc"))
	for choice: String in ["repeat","fresh","cancel","end","guide"]:
		UIStyle.surface(self, choice_rect(choice),Color("35483c") if choice in ["repeat","fresh"] else Color("263038"))
		_label(choice_rect(choice).position+Vector2(32,28),"REPEAT THIS SEED" if choice == "repeat" else "START WITH A FRESH SEED" if choice == "fresh" else "COLONY STATUS" if choice == "guide" else "END RUN AND REVIEW" if choice == "end" else "CANCEL",14,Color("dce5d9"))
	for action: String in ["save", "load", "sound", "help", "pause"]:
		UIStyle.surface(self, utility_rect(action), Color("1a303e"))
		_label(utility_rect(action).position + Vector2(22,28), {"save":"SAVE COLONY     Ctrl+S", "load":"LOAD COLONY     Ctrl+L", "sound":"SOUND", "help":"HOW TO PLAY", "pause":"PAUSE / RESUME"}[action], 14, Color("dcebf1"))
	_label(panel.position + Vector2(24,440), "Escape returns to play", 12, Color("78949e"))
	_label(panel.position + Vector2(376,405), preload("res://src/presentation/interface_text.gd").fit_line(feedback,_font,12,328), 12, Color("8fd6c1"))

func _draw_status(panel: Rect2) -> void:
	var status: Dictionary=status_provider.call() if status_provider.is_valid() else {}
	var phase: String=status.get("phase","awaiting")
	_status_line(panel,32,"Colony status",20)
	_status_line(panel,64,{"viable":"Lineage can continue","queenless":"Queenless · paid continuation remains","awaiting":"Awaiting remaining journey reports","unrecoverable":"No supported lineage continuation"}.get(phase,"Continuity uncertain"),17)
	_status_line(panel,88,"A paid young group can establish a mother." if phase=="queenless" else "Expected returns remain unsettled." if phase=="awaiting" else "No reproductive or labor recovery remains." if phase=="unrecoverable" else "Food, care and travel still constrain recovery.",13)
	_status_line(panel,110,"Review is voluntary; the saved slot stays." if phase=="unrecoverable" else "No free workers? Inspect held jobs and care.",13)
	var receipt: Dictionary=status.get("accomplishment",{})
	_status_line(panel,134,"Generation %d offspring raised · %s ago" % [receipt.generation,preload("res://src/presentation/interface_text.gd").duration(status.time-receipt.tick*SimulationClock.TICK_INTERVAL)] if receipt.get("generation",0)>0 else "Later-generation offspring not yet raised",13)
	var rows: Array=status.get("piles",[])
	for index: int in mini(4,rows.size()):
		var row: Dictionary=rows[index]
		if not row.local:
			_status_line(panel,160+index*22,row.name+" · inspect this nest locally",13);continue
		var condition: String="relinquished" if row.relinquished else "isolated" if row.isolated else "mother" if row.queen else "paid young" if row.young else "queenless"
		_status_line(panel,160+index*22,"%s · %s · %d expected / %d free" % [row.name,condition,row.workers_expected,row.free],13)
	if rows.size()>4:_status_line(panel,245,"%d other nests included" % (rows.size()-4),12)
	for action: String in ["cancel","end","guide"]:
		UIStyle.surface(self,choice_rect(action),Color("263038"))
		_label(choice_rect(action).position+Vector2(24,28),{"cancel":"KEEP PLAYING","end":"END RUN AND REVIEW","guide":"HELP"}[action],14,Color("dce5d9"))

func _status_line(panel: Rect2, y: float, value: String, size: int) -> void:
	_label(panel.position+Vector2(24,y),preload("res://src/presentation/interface_text.gd").fit_line(value,_font,size,panel.size.x-48),size,Color("c4d0c1"))


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

func build_caption() -> String:
	return "Build %s · same-build saves only" % SaveBuild.current().trim_prefix("windows-").trim_prefix("editor-").left(8)
