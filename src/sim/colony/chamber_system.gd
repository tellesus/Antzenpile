class_name ChamberSystem
extends RefCounted
var _run: RunState
var last_error: String=""
func _init(run: RunState) -> void: _run=run
func order(pile_id: String, chamber_id: Variant, cancel: bool=false) -> bool:
	if not _run.colony.piles.has(pile_id) or not chamber_id is String or not ChamberCatalog.DEFINITIONS.has(chamber_id): return _reject("Unknown pile or chamber")
	var pile: PileState=_run.colony.piles[pile_id]
	if cancel:
		if not pile.chambers.projects.has(chamber_id) or pile.chambers.complete(chamber_id): return _reject("Only pending or developing projects can be canceled")
		var project: ChamberProject=pile.chambers.projects[chamber_id]
		if project.phase=="developing":
			var commitment: String="organ:"+pile_id+":"+chamber_id
			if not pile.workers.release(commitment,ChamberCatalog.DEFINITIONS[chamber_id].workers): return _reject("Construction labor unavailable")
			var retired: bool=pile.workers.retire_commitment(commitment);assert(retired)
		pile.chambers.projects.erase(chamber_id)
	else:
		if pile.chambers.projects.has(chamber_id): return _reject("Chamber already ordered or complete")
		var project:=ChamberProject.new();project.id=chamber_id;pile.chambers.projects[chamber_id]=project
	last_error="";return true
func blocker(pile: PileState, definition: ChamberDefinition) -> String:
	if pile.nursery_state!="developed": return "Develop Nursery first"
	if pile.workers_assignable<definition.workers: return "Need %d free construction workers; carers held" % definition.workers
	for id: String in PileState.RESOURCE_IDS:
		if pile.resources[id]<definition.costs()[id]: return "Need %.0f %s for construction" % [definition.costs()[id],id]
	return ""
func tick() -> void:
	var piles: Array=_run.colony.piles.keys();piles.sort()
	for pile_id: String in piles:
		var pile: PileState=_run.colony.piles[pile_id]
		var ids: Array=pile.chambers.projects.keys();ids.sort()
		for id: String in ids:
			var project: ChamberProject=pile.chambers.projects[id]
			var definition: ChamberDefinition=ChamberCatalog.DEFINITIONS[id]
			var commitment: String="organ:"+pile_id+":"+id
			if project.phase=="queued":
				if not blocker(pile,definition).is_empty(): continue
				if not pile.workers.create_commitment(commitment,"internal",pile_id): continue
				if not pile.allocate_workers(commitment,definition.workers): pile.workers.retire_commitment(commitment);continue
				if not pile.consume_resources(definition.costs()): pile.workers.release(commitment,definition.workers);pile.workers.retire_commitment(commitment);continue
				project.phase="developing"
				project.funded_tick=maxi(0,_run.clock.tick_count-1)
			if project.phase!="developing": continue
			project.progress_ticks+=1
			if project.progress_ticks<definition.duration_ticks: continue
			var released: bool=pile.workers.release(commitment,definition.workers);var retired: bool=pile.workers.retire_commitment(commitment);assert(released and retired)
			project.phase="complete"
func summary(pile_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not _run.colony.piles.has(pile_id): return result
	var pile: PileState=_run.colony.piles[pile_id]
	var ids: Array=ChamberCatalog.DEFINITIONS.keys();ids.sort()
	for id: String in ids:
		var definition: ChamberDefinition=ChamberCatalog.DEFINITIONS[id]
		var project: ChamberProject=pile.chambers.projects.get(id)
		result.append({"id":id,"name":definition.display_name,"description":definition.description,"phase":project.phase if project!=null else "unbuilt","progress":float(project.progress_ticks)/definition.duration_ticks if project!=null else 0,"workers":definition.workers,"duration":definition.duration_ticks*SimulationClock.TICK_INTERVAL,"costs":definition.costs(),"wait":blocker(pile,definition) if project==null or project.phase=="queued" else "","space":definition.reproductive_spaces,"occupied":pile.reproduction.occupied_space() if pile.chambers.complete(id) else 0})
	return result
func _reject(reason: String) -> bool: last_error=reason;return false
