class_name RefugeControls
extends RefCounted
const Copy=preload("res://src/presentation/interface_text.gd")
const Style=preload("res://src/presentation/organic_ui.gd")
var opened: bool=false
func button() -> Rect2:return Rect2(24,258,154,44)
func panel(size: Vector2) -> Rect2:return Rect2((size.x-minf(620,size.x-48))/2,maxf(24,(size.y-510)/2),minf(620,size.x-48),510)
func rect(size: Vector2, action: String) -> Rect2:
	var box: Rect2=panel(size)
	var top: float={"priority":230,"prepare":286,"release":340,"connections":394,"back":448}.get(action,0)
	return Rect2(box.position+Vector2(16,top),Vector2(box.size.x-32,44))
func activate(view: Node2D, point: Vector2, status: Dictionary, command: Callable) -> bool:
	if not opened:
		if button().has_point(point):opened=true;return true
		return false
	var size: Vector2=view.get_viewport_rect().size
	if not panel(size).has_point(point):return true
	if rect(size,"back").has_point(point):opened=false;return true
	if rect(size,"connections").has_point(point):
		opened=false;view.selected_id="entrance";view.connection_controls.opened=true;return true
	for action: String in ["priority","prepare","release"]:
		if not rect(size,action).has_point(point):continue
		if action=="priority":action="workers" if status.get("refuge",{}).get("priority","royals")=="royals" else "royals"
		if command.is_valid():
			var result: Dictionary=command.call(action);view.activation.outcome(result)
			view.show_feedback("Shelter choice updated" if result.get("accepted",false) else result.get("reason","Shelter unavailable"))
		return true
	return true
func draw(view: Node2D, status: Dictionary) -> void:
	var warning: bool=not status.get("nest_crisis",{}).is_empty() and status.nest_crisis.ongoing
	Style.surface(view,button(),Color("473930") if warning else Color("17262d"));_text(view,button().position+Vector2(14,28),"GROUND WARNING" if warning else "REFUGE / GROUND",13,126)
	if not opened:return
	var size: Vector2=view.get_viewport_rect().size;var box: Rect2=panel(size)
	var refuge: Dictionary=status.get("refuge",{});var crisis: Dictionary=status.get("nest_crisis",{})
	Style.surface(view,box,Color("111d22"));Style.surface(view,box,Color("716753"),true)
	_text(view,box.position+Vector2(16,30),"Refuge and local ground",20,box.size.x-32)
	var cue: String="No local ground warning" if crisis.is_empty() else "Ground settled here" if not crisis.ongoing else "Local ground pressure observed" if crisis.impact_observed else "Local ground-shift warning"
	if crisis.get("impact_observed",false):cue+=" · lost %d workers / %d brood / %d young" % [crisis.workers_lost,crisis.brood_lost,crisis.royals_lost]
	_text(view,box.position+Vector2(16,60),cue,14,box.size.x-32)
	_text(view,box.position+Vector2(16,85),"Build Refuge through CHAMBERS" if not refuge.get("built",false) else "Shelter: %s · %d/17 slots held · %d carers" % [refuge.phase,refuge.reserved,refuge.workers],14,box.size.x-32)
	var targets: Array=refuge.get("targets",[])
	for index: int in mini(4,targets.size()):_text(view,box.position+Vector2(16,112+index*21),targets[index],13,box.size.x-32)
	_text(view,box.position+Vector2(16,208),"Prepare: 3 carbs · 2 water · four carers · 20 seconds",12,box.size.x-32)
	if not refuge.get("blocker","").is_empty():_text(view,box.position+Vector2(16,225),refuge.blocker,12,box.size.x-32)
	for action: String in ["priority","prepare","release","connections","back"]:
		var target: Rect2=rect(size,action);Style.surface(view,target,Color("24333a"))
		var text: String={"priority":"PRIORITY: YOUNG GROUPS" if refuge.get("priority","royals")=="royals" else "PRIORITY: WORKER BROOD","prepare":"PREPARE NAMED DEPENDENTS","release":"STAND DOWN · RELEASE CARERS","connections":"RESCUE / TRAFFIC CONTROLS","back":"BACK"}[action]
		_text(view,target.position+Vector2(12,28),text,13,target.size.x-24)
func _text(view: Node2D, point: Vector2, text: String, size: int, width: float) -> void:
	view.draw_string(ThemeDB.fallback_font,point,Copy.fit_line(text,ThemeDB.fallback_font,size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("d4dccd"))
