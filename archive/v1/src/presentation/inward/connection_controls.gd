class_name ConnectionControls
extends RefCounted
## Detached connection summaries only. Selection and staffing drafts are free.
const Copy=preload("res://src/presentation/interface_text.gd")
const Style=preload("res://src/presentation/organic_ui.gd")
var opened: bool=false
var selected: String=""
var purpose: String="supplies"
var settlers: int=8
var cohort_uid: String=""
var cargo_id: String="water"
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
		"supplies","workers","queen","brood","stores","royals","departure":
			var index: int=["supplies","workers","queen","brood","stores","royals","departure"].find(action)
			var width: float=(box.size.x-80)/7
			return Rect2(at+Vector2(16+index*(width+8),122),Vector2(width,44))
		"cohort_previous":return Rect2(at+Vector2(16,174),Vector2(48,44))
		"cohort_next":return Rect2(at+Vector2(box.size.x-64,174),Vector2(48,44))
		"less":return Rect2(at+Vector2(16,232 if purpose in ["brood","stores"] else 184),Vector2(48,44))
		"more":return Rect2(at+Vector2(box.size.x-64,232 if purpose in ["brood","stores"] else 184),Vector2(48,44))
		"order":return Rect2(at+Vector2(16,388),Vector2(box.size.x-32,44))
		"stop":return Rect2(at+Vector2(16,446),Vector2((box.size.x-188)/2,44))
		"policy":return Rect2(at+Vector2(24+(box.size.x-188)/2,446),Vector2((box.size.x-188)/2,44))
		"back":return Rect2(at+Vector2(box.size.x-148,446),Vector2(132,44))
	return Rect2()
func sync(entries: Array, pile_id: String) -> void:
	if _pile_id!=pile_id:_pile_id=pile_id;selected="";settlers=8;cohort_uid=""
	if not entries.any(func(entry: Dictionary) -> bool:return entry.id==selected):selected=entries[0].id if not entries.is_empty() else ""
	if not entries.is_empty():
		var choices: Array=entries[0].get("cohorts",[])
		if not choices.any(func(value: Dictionary)->bool:return value.uid==cohort_uid):cohort_uid=choices[0].uid if not choices.is_empty() else ""
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
	for action: String in ["previous","next","supplies","workers","queen","brood","stores","royals","departure","cohort_previous","cohort_next","less","more","order","stop","policy"]:
		if action in ["cohort_previous","cohort_next"] and purpose not in ["brood","stores"]:continue
		if not rect(size,action).has_point(at):continue
		match action:
			"previous","next":
				var index: int=0
				for i: int in entries.size():
					if entries[i].id==selected:index=i
				selected=entries[posmod(index+(-1 if action=="previous" else 1),entries.size())].id
			"supplies","workers","queen","brood","stores","royals","departure":
				purpose=action
				if purpose=="queen":settlers=maxi(2,settlers)
			"cohort_previous","cohort_next":
				if purpose=="stores":
					cargo_id=PileState.RESOURCE_IDS[posmod(PileState.RESOURCE_IDS.find(cargo_id)+(-1 if action=="cohort_previous" else 1),3)]
					return true
				var choices: Array=entry.get("cohorts",[])
				if not choices.is_empty():
					var index: int=0
					for i: int in choices.size():
						if choices[i].uid==cohort_uid:index=i
					cohort_uid=choices[posmod(index+(-1 if action=="cohort_previous" else 1),choices.size())].uid
			"less","more":settlers=clampi(settlers+(-1 if action=="less" else 1),2 if purpose=="queen" else 1,entry.stores.capacity if purpose=="stores" else maxi(1,entry.available-1))
			"policy":
				if command.is_valid():
					var result: Dictionary=command.call(selected,entry.source_id,"open" if entry.closed else "close",settlers,cohort_uid)
					view.activation.outcome(result);view.show_feedback(("Connection reopened; order new traffic" if entry.closed else "Connection closed; paid trips finish") if result.get("accepted",false) else result.get("reason","Connection unavailable"))
			"order","stop":
				if not command.is_valid():return true
				var source_id: String=entry.source_id
				var order: String="supply" if purpose=="supplies" else "relocate_queen" if purpose=="queen" else "rescue_brood" if purpose=="brood" else "rescue_stores" if purpose=="stores" else "rescue_royals" if purpose=="royals" else "final_departure" if purpose=="departure" else "migrate"
				if action=="stop":
					source_id=entry.payer_id;order="recall_departure" if entry.assigned_departure.away else "recall_royals" if entry.assigned_royals.away else "recall_stores" if entry.assigned_stores.away else "recall_brood" if entry.assigned_brood.away else "recall_queen" if entry.assigned_queen.away else "recall" if entry.assigned_migration.away else "stop_supply"
				var result: Dictionary=command.call(selected,source_id,order,settlers,cargo_id if purpose=="stores" else cohort_uid)
				view.activation.outcome(result);view.show_feedback(("Connection order accepted" if action=="order" else "Return requested; arrived ants and cargo stay") if result.get("accepted",false) else result.get("reason","Connection unavailable"))
		return true
	return true
func draw(view: Node2D, entries: Array) -> void:
	if not opened:return
	var size: Vector2=view.get_viewport_rect().size;var box: Rect2=panel(size);var entry: Dictionary=chosen(entries)
	Style.surface(view,box,Color("111d22"));Style.surface(view,box,Color("716753"),true)
	_text(view,box.position+Vector2(16,30),"Connection orders",20,box.size.x-32)
	if entry.is_empty():return
	if not entry.get("residue_report",{}).is_empty():
		_text(view,box.position+Vector2(16,50),"Strange ground reported "+Copy.duration(entry.get("time",0)-entry.residue_report.received_at)+" ago · close/stop limits new traffic",12,box.size.x-32)
	_button(view,rect(size,"previous"),"‹");_button(view,rect(size,"next"),"›")
	_text(view,box.position+Vector2(76,90),entry.source_name+" → "+entry.destination_name,17,box.size.x-152)
	_button(view,rect(size,"supplies"),"SUPPLY",purpose=="supplies");_button(view,rect(size,"workers"),"WORKERS",purpose=="workers");_button(view,rect(size,"queen"),"QUEEN",purpose=="queen");_button(view,rect(size,"brood"),"BROOD",purpose=="brood");_button(view,rect(size,"stores"),"STORES",purpose=="stores");_button(view,rect(size,"royals"),"YOUNG",purpose=="royals");_button(view,rect(size,"departure"),"LEAVE",purpose=="departure")
	var lines: Array[String]=[]
	if purpose=="stores":
		var state: Dictionary=entry.stores;var costs: Dictionary=state.costs
		_button(view,rect(size,"cohort_previous"),"‹");_button(view,rect(size,"cohort_next"),"›")
		_text(view,box.position+Vector2(76,202),cargo_id.capitalize()+" · actual stores at "+entry.source_name,14,box.size.x-152)
		_button(view,rect(size,"less"),"−");_button(view,rect(size,"more"),"+")
		_text(view,box.position+Vector2(76,260),"%d units · capacity %d · 8 returning carriers" % [settlers,state.capacity],14,box.size.x-152)
		lines=["One pack; inspection and quantity changes are free","Pay %.3f carbs / %.3f protein / %.3f water" % [costs.carbohydrate,costs.protein,costs.water],"Last: %d %s %s" % [state.last_amount,state.last_resource,"delivered" if state.last_delivered else "returned home"] if state.reports>0 else "Receipt arrives with the returning carriers"]
	elif purpose=="brood":
		var state: Dictionary=entry.brood;var food: Dictionary=state.provisions
		_button(view,rect(size,"cohort_previous"),"‹");_button(view,rect(size,"cohort_next"),"›")
		_text(view,box.position+Vector2(76,202),"%s · %d surviving · %s" % [state.stage.capitalize(),state.count,"paid trial" if state.trial else "worker brood"],14,box.size.x-152)
		_button(view,rect(size,"less"),"−");_button(view,rect(size,"more"),"+")
		_text(view,box.position+Vector2(76,260),"%d settlers incl. 2 carers + 1 messenger" % settlers,14,box.size.x-152)
		lines=["Minimum %d staff · receiving and return spaces held" % state.minimum_staff,"Pay %.3f carbs / %.3f protein / %.3f water" % [state.cost+food.carbohydrate,food.protein,food.water],"Last: returned · recipient became unsuitable" if state.last_result=="landing" else "Last: returned · carers could not settle" if state.last_result=="escorts" else "%d deliveries reported · last %d live brood" % [state.deliveries,state.last_count]]
	elif purpose=="departure":
		var state: Dictionary=entry.departure;var stores: Dictionary=state.left_stores
		_text(view,box.position+Vector2(16,208),"Final departure · %d workers · no returning messenger" % state.workers,14,box.size.x-32)
		lines=["Relinquish "+entry.source_name+"; all remaining workers leave","Travel: %.3f carbs · queen/funded brood must be rescued" % state.cost,"Leave %.1f carbs / %.1f protein / %.1f water" % [stores.carbohydrate,stores.protein,stores.water],"Built organs stay · receiver observes its own arrival"]
		if state.relinquished:lines=["Nest relinquished · departure is known","No source messenger; inspect the receiving nest","Stores and built organs recorded as left","Return request only works before actual settlement"]
	elif purpose=="royals":
		var state: Dictionary=entry.royals;var food: Dictionary=state.provisions
		_button(view,rect(size,"less"),"−");_button(view,rect(size,"more"),"+")
		_text(view,box.position+Vector2(76,212),"%d settling staff + 1 returning messenger" % settlers,14,box.size.x-152)
		lines=["Young queen + 2 males · %s · generation %d" % [state.stage.capitalize(),state.generation],"8 staff minimum; includes four reproductive nurses","Pay %.3f carbs / %.3f protein / %.3f water" % [state.cost+food.carbohydrate,food.protein,food.water],"%d group deliveries reported · original lineage retained" % state.deliveries]
	elif purpose=="queen":
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
	for i: int in lines.size():_text(view,box.position+Vector2(16,(292 if purpose in ["brood","stores"] else 250)+26*i),lines[i],13,box.size.x-32)
	var wait: String=entry.departure.blocker if purpose=="departure" and not entry.departure.blocker.is_empty() else entry.royals.blocker if purpose=="royals" and not entry.royals.blocker.is_empty() else entry.stores.blocker if purpose=="stores" and not entry.stores.blocker.is_empty() else entry.brood.blocker if purpose=="brood" and not entry.brood.blocker.is_empty() else entry.queen.blocker if purpose=="queen" and not entry.queen.blocker.is_empty() else entry.migration.blocker if purpose=="workers" and not entry.migration.blocker.is_empty() else entry.supply.blocker if purpose=="supplies" and not entry.supply.get("blocker","").is_empty() else "Shared connection is free"
	if entry.busy:
		wait=entry.payer_name+": "
		if entry.assigned_departure.away:wait+="Final departure known · no returning messenger"
		elif entry.assigned_royals.away:wait+="Young queen party · away "+Copy.duration(entry.assigned_royals.age)
		elif entry.assigned_stores.away:wait+="Store carriers · away "+Copy.duration(entry.assigned_stores.age)
		elif entry.assigned_brood.away:wait+="Brood party · %d sent · away %s" % [entry.assigned_brood.sent,Copy.duration(entry.assigned_brood.age)]
		elif entry.assigned_queen.away:wait+="Queen party · %d sent · away %s" % [entry.assigned_queen.sent,Copy.duration(entry.assigned_queen.age)]
		elif entry.assigned_migration.away:wait+="%d sent · away %s" % [entry.assigned_migration.sent,Copy.duration(entry.assigned_migration.age)]
		else:wait+="%d supply workers · %s" % [entry.assigned_supply.workers,entry.assigned_supply.status]
	if entry.closed:wait="Closed to new traffic · "+(wait if entry.busy else "reopen before ordering")
	_text(view,box.position+Vector2(16,368),wait,13,box.size.x-32)
	_button(view,rect(size,"order"),"ORDER SUPPLIES" if purpose=="supplies" else "FINAL DEPARTURE · RELINQUISH NEST" if purpose=="departure" else "ORDER YOUNG QUEEN RESCUE" if purpose=="royals" else "ORDER ONE STORE PACK" if purpose=="stores" else "ORDER BROOD RESCUE" if purpose=="brood" else "ORDER QUEEN RELOCATION" if purpose=="queen" else "ORDER %d SETTLERS" % settlers)
	_button(view,rect(size,"stop"),"REQUEST RETURN" if entry.assigned_departure.away or entry.assigned_royals.away or entry.assigned_stores.away or entry.assigned_migration.away or entry.assigned_queen.away or entry.assigned_brood.away else "STOP AFTER SUPPLY TRIP")
	_button(view,rect(size,"policy"),"OPEN CONNECTION" if entry.closed else "CLOSE TRAFFIC")
	_button(view,rect(size,"back"),"BACK")
func _button(view: Node2D, box: Rect2, label: String, active: bool=false) -> void:
	Style.surface(view,box,Color("344c43") if active else Color("24333a"));_text(view,box.position+Vector2(12,28),label,11 if box.position.y==panel(view.get_viewport_rect().size).position.y+122 else 13,box.size.x-24)
func _text(view: Node2D, at: Vector2, value: String, font_size: int, width: float) -> void:
	view.draw_string(ThemeDB.fallback_font,at,Copy.fit_line(value,ThemeDB.fallback_font,font_size,width),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("d4dccd"))
