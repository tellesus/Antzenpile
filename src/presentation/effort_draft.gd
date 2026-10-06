class_name EffortDraft
extends RefCounted
const Copy=preload("res://src/presentation/interface_text.gd")
const Style=preload("res://src/presentation/organic_ui.gd")
var opened: bool=false
var kind: String=""
var amount: int=0
var maximum: int=0
var suggestion: int=1
func begin(job: String, current: int, cap: int, recommended: int=1) -> void:
	opened=true;kind=job;maximum=maxi(0,cap);amount=clampi(current,0,maximum);suggestion=clampi(recommended,0,maximum)
func panel(size: Vector2) -> Rect2: return Rect2(size.x-316,144,292,334)
func rect(size: Vector2, action: String) -> Rect2:
	var at: Vector2=panel(size).position
	match action:
		"effort_less": return Rect2(at+Vector2(16,110),Vector2(56,44))
		"effort_suggest": return Rect2(at+Vector2(78,110),Vector2(108,44))
		"effort_more": return Rect2(at+Vector2(192,110),Vector2(84,44))
		"effort_zero": return Rect2(at+Vector2(16,160),Vector2(126,44))
		"effort_max": return Rect2(at+Vector2(150,160),Vector2(126,44))
		"effort_commit": return Rect2(at+Vector2(16,274),Vector2(164,44))
		"effort_back": return Rect2(at+Vector2(188,274),Vector2(88,44))
	return Rect2()
func action_at(size: Vector2, at: Vector2) -> String:
	for action: String in ["effort_less","effort_suggest","effort_more","effort_zero","effort_max","effort_commit","effort_back"]:
		if rect(size,action).has_point(at): return action
	return "effort_panel" if panel(size).has_point(at) else ""
func activate(view: Node2D, _size: Vector2, action: String, command: Callable) -> void:
	match action:
		"effort_less": amount=maxi(0,amount-1)
		"effort_more": amount=mini(maximum,amount+1)
		"effort_suggest": amount=suggestion
		"effort_zero": amount=0
		"effort_max": amount=maximum
		"effort_back": opened=false
		"effort_commit":
			if not command.is_valid(): view.show_feedback("Staffing command unavailable");return
			var result: Dictionary=command.call(kind,amount);view.activation.outcome(result)
			if result.get("accepted",false): opened=false
			view.show_feedback(("Standing target set · trips start when funded" if kind=="exploration" else "Local workers reassigned · carers held") if result.get("accepted",false) else result.get("reason","Staffing unavailable"))
func draw(view: Node2D, size: Vector2, free: int) -> void:
	var box: Rect2=panel(size);Style.surface(view,box,Color("111d22"));Style.surface(view,box,Color("716753"),true)
	var title: String={"climate":"Choose climate carers","cleanup":"Choose cleanup workers","exploration":"Choose standing scouts"}.get(kind,"Choose workers")
	_text(view,box.position+Vector2(16,28),title,18,260)
	_text(view,box.position+Vector2(16,52),"Up to %d here · whole worker targets" % maximum,12,260)
	_text(view,box.position+Vector2(16,76),"%d free nest workers · brood carers held" % free,12,260)
	_text(view,box.position+Vector2(16,101),"%d %s" % [amount,"standing scouts" if kind=="exploration" else "local workers"],18,260)
	for pair: Array in [["effort_less","−1"],["effort_suggest","SUGGEST %d" % suggestion],["effort_more","+1"],["effort_zero","ZERO / STOP"],["effort_max","MAX %d" % maximum],["effort_commit","SET TARGET" if kind=="exploration" else "ASSIGN %d" % amount],["effort_back","BACK"]]:
		var target: Rect2=rect(size,pair[0]);Style.surface(view,target,Color("29343a"));_text(view,target.position+Vector2(8,28),pair[1],12,target.size.x-16)
	_text(view,box.position+Vector2(16,231),"Shared cap; manual trips can delay dispatch" if kind=="exploration" else "Moistening and cooling use water" if kind=="climate" else "Isolating refuse improves Nursery health",11,260)
	_text(view,box.position+Vector2(16,252),"Zero requests return; travel still takes time" if kind=="exploration" else "Zero releases these local workers",12,260)
func _text(view: Node2D, at: Vector2, value: String, font_size: int, width: float) -> void:
	view.draw_string(ThemeDB.fallback_font,at,Copy.fit_line(value,ThemeDB.fallback_font,font_size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("d4dccd"))
