class_name BroodCohort
extends RefCounted
## One aggregate immature cohort; never part of the living-worker ledger.

const CONFIG = preload("res://data/resources/default_brood.tres")
const RESOURCE_IDS: Array[String] = ["carbohydrate", "protein", "water"]
var origin_pile: String=""
var transport_count: int=0
var inherited_lost: int=0
var id: String = "brood_1"
var stage: String = "egg"
var count: int = CONFIG.starting_count
var lost_count: int = 0
var progress_seconds: float = 0.0
var nutrition: float = 1.0
var care: float = 1.0
var nutrition_shortfalls: Array[String] = []
var adaptation_id: String = ""
var adaptation_trial: bool = false
var inherited_traits: Array[String] = []
var parent_queen_id: String = ""
var parent_generation: int = 0
var rain_comparison: bool = false
var recognition_comparison: bool = false
var environment_exposure: Array[String] = []
var repair_comparison: bool = false


static func next_id(matured_total: int, active_count: int = 0) -> String:
	return "brood_%d" % (matured_total / CONFIG.starting_count + active_count + 1)


func to_dict() -> Dictionary:
	return {"origin_pile":origin_pile,"transport_count":transport_count,"inherited_lost":inherited_lost,"id": id, "stage": stage, "count": count, "lost_count": lost_count, "progress_seconds": progress_seconds,
		"nutrition": nutrition, "care": care,
		"nutrition_shortfalls": nutrition_shortfalls.duplicate(),
		"adaptation_id": adaptation_id, "adaptation_trial": adaptation_trial,
		"parent_queen_id":parent_queen_id,"parent_generation":parent_generation,"inherited_traits":inherited_traits.duplicate(), "rain_comparison": rain_comparison,
		"recognition_comparison": recognition_comparison,"environment_exposure":environment_exposure.duplicate(),"repair_comparison":repair_comparison}


func restore(data: Dictionary) -> bool:
	if not data.has_all(["id", "stage", "count", "progress_seconds", "nutrition", "care"]):
		return false
	var lost: Variant = data.get("lost_count", 0)
	var origin: Variant=data.get("origin_pile","");var moves: Variant=data.get("transport_count",0);var previous_loss: Variant=data.get("inherited_lost",0)
	if not origin is String or (not origin.is_empty() and not PileState.valid_id(origin)) or not WorkerLedger.valid_count(moves) or not WorkerLedger.valid_count(previous_loss):return false
	if not WorkerLedger.valid_count(lost):return false
	if moves>0 and origin.is_empty() or previous_loss>lost or moves==0 and previous_loss!=0:return false
	if not data.id is String or not data.id.begins_with("brood_") or not data.stage in ["egg", "larva", "pupa"] or not WorkerLedger.valid_count(data.count) or not WorkerLedger.valid_count(lost) or data.count < 1 or data.count + lost != CONFIG.starting_count:
		return false
	for key: String in ["progress_seconds", "nutrition", "care"]:
		if not typeof(data[key]) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[key])) or data[key] < 0.0:
			return false
	if data.progress_seconds >= CONFIG.stage_seconds(data.stage) or data.nutrition > 1.0 or data.care > 1.0:
		return false
	var parent_id: Variant=data.get("parent_queen_id","");var generation: Variant=data.get("parent_generation",0)
	if not parent_id is String or parent_id.length()>160 or (not parent_id.is_empty() and not parent_id.begins_with("queen:")) or not WorkerLedger.valid_count(generation): return false
	parent_queen_id=parent_id;parent_generation=int(generation)
	var shortfalls: Variant = data.get("nutrition_shortfalls", [])
	if not shortfalls is Array: return false
	var parsed_shortfalls: Array[String] = []
	for value: Variant in shortfalls:
		if not value is String or value not in RESOURCE_IDS or value in parsed_shortfalls: return false
		parsed_shortfalls.append(value)
	if not parsed_shortfalls.is_empty() and (data.stage != "larva" or data.care < 1.0 or data.nutrition >= 1.0): return false
	var trait_id: Variant = data.get("adaptation_id", "")
	var trial: Variant = data.get("adaptation_trial", false)
	if not trait_id is String or not (trait_id == "" or AdaptationRules.valid_trait(trait_id)) or typeof(trial) != TYPE_BOOL or (trial and trait_id == ""):
		return false
	var traits: Variant = data.get("inherited_traits", [] if trait_id == "" else [trait_id])
	if not traits is Array:
		return false
	var parsed_traits: Array[String] = []
	for value: Variant in traits:
		if not value is String or not AdaptationRules.valid_trait(value) or value in parsed_traits:
			return false
		parsed_traits.append(value)
	if not AdaptationRules.compatible(parsed_traits) or (trait_id != "" and trait_id not in parsed_traits):
		return false
	var foraging_id: String = "lean" if "lean" in parsed_traits else "load" if "load" in parsed_traits else ""
	if not trial and trait_id != foraging_id:
		return false
	if typeof(data.get("rain_comparison", false)) != TYPE_BOOL:
		return false
	if typeof(data.get("recognition_comparison", false)) != TYPE_BOOL:
		return false
	if not data.get("repair_comparison",false) is bool: return false
	repair_comparison=data.get("repair_comparison",false)
	var exposure: Variant = data.get("environment_exposure",[])
	if not BroodEnvironment.valid_exposure(exposure) or data.stage=="egg" and not exposure.is_empty(): return false
	environment_exposure.assign(exposure)
	origin_pile=origin;transport_count=int(moves);inherited_lost=int(previous_loss)
	id = data.id
	stage = data.stage
	count = int(data.count)
	lost_count = int(lost)
	progress_seconds = float(data.progress_seconds)
	nutrition = float(data.nutrition)
	care = float(data.care)
	nutrition_shortfalls = parsed_shortfalls
	adaptation_id = trait_id
	adaptation_trial = trial
	inherited_traits = parsed_traits
	rain_comparison = data.get("rain_comparison", false)
	recognition_comparison = data.get("recognition_comparison", false)
	return true

func uid(owner_id: String) -> String:return (origin_pile if not origin_pile.is_empty() else owner_id)+":"+id
func mother_record() -> Dictionary:
	var traits: Array[String]=inherited_traits.duplicate()
	if adaptation_trial:traits.erase(adaptation_id)
	return {"identity":parent_queen_id,"generation":parent_generation,"inherited_traits":traits}
