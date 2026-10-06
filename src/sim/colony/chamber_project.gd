class_name ChamberProject
extends RefCounted
var id: String=""
var phase: String="queued"
var progress_ticks: int=0
var funded_tick: int=0
func to_dict() -> Dictionary: return {"id":id,"phase":phase,"progress_ticks":progress_ticks,"funded_tick":funded_tick}
func restore(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=4 or not data.has_all(["id","phase","progress_ticks","funded_tick"]) or not data.id is String or data.id not in ChamberCatalog.DEFINITIONS or data.phase not in ["queued","developing","complete"] or not WorkerLedger.valid_count(data.progress_ticks) or not WorkerLedger.valid_count(data.funded_tick): return false
	var duration: int=ChamberCatalog.DEFINITIONS[data.id].duration_ticks
	if data.progress_ticks>duration or data.phase=="queued" and (data.progress_ticks!=0 or data.funded_tick!=0) or data.phase=="developing" and data.progress_ticks>=duration or data.phase=="complete" and data.progress_ticks!=duration: return false
	id=data.id;phase=data.phase;progress_ticks=int(data.progress_ticks);funded_tick=int(data.funded_tick)
	return true
