class_name QueenState
extends RefCounted
## Local aggregate queen viability and one physically owned replacement group.
const CONFIG = preload("res://data/resources/default_queen.tres")
var in_transit: bool=false
var count: int = 1
var identity: String = ""
var parent_identity: String = ""
var generation: int = 0
var condition: int = CONFIG.maximum_condition
var carers: int = 0
var inherited_traits: Array[String] = []
var previous_mothers: Array[Dictionary]=[]
var arrival_record: Dictionary={}
var replacement_group: Dictionary = {}
var replacement_progress: int = 0
var replacement_started: int = 0

func queen_id(pile_id: String) -> String:
	return identity if not identity.is_empty() else "queen:"+pile_id+":founder"
func replacing() -> bool: return not replacement_group.is_empty()
func to_dict(pile_id: String) -> Dictionary:
	return {"in_transit":in_transit,"previous_mothers":previous_mothers.duplicate(true),"arrival_record":arrival_record.duplicate(),"lineage_version":1,"count":count,"identity":queen_id(pile_id),"parent_identity":parent_identity,"generation":generation,"condition":condition,"carers":carers,"inherited_traits":inherited_traits.duplicate(),"replacement_group":replacement_group.duplicate(true),"replacement_progress":replacement_progress,"replacement_started":replacement_started}

func restore(data: Variant, pile_id: String, queens: int, ledger: WorkerLedger, established: Array[String], matured: int, nursery: String, food: String, reproduction: ReproductionState, legacy_traits: Array[String]=[]) -> bool:
	if not data is Dictionary or data.size()!=10+int(data.has("lineage_version"))+int(data.has("previous_mothers"))+int(data.has("arrival_record"))+int(data.has("in_transit")) or not data.has_all(["count","identity","parent_identity","generation","condition","carers","inherited_traits","replacement_group","replacement_progress","replacement_started"]): return false
	if not data.get("in_transit",false) is bool or data.get("in_transit",false) and data.count!=0:return false
	for key: String in ["count","generation","condition","carers","replacement_progress","replacement_started"]:
		if not WorkerLedger.valid_count(data[key]): return false
	if data.count!=queens or data.condition>CONFIG.maximum_condition or (data.count>0)!=(data.condition>0) or data.carers>CONFIG.care_cap or data.count==0 and data.carers>0: return false
	for key: String in ["identity","parent_identity"]:
		if not data[key] is String or data[key].length()>160: return false
	if not data.identity.begins_with("queen:") or (data.generation==0)!=(data.parent_identity=="") or data.identity==data.parent_identity: return false
	if not data.inherited_traits is Array or not data.replacement_group is Dictionary: return false
	var bundle: Variant=lineage_traits(data,legacy_traits)
	if bundle==null: return false
	var histories: Variant=parse_mothers(data.get("previous_mothers",[]))
	var arrival: Variant=data.get("arrival_record",{})
	if histories==null or not valid_arrival(arrival):return false
	var traits: Array[String]=[]
	for value: Variant in bundle:
		if not value is String or not AdaptationRules.valid_trait(value) or (value not in established and arrival.is_empty() and not histories.any(func(mother_record: Dictionary)->bool:return value in mother_record.inherited_traits)) or value in traits: return false
		traits.append(value)
	if not AdaptationRules.compatible(traits): return false
	var care: Dictionary=ledger.to_dict().commitments.get("queen_care:"+pile_id,{})
	if data.carers==0 and not care.is_empty() or data.carers>0 and care!={"kind":"internal","owner_id":pile_id,"count":int(data.carers)}: return false
	var replacement: Dictionary=ledger.to_dict().commitments.get("queen_replacement:"+pile_id,{})
	var restored_group: Dictionary={}
	if data.replacement_group.is_empty():
		if data.replacement_progress!=0 or data.replacement_started!=0 or not replacement.is_empty(): return false
	else:
		if data.count!=0 or reproduction.phase!="none" or data.replacement_progress>=CONFIG.replacement_ticks or replacement!={"kind":"internal","owner_id":pile_id,"count":CONFIG.replacement_nurses}: return false
		var group:=ReproductionState.new()
		if not group.restore(data.replacement_group,WorkerLedger.new(),pile_id,PileState._merged_traits(established,traits),matured,nursery,food,0) or group.phase!="ready": return false
		if group.laid_tick+group.CONFIG.egg_ticks+group.CONFIG.larva_ticks+group.CONFIG.pupa_ticks>data.replacement_started: return false
		restored_group=group.to_dict()
	in_transit=data.get("in_transit",false)
	count=int(data.count);identity=data.identity;parent_identity=data.parent_identity;generation=int(data.generation)
	condition=int(data.condition);carers=int(data.carers);inherited_traits=traits;previous_mothers.assign(histories);arrival_record=arrival.duplicate()
	if not arrival_record.is_empty():arrival_record.index=int(arrival_record.index)
	replacement_group=restored_group;replacement_progress=int(data.replacement_progress);replacement_started=int(data.replacement_started)
	return true

static func lineage_traits(data: Variant, legacy_traits: Array[String]) -> Variant:
	if not data is Dictionary: return null
	if data.has("lineage_version"):
		if not typeof(data.lineage_version) in [TYPE_INT,TYPE_FLOAT] or data.lineage_version!=1 or not data.get("inherited_traits") is Array: return null
		return data.inherited_traits.duplicate()
	# Older replacement records already captured their paid group's lineage.
	if data.has("generation") and not WorkerLedger.valid_count(data.generation): return null
	return data.inherited_traits.duplicate() if data.get("generation",0)>0 and data.get("inherited_traits") is Array else legacy_traits.duplicate()

func mother(pile_id: String) -> Dictionary:
	return {"identity":queen_id(pile_id),"generation":generation,"inherited_traits":inherited_traits.duplicate()}

static func valid_mother(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=3 or not value.has_all(["identity","generation","inherited_traits"]):return false
	if not value.identity is String or not value.identity.begins_with("queen:") or value.identity.length()>160 or not WorkerLedger.valid_count(value.generation) or not value.inherited_traits is Array:return false
	var traits: Array[String]=[]
	for item: Variant in value.inherited_traits:
		if not item is String or not AdaptationRules.valid_trait(item) or item in traits:return false
		traits.append(item)
	return AdaptationRules.compatible(traits)

static func parse_mothers(value: Variant) -> Variant:
	if not value is Array or value.size()>64:return null
	var result: Array[Dictionary]=[];var ids: Array[String]=[]
	for item: Variant in value:
		if not valid_mother(item) or item.identity in ids:return null
		var parsed: Dictionary=item.duplicate(true);var traits: Array[String]=[];traits.assign(item.inherited_traits)
		parsed.generation=int(item.generation);parsed.inherited_traits=traits
		result.append(parsed);ids.append(item.identity)
	return result

static func valid_arrival(value: Variant) -> bool:
	return value is Dictionary and (value.is_empty() or value.size()==3 and value.has_all(["route_id","source_id","index"]) and value.route_id is String and value.route_id.begins_with("route_") and PileState.valid_id(value.source_id) and WorkerLedger.valid_count(value.index) and value.index<64)

static func known_parent(identity: String, generation_value: int, current_id: String, current_generation: int, mothers: Array) -> bool:
	if identity.is_empty():return true
	if identity==current_id:return generation_value==current_generation
	for value: Dictionary in mothers:
		if value.identity==identity:return value.generation==generation_value
	return generation_value<current_generation
