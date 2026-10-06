class_name ChamberControls
extends RefCounted
const Copy=preload("res://src/presentation/interface_text.gd")
const Style=preload("res://src/presentation/organic_ui.gd")
var opened: bool=false
var selected: String="reproductive_alcove"
func reset() -> void: opened=false;selected="reproductive_alcove"
func button() -> Rect2: return Rect2(24,206,154,44)
func panel(size: Vector2) -> Rect2:
	var width: float=minf(680,size.x-48)
	return Rect2((size.x-width)/2,144,width,340)
func rect(size: Vector2, action: String, index: int=0) -> Rect2:
	var box: Rect2=panel(size)
	match action:
		"row": return Rect2(box.position+Vector2(16,58+index*54),Vector2(200,48))
		"order": return Rect2(box.position+Vector2(232,280),Vector2(272,44))
		"back": return Rect2(box.position+Vector2(box.size.x-160,280),Vector2(144,44))
	return Rect2()
func activate(view: Node2D, at: Vector2, entries: Array, command: Callable) -> bool:
	if button().has_point(at): opened=not opened;return true
	if not opened or not panel(view.get_viewport_rect().size).has_point(at): return false
	var size: Vector2=view.get_viewport_rect().size
	if rect(size,"back").has_point(at): opened=false;return true
	for index: int in entries.size():
		if rect(size,"row",index).has_point(at): selected=entries[index].id;return true
	for entry: Dictionary in entries:
		if entry.id!=selected or entry.phase=="complete" or not rect(size,"order").has_point(at): continue
		if command.is_valid():
			var cancel: bool=entry.phase in ["queued","developing"]
			var result: Dictionary=command.call(selected,cancel);view.activation.outcome(result)
			view.show_feedback(("Project canceled · spent food stays spent" if cancel else "Construction queued · carers held") if result.get("accepted",false) else result.get("reason","Project unavailable"))
		return true
	return true
func draw(view: Node2D, entries: Array) -> void:
	Style.surface(view,button(),Color("17262d"));_text(view,button().position+Vector2(16,28),"CHAMBERS",14,122)
	if not opened: return
	var size: Vector2=view.get_viewport_rect().size;var box: Rect2=panel(size)
	Style.surface(view,box,Color("111d22"));Style.surface(view,box,Color("716753"),true)
	_text(view,box.position+Vector2(16,30),"Chamber projects",20,box.size.x-32)
	var chosen: Dictionary={}
	for index: int in entries.size():
		var entry: Dictionary=entries[index];var target: Rect2=rect(size,"row",index)
		Style.surface(view,target,Color("34454a") if entry.id==selected else Color("24333a"))
		_text(view,target.position+Vector2(8,20),entry.name,13,target.size.x-16);_text(view,target.position+Vector2(8,38),entry.phase.capitalize(),11,target.size.x-16)
		if entry.id==selected: chosen=entry
	if not chosen.is_empty():
		var costs: Dictionary=chosen.costs
		var lines: Array[String]=[chosen.name,chosen.description,"%d construction ants · %s" % [chosen.workers,Copy.duration(chosen.duration)],"Build: %.0f carbs · %.0f protein · %.0f water" % [costs.carbohydrate,costs.protein,costs.water],"%s · %.0f%%" % [chosen.phase.capitalize(),chosen.progress*100],chosen.wait if not chosen.wait.is_empty() else "%d/%d reproductive spaces occupied" % [chosen.occupied,chosen.space] if chosen.phase=="complete" else "Existing care and feeding continue","Queue is free; funding pays once","Cancel releases workers, refunds no spent food","Queen controls reproductive intent"]
		if chosen.id=="ventilation_gallery":
			lines[5]=chosen.wait if not chosen.wait.is_empty() else "Climate staff and water still required"
			lines[8]="Assign climate carers in Nursery"
		for index: int in lines.size(): _text(view,box.position+Vector2(232,64+index*23),lines[index],14 if index==0 else 12,box.size.x-248)
		if chosen.phase!="complete":
			var target: Rect2=rect(size,"order");Style.surface(view,target,Color("35463d"));_text(view,target.position+Vector2(12,28),"CANCEL PROJECT" if chosen.phase in ["queued","developing"] else "QUEUE CONSTRUCTION",13,target.size.x-24)
	var back: Rect2=rect(size,"back");Style.surface(view,back,Color("24333a"));_text(view,back.position+Vector2(16,28),"BACK",13,back.size.x-32)
func _text(view: Node2D, at: Vector2, value: String, font_size: int, width: float) -> void:
	view.draw_string(ThemeDB.fallback_font,at,Copy.fit_line(value,ThemeDB.fallback_font,font_size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("d4dccd"))
