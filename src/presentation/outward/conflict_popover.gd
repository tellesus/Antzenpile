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
	if finding in ["ambush", "mixed"] and not Memory.predator_addressed(route,state): return "defend"
	if route.get("foreign_reports", 0) > 0 or route.get("conflict_report", "") != "":return "gather"
	return "defend" if route.get("reported_losses",0)>0 and not Memory.predator_addressed(route,state) else ""

func searching(route: Dictionary, status: Dictionary) -> bool:
	return not own_party(route,status) and kind(route,status)=="defend" and status.get("journey_response",{}).get("reports",{}).get(route.get("id"),{}).get("finding","") not in ["ambush","mixed"]

func borrowing_copy() -> Dictionary:
	return {"title":"BORROW WORKERS FROM OTHER JOBS: " + ("ON" if all_hands else "OFF"),
		"detail":"Can interrupt gathering, cleaning and climate" if all_hands else "Idle nest ants; trail gatherers stay assigned" if draft_kind=="gather" else "Idle ants + workers recalled from this trail"}

func goal_editable(route: Dictionary, status: Dictionary) -> bool:
	return draft_kind=="defend" and not searching(route,status) and not own_party(route,status)

func limit(route: Dictionary, status: Dictionary) -> int:
	var committed: int = int(status.journey_response.get("workers",0)) if own_party(route,status) else int(route.get("allocated_workers",0)) if kind(route,status)=="gather" else 0
	return maxi(1, int(status.get("workers_total",0)) - committed)

func suggestion(route: Dictionary, status: Dictionary) -> int:
	return mini(limit(route, status), CONFIG.reinforcement_workers) if own_party(route, status) or kind(route, status) == "gather" else mini(limit(route, status), CONFIG.defense_workers)

func start_edit(route: Dictionary, status: Dictionary) -> void:
	editing = true; history_open = false
	draft_kind = kind(route, status)
	var entry: Dictionary = status.get("journey_response", {}).get("recruitment", {}).get(route.get("id"), {})
	amount = clampi(int(entry.get("requested", suggestion(route, status))), 1, limit(route, status))
	all_hands = entry.get("all_hands", false)
	goal = status.get("journey_response", {}).get("goal", "clear") if own_party(route, status) else status.get("journey_response", {}).get("goals", {}).get(route.get("id"), "clear")
	if searching(route,status):goal="clear"

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
	var editor := Rect2(center.x+radius+12, maxf(140, center.y-175), 320, 350)
	if editing:
		buttons.merge({"draft_less_many":Rect2(editor.position+Vector2(12,116),Vector2(44,44)),
			"draft_less":Rect2(editor.position+Vector2(62,116),Vector2(44,44)),
			"draft_suggest":Rect2(editor.position+Vector2(112,116),Vector2(96,44)),
			"draft_more":Rect2(editor.position+Vector2(214,116),Vector2(44,44)),
			"draft_more_many":Rect2(editor.position+Vector2(264,116),Vector2(44,44)),
			"draft_goal":Rect2(editor.position+Vector2(12,166),Vector2(296,44)),
			"draft_all":Rect2(editor.position+Vector2(12,216),Vector2(296,44)),
			"draft_commit":Rect2(editor.position+Vector2(12,302),Vector2(296,44)),
			"draft_back":Rect2(editor.position+Vector2(264,6),Vector2(44,44))})
	elif history_open:
		buttons.draft_back = Rect2(editor.position+Vector2(12,262),Vector2(236,44))
	var bounds := Rect2(Vector2(left, center.y-radius-62),Vector2(right+160-left, 2*radius+124))
	if editing or history_open: bounds = bounds.merge(editor)
	var portrait := Rect2(center + Vector2(-radius+24, -radius+48), Vector2(2*radius-48, radius-44))
	return {"center":center,"radius":radius,"buttons":buttons,"editor":editor,"bounds":bounds,"portrait":portrait}

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
		if route.get("surface_warning", false): return "Use avoidance for this ground hazard"
		if own_party(route, status):
			if state.get("mode") != "defend": return "Wait for the survey's return"
			if state.get("workers", 0) >= status.get("workers_total",0): return "Whole known workforce committed"
		if Memory.predator_addressed(route,state):return "Earlier response resolved this danger"
		if kind(route, status).is_empty(): return "Needs a returned loss or predator report"
	if action in ["conflict_survey", "conflict_approach"]:
		if state.get("away", false) or not state.get("other_party", "").is_empty(): return "Another response party is away"
		if state.get("recruitment", {}).has(route.get("id")): return "Cancel the recruitment order first"
		if action == "conflict_survey" and route.get("reported_losses", 0) == 0 and route.get("residue_report",{}).is_empty() and route.get("passage_memory",{}).is_empty(): return "Needs a returned loss or ground cue"
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
	view.draw_circle(center, radius+3, Color("ff637c",0.045))
	view.draw_circle(center, radius, Color("081219"))
	view.draw_arc(center, radius, 0, TAU, 96, Color("874958"), 1.2, true)
	view.draw_arc(center, radius-4, -PI*0.78, -PI*0.22, 32, Color("ff7c99",0.8), 1.8, true)
	_text(view, center+Vector2(0,-radius+22), identity, 15, 2*radius-18, Color("ffe1eb"))
	_text(view, center+Vector2(0,-radius+40), _source_name(route, status), 12, 2*radius-24, Color("9eaaa8"))
	var latest: Dictionary = _latest(route, status)
	var lines: Array[String] = summary_lines(latest.text, 12, 2*radius-18)
	for index: int in lines.size():
		_text(view, center+Vector2(0,14+index*15), lines[index], 12, 2*radius-18, Color("e4f4f8"))
	_text(view, center+Vector2(0,47), latest.date, 12, 2*radius-24, Color("92b5c2"))
	var entry: Dictionary = state.get("recruitment", {}).get(route.get("id"), {})
	var counts: String = "%d sent · awaiting report" % state.get("workers",0) if own_party(route,status) else "%d gatherers assigned" % route.get("allocated_workers",0)
	if not entry.is_empty(): counts = "%d/%d recruits at nest" % [entry.reserved, entry.requested]
	_text(view, center+Vector2(0,67), counts, 12, 2*radius-24)
	var waiting: String = "%d still traveling home" % entry.returning if entry.get("returning",0)>0 else "Needs %d more workers" % entry.shortfall if entry.get("shortfall",0)>0 else "Waiting for food / party" if not entry.is_empty() else "Memory · not live"
	_text(view, center+Vector2(0,83), waiting, 11, 2*radius-28, Color("92b5c2"))
	for command: String in ["conflict_send","conflict_retreat","conflict_survey","conflict_approach"]:
		var box: Rect2 = positions.buttons[command]
		if (editing or history_open) and positions.editor.intersects(box): continue
		view.draw_line(center+(box.get_center()-center).normalized()*radius, box.get_center(), Color("477581"), 1.0, true)
		var blocked: String = reason(command,route,status)
		var title: String = {"conflict_send":"REINFORCE" if own_party(route,status) or kind(route,status)=="gather" else "SEARCH & DEFEND" if searching(route,status) else "SEND ANTS", "conflict_retreat":"RETREAT / CANCEL", "conflict_survey":"RECHECK DANGER" if not state.get("reports",{}).get(route.get("id"),{}).is_empty() else "SURVEY DANGER", "conflict_approach":"ANOTHER APPROACH"}[command]
		var detail: String = {"conflict_send":"Choose response workers", "conflict_retreat":"Recall this trail and response", "conflict_survey":"Optional · 3 survey workers", "conflict_approach":{"withdraw":"Recall gatherers to reroute", "waiting":"Wait for gatherers to return", "resume":"Resume the reported course", "test":"3 workers test a longer course"}[approach_action(route,status)]}[command]
		_button(view, box, title, blocked if not blocked.is_empty() else detail, not blocked.is_empty())
	_button(view,positions.buttons.conflict_reports,"REPORT HISTORY")
	if not editing and not history_open:
		var outcome: Dictionary = state.get("outcomes",{}).get(route.get("id"),{})
		_button(view,positions.buttons.journey_close,"INSPECT REMAINS" if outcome.get("goal", "clear")=="hunt" and outcome.get("outcome","")=="secured" else "INSPECT SOURCE")
		_button(view,positions.buttons.conflict_close,"×")
	if editing: _draw_editor(view,positions,route,status)
	elif history_open: _draw_history(view,positions,route,status)

func preview(route: Dictionary, status: Dictionary) -> Dictionary:
	# Counts are detached knowledge, including unreported travelers, never bodies.
	var additional: bool = own_party(route,status) or draft_kind == "gather"
	var sent: int = int(status.journey_response.get("workers",0)) if own_party(route,status) else int(route.get("allocated_workers",0)) if draft_kind == "gather" else 0
	var entry: Dictionary = status.get("journey_response",{}).get("recruitment",{}).get(route.get("id"),{})
	return {"additional":additional,"sent":sent,"total":sent+amount,"requested":amount,
		"waiting":int(entry.get("requested",0)),"reserved":int(entry.get("reserved",0)),
		"returning":int(entry.get("returning",0)),"available":int(status.get("available_workers",0)),
		"action":"ADD %d ANTS" % amount if additional else "SEARCH & DEFEND · %d ANTS" % amount if searching(route,status) else "RECRUIT %d ANTS" % amount}

func receipt(result: Dictionary) -> String:
	if not result.get("accepted",false): return result.get("reason","Order unavailable")
	var text: String = "%d ants ordered" % result.get("ordered_total",amount)
	return text + (" · %d still recruiting" % result.waiting if result.get("waiting",0)>0 else " · awaiting their report")

func _draw_editor(view: Node2D, positions: Dictionary, route: Dictionary, status: Dictionary) -> void:
	var box: Rect2 = positions.editor
	var plan: Dictionary = preview(route,status)
	Style.surface(view,box,Color("111e29")); Style.surface(view,box,Color("568b9c"),true)
	_text(view,box.position+Vector2(136,25),"PROPOSED ADDITION" if plan.additional else "ARMED SEARCH" if searching(route,status) else "PROPOSED RESPONSE",15,240,Color("7de5ee"))
	_text(view,box.position+Vector2(160,49),("Already assigned %d · ordered total %d" if draft_kind=="gather" else "Already sent %d · ordered total %d") % [plan.sent,plan.total],13,296)
	_text(view,box.position+Vector2(160,78),("+%d ants" if plan.additional else "%d ants") % amount,23,296,Color("d9fbff"))
	_text(view,box.position+Vector2(160,101),"%d idle at nest · care & building protected" % plan.available,12,296)
	_button(view,positions.buttons.draft_less_many,"−5")
	_button(view,positions.buttons.draft_less,"−1")
	_button(view,positions.buttons.draft_more,"+1")
	_button(view,positions.buttons.draft_more_many,"+5")
	_button(view,positions.buttons.draft_suggest,"SET TO %d" % suggestion(route,status))
	var goal_title: String="HOLD THE JUNCTION" if draft_kind=="gather" else "SEARCH AND DEFEND" if searching(route,status) else "HUNT FOR PROTEIN" if goal=="hunt" else "DRIVE PREDATOR AWAY"
	var goal_detail: String="Gathering workers also fight" if draft_kind=="gather" else "Unknown threat · survey is optional" if searching(route,status) else "Locked for the sent party" if own_party(route,status) else "Tap to change · hunt adds risk"
	if goal_editable(route,status):_button(view,positions.buttons.draft_goal,goal_title,goal_detail)
	else:
		var center: Vector2=positions.buttons.draft_goal.get_center()
		_text(view,center+Vector2(0,-3),"GOAL: "+goal_title,13,284,Color("d5eaf0"))
		_text(view,center+Vector2(0,16),goal_detail,11,284,Color("91b2bf"))
	var borrowing: Dictionary=borrowing_copy()
	_button(view,positions.buttons.draft_all,borrowing.title,borrowing.detail)
	var consequence: String = "May recall aphid attendants, scouts & supplies."
	var detail: String = "Care/building protected; restart jobs yourself."
	if not all_hands:
		consequence = "Gatherers keep working while recruits join." if draft_kind=="gather" else "Recalled ants must reach home before joining."
		detail = "%d waiting · %d at nest · %d returning" % [plan.waiting,plan.reserved,plan.returning] if plan.waiting>0 else "Arrival and outcome need a returned report."
	_text(view,box.position+Vector2(160,279),consequence,12,296,Color("ffd083") if all_hands else Color("a4bdc5"))
	_text(view,box.position+Vector2(160,295),detail,12,296,Color("ffd083") if all_hands else Color("a4bdc5"))
	Style.surface(view,positions.buttons.draft_commit,Color("164757"))
	Style.surface(view,positions.buttons.draft_commit,Color("69dceb"),true)
	_text(view,positions.buttons.draft_commit.get_center()+Vector2(0,5),plan.action,16,280,Color("ddfcff"))
	_button(view,positions.buttons.draft_back,"×")

func _draw_history(view: Node2D, positions: Dictionary, route: Dictionary, status: Dictionary) -> void:
	var box: Rect2 = positions.editor
	Style.surface(view,box,Color("111e29")); Style.surface(view,box,Color("568b9c"),true)
	_text(view,box.position+Vector2(160,25),"Returned report history",16,296)
	var lines: Array[String] = []
	for record: Dictionary in _history_records(route,status): lines.append_array(record.lines)
	if lines.is_empty(): lines.append("No survey or response has returned")
	for i: int in lines.size(): _text(view,box.position+Vector2(160,52+i*15),lines[i],12,296)
	_button(view,positions.buttons.draft_back,"BACK TO CONFLICT")

func _history_records(route: Dictionary, status: Dictionary) -> Array[Dictionary]:
	var state: Dictionary = status.get("journey_response",{})
	var records: Array[Dictionary] = []
	var id: String = route.get("id","")
	var report: Dictionary = state.get("reports",{}).get(id,{})
	if not report.is_empty():
		var text: String = Memory.survey_label(report)
		records.append({"text":text,"received":report.received_at,"lines":["Survey: "+text,_report_dates(report,status)]})
	var outcome: Dictionary = state.get("outcomes",{}).get(id,{})
	if not outcome.is_empty():
		var text: String = Memory.defense_label(outcome)
		records.append({"text":text,"received":outcome.received_at,"priority":1,"lines":[text,"%d returned / %d sent" % [outcome.sent-outcome.lost,outcome.sent],_report_dates(outcome,status)]})
	var pressure: Dictionary = state.get("pressure_reports",{}).get(id,{})
	if not pressure.is_empty():
		var text: String = "Holding against resistance" if pressure.pressure=="holding" else "Resistance remains strong"
		records.append({"text":text,"received":pressure.received_at,"lines":[text,_report_dates(pressure,status)]})
	if route.get("conflict_report","")!="":
		var text: String = {"contested":"Junction contested","holding":"Junction holding","resisted":"Strong foreign resistance","reinforced":"Foreign reinforcements reported","secured":"Foreign force withdrew","withdrew":"Our ants withdrew","dispersed":"Encounter dispersed"}.get(route.conflict_report,"Junction report")
		var lines: Array=[text,_report_dates({"received_at":route.conflict_received_at,"observed_at":route.get("conflict_observed_at",0)},status)]
		if route.conflict_report=="secured":lines.append("Encounter ended · later traffic remains uncertain")
		records.append({"text":text,"received":route.conflict_received_at,"lines":lines})
	var impact: Dictionary = route.get("impact_report",{})
	if not impact.is_empty(): records.append({"text":"Heavy surface impact reported","received":impact.received_at,"lines":["Heavy surface impact reported",_report_dates(impact,status)]})
	var residue: Dictionary=route.get("residue_report",{})
	if not residue.is_empty(): records.append({"text":"Strange ground residue reported","received":residue.received_at,"lines":["Strange ground residue reported",_report_dates(residue,status)]})
	var passage: Dictionary=route.get("passage_memory",{})
	if not passage.is_empty():
		var text: String=Memory.passage_name(passage.impression)+" witnessed"
		records.append({"text":text,"received":passage.received_at,"lines":[text,_report_dates(passage,status)]})
	var approach: Dictionary = state.get("approach_reports",{}).get(id,{})
	if not approach.is_empty():
		var text: String = {"found":"Alternate course established","danger":"Danger on alternate course","unconfirmed":"Alternate course unconfirmed"}.get(approach.outcome,"Approach report")
		records.append({"text":text,"received":approach.received_at,"lines":[text,_report_dates(approach,status)]})
	records.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.received>b.received if a.received!=b.received else a.get("priority",0)>b.get("priority",0))
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
	if route.get("surface_warning",false): return "Strange ground residue" if route.get("warning_kind","")=="residue" else Memory.passage_name(route.get("passage_memory",{}).get("impression",""))
	var report: Dictionary = status.get("journey_response",{}).get("reports",{}).get(route.get("id"),{})
	if report.get("finding", "") in ["ambush","mixed"]: return Memory.predator_name(report.get("predator_profile", ""))
	return "Foreign ants" if kind(route,status)=="gather" else "Unidentified threat"

func _source_name(route: Dictionary, status: Dictionary) -> String:
	return Memory.display_name({"knowledge_id":route.get("destination_knowledge_id",""),"category":route.get("category","carbohydrate"),"source_type":route.get("source_type",""),"memory_label":route.get("memory_label",""),"honeydew":route.get("destination_knowledge_id","")==status.get("honeydew",{}).get("knowledge_id","")})

static func summary_lines(value: String, font_size: int, width: float) -> Array[String]:
	var lines: Array[String] = [""]
	var font: Font = ThemeDB.fallback_font
	for word: String in value.split(" ", false):
		var next: String = word if lines[-1].is_empty() else lines[-1] + " " + word
		if lines.size() == 1 and not lines[0].is_empty() and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(word)
		else: lines[-1] = next
	return lines


func _button(view: Node2D, box: Rect2, title: String, detail: String = "", blocked: bool = false) -> void:
	Style.surface(view,box,Color("111d25") if blocked else Color("183441"))
	Style.surface(view,box,Color("3c5662") if blocked else Color("568b9c"),true)
	var lines: Array[String] = []
	if box.size.y>=54: lines = summary_lines(detail,11,box.size.x-12)
	else: lines.append(detail)
	var two_lines: bool = lines.size()>1
	_text(view,box.get_center()+Vector2(0,5 if detail.is_empty() else -12 if two_lines else -3),title,13,box.size.x-12,Color("8099a5") if blocked else Color("dcf5fb"))
	if not detail.is_empty():
		for index: int in lines.size():
			_text(view,box.get_center()+Vector2(0,5+index*13 if two_lines else 15),lines[index],11,box.size.x-12,Color("94b4c1"))

func _text(view: Node2D, at: Vector2, value: String, font_size: int, width: float, color: Color = Color("d7dacf")) -> void:
	var font: Font = ThemeDB.fallback_font
	var fitted: String = Copy.fit_line(value,font,font_size,width)
	var extent: float = font.get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	view.draw_string(font,at-Vector2(extent*0.5,0),fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
