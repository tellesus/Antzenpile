class_name ChamberSet
extends RefCounted
var projects: Dictionary[String,ChamberProject]={}
func complete(id: String) -> bool: return projects.has(id) and projects[id].phase=="complete"
func reproductive_spaces() -> int:
	return ChamberCatalog.DEFINITIONS.reproductive_alcove.reproductive_spaces if complete("reproductive_alcove") else 0
func climate_step(base: int) -> int:
	return floori(float(base)*ChamberCatalog.DEFINITIONS.ventilation_gallery.climate_gain_percent/100.0) if complete("ventilation_gallery") else base
func to_dict() -> Array[Dictionary]:
	var result: Array[Dictionary]=[];var ids: Array=projects.keys();ids.sort()
	for id: String in ids: result.append(projects[id].to_dict())
	return result
func restore(data: Variant, ledger: WorkerLedger, pile: String, nursery: String) -> bool:
	if not data is Array or data.size()>ChamberCatalog.DEFINITIONS.size(): return false
	var restored: Dictionary[String,ChamberProject]={}
	for item: Variant in data:
		var project:=ChamberProject.new()
		if not project.restore(item) or restored.has(project.id) or project.phase!="queued" and nursery!="developed": return false
		var definition: ChamberDefinition=ChamberCatalog.DEFINITIONS[project.id]
		var record: Dictionary=ledger.to_dict().commitments.get("organ:"+pile+":"+project.id,{})
		if project.phase=="developing":
			if record.get("kind")!="internal" or record.get("owner_id")!=pile or record.get("count")!=definition.workers: return false
		elif not record.is_empty(): return false
		restored[project.id]=project
	for id: String in ledger.to_dict().commitments:
		if not id.begins_with("organ:"): continue
		var parts: PackedStringArray=id.split(":")
		if parts.size()!=3 or parts[1]!=pile or not restored.has(parts[2]) or restored[parts[2]].phase!="developing": return false
	projects=restored;return true
