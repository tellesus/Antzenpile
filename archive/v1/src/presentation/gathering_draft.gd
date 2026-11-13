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
func panel(size: Vector2) -> Rect2: return Rect2(size.x-364,140,340,344)
func rect(size: Vector2, command: String) -> Rect2:
	var box: Rect2=panel(size)
	var center: Vector2=box.position+Vector2(170,154)
	var angles: Dictionary={"gather_less":-145.0,"gather_more":-35.0,"gather_less_many":155.0,"gather_more_many":25.0,"gather_commit":90.0}
	if angles.has(command):
		var at: Vector2=center+Vector2.from_angle(deg_to_rad(angles[command]))*100
		var radius: float=28 if command=="gather_commit" else 24
		return Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2)
	if command=="gather_suggest":return Rect2(center-Vector2(56,56),Vector2(112,112))
	if command=="gather_back":return Rect2(box.position+Vector2(288,8),Vector2(44,44))
	return Rect2()
func command_at(at: Vector2, size: Vector2) -> String:
	for command: String in ["gather_less","gather_suggest","gather_more","gather_less_many","gather_more_many","gather_commit","gather_back"]:
		if Style.circle_hit(rect(size,command),at): return command
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
	var box: Rect2=panel(size)
	Style.surface(view,box,Color("424936"))
	_text(view,box.position+Vector2(18,28),"Gathering",20,252,Style.TEXT)
	_text(view,box.position+Vector2(18,49),source_name,13,252,Style.GOLD)
	_center(view,box.position+Vector2(170,66),"%d assigned · %d queued · %d free" % [assigned,queued,available],12,304)
	var core: Rect2=rect(size,"gather_suggest")
	for command: String in ["gather_less","gather_more","gather_less_many","gather_more_many","gather_commit"]:
		var target: Rect2=rect(size,command)
		var direction: Vector2=(target.get_center()-core.get_center()).normalized()
		view.draw_line(core.get_center()+direction*54,target.get_center(),Color(Style.GOLD,0.45),2,true)
	Style.orb(view,core,Style.GOLD)
	_center(view,core.get_center()+Vector2(0,-22),"TOTAL",11,100,Style.GOLD)
	_center(view,core.get_center()+Vector2(0,13),str(amount),34,100,Style.TEXT)
	_center(view,core.get_center()+Vector2(0,34),"gatherers",11,100)
	for pair: Array in [["gather_less","−1"],["gather_more","+1"],["gather_less_many","−5"],["gather_more_many","+5"],["gather_commit","SEND"],["gather_back","×"]]:
		var target: Rect2=rect(size,pair[0])
		Style.orb(view,target,Color("b9dc83") if pair[0]=="gather_commit" else Style.GOLD,pair[0]=="gather_commit")
		_center(view,target.get_center()+Vector2(0,5),pair[1],12 if pair[0]=="gather_commit" else 17,target.size.x-8,Style.TEXT)
	var change: Dictionary=preview(assigned,available)
	var detail: String="Up to %d leave · %d wait for free labor" % [change.now,change.waiting]
	if change.surplus>0:detail="Lower target; surplus returns by travel"
	elif change.additional==0:detail="Keeps current assignment; no extra workers"
	_center(view,box.position+Vector2(170,299),action_title(assigned,available),13,308,Color("c4e3a5"))
	_center(view,box.position+Vector2(170,319),detail,12,308)
	_center(view,box.position+Vector2(170,336),"Care protected · travel and food still required",10,308,Color("a4b29b"))
	Style.tooltip(view,core,"Reset to suggested count","Sets the free draft to %d; sends nothing" % mini(maximum,CONFIG.initial_workers),size)
	Style.tooltip(view,rect(size,"gather_commit"),action_title(assigned,available),"Commit this total; unfunded workers queue",size)

func _text(view: Node2D, at: Vector2, value: String, size: int, width: float, color: Color = Color("bccdd2")) -> void:
	view.draw_string(ThemeDB.fallback_font,at,Copy.fit_line(value,ThemeDB.fallback_font,size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(view: Node2D, at: Vector2, value: String, size: int, width: float, color: Color = Color("dcebf1")) -> void:
	var fitted: String=Copy.fit_line(value,ThemeDB.fallback_font,size,width)
	_text(view,at-Vector2(ThemeDB.fallback_font.get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*0.5,0),fitted,size,width,color)
