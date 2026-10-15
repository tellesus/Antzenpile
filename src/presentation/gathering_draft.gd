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
		"gather_suggest": return Rect2(box.position+Vector2(78,160),Vector2(132,44))
		"gather_more": return Rect2(box.position+Vector2(216,110),Vector2(60,44))
		"gather_less_many": return Rect2(box.position+Vector2(16,160),Vector2(56,44))
		"gather_more_many": return Rect2(box.position+Vector2(216,160),Vector2(60,44))
		"gather_commit": return Rect2(box.position+Vector2(16,274),Vector2(260,44))
		"gather_back": return Rect2(box.position+Vector2(232,8),Vector2(44,44))
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
func preview(assigned: int, available: int) -> Dictionary:
	var additional: int = maxi(0,amount-assigned)
	return {"additional":additional,"now":mini(additional,maxi(0,available)),
		"waiting":maxi(0,additional-maxi(0,available)),"surplus":maxi(0,assigned-amount)}

func action_title(assigned: int, available: int) -> String:
	if assigned > 0: return "SET TOTAL TO %d" % amount
	if available == 0: return "QUEUE %d GATHERERS" % amount
	return ("SEND %d GATHERERS" if available >= amount else "ORDER %d GATHERERS") % amount

static func receipt(result: Dictionary) -> String:
	if not result.get("accepted",false): return result.get("reason","Gathering unavailable")
	if not result.has("target"): return "Gathering accepted · await actual travel"
	var text: String = "Target %d: %d assigned · %d queued" % [result.target,result.assigned,result.waiting]
	return text + (" · surplus returns by travel" if result.get("reduced",false) else " · trips take time")

func draw(view: Node2D, size: Vector2, source_name: String, assigned: int, available: int, queued: int = 0) -> void:
	var box: Rect2=panel(size);Style.surface(view,box,Color("111d22"));Style.surface(view,box,Color("39727c"),true)
	_text(view,box.position+Vector2(16,28),"Gatherers",20,204,Color("e9f6fa"))
	_text(view,box.position+Vector2(16,52),source_name,13,204)
	_text(view,box.position+Vector2(16,76),"Already assigned %d · queued %d" % [assigned,queued],12,260)
	_text(view,box.position+Vector2(16,96),"Available now %d · brood carers held" % available,12,260,Color("8fced4"))
	var counter:=Rect2(box.position+Vector2(78,110),Vector2(132,44))
	Style.surface(view,counter,Color("15232d"))
	_center(view,counter.position+Vector2(66,13),"PROPOSED TOTAL",10,124,Color("8fa1a8"))
	_center(view,counter.position+Vector2(66,39),str(amount),25,124,Color("e9f6fa"))
	for pair: Array in [["gather_less","−1"],["gather_suggest","SET TO %d" % mini(maximum,CONFIG.initial_workers)],["gather_more","+1"],["gather_less_many","−5"],["gather_more_many","+5"],["gather_back","×"]]:
		var target: Rect2=rect(size,pair[0]);Style.surface(view,target,Color("26363e"))
		_center(view,target.get_center()+Vector2(0,5),pair[1],14,target.size.x-12)
	var change: Dictionary=preview(assigned,available)
	var first: String="On send: up to %d from the nest" % change.now
	var second: String="%d wait for free labor" % change.waiting if change.waiting>0 else "Trips need food and take time"
	if change.surplus>0:
		first="Lower target by %d gatherers" % change.surplus
		second="Travelers return before becoming free"
	elif change.additional==0:
		first="Keeps the current %d assigned" % assigned
		second="This is a total, not extra workers"
	_text(view,box.position+Vector2(16,229),first,13,260,Color("c5e4dc"))
	_text(view,box.position+Vector2(16,249),second,12,260)
	_text(view,box.position+Vector2(16,266),"Only the button below commits this proposal",11,260,Color("8fa1a8"))
	var send: Rect2=rect(size,"gather_commit")
	Style.surface(view,send,Color("287375"))
	_center(view,send.get_center()+Vector2(0,5),action_title(assigned,available),15,248,Color("efffff"))

func _text(view: Node2D, at: Vector2, value: String, size: int, width: float, color: Color = Color("bccdd2")) -> void:
	view.draw_string(ThemeDB.fallback_font,at,Copy.fit_line(value,ThemeDB.fallback_font,size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(view: Node2D, at: Vector2, value: String, size: int, width: float, color: Color = Color("dcebf1")) -> void:
	var fitted: String=Copy.fit_line(value,ThemeDB.fallback_font,size,width)
	_text(view,at-Vector2(ThemeDB.fallback_font.get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*0.5,0),fitted,size,width,color)
