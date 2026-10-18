class_name AdaptationWeb
extends RefCounted
## Knowledge-derived attention graph, not a physical network or a hidden tech tree.

const Style = preload("res://src/presentation/organic_ui.gd")
const Art = preload("res://src/presentation/sensory_art.gd")

const LEAVES: Array[String] = ["lean","load","fighter","efficient_nurses","security","tolerance","heat_resilience","moisture_resilience","persistent","rapid_repair"]
const HIT_RADIUS: float = 22.0

static func positions(size: Vector2) -> Dictionary:
	var width: float = size.x - 340.0
	var result: Dictionary = {"foraging":Vector2(24+width*0.5,164)}
	for index: int in LEAVES.size():
		var row: int = index / 4
		var column: int = index % 4
		result[LEAVES[index]]=Vector2(24+width*(0.10+column*0.26),lerpf(246,size.y-198,row/2.0))
	result.honeydew=Vector2(24+width*0.88,size.y-198)
	return result

static func visible_nodes(status: Dictionary, _family: String = "") -> Array[String]:
	var result: Array[String]=["foraging"]
	result.append_array(LEAVES)
	if not status.get("honeydew",{}).is_empty(): result.append("honeydew")
	return result

static func known(status: Dictionary, id: String) -> bool:
	if id=="honeydew": return not status.get("honeydew",{}).is_empty()
	return id=="foraging" or id in ["lean","load"] or status.get("adaptation_options",{}).has(id)

static func node_at(at: Vector2, size: Vector2, status: Dictionary, _family: String = "") -> String:
	var centers: Dictionary = positions(size)
	for id: String in visible_nodes(status):
		if at.distance_to(centers[id])<=HIT_RADIUS: return id
	return ""

static func trait_state(status: Dictionary, id: String) -> String:
	if not known(status,id): return "Undiscovered"
	if status.get("adaptation_queue", {}).get("trait_id", "") == id:
		return "Queued · next brood"
	if status.get("adaptation_trial", {}).get("adaptation_id", "") == id:
		return "Growing trial brood"
	if id in ["lean","load"] and status.get("adaptation_options",{}).has(id):
		var option: Dictionary=status.adaptation_options[id]
		if option.get("inherited",false): return "Inherited · %d adult carriers" % option.get("expressed",0)
		var other: String="load" if id=="lean" else "lean"
		if status.adaptation_options.get(other,{}).get("inherited",false) or status.get("adaptation_trial",{}).get("adaptation_id","")==other: return "Other branch chosen"
		if option.get("available",false): return "Available · queue maternal brood"
	if id in ["persistent", "security", "tolerance", "fighter","efficient_nurses","heat_resilience","moisture_resilience","rapid_repair"]:
		var option: Dictionary = status.get("adaptation_options", {}).get(id, {})
		if option.get("inherited", false):
			return "Inherited · %d adult carriers" % option.get("expressed", 0)
		if id in ["security", "tolerance"]:
			var other: String = "tolerance" if id == "security" else "security"
			if status.get("adaptation_options", {}).get(other, {}).get("inherited", false) or status.get("adaptation_trial", {}).get("adaptation_id", "") == other:
				return "Other branch chosen"
		if option.get("available", false): return "Available · queue next brood"
		if id=="rapid_repair" and not status.get("repair_candidate",false): return "Needs later brood to reach pupae"
		if id in BroodEnvironment.TRAITS and id not in status.get("environment_candidates",[]): return "Needs exposed larvae to reach pupae"
		if id=="efficient_nurses" and not status.get("care_candidate",false): return "Needs supported brood emergence"
		return "Candidate · variation observed" if status.get("adaptation_trial", {}).is_empty() else "Another trial is growing"
	if status.get("adaptation_repertoire", "") == id:
		return "Inherited · %d adult carriers" % status.get("adapted_workers", 0)
	if status.get("adaptation_repertoire", "") != "" or status.get("adaptation_trial", {}).get("adaptation_id", "") in ["lean", "load"]:
		return "Other branch chosen"
	if status.get("adaptation_options", {}).get(id, {}).get("available", false):
		return "Available · queue next brood"
	if status.get("adaptation_trial", {}).get("adaptation_id", "") in ["persistent", "security", "tolerance", "fighter"]:
		return "Another trial is growing"
	if status.get("adaptation_repertoire", "") != "" or not status.get("adaptation_trial", {}).is_empty():
		return "Other branch chosen"
	return "Brood trial available"

static func title(id: String) -> String:
	return TraitCatalog.DEFINITIONS[id].title if TraitCatalog.DEFINITIONS.has(id) else {"foraging":"Colony repertoire","honeydew":"Honeydew relationship"}.get(id,"Trait")


static func short_title(id: String) -> String:
	return TraitCatalog.DEFINITIONS[id].short_title if TraitCatalog.DEFINITIONS.has(id) and not TraitCatalog.DEFINITIONS[id].short_title.is_empty() else title(id)

static func queue_wait(status: Dictionary) -> String:
	var waiting: String = status.get("adaptation_queue", {}).get("waiting", "none")
	if waiting == "ready":
		return "Ready · resume to lay" if status.get("paused", false) else "Ready · lays on next tick"
	return {"space": "Waiting for Nursery space", "trial": "Waiting for current trial to finish",
		"priority":"Reproductives have next priority",
		"nurses": "Waiting for two available nurses", "population": "Population limit reached",
		"carbohydrate": "Waiting for trial carbs", "protein": "Waiting for trial protein",
		"water": "Waiting for trial water", "unavailable": "Trait unavailable"}.get(waiting, "")


static func draw_graph(view: Node2D, size: Vector2, status: Dictionary, selected: String, phase: float) -> void:
	var centers: Dictionary = positions(size)
	# Branches group related variation; they do not invent purchase prerequisites.
	for pair: Array in [["foraging","lean"],["lean","load"],["foraging","fighter"],["fighter","efficient_nurses"],["lean","security"],["security","tolerance"],["fighter","heat_resilience"],["heat_resilience","moisture_resilience"],["security","persistent"],["persistent","rapid_repair"]]:
		var start: Vector2=centers[pair[0]]
		var finish: Vector2=centers[pair[1]]
		var points:=PackedVector2Array()
		var control: Vector2=(start+finish)*0.5+Vector2(18,-18)
		for index: int in 17:
			var t: float=index/16.0
			points.append(start*(1-t)*(1-t)+control*2*(1-t)*t+finish*t*t)
		var tint: Color=Color("bb86f1") if known(status,pair[1]) else Color("514458")
		view.draw_polyline(points,Color(tint,0.12),8,true)
		view.draw_polyline(points,Color(tint,0.48),1.2,true)
	if centers.has("honeydew") and not status.get("honeydew",{}).is_empty():
		view.draw_line(centers.moisture_resilience,centers.honeydew,Color("7ebba2"),1,true)
	for id: String in visible_nodes(status):
		var at: Vector2=centers[id]
		var discovered: bool=known(status,id)
		var color: Color=Color("6e6577") if not discovered else Color("8ed9af") if id=="honeydew" else Color("bc8bf2")
		var state: String=trait_state(status,id) if id not in ["foraging","honeydew"] else ""
		Style.orb(view,Rect2(at-Vector2.ONE*22,Vector2.ONE*44),color,id==selected)
		if not discovered:
			view._label(at+Vector2(0,7),"?",Color("a59aae"),23,HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var lobes: int=3 if id=="foraging" else 5 if id in ["fighter","heat_resilience","moisture_resilience"] else 2
			for index: int in lobes:
				var dot: Vector2=at+Vector2.from_angle(index*TAU/lobes+phase*.08)*9
				view.draw_line(at,dot,Color(color,0.6),1,true)
				view.draw_circle(dot,2.7,Color(color,0.8))
		if state.begins_with("Inherited"): view.draw_arc(at,25,0,TAU,32,Color("99dab1"),1.7,true)
		elif state=="Growing trial brood": view.draw_arc(at,25,phase,phase+PI*1.5,24,color,2,true)
		elif state.begins_with("Queued"): view.draw_arc(at,25,0,PI*1.5,24,Style.GOLD,2,true)
		var label: String="?" if not discovered else "Colony repertoire" if id=="foraging" else {"persistent":"Trail Persistence","rapid_repair":"Trail Repair"}.get(id,short_title(id))
		label=preload("res://src/presentation/interface_text.gd").fit_line(label,ThemeDB.fallback_font,12,(size.x-340)*0.25)
		view._label(at+Vector2(0,37),label,color,12,HORIZONTAL_ALIGNMENT_CENTER)
		var subtitle: String="Undiscovered" if not discovered else "Inherited" if state.begins_with("Inherited") else "Queued" if state.begins_with("Queued") else "Growing" if state=="Growing trial brood" else "Other branch" if state=="Other branch chosen" else "Available" if state.begins_with("Available") else "Inspect" if id not in ["foraging","honeydew"] else "Learn / grow / inherit" if id=="foraging" else "Ecological relationship"
		view._label(at+Vector2(0,52),subtitle,Color(color,0.7),10,HORIZONTAL_ALIGNMENT_CENTER)
