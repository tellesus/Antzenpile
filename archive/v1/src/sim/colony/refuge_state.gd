class_name RefugeState
extends RefCounted
## Reserved protected slots reference bodies; they never own a second queen/brood.
const CAPACITY: int=17
const WORKERS: int=4
const PREPARATION_TICKS: int=80
const COSTS: Dictionary={"carbohydrate":3.0,"water":2.0}
var priority: String="royals"
var phase: String="none"
var progress_ticks: int=0
var started_tick: int=0
var targets: Array[Dictionary]=[]
func reserved_space() -> int:
	var result: int=0
	for target: Dictionary in targets:result+=target.space
	return result
func protects(uid: String) -> bool:
	return phase=="ready" and targets.any(func(target: Dictionary)->bool:return target.uid==uid)
func to_dict() -> Dictionary:
	return {"priority":priority,"phase":phase,"progress_ticks":progress_ticks,"started_tick":started_tick,"targets":targets.duplicate(true)}
func restore(data: Variant, pile: PileState, tick: int) -> bool:
	if not data is Dictionary or data.size()!=5 or not data.has_all(to_dict().keys()) or data.priority not in ["royals","workers"] or data.phase not in ["none","preparing","ready"]:return false
	if not WorkerLedger.valid_count(data.progress_ticks) or not WorkerLedger.valid_count(data.started_tick) or data.started_tick>tick or data.progress_ticks>PREPARATION_TICKS or data.progress_ticks>tick-data.started_tick:return false
	if not data.targets is Array or data.targets.size()>CAPACITY:return false
	var parsed: Array[Dictionary]=[];var ids: Array[String]=[];var space: int=0
	for target: Variant in data.targets:
		if not target is Dictionary or target.size()!=3 or not target.has_all(["kind","uid","space"]) or target.kind not in ["queen","royal","brood"] or not target.uid is String or target.uid.length()>160 or target.uid in ids:return false
		if not WorkerLedger.valid_count(target.space) or target.space<1 or target.space>8 or target.kind=="queen" and target.space!=1 or target.kind=="royal" and target.space!=8:return false
		if target.kind in ["queen","royal"] and not target.uid.begins_with("queen:") or target.kind=="brood" and not target.uid.contains(":brood_"):return false
		ids.append(target.uid);space+=int(target.space);parsed.append({"kind":target.kind,"uid":target.uid,"space":int(target.space)})
	if space>CAPACITY:return false
	var pool: Dictionary=pile.workers.to_dict().commitments.get("refuge:"+pile.id,{})
	if data.phase=="none":
		if data.progress_ticks!=0 or data.started_tick!=0 or not parsed.is_empty() or not pool.is_empty():return false
	else:
		if not pile.chambers.complete("refuge_chamber") or parsed.is_empty() or pool.get("count",0)!=WORKERS or pool.get("kind","")!="internal" or pool.get("owner_id","")!=pile.id:return false
		if (data.phase=="ready")!=(data.progress_ticks==PREPARATION_TICKS):return false
	priority=data.priority;phase=data.phase;progress_ticks=int(data.progress_ticks);started_tick=int(data.started_tick);targets=parsed;return true
