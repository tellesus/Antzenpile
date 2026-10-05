class_name ReportControls
extends Node2D
const Style=preload("res://src/presentation/organic_ui.gd")
const Copy=preload("res://src/presentation/interface_text.gd")
const Text=preload("res://src/presentation/report_copy.gd")
var provider: Callable
var inspect_command: Callable
var need_command: Callable
var read_command: Callable
var pause_command: Callable
var blocked: Callable
var interaction_started: Callable
var opened: bool=false
var tab: String="history"
var page: int=0
var status: Dictionary={}
var feedback: String=""
var activation:=preload("res://src/presentation/activation_feedback.gd").new()
var _font: Font=ThemeDB.fallback_font

func _process(_delta: float) -> void:
	if provider.is_valid(): status=provider.call(opened)
	page=clampi(page,0,maxi(0,ceili(float(_rows().size())/visible_rows())-1));queue_redraw()

func button_rect() -> Rect2: return Rect2(24,150,154,44)
func panel_rect() -> Rect2:
	var size: Vector2=get_viewport_rect().size
	var width: float=minf(700,size.x-48)
	return Rect2((size.x-width)*0.5,144,width,maxf(278,size.y-266))
func visible_rows() -> int: return maxi(1,floori((panel_rect().size.y-166)/56))
func row_rect(index: int) -> Rect2: return Rect2(panel_rect().position+Vector2(12,106+index*56),Vector2(panel_rect().size.x-24,50))
func command_rect(command: String) -> Rect2:
	var box: Rect2=panel_rect();var width: float=box.size.x
	match command:
		"history": return Rect2(box.position+Vector2(12,54),Vector2(160,44))
		"needs": return Rect2(box.position+Vector2(180,54),Vector2(160,44))
		"pause": return Rect2(box.position+Vector2(width-160,54),Vector2(148,44))
		"previous": return Rect2(box.position+Vector2(12,box.size.y-54),Vector2(72,44))
		"next": return Rect2(box.position+Vector2(92,box.size.y-54),Vector2(72,44))
		"read": return Rect2(box.position+Vector2(172,box.size.y-54),Vector2(width-320,44))
		"close": return Rect2(box.position+Vector2(width-140,box.size.y-54),Vector2(128,44))
	return Rect2()
func _rows() -> Array: return status.get("needs",[]) if tab=="needs" else status.get("entries",[])

func activate_at(at: Vector2) -> bool:
	if blocked.is_valid() and blocked.call(): return false
	activation.begin()
	if not opened:
		if not button_rect().has_point(at): return false
		opened=true;page=0;feedback=""
		if interaction_started.is_valid(): interaction_started.call()
		_process(0);activation.tap(at);return true
	var rows: Array=_rows()
	for command: String in ["history","needs","pause","previous","next","read","close"]:
		if not command_rect(command).has_point(at): continue
		match command:
			"history","needs": tab=command;page=0
			"pause": if pause_command.is_valid(): pause_command.call()
			"previous": page=maxi(0,page-1)
			"next": page=mini(maxi(0,ceili(float(rows.size())/visible_rows())-1),page+1)
			"read":
				if tab=="history" and read_command.is_valid(): read_command.call(0)
				else: feedback="Inspect a need to act"
			"close": opened=false
		activation.tap(at);_process(0);return true
	for index: int in visible_rows():
		var slot: int=page*visible_rows()+index
		if slot>=rows.size() or not row_rect(index).has_point(at): continue
		var row: Dictionary=rows[slot]
		var result: Dictionary=need_command.call(row.pile_id,row.organ) if tab=="needs" and need_command.is_valid() else inspect_command.call(int(row.id)) if inspect_command.is_valid() else {"accepted":false,"reason":"Report navigation unavailable"}
		activation.outcome(result)
		if result.get("accepted",false): opened=false
		else: feedback=result.get("reason","Conditions changed")
		activation.tap(at);return true
	return true # Modal background is attention, never a field gesture.

func _input(event: InputEvent) -> void:
	if blocked.is_valid() and blocked.call(): return
	if opened and event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE: opened=false
		elif event.is_action_pressed("pause") and pause_command.is_valid(): pause_command.call()
		get_viewport().set_input_as_handled();return
	if event is InputEventScreenTouch and event.pressed:
		if activate_at(event.position): get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if activate_at(event.position): get_viewport().set_input_as_handled()
	elif opened: get_viewport().set_input_as_handled()

func _draw() -> void:
	if blocked.is_valid() and blocked.call(): return
	_button(button_rect(),"REPORTS"+(" (%d)" % status.get("unread",0) if status.get("unread",0)>0 else ""))
	if opened:
		var box: Rect2=panel_rect();Style.surface(self,box,Color("10191d"));Style.surface(self,box,Color("716553"),true)
		_label(box.position+Vector2(16,25),"Colony reports",18,box.size.x-32)
		var note: String="Simulation paused" if status.get("paused",false) else "Simulation continues · Pause or Space stops time"
		if status.get("abbreviated",false): note+=" · History abbreviated"
		elif status.get("since",0)>0: note+=" · Journal began on load"
		_label(box.position+Vector2(16,46),note,12,box.size.x-32)
		_button(command_rect("history"),"RETURNED HISTORY")
		_button(command_rect("needs"),"CURRENT NEEDS (%d)" % status.get("needs",[]).size())
		_button(command_rect("pause"),"RESUME" if status.get("paused",false) else "PAUSE")
		var rows: Array=_rows()
		for index: int in visible_rows():
			var slot: int=page*visible_rows()+index
			if slot>=rows.size(): break
			var row: Dictionary=rows[slot];var rect: Rect2=row_rect(index)
			Style.surface(self,rect,Color("252c2a") if row.get("unread",false) or tab=="needs" else Color("162125"))
			_label(rect.position+Vector2(10,19),Text.pile_name(row.pile_id)+" · "+row.title if tab=="needs" else Text.title(row,status),14,rect.size.x-20)
			_label(rect.position+Vector2(10,40)," + ".join(row.causes) if tab=="needs" else Text.detail(row,status.get("time",0)),12,rect.size.x-20)
		if rows.is_empty(): _label(box.position+Vector2(16,135),"No current needs" if tab=="needs" else "No new reports yet · history begins here",14,box.size.x-32)
		_button(command_rect("previous"),"←")
		_button(command_rect("next"),"→")
		_button(command_rect("read"),"MARK READ" if tab=="history" and feedback.is_empty() else "NEEDS REQUIRE ACTION" if feedback.is_empty() else feedback)
		_button(command_rect("close"),"CLOSE")
	activation.draw(self)

func _button(box: Rect2, text: String) -> void:
	Style.surface(self,box,Color("273239"));Style.surface(self,box,Color("706350"),true)
	_label(box.position+Vector2(8,28),text,13,box.size.x-16)
func _label(at: Vector2,text: String,size: int,width: float) -> void:
	draw_string(_font,at,Copy.fit_line(text,_font,size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("d9ddcc"))
