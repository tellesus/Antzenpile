class_name RunReview
extends Node2D
## Post-run truth only. Stored keyframes do not drive or resume simulation.

const UIStyle = preload("res://src/presentation/organic_ui.gd")
const EVENT_LABELS: Dictionary = {"worker_loss": "Workers lost", "brood_loss": "Brood lost", "emergence": "Workers emerged", "pile_established": "Pile established", "trail_changed": "Trail changed", "findings_returned": "Findings returned", "rain_start": "Rain started", "rain_end": "Rain ended", "surface_impact": "Surface impact", "predator_loss": "Predator losses", "impact_loss": "Surface-impact losses", "rival_loss": "Rival losses", "predator_killed": "Predator killed", "food_toxicity_loss": "Food poisoning losses"}
const PREDATOR = preload("res://data/ecology/backyard_predator.tres")
const IMPACT = preload("res://data/weather/roadside_surface_impact.tres")
const RIVAL = preload("res://data/ecology/backyard_rival.tres")
var new_command: Callable
var load_command: Callable
var data: Dictionary = {}
var cursor: int = 0
var playing: bool = false
var playback_time: float = 0
var selected_id: String = ""
var feedback: String = ""
var _font: Font = ThemeDB.fallback_font
var _dragging: bool = false

func open(snapshot: Dictionary) -> void:
	data=snapshot.duplicate(true); visible=not data.is_empty(); playing=false; selected_id=""; feedback=""
	cursor=data.history.frames.size()-1 if visible else 0
	set_process(visible); set_process_input(visible)

func _ready() -> void:
	if data.is_empty(): visible=false; set_process(false); set_process_input(false)

func map_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size
	var edge: float = minf(size.y-264,size.x-350)
	return Rect2(32,112,edge,edge)

func timeline_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size
	return Rect2(32,size.y-116,size.x-64,44)

func button_rect(action: String) -> Rect2:
	var index: int = ["first","previous","play","next","last","new","load"].find(action)
	var width: float = (get_viewport_rect().size.x-100)/7
	return Rect2(32+index*(width+6),get_viewport_rect().size.y-60,width,44)

func event_rect(index: int) -> Rect2:
	return Rect2(map_rect().end.x+32,350+index*30,get_viewport_rect().size.x-map_rect().end.x-56,28)

func _process(delta: float) -> void:
	if playing:
		playback_time+=delta*30
		while cursor<data.history.frames.size()-1 and float(data.history.frames[cursor+1].tick)*0.25<=playback_time: cursor+=1
		if cursor==data.history.frames.size()-1: playing=false
	queue_redraw()

func _scrub(at: Vector2) -> void:
	var frames: Array = data.history.frames
	var start: float = float(frames[0].tick); var finish: float = float(frames.back().tick)
	var tick: float = lerpf(start,finish,clampf((at.x-timeline_rect().position.x)/timeline_rect().size.x,0,1))
	cursor=_nearest(tick); playing=false

func _nearest(tick: float) -> int:
	var result: int = 0
	for index: int in data.history.frames.size():
		if absf(float(data.history.frames[index].tick)-tick)<absf(float(data.history.frames[result].tick)-tick): result=index
	return result

func activate_at(at: Vector2) -> bool:
	if not visible: return false
	if timeline_rect().has_point(at): _scrub(at); _dragging=true; return true
	for action: String in ["first","previous","play","next","last","new","load"]:
		if not button_rect(action).has_point(at): continue
		playing=false
		match action:
			"first":cursor=0
			"previous":cursor=maxi(0,cursor-1)
			"next":cursor=mini(data.history.frames.size()-1,cursor+1)
			"last":cursor=data.history.frames.size()-1
			"play":
				if cursor==data.history.frames.size()-1: cursor=0
				playing=true; playback_time=float(data.history.frames[cursor].tick)*0.25
			"new":
				if new_command.is_valid(): new_command.call()
			"load":
				if load_command.is_valid():
					var result: Dictionary = load_command.call()
					if not result.accepted: feedback=result.reason
		return true
	var recent: Array = _recent_events()
	for index: int in recent.size():
		if event_rect(index).has_point(at): cursor=_nearest(float(recent[index].tick)); playing=false; return true
	var frame: Dictionary = data.history.frames[cursor]
	for item: Dictionary in frame.piles+frame.nodes:
		if _at(item.position).distance_to(at)<18: selected_id=item.id; return true
	selected_id=""; return true

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT or event is InputEventScreenTouch:
		if event.pressed: activate_at(event.position)
		else: _dragging=false
	elif _dragging and (event is InputEventMouseMotion or event is InputEventScreenDrag): _scrub(event.position)
	get_viewport().set_input_as_handled()

func _at(point: Array) -> Vector2:
	var bounds: Array = data.bounds
	return map_rect().position+Vector2((point[0]-bounds[0])/bounds[2],(point[1]-bounds[1])/bounds[3])*map_rect().size

func _recent_events() -> Array:
	var result: Array = []; var tick: int = data.history.frames[cursor].tick.to_int()
	for event: Dictionary in data.history.events:
		if event.tick.to_int()<=tick: result.append(event)
	return result.slice(maxi(0,result.size()-4))

func _draw() -> void:
	if not visible or data.is_empty(): return
	draw_rect(get_viewport_rect(),Color("050708"))
	_label(Vector2(32,38),"COLONY HISTORY  /  PHYSICAL REVEAL",24,Color("e6d5af"))
	_label(Vector2(32,65),"This run has ended. Review reveals what the colony could not see.",15,Color("b9bcb7"))
	_label(Vector2(32,91),"%s  /  seed %s  /  %s" % [ScenarioCatalog.label_for(data.scenario),data.seed,_time(float(data.history.frames[cursor].tick)*0.25)],14,Color("9bbbc0"))
	var rect: Rect2 = map_rect(); UIStyle.surface(self,rect,Color("192123"))
	for region: Dictionary in data.terrain:
		var p: Vector2 = _at([region.bounds[0],region.bounds[1]])
		var end: Vector2 = _at([region.bounds[0]+region.bounds[2],region.bounds[1]+region.bounds[3]])
		draw_rect(Rect2(p,end-p),Color(0.20,0.27,0.22,0.2) if region.traversable else Color(0.38,0.29,0.17,0.45))
	var frame: Dictionary = data.history.frames[cursor]
	for trail: Dictionary in frame.trails:
		var points := PackedVector2Array()
		for point: Array in trail.points: points.append(_at(point))
		draw_polyline(points,Color(0.85,0.68,0.36,0.35+0.6*trail.scent),2,true)
	if frame.predator:
		_zone(PREDATOR.position,PREDATOR.radius,Color("b76d60"),"Ambusher")
	if frame.impact: _zone(IMPACT.position,IMPACT.radius,Color("d99658"),"Surface impact")
	if frame.rival:
		var at: Vector2 = _at([RIVAL.pile_position.x,RIVAL.pile_position.y])
		draw_rect(Rect2(at-Vector2(5,5),Vector2(10,10)),Color("b56fa6")); _label(at+Vector2(9,4),"Rival pile",12,Color("b56fa6"))
	for node: Dictionary in frame.nodes:
		var at: Vector2 = _at(node.position)
		var color: Color = Color("68baca") if node.kind=="water" else Color("c89767") if node.kind=="protein" else Color("a2ad84") if node.kind=="nest_site" else Color("cbb574")
		if not node.active or node.quantity<=0: draw_arc(at,5,0,TAU,16,color*Color(1,1,1,0.5),1,true)
		else: draw_circle(at,5,color)
		if node.known: draw_arc(at,9,0,TAU,20,Color("ccccbc"),1,true)
		if selected_id==node.id: draw_arc(at,14,0,TAU,24,Color.WHITE,1,true)
	for pile: Dictionary in frame.piles:
		var at: Vector2 = _at(pile.position)
		draw_circle(at,8,Color("edd49d")); _label(at+Vector2(13,4),"Home" if pile.id=="home" else "Daughter",13,Color("edd49d"))
	for scout: Dictionary in frame.scouts: draw_circle(_at(scout.position),2,Color("e5e8e0"))
	if frame.rain: _label(rect.position+Vector2(12,24),"RAIN",15,Color("68baca"))
	var side: Vector2 = Vector2(rect.end.x+32,126)
	_label(side,"WHAT WAS REALLY THERE",16,Color("e6d5af"))
	_label(side+Vector2(0,27),"Filled source: available  /  ring: empty",13,Color("aebbb9"))
	_label(side+Vector2(0,49),"Outer ring: returned colony memory",13,Color("aebbb9"))
	_label(side+Vector2(0,71),"Dots: scouts  /  lines: physical trails",13,Color("aebbb9"))
	var swatches: Array = [["Water","68baca"],["Protein","c89767"],["Carbs","cbb574"],["Shelter","a2ad84"]]
	for index: int in swatches.size():
		var at: Vector2 = side+Vector2(index*94,91)
		draw_circle(at+Vector2(3,-4),3,Color(swatches[index][1]))
		_label(at+Vector2(11,0),swatches[index][0],12,Color(swatches[index][1]))
	_label(side+Vector2(0,120),"Workers %d  /  lost %d  /  brood lost %d" % [frame.stats[0],frame.stats[1],frame.stats[2]],14,Color("ded0b7"))
	var detail: Array[String] = ["Tap a source or pile to inspect."]
	for item: Dictionary in frame.piles+frame.nodes:
		if item.id!=selected_id: continue
		detail=[item.id.replace("_"," ")]
		if item.has("quantity"): detail.append("%s: %.1f physically present" % [item.kind,item.quantity]); detail.append("Returned memory exists" if item.known else "Unknown to colony at this time")
		else: detail.append("%d workers / %d brood" % [item.workers,item.brood]); detail.append("Stores %.1f / %.1f / %.1f" % item.stores)
	for index: int in detail.size(): _label(side+Vector2(0,146+index*22),detail[index],14,Color("b8c9c8"))
	_label(side+Vector2(0,215),"RECENT EVENTS  /  TAP TO JUMP",13,Color("e6d5af"))
	var recent: Array = _recent_events()
	for index: int in recent.size():
		UIStyle.surface(self,event_rect(index),Color("172328"))
		_label(event_rect(index).position+Vector2(8,19),"%s  %s%s" % [_time(float(recent[index].tick)*0.25),EVENT_LABELS.get(recent[index].kind,recent[index].kind)," +%d" % recent[index].amount if recent[index].amount>0 else ""],12,Color("c5ccbf"))
	var note: String = "Keyframes: changes between samples are approximate."
	if data.history.thinned: note="Older history is thinned; recent samples retained."
	if data.history.omitted_events>0: note+=" %d earlier event notes omitted." % data.history.omitted_events
	_label(Vector2(32,get_viewport_rect().size.y-142),note,13,Color("929f9f"))
	if not feedback.is_empty(): _label(side+Vector2(0,353),feedback,13,Color("e1a17c"))
	var timeline: Rect2 = timeline_rect(); UIStyle.surface(self,timeline,Color("1b282c"))
	var first: float = float(data.history.frames[0].tick); var last: float = float(data.history.frames.back().tick)
	var fraction: float = (float(frame.tick)-first)/(last-first) if last>first else 0
	draw_line(timeline.position+Vector2(8,22),timeline.end-Vector2(8,22),Color("637372"),2)
	for event: Dictionary in data.history.events:
		var event_fraction: float = (float(event.tick)-first)/(last-first) if last>first else 0
		var at: Vector2 = timeline.position+Vector2(8+(timeline.size.x-16)*event_fraction,22)
		draw_line(at-Vector2(0,5),at+Vector2(0,5),Color("ba895b"),1)
	draw_circle(timeline.position+Vector2(8+(timeline.size.x-16)*fraction,22),6,Color("edcf94"))
	_label(timeline.position+Vector2(12,15),"Recorded from %s" % _time(first*0.25),11,Color("bec8c0"))
	for action: String in ["first","previous","play","next","last","new","load"]:
		UIStyle.surface(self,button_rect(action),Color("283c35") if action=="new" else Color("19282f"))
		var label: String = {"first":"FIRST","previous":"PREVIOUS","play":"PAUSE" if playing else "PLAY 30x","next":"NEXT","last":"LAST","new":"NEW COLONY","load":"LOAD SAVED"}[action]
		_label(button_rect(action).position+Vector2(12,28),label,13,Color("ded7bf"))

func _zone(position: Vector2, radius: float, color: Color, text: String) -> void:
	var at: Vector2 = _at([position.x,position.y]); var extent: float = radius/data.bounds[2]*map_rect().size.x
	draw_circle(at,extent,Color(color,0.13)); draw_arc(at,extent,0,TAU,32,color,1,true)
	_label(at+Vector2(extent+4,0),text,12,color)

func _label(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

static func _time(seconds: float) -> String:
	return "%dm %02ds" % [int(seconds)/60,int(seconds)%60]
