class_name ConflictPopover
extends RefCounted
## A returned-evidence status circle and direct actions; worker choices are local drafts.
const Copy = preload("res://src/presentation/interface_text.gd")
const Memory = preload("res://src/presentation/outward/source_memory.gd")
const Style = preload("res://src/presentation/organic_ui.gd")
const CONFIG = preload("res://data/ecology/default_journey_response.tres")
var editing: bool = false
var history_open: bool = false
var amount: int = 12
var all_hands: bool = false
var goal: String = "clear"
var draft_kind: String = "defend"
var selected_route: String = ""

func reset() -> void:
	editing = false; history_open = false; selected_route = ""

func sync(route: Dictionary, status: Dictionary) -> void:
	if selected_route != route.get("id", ""):
		reset(); selected_route = route.get("id", "")
	if editing: amount = clampi(amount, 1, limit(route, status))

func own_party(route: Dictionary, status: Dictionary) -> bool:
	var state: Dictionary = status.get("journey_response", {})
	return state.get("away", false) and state.get("route_id", "") == route.get("id", "")

func kind(route: Dictionary, status: Dictionary) -> String:
	var state: Dictionary = status.get("journey_response", {})
	if own_party(route, status): return "defend" if state.get("mode") == "defend" else ""
	if route.get("surface_warning", false): return ""
	var finding: String = state.get("reports", {}).get(route.get("id"), {}).get("finding", "")
	if finding in ["ambush", "mixed"] and state.get("outcomes", {}).get(route.get("id"), {}).get("outcome", "") != "secured": return "defend"
	return "gather" if route.get("foreign_reports", 0) > 0 or route.get("conflict_report", "") != "" else ""

func limit(route: Dictionary, status: Dictionary) -> int:
	var committed: int = int(status.journey_response.get("workers",0)) if own_party(route,status) else int(route.get("allocated_workers",0)) if kind(route,status)=="gather" else 0
	return maxi(1, int(status.get("workers_total",0)) - committed)

func suggestion(route: Dictionary, status: Dictionary) -> int:
	return mini(limit(route, status), CONFIG.reinforcement_workers) if own_party(route, status) or kind(route, status) == "gather" else CONFIG.defense_workers

func start_edit(route: Dictionary, status: Dictionary) -> void:
	editing = true; history_open = false
	draft_kind = kind(route, status)
	var entry: Dictionary = status.get("journey_response", {}).get("recruitment", {}).get(route.get("id"), {})
	amount = clampi(int(entry.get("requested", suggestion(route, status))), 1, limit(route, status))
	all_hands = entry.get("all_hands", false)
	goal = status.get("journey_response", {}).get("goal", "clear") if own_party(route, status) else status.get("journey_response", {}).get("goals", {}).get(route.get("id"), "clear")

func layout(size: Vector2) -> Dictionary:
	var radius: float = clampf((size.y - 392) * 0.5, 96, 122)
	var center := Vector2(size.x * 0.5 - (110 if editing or history_open else 0), (142 + size.y - 118) * 0.5)
	var left: float = center.x - radius - 170
	var right: float = center.x + radius + 10
	var buttons: Dictionary = {
		"conflict_send":Rect2(center.x-80, center.y-radius-62, 160, 54),
		"conflict_retreat":Rect2(center.x-80, center.y+radius+8, 160, 54),
		"conflict_survey":Rect2(left, center.y-27, 160, 54),
		"conflict_approach":Rect2(right, center.y-27, 160, 54),
		"conflict_reports":Rect2(left, center.y+55, 160, 44),
		"journey_close":Rect2(right, center.y+55, 160, 44),
		"conflict_close":Rect2(right+116, center.y-radius-62, 44, 44)}
	var editor := Rect2(center.x+radius+12, center.y-156, 260, 312)
	if editing:
		buttons.merge({"draft_less":Rect2(editor.position+Vector2(12,96),Vector2(56,44)),
			"draft_suggest":Rect2(editor.position+Vector2(74,96),Vector2(112,44)),
			"draft_more":Rect2(editor.position+Vector2(192,96),Vector2(56,44)),
			"draft_goal":Rect2(editor.position+Vector2(12,146),Vector2(236,44)),
			"draft_all":Rect2(editor.position+Vector2(12,196),Vector2(236,44)),
			"draft_commit":Rect2(editor.position+Vector2(12,262),Vector2(156,44)),
			"draft_back":Rect2(editor.position+Vector2(176,262),Vector2(72,44))})
	elif history_open:
		buttons.draft_back = Rect2(editor.position+Vector2(12,262),Vector2(236,44))
	var bounds := Rect2(Vector2(left, center.y-radius-62),Vector2(right+160-left, 2*radius+124))
	if editing or history_open: bounds = bounds.merge(editor)
	return {"center":center,"radius":radius,"buttons":buttons,"editor":editor,"bounds":bounds}

func button_at(at: Vector2, size: Vector2) -> String:
	var positions: Dictionary = layout(size)
	if (editing or history_open) and positions.editor.has_point(at):
		for command: String in positions.buttons:
			if command.begins_with("draft_") and positions.buttons[command].has_point(at): return command
		return "journey_panel"
	for command: String in positions.buttons:
		if (editing or history_open) and positions.editor.intersects(positions.buttons[command]): continue
		if not command.begins_with("draft_") and positions.buttons[command].has_point(at): return command
	return "journey_panel" if positions.bounds.has_point(at) else ""

func reason(action: String, route: Dictionary, status: Dictionary) -> String:
	var state: Dictionary = status.get("journey_response", {})
	if action == "conflict_send":
		if route.get("surface_warning", false): return "Use avoidance for surface impacts"
		if own_party(route, status):
			if state.get("mode") != "defend": return "Wait for the survey's return"
			if state.get("workers", 0) >= status.get("workers_total",0): return "Whole known workforce committed"
		if kind(route, status).is_empty(): return "Survey to learn who caused the loss"
	if action in ["conflict_survey", "conflict_approach"]:
		if state.get("away", false) or not state.get("other_party", "").is_empty(): return "Another response party is away"
		if state.get("recruitment", {}).has(route.get("id")): return "Cancel the recruitment order first"
		if action == "conflict_survey" and route.get("reported_losses", 0) == 0: return "Needs a returned loss report"
	return ""

func approach_action(route: Dictionary, status: Dictionary) -> String:
	if route.get("desired_workers", 0) > 0: return "withdraw"
	if route.get("allocated_workers", 0) > 0: return "waiting"
	var report: Dictionary = status.get("journey_response", {}).get("approach_reports", {}).get(route.get("id"), {})
	return "resume" if report.get("outcome", "") == "found" else "test"

func draw(view: Node2D, route: Dictionary, status: Dictionary, size: Vector2) -> void:
	sync(route, status)
	var positions: Dictionary = layout(size)
	var center: Vector2 = positions.center
	var radius: float = positions.radius
	var state: Dictionary = status.get("journey_response", {})
	var identity: String = _identity(route, status)
	view.draw_circle(center, radius, Color("10181b"))
	view.draw_arc(center, radius, 0, TAU, 64, Color("8e7160"), 1.2, true)
	_text(view, center+Vector2(0,-radius+22), identity, 15, 2*radius-18)
	_text(view, center+Vector2(0,-radius+40), _source_name(route, status), 12, 2*radius-24, Color("9eaaa8"))
	_impression(view, center+Vector2(0,-28), route, status)
	var latest: Dictionary = _latest(route, status)
	_text(view, center+Vector2(0,17), latest.text, 13, 2*radius-18)
	_text(view, center+Vector2(0,35), latest.date, 12, 2*radius-24, Color("abb5b1"))
	var entry: Dictionary = state.get("recruitment", {}).get(route.get("id"), {})
	var counts: String = "%d sent · awaiting return" % state.get("workers",0) if own_party(route,status) else "%d gatherers assigned" % route.get("allocated_workers",0)
	if not entry.is_empty(): counts = "%d/%d recruits at nest" % [entry.reserved, entry.requested]
	_text(view, center+Vector2(0,57), counts, 12, 2*radius-24)
	var waiting: String = "%d recalled · still traveling" % entry.returning if entry.get("returning",0)>0 else "Needs %d more workers" % entry.shortfall if entry.get("shortfall",0)>0 else "Waiting for travel food / party" if not entry.is_empty() else "Returned reports are snapshots"
	_text(view, center+Vector2(0,75), waiting, 12, 2*radius-28, Color("abb5b1"))
	for command: String in ["conflict_send","conflict_retreat","conflict_survey","conflict_approach"]:
		var box: Rect2 = positions.buttons[command]
		if (editing or history_open) and positions.editor.intersects(box): continue
		view.draw_line(center+(box.get_center()-center).normalized()*radius, box.get_center(), Color("645345"), 1.0, true)
		var blocked: String = reason(command,route,status)
		var title: String = {"conflict_send":"REINFORCE" if own_party(route,status) or kind(route,status)=="gather" else "SEND ANTS", "conflict_retreat":"RETREAT / CANCEL", "conflict_survey":"RECHECK DANGER" if not state.get("reports",{}).get(route.get("id"),{}).is_empty() else "INVESTIGATE", "conflict_approach":"ANOTHER APPROACH"}[command]
		var detail: String = {"conflict_send":"Choose workers and commitment", "conflict_retreat":"Recall this trail and response", "conflict_survey":"3 workers · return with evidence", "conflict_approach":{"withdraw":"Recall gatherers to reroute", "waiting":"Wait for gatherers to return", "resume":"Resume the reported course", "test":"3 workers test a longer course"}[approach_action(route,status)]}[command]
		_button(view, box, title, blocked if not blocked.is_empty() else detail, not blocked.is_empty())
	_button(view,positions.buttons.conflict_reports,"REPORT HISTORY")
	if not editing and not history_open:
		var outcome: Dictionary = state.get("outcomes",{}).get(route.get("id"),{})
		_button(view,positions.buttons.journey_close,"INSPECT REMAINS" if outcome.get("goal", "clear")=="hunt" and outcome.get("outcome","")=="secured" else "INSPECT SOURCE")
		_button(view,positions.buttons.conflict_close,"×")
	if editing: _draw_editor(view,positions,route,status)
	elif history_open: _draw_history(view,positions,route,status)

func _draw_editor(view: Node2D, positions: Dictionary, route: Dictionary, status: Dictionary) -> void:
	var box: Rect2 = positions.editor
	Style.surface(view,box,Color("172024")); Style.surface(view,box,Color("8e7160"),true)
	_text(view,box.position+Vector2(130,23),"Choose the commitment",16,236)
	_text(view,box.position+Vector2(130,46),"Trail first → nest → optional other jobs" if draft_kind=="defend" else "Gatherers stay; add local workers",12,236)
	_text(view,box.position+Vector2(130,64),"%d free nest workers · carers held" % status.get("available_workers",0),12,236)
	_text(view,box.position+Vector2(130,87),"%d additional ants" % amount if own_party(route,status) or draft_kind=="gather" else "%d ants for this attempt" % amount,15,236)
	_button(view,positions.buttons.draft_less,"−1")
	_button(view,positions.buttons.draft_more,"+1")
	_button(view,positions.buttons.draft_suggest,"SUGGEST %d" % suggestion(route,status),"Starting point, not certainty")
	_button(view,positions.buttons.draft_goal,"HOLD THE JUNCTION" if draft_kind=="gather" else "HUNT FOR PROTEIN" if goal=="hunt" else "DRIVE PREDATOR AWAY", "Gathering workers also fight" if draft_kind=="gather" else "Locked for the sent party" if own_party(route,status) else "Tap to change · hunt adds risk")
	_button(view,positions.buttons.draft_all,"ALL HANDS: ON" if all_hands else "ALL HANDS: OFF", "May pause other jobs" if all_hands else "Use alerted trail and free nest workers")
	_text(view,box.position+Vector2(130,255),"Reduced jobs need reassignment" if all_hands else "Recalled ants must travel home first",12,236)
	_button(view,positions.buttons.draft_commit,"ORDER %d ANTS" % amount)
	_button(view,positions.buttons.draft_back,"BACK")

func _draw_history(view: Node2D, positions: Dictionary, route: Dictionary, status: Dictionary) -> void:
	var box: Rect2 = positions.editor
	Style.surface(view,box,Color("172024")); Style.surface(view,box,Color("8e7160"),true)
	_text(view,box.position+Vector2(130,25),"Returned report history",16,236)
	var lines: Array[String] = []
	for record: Dictionary in _history_records(route,status): lines.append_array(record.lines)
	if lines.is_empty(): lines.append("No survey or response has returned")
	for i: int in lines.size(): _text(view,box.position+Vector2(130,52+i*15),lines[i],12,236)
	_button(view,positions.buttons.draft_back,"BACK TO CONFLICT")

func _history_records(route: Dictionary, status: Dictionary) -> Array[Dictionary]:
	var state: Dictionary = status.get("journey_response",{})
	var records: Array[Dictionary] = []
	var id: String = route.get("id","")
	var report: Dictionary = state.get("reports",{}).get(id,{})
	if not report.is_empty():
		var text: String = {"ambush":"Predator witnessed", "foreign":"Foreign ants witnessed", "mixed":"Predator and foreign ants", "surface":"Heavy impact witnessed", "inconclusive":"Attacker unidentified"}.get(report.finding,"Cause remains uncertain")
		records.append({"text":text,"received":report.received_at,"lines":["Survey: "+text,_report_dates(report,status)]})
	var outcome: Dictionary = state.get("outcomes",{}).get(id,{})
	if not outcome.is_empty():
		var text: String = Memory.defense_label(outcome)
		records.append({"text":text,"received":outcome.received_at,"lines":[text,"%d returned / %d sent" % [outcome.sent-outcome.lost,outcome.sent],_report_dates(outcome,status)]})
	var pressure: Dictionary = state.get("pressure_reports",{}).get(id,{})
	if not pressure.is_empty():
		var text: String = "Holding against resistance" if pressure.pressure=="holding" else "Resistance remains strong"
		records.append({"text":text,"received":pressure.received_at,"lines":[text,_report_dates(pressure,status)]})
	if route.get("conflict_report","")!="":
		var text: String = {"contested":"Junction contested","holding":"Junction holding","resisted":"Strong foreign resistance","reinforced":"Foreign reinforcements reported","secured":"Foreign force withdrew","withdrew":"Our ants withdrew","dispersed":"Encounter dispersed"}.get(route.conflict_report,"Junction report")
		records.append({"text":text,"received":route.conflict_received_at,"lines":[text,_report_dates({"received_at":route.conflict_received_at,"observed_at":route.get("conflict_observed_at",0)},status)]})
	var impact: Dictionary = route.get("impact_report",{})
	if not impact.is_empty(): records.append({"text":"Heavy surface impact reported","received":impact.received_at,"lines":["Heavy surface impact reported",_report_dates(impact,status)]})
	var approach: Dictionary = state.get("approach_reports",{}).get(id,{})
	if not approach.is_empty():
		var text: String = {"found":"Alternate course established","danger":"Danger on alternate course","unconfirmed":"Alternate course unconfirmed"}.get(approach.outcome,"Approach report")
		records.append({"text":text,"received":approach.received_at,"lines":[text,_report_dates(approach,status)]})
	records.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.received>b.received)
	return records

func _report_dates(report: Dictionary, status: Dictionary) -> String:
	var received: String = Copy.duration(status.get("time",0)-report.get("received_at",0))
	return "Seen %s ago · home %s ago" % [Copy.duration(status.get("time",0)-report.observed_at),received] if report.get("observed_at",0)>0 else "Arrived "+received+" ago"

func _latest(route: Dictionary, status: Dictionary) -> Dictionary:
	var state: Dictionary = status.get("journey_response",{})
	var text: String = "Cause remains uncertain"
	var received: float = float(route.get("last_loss_time",0))
	var pressure: Dictionary = state.get("pressure_reports",{}).get(route.get("id"),{})
	if own_party(route,status):
		text = "Awaiting the party's report"; received=0
		if state.get("mode")=="defend" and pressure.get("observed_at",0)>=status.get("time",0)-state.get("age",0) and not pressure.is_empty():
			text = "Holding against resistance" if pressure.pressure=="holding" else "Resistance remains strong"; received=pressure.received_at
	else:
		var records: Array[Dictionary] = _history_records(route,status)
		if not records.is_empty() and records[0].received>=received: text=records[0].text; received=records[0].received
	return {"text":text,"date":"Arrived " + Copy.duration(status.get("time",0)-received) + " ago" if received>0 else "No fresh return yet"}

func _identity(route: Dictionary, status: Dictionary) -> String:
	if route.get("surface_warning",false): return "Surface disturbance"
	var finding: String = status.get("journey_response",{}).get("reports",{}).get(route.get("id"),{}).get("finding","")
	if finding in ["ambush","mixed"]: return "Predatory arthropod"
	return "Foreign ants" if kind(route,status)=="gather" else "Unidentified threat"

func _source_name(route: Dictionary, status: Dictionary) -> String:
	return Memory.display_name({"knowledge_id":route.get("destination_knowledge_id",""),"category":route.get("category","carbohydrate"),"honeydew":route.get("destination_knowledge_id","")==status.get("honeydew",{}).get("knowledge_id","")})

func _impression(view: Node2D, at: Vector2, route: Dictionary, status: Dictionary) -> void:
	var identity: String = _identity(route,status)
	var color := Color("8c7866")
	if identity=="Predatory arthropod":
		var clear: bool = not status.get("journey_response",{}).get("pressure_reports",{}).get(route.get("id"),{}).is_empty() or not status.get("journey_response",{}).get("outcomes",{}).get(route.get("id"),{}).is_empty()
		view.draw_circle(at,14,Color(color,0.35)); view.draw_circle(at+Vector2(0,-15),7,Color(color,0.3))
		for side: int in [-1,1]:
			for i: int in (4 if clear else 2):
				var bend: Vector2 = at+Vector2(side*(22+i*2),-12+i*8)
				view.draw_polyline(PackedVector2Array([at+Vector2(side*8,-8+i*6),bend,bend+Vector2(side*8,9)]),Color(color,0.65 if clear else 0.22),1.2,true)
	elif identity=="Foreign ants":
		for i: int in 3:
			var ant: Vector2 = at+Vector2((i-1)*24,(i%2)*6)
			for part: int in 3: view.draw_circle(ant+Vector2(0,(part-1)*5),3,Color(color,0.6))
			for side: int in [-1,1]: view.draw_line(ant,ant+Vector2(side*8,5),Color(color,0.4),1,true)
	elif identity=="Surface disturbance":
		for i: int in 3: view.draw_arc(at+Vector2(0,i*7),28-i*4,PI*0.1,PI*0.9,16,Color(color,0.4-i*0.08),2,true)
	else:
		for i: int in 5: view.draw_circle(at+Vector2(sin(i*2.1)*17,cos(i*1.7)*11),10,Color(color,0.065))

func _button(view: Node2D, box: Rect2, title: String, detail: String = "", blocked: bool = false) -> void:
	Style.surface(view,box,Color("1a2022") if blocked else Color("283137"))
	Style.surface(view,box,Color("4f5149") if blocked else Color("806957"),true)
	_text(view,box.get_center()+Vector2(0,5 if detail.is_empty() else -3),title,13,box.size.x-12,Color("89938e") if blocked else Color("e1d6c4"))
	if not detail.is_empty(): _text(view,box.get_center()+Vector2(0,15),detail,11,box.size.x-10,Color("a2aaa4"))

func _text(view: Node2D, at: Vector2, value: String, font_size: int, width: float, color: Color = Color("d7dacf")) -> void:
	var font: Font = ThemeDB.fallback_font
	var fitted: String = Copy.fit_line(value,font,font_size,width)
	var extent: float = font.get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	view.draw_string(font,at-Vector2(extent*0.5,0),fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
