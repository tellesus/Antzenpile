class_name ReproductionState
extends RefCounted
## One aggregate reproductive group, never part of the worker birth ledger.

const CONFIG = preload("res://data/resources/default_reproduction.tres")
var phase: String = "none"
var origin_pile: String=""
var transport_count: int=0
var progress_quarters: int = 0
var progress_remainder: int = 0
var environment_exposure: Array[String] = []
var repair_comparison: bool = false

var laid_tick: int = 0
var inherited_traits: Array[String] = []
var parent_queen_id: String = ""
var parent_generation: int = 0
var food_shortfalls: Array[String] = []

func progress_ticks() -> float:
	return (progress_quarters * 20 + progress_remainder) / 80.0

func active() -> bool: return phase in ["egg","larva","pupa"]
func occupied_space() -> int: return CONFIG.space if active() else 0
func identity(owner: String) -> String:return "queen:"+(origin_pile if not origin_pile.is_empty() else owner)+":raised:"+str(laid_tick)
static func body_identity(body: Dictionary, owner: String) -> String:return "queen:"+(body.get("origin_pile","") if not body.get("origin_pile","").is_empty() else owner)+":raised:"+str(int(body.laid_tick))
func mother_record() -> Dictionary:return {"identity":parent_queen_id,"generation":parent_generation,"inherited_traits":inherited_traits.duplicate()}

func to_dict() -> Dictionary:
	return {"origin_pile":origin_pile,"transport_count":transport_count,"phase":phase,"progress_quarters":progress_quarters,"progress_remainder":progress_remainder,"environment_exposure":environment_exposure.duplicate(),"repair_comparison":repair_comparison,"laid_tick":laid_tick,"parent_queen_id":parent_queen_id,"parent_generation":parent_generation,"inherited_traits":inherited_traits.duplicate(),"food_shortfalls":food_shortfalls.duplicate()}

func restore(data: Dictionary, ledger: WorkerLedger, pile_id: String, established: Array[String], matured: int, nursery_state: String, food_state: String, queens: int) -> bool:
	if data.size()!=5+int(data.has("origin_pile"))+int(data.has("transport_count"))+int(data.has("progress_remainder"))+int(data.has("environment_exposure"))+int(data.has("repair_comparison"))+int(data.has("parent_queen_id"))+int(data.has("parent_generation")) or not data.has_all(["phase","progress_quarters","laid_tick","inherited_traits","food_shortfalls"]): return false
	var origin: Variant=data.get("origin_pile","");var moves: Variant=data.get("transport_count",0)
	if not origin is String or not origin.is_empty() and not PileState.valid_id(origin) or not WorkerLedger.valid_count(moves) or moves>0 and origin.is_empty():return false
	if not data.phase is String or data.phase not in ["none","egg","larva","pupa","ready"] or not WorkerLedger.valid_count(data.progress_quarters) or not WorkerLedger.valid_count(data.laid_tick): return false
	if not data.inherited_traits is Array or not data.food_shortfalls is Array: return false
	var parent_id: Variant=data.get("parent_queen_id","");var generation: Variant=data.get("parent_generation",0)
	if not parent_id is String or parent_id.length()>160 or (not parent_id.is_empty() and not parent_id.begins_with("queen:")) or not WorkerLedger.valid_count(generation): return false
	parent_queen_id=parent_id;parent_generation=int(generation)
	var traits: Array[String] = []
	for value: Variant in data.inherited_traits:
		if not value is String or value not in established or value in traits: return false
		traits.append(value)
	var shortfalls: Array[String] = []
	for value: Variant in data.food_shortfalls:
		if not value is String or value not in ["carbohydrate","protein","water"] or value in shortfalls: return false
		shortfalls.append(value)
	var comparison: Variant=data.get("repair_comparison",false)
	if not comparison is bool or data.phase=="none" and comparison: return false
	var remainder: Variant = data.get("progress_remainder",0)
	var exposure: Variant = data.get("environment_exposure",[])
	if not WorkerLedger.valid_count(remainder) or remainder>=20 or not BroodEnvironment.valid_exposure(exposure): return false
	if data.phase in ["none","egg"] and not exposure.is_empty(): return false
	if data.phase!="larva" and remainder!=0: return false
	var ongoing: bool = data.phase in ["egg","larva","pupa"]
	if ongoing and data.progress_quarters >= CONFIG.stage_ticks(data.phase)*4: return false
	if not ongoing and data.progress_quarters!=0: return false
	if not shortfalls.is_empty() and data.phase!="larva": return false
	if data.phase == "none":
		if not origin.is_empty() or moves!=0 or data.laid_tick!=0 or not traits.is_empty() or not shortfalls.is_empty() or not parent_id.is_empty() or generation!=0: return false
	elif moves==0 and (matured < CONFIG.emerged_required or nursery_state != "developed" or food_state != "developed"): return false
	elif ongoing and (nursery_state!="developed" or food_state!="developed"):return false
	var record: Dictionary = ledger.to_dict().commitments.get("reproduction:"+pile_id,{})
	if ongoing:
		if record.get("kind")!="internal" or record.get("owner_id")!=pile_id or record.get("count")!=CONFIG.nurses: return false
	elif not record.is_empty(): return false
	repair_comparison=comparison
	progress_remainder=int(remainder); environment_exposure.assign(exposure)
	phase = data.phase; progress_quarters = int(data.progress_quarters); laid_tick = int(data.laid_tick)
	origin_pile=origin;transport_count=int(moves)
	inherited_traits = traits; food_shortfalls = shortfalls
	return true
