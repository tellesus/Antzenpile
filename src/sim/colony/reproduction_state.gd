class_name ReproductionState
extends RefCounted
## One aggregate reproductive group, never part of the worker birth ledger.

const CONFIG = preload("res://data/resources/default_reproduction.tres")
var phase: String = "none"
var progress_quarters: int = 0
var laid_tick: int = 0
var inherited_traits: Array[String] = []
var food_shortfalls: Array[String] = []

func active() -> bool: return phase in ["egg","larva","pupa"]
func occupied_space() -> int: return CONFIG.space if active() else 0

func to_dict() -> Dictionary:
	return {"phase":phase,"progress_quarters":progress_quarters,"laid_tick":laid_tick,"inherited_traits":inherited_traits.duplicate(),"food_shortfalls":food_shortfalls.duplicate()}

func restore(data: Dictionary, ledger: WorkerLedger, pile_id: String, established: Array[String], matured: int, nursery_state: String, food_state: String, queens: int) -> bool:
	if data.size()!=5 or not data.has_all(["phase","progress_quarters","laid_tick","inherited_traits","food_shortfalls"]): return false
	if not data.phase is String or data.phase not in ["none","egg","larva","pupa","ready"] or not WorkerLedger.valid_count(data.progress_quarters) or not WorkerLedger.valid_count(data.laid_tick): return false
	if not data.inherited_traits is Array or not data.food_shortfalls is Array: return false
	var traits: Array[String] = []
	for value: Variant in data.inherited_traits:
		if not value is String or value not in established or value in traits: return false
		traits.append(value)
	var shortfalls: Array[String] = []
	for value: Variant in data.food_shortfalls:
		if not value is String or value not in ["carbohydrate","protein","water"] or value in shortfalls: return false
		shortfalls.append(value)
	var ongoing: bool = data.phase in ["egg","larva","pupa"]
	if ongoing and data.progress_quarters >= CONFIG.stage_ticks(data.phase)*4: return false
	if not ongoing and data.progress_quarters!=0: return false
	if not shortfalls.is_empty() and data.phase!="larva": return false
	if data.phase == "none":
		if data.laid_tick!=0 or not traits.is_empty() or not shortfalls.is_empty(): return false
	elif matured < CONFIG.emerged_required or nursery_state != "developed" or food_state != "developed" or queens < 1: return false
	var record: Dictionary = ledger.to_dict().commitments.get("reproduction:"+pile_id,{})
	if ongoing:
		if record.get("kind")!="internal" or record.get("owner_id")!=pile_id or record.get("count")!=CONFIG.nurses: return false
	elif not record.is_empty(): return false
	phase = data.phase; progress_quarters = int(data.progress_quarters); laid_tick = int(data.laid_tick)
	inherited_traits = traits; food_shortfalls = shortfalls
	return true
