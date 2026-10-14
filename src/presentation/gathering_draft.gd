class_name GatheringDraft
extends RefCounted
const Copy=preload("res://src/presentation/interface_text.gd")
const Style=preload("res://src/presentation/organic_ui.gd")
const CONFIG=preload("res://data/trails/default_trails.tres")
var opened: bool=false
var source: String=""
var amount: int=5
var maximum: int=1

func begin(source_id: String, current: int, total: int) -> void:
	opened=true;source=source_id;maximum=maxi(1,total);amount=clampi(current if current>0 else CONFIG.initial_workers,1,maximum)
func panel(size: Vector2) -> Rect2: return Rect2(size.x-316,144,292,334)
func rect(size: Vector2, command: String) -> Rect2:
	var box: Rect2=panel(size)
	match command:
		"gather_less": return Rect2(box.position+Vector2(16,110),Vector2(56,44))
		"gather_suggest": return Rect2(box.position+Vector2(78,110),Vector2(108,44))
		"gather_more": return Rect2(box.position+Vector2(192,110),Vector2(84,44))
		"gather_less_many": return Rect2(box.position+Vector2(16,160),Vector2(126,44))
		"gather_more_many": return Rect2(box.position+Vector2(150,160),Vector2(126,44))
		"gather_commit": return Rect2(box.position+Vector2(16,274),Vector2(164,44))
		"gather_back": return Rect2(box.position+Vector2(188,274),Vector2(88,44))
	return Rect2()
func command_at(at: Vector2, size: Vector2) -> String:
	for command: String in ["gather_less","gather_suggest","gather_more","gather_less_many","gather_more_many","gather_commit","gather_back"]:
		if rect(size,command).has_point(at): return command
	return "gather_panel" if panel(size).has_point(at) else ""
func edit(command: String) -> void:
	match command:
		"gather_less": amount=maxi(1,amount-1)
		"gather_more": amount=mini(maximum,amount+1)
		"gather_less_many": amount=maxi(1,amount-5)
		"gather_more_many": amount=mini(maximum,amount+5)
		"gather_suggest": amount=mini(maximum,CONFIG.initial_workers)
		"gather_back": opened=false
func draw(view: Node2D, size: Vector2, source_name: String, assigned: int, available: int) -> void:
	var box: Rect2=panel(size);Style.surface(view,box,Color("111d22"));Style.surface(view,box,Color("746553"),true)
	_text(view,box.position+Vector2(16,28),"Choose gatherers",18,260)
	_text(view,box.position+Vector2(16,52),source_name,13,260)
	_text(view,box.position+Vector2(16,76),"%d free nest workers · carers held" % available,12,260)
	_text(view,box.position+Vector2(16,101),"%d total gatherers" % amount,18,260)
	for pair: Array in [["gather_less","−1"],["gather_suggest","SUGGEST 5"],["gather_more","+1"],["gather_less_many","−5"],["gather_more_many","+5"],["gather_commit","ORDER %d" % amount],["gather_back","BACK"]]:
		var target: Rect2=rect(size,pair[0]);Style.surface(view,target,Color("29343a"));Style.surface(view,target,Color("756653"),true)
		_text(view,target.position+Vector2(8,28),pair[1],13,target.size.x-16)
	var needed: int=maxi(0,amount-assigned)
	_text(view,box.position+Vector2(16,231),"%d from nest · %d wait for labor" % [mini(needed,available),maxi(0,needed-available)],12,260)
	_text(view,box.position+Vector2(16,252),"Trips still spend food and take time",12,260)

func _text(view: Node2D, at: Vector2, value: String, size: int, width: float) -> void:
	view.draw_string(ThemeDB.fallback_font,at,Copy.fit_line(value,ThemeDB.fallback_font,size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("d4dccd"))
