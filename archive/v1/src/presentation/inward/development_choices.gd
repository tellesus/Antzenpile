class_name DevelopmentChoices
extends RefCounted
## One view of existing functions and their improvements, from local summaries.
const Copy = preload("res://src/presentation/interface_text.gd")

static func entries(status: Dictionary, projects: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in ["food_exchange", "nursery", "midden", "nursery_expansion"]:
		var entry: Dictionary = {"id":id,"legacy":true,"inspect":"nursery" if id=="nursery_expansion" else id,"wait":"","progress":0.0}
		match id:
			"food_exchange":
				entry.merge({"name":"Food Exchange","state":status.get("food_exchange_state","primitive"),"now":"Food is already shared with brood.","after":"Larval food use drops by %.0f%%." % ((1.0-status.get("food_exchange_food_multiplier",0.75))*100),"costs":status.get("food_exchange_costs",{}),"workers":status.get("food_exchange_workers_required",4),"duration":status.get("food_exchange_duration",60.0),"elapsed":status.get("food_exchange_progress",0.0),"command":"develop"})
			"nursery":
				entry.merge({"name":"Nursery","state":status.get("nursery_state","primitive"),"now":"Basic space and brood care already work.","after":"%d brood spaces; climate staffing opens." % status.get("nursery_developed_capacity",16),"costs":status.get("nursery_costs",{}),"workers":status.get("nursery_workers_required",4),"duration":status.get("nursery_build_duration",90.0),"elapsed":status.get("nursery_progress",0.0),"command":"develop_nursery"})
			"midden":
				var midden: Dictionary=status.get("midden",{})
				entry.merge({"name":"Midden isolation","state":midden.get("state","primitive"),"now":"Cleaners can work the open refuse heap." if midden.get("revealed",false) else "Waste accumulates as ants live and feed.","after":"The same cleaners remove twice as much.","costs":midden.get("costs",{}),"workers":midden.get("build_workers",4),"duration":midden.get("build_seconds",90.0),"elapsed":midden.get("progress",0.0)*midden.get("build_seconds",90.0),"command":"develop_midden"})
				if not midden.get("revealed",false): entry.wait="Opens when accumulated waste reveals a refuse heap."
			"nursery_expansion":
				var expansion: Dictionary=status.get("nursery_expansion",{})
				entry.merge({"name":"Nursery expansion","state":expansion.get("state","latent"),"now":"Existing brood space stays usable during work.","after":"Increase Nursery space to %d." % expansion.get("capacity",32),"costs":expansion.get("costs",{}),"workers":expansion.get("workers",8),"duration":expansion.get("duration",180.0),"elapsed":expansion.get("progress_seconds",0.0),"command":"expand_nursery"})
				if entry.state=="latent": entry.wait="Needs developed Nursery, %d emerged workers and a full Nursery." % expansion.get("matured_required",16)
		entry.phase="complete" if entry.state in ["developed","expanded"] else "developing" if entry.state=="developing" else "unbuilt"
		entry.progress=clampf(float(entry.elapsed)/maxf(1.0,float(entry.duration)),0,1)
		if entry.phase=="unbuilt" and entry.wait.is_empty(): entry.wait=Copy.local_shortage(status,entry.costs,entry.workers)
		result.append(entry)
	for project: Dictionary in projects:
		var entry: Dictionary=project.duplicate(true)
		entry.legacy=false
		entry.now="No dedicated chamber yet." if entry.phase!="complete" else "Dedicated chamber is working."
		entry.after=entry.description
		result.append(entry)
	return result
