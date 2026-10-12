class_name ConnectionControls
extends RefCounted
## Detached connection summaries only. Selection and staffing drafts are free.
const Copy=preload("res://src/presentation/interface_text.gd")
const Style=preload("res://src/presentation/organic_ui.gd")
var opened: bool=false
var selected: String=""
var purpose: String="supplies"
var settlers: int=8
var _pile_id: String=""

func button(size: Vector2) -> Rect2:return Rect2(size.x-300,282,260,44)
func panel(size: Vector2) -> Rect2:
	var width: float=minf(620,size.x-48)
	return Rect2((size.x-width)/2,maxf(24,(size.y-510)/2),width,510)
func rect(size: Vector2, action: String) -> Rect2:
	var box: Rect2=panel(size);var at: Vector2=box.position
	match action:
		"previous":return Rect2(at+Vector2(16,62),Vector2(48,44))
		"next":return Rect2(at+Vector2(box.size.x-64,62),Vector2(48,44))
		"supplies":return Rect2(at+Vector2(16,122),Vector2((box.size.x-48)/3,44))
		"workers":return Rect2(at+Vector2(24+(box.size.x-48)/3,122),Vector2((box.size.x-48)/3,44))
		"queen":return Rect2(at+Vector2(32+2*(box.size.x-48)/3,122),Vector2((box.size.x-48)/3,44))
		"less":return Rect2(at+Vector2(16,184),Vector2(48,44))
		"more":return Rect2(at+Vector2(box.size.x-64,184),Vector2(48,44))
		"order":return Rect2(at+Vector2(16,388),Vector2(box.size.x-32,44))
		"stop":return Rect2(at+Vector2(16,446),Vector2(box.size.x-180,44))
		"back":return Rect2(at+Vector2(box.size.x-148,446),Vector2(132,44))
	return Rect2()
func sync(entries: Array, pile_id: String) -> void:
	if _pile_id!=pile_id:_pile_id=pile_id;selected="";settlers=8
	if not entries.any(func(entry: Dictionary) -> bool:return entry.id==selected):selected=entries[0].id if not entries.is_empty() else ""
func chosen(entries: Array) -> Dictionary:
	for entry: Dictionary in entries:
		if entry.id==selected:return entry
	return {}
func activate(view: Node2D, at: Vector2, entries: Array, command: Callable) -> bool:
	var size: Vector2=view.get_viewport_rect().size
	if not opened:
		if not entries.is_empty() and view.selected_id=="entrance" and button(size).has_point(at):opened=true;return true
		return false
	if rect(size,"back").has_point(at):opened=false;return true
	var entry: Dictionary=chosen(entries)
	if entry.is_empty():return true
	for action: String in ["previous","next","supplies","workers","queen","less","more","order","stop"]:
		if not rect(size,action).has_point(at):continue
		match action:
			"previous","next":
				var index: int=0
				for i: int in entries.size():
					if entries[i].id==selected:index=i
				selected=entries[posmod(index+(-1 if action=="previous" else 1),entries.size())].id
			"supplies","workers","queen":
				purpose=action
				if purpose=="queen":settlers=maxi(2,settlers)
			"less","more":settlers=clampi(settlers+(-1 if action=="less" else 1),2 if purpose=="queen" else 1,maxi(1,entry.available-1))
			"order","stop":
				if not command.is_valid():return true
				var source_id: String=entry.source_id
				var order: String="supply" if purpose=="supplies" else "relocate_queen" if purpose=="queen" else "migrate"
				if action=="stop":
					source_id=entry.payer_id;order="recall_queen" if entry.assigned_queen.away else "recall" if entry.assigned_migration.away else "stop_supply"
				var result: Dictionary=command.call(selected,source_id,order,settlers)
				view.activation.outcome(result);view.show_feedback(("Connection order accepted" if action=="order" else "Return requested; settlers already arrived stay") if result.get("accepted",false) else result.get("reason","Connection unavailable"))
		return true
	return true
func draw(view: Node2D, entries: Array) -> void:
	if not opened:return
	var size: Vector2=view.get_viewport_rect().size;var box: Rect2=panel(size);var entry: Dictionary=chosen(entries)
	Style.surface(view,box,Color("111d22"));Style.surface(view,box,Color("716753"),true)
	_text(view,box.position+Vector2(16,30),"Connection orders",20,box.size.x-32)
	if entry.is_empty():return
	_button(view,rect(size,"previous"),"‹");_button(view,rect(size,"next"),"›")
	_text(view,box.position+Vector2(76,90),entry.source_name+" → "+entry.destination_name,17,box.size.x-152)
	_button(view,rect(size,"supplies"),"SUPPLIES",purpose=="supplies");_button(view,rect(size,"workers"),"WORKERS",purpose=="workers");_button(view,rect(size,"queen"),"QUEEN RELOCATION",purpose=="queen")
	var lines: Array[String]=[]
	if purpose=="queen":
		_button(view,rect(size,"less"),"−");_button(view,rect(size,"more"),"+")
		_text(view,box.position+Vector2(76,212),"%d settling escorts + 1 messenger" % settlers,15,box.size.x-152)
		var state: Dictionary=entry.queen;var food: Dictionary=state.provisions
		lines=["Mother · generation %d · %s" % [state.generation,entry.source_name] if state.queen_available else "No laying mother at "+entry.source_name,"Recipient must be queenless; funded brood stays local","Pay %.3f carbs / %.3f protein / %.3f water" % [state.cost+food.carbohydrate,food.protein,food.water],"Last: returned · recipient became unsuitable" if state.last_result=="landing" else "Last: returned · escorts could not settle" if state.last_result=="escorts" else "%d queen deliveries confirmed by returning messenger" % state.queen_deliveries]
	elif purpose=="workers":
		_button(view,rect(size,"less"),"−");_button(view,rect(size,"more"),"+")
		_text(view,box.position+Vector2(76,212),"%d settlers + 1 returning messenger" % settlers,15,box.size.x-152)
		var state: Dictionary=entry.migration
		lines=["Available at "+entry.source_name+": %d · care held" % entry.available,"Travel food: %.2f carbs · paid by %s" % [state.cost,entry.source_name],"%d settled workers reported · %d returns" % [state.reported_workers,state.reports],"Settlers stay; only messenger return confirms arrival"]
	else:
		var state: Dictionary=entry.supply;var costs: Dictionary=state.costs
		lines=["8 supply workers · care held · repeats until stopped","Each pack: 4 carbs / 2 protein / 2 water + carrying traits","Pay %.2f carbs / %.2f protein / %.2f water at %s" % [costs.carbohydrate,costs.protein,costs.water,entry.source_name],"%d deliveries reported · %.1f total resources" % [state.trips_reported,state.reported_total]]
		_text(view,box.position+Vector2(16,212),"Cargo arrives physically; reports return with workers",14,box.size.x-32)
	for i: int in lines.size():_text(view,box.position+Vector2(16,250+26*i),lines[i],13,box.size.x-32)
	var wait: String=entry.queen.blocker if purpose=="queen" and not entry.queen.blocker.is_empty() else entry.migration.blocker if purpose=="workers" and not entry.migration.blocker.is_empty() else entry.supply.blocker if purpose=="supplies" and not entry.supply.get("blocker","").is_empty() else "Shared connection is free"
	if entry.busy:
		wait=entry.payer_name+": "
		if entry.assigned_queen.away:wait+="Queen party · %d sent · away %s" % [entry.assigned_queen.sent,Copy.duration(entry.assigned_queen.age)]
		elif entry.assigned_migration.away:wait+="%d sent · away %s" % [entry.assigned_migration.sent,Copy.duration(entry.assigned_migration.age)]
		else:wait+="%d supply workers · %s" % [entry.assigned_supply.workers,entry.assigned_supply.status]
	_text(view,box.position+Vector2(16,368),wait,13,box.size.x-32)
	_button(view,rect(size,"order"),"ORDER SUPPLIES" if purpose=="supplies" else "ORDER QUEEN RELOCATION" if purpose=="queen" else "ORDER %d SETTLERS" % settlers)
	_button(view,rect(size,"stop"),"REQUEST RETURN" if entry.assigned_migration.away or entry.assigned_queen.away else "STOP AFTER SUPPLY TRIP")
	_button(view,rect(size,"back"),"BACK")
func _button(view: Node2D, box: Rect2, label: String, active: bool=false) -> void:
	Style.surface(view,box,Color("344c43") if active else Color("24333a"));_text(view,box.position+Vector2(12,28),label,13,box.size.x-24)
func _text(view: Node2D, at: Vector2, value: String, font_size: int, width: float) -> void:
	view.draw_string(ThemeDB.fallback_font,at,Copy.fit_line(value,ThemeDB.fallback_font,font_size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("d4dccd"))
