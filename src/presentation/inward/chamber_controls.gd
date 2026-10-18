class_name ChamberControls
extends RefCounted
const Copy = preload("res://src/presentation/interface_text.gd")
const Style = preload("res://src/presentation/organic_ui.gd")
const Choices = preload("res://src/presentation/inward/development_choices.gd")
var opened: bool = false
var selected: String = "food_exchange"
func reset() -> void: opened=false; selected="food_exchange"
func button() -> Rect2: return Rect2(24,206,154,44)
func panel(size: Vector2) -> Rect2:
	var width: float=minf(840,size.x-48)
	return Rect2((size.x-width)/2,112,width,minf(480,size.y-224))
func rect(size: Vector2, action: String, index: int=0) -> Rect2:
	var box: Rect2=panel(size)
	match action:
		"row": return Rect2(box.position+Vector2(12,50+index*46),Vector2(200,44))
		"order": return Rect2(box.position+Vector2(232,box.size.y-56),Vector2(272,44))
		"back": return Rect2(box.position+Vector2(box.size.x-160,box.size.y-56),Vector2(144,44))
		"inspect": return Rect2(box.position+Vector2(232,box.size.y-108),Vector2(200,44))
	return Rect2()
func activate(view: Node2D, at: Vector2, projects: Array, command: Callable, status: Dictionary={}) -> bool:
	if button().has_point(at): opened=not opened; return true
	if not opened: return false
	var size: Vector2=view.get_viewport_rect().size
	if rect(size,"back").has_point(at): opened=false; return true
	var entries: Array[Dictionary]=Choices.entries(status,projects)
	for index: int in entries.size():
		if rect(size,"row",index).has_point(at): selected=entries[index].id; return true
	for entry: Dictionary in entries:
		if entry.id!=selected: continue
		if entry.get("legacy",false) and rect(size,"inspect").has_point(at):
			if entry.id=="midden" and not status.get("midden",{}).get("revealed",false):
				view.show_feedback(entry.wait); return true
			view.selected_id=entry.inspect; opened=false; return true
		if entry.phase=="complete" or not rect(size,"order").has_point(at): continue
		if entry.get("legacy",false):
			if entry.phase=="developing": return true
			if not entry.wait.is_empty(): view.show_feedback(entry.wait); return true
			view._run_command(entry.command)
		elif command.is_valid():
			var cancel: bool=entry.phase in ["queued","developing"]
			var result: Dictionary=command.call(selected,cancel)
			view.activation.outcome(result)
			view.show_feedback(("Project canceled; paid food stays spent" if cancel else "Project queued; starts when food and workers are ready") if result.get("accepted",false) else result.get("reason","Project unavailable"))
		return true
	return true
func draw(view: Node2D, projects: Array, status: Dictionary={}) -> void:
	Style.surface(view,button(),Color("17262d")); _text(view,button().position+Vector2(12,28),"DEVELOP COLONY",13,132)
	if not opened: return
	var size: Vector2=view.get_viewport_rect().size
	var box: Rect2=panel(size)
	view.draw_rect(view.get_viewport_rect(),Color(0.01,0.015,0.02,0.76))
	Style.surface(view,box,Color("141c1b")); Style.surface(view,box,Style.GOLD,true)
	_text(view,box.position+Vector2(16,30),"Colony functions and improvements",20,box.size.x-32)
	var chosen: Dictionary={}
	var entries: Array[Dictionary]=Choices.entries(status,projects)
	for index: int in entries.size():
		var entry: Dictionary=entries[index]
		var target: Rect2=rect(size,"row",index)
		Style.surface(view,target,Color("484735") if entry.id==selected else Color("25312c"))
		_text(view,target.position+Vector2(9,18),entry.name,13,182)
		_text(view,target.position+Vector2(9,35),phase_label(entry),11,182)
		if entry.id==selected: chosen=entry
	if not chosen.is_empty():
		var costs: Dictionary=chosen.costs
		var lines: Array[String]=[chosen.name,"NOW: "+chosen.now,"IMPROVEMENT: "+chosen.after,
			"Build: %.0f carbs / %.0f protein / %.0f water" % [costs.get("carbohydrate",0),costs.get("protein",0),costs.get("water",0)],
			"%d construction ants for %s; brood carers held" % [chosen.workers,Copy.duration(chosen.duration)],
			"Working; builders released" if chosen.phase=="complete" else "Building %.0f%%; food already paid" % (chosen.progress*100) if chosen.phase=="developing" else chosen.wait if not chosen.wait.is_empty() else "Ready to start" if chosen.get("legacy",false) else "Ready; queue starts on the next tick",
			"Starts now; food paid once. Builders return on completion." if chosen.get("legacy",false) else "Queue is free. Cancel releases workers, not spent food."]
		var y: float=54
		for index: int in lines.size():
			var wrapped: PackedStringArray=_wrap(lines[index],box.size.x-256,17 if index==0 else 13)
			for line: String in wrapped:
				_text(view,box.position+Vector2(232,y),line,17 if index==0 else 13,box.size.x-256)
				y+=19
			y+=9
		if chosen.get("legacy",false): _button(view,rect(size,"inspect"),"VIEW FUNCTION")
		if chosen.phase!="complete":
			_button(view,rect(size,"order"),"BUILDING..." if chosen.get("legacy",false) and chosen.phase=="developing" else "BUILD IMPROVEMENT" if chosen.get("legacy",false) else "CANCEL PROJECT" if chosen.phase in ["queued","developing"] else "QUEUE CONSTRUCTION")
	_button(view,rect(size,"back"),"BACK")
func phase_label(entry: Dictionary) -> String:
	if entry.phase=="complete": return "Improvement working"
	if entry.phase=="developing": return "Building %.0f%%" % (entry.progress*100)
	if entry.phase=="queued": return "Queued / waiting" if not entry.wait.is_empty() else "Queued / ready"
	return "Not ready yet" if not entry.wait.is_empty() else "Ready to build"
func _wrap(value: String, width: float, size: int) -> PackedStringArray:
	var result:=PackedStringArray()
	var line: String=""
	for word: String in value.split(" "):
		var candidate: String=word if line.is_empty() else line+" "+word
		if not line.is_empty() and ThemeDB.fallback_font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			result.append(line); line=word
		else: line=candidate
	if not line.is_empty(): result.append(line)
	return result
func _button(view: Node2D, target: Rect2, title: String) -> void:
	Style.surface(view,target,Color("354236")); _text(view,target.position+Vector2(12,28),title,13,target.size.x-24)
func _text(view: Node2D, at: Vector2, value: String, font_size: int, width: float) -> void:
	view.draw_string(ThemeDB.fallback_font,at,Copy.fit_line(value,ThemeDB.fallback_font,font_size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Style.TEXT)
