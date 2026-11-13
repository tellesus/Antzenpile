class_name QueenTransportState
extends RefCounted
## One exclusively owned traveling mother; old manifests are proof, not bodies.
const LIMIT: int=64
var source_id: String=""
var movement:=WorkerReinforcementState.new()
var body: Dictionary={}
var manifests: Array[Dictionary]=[]
func active() -> bool:return movement.active()
func current() -> Dictionary:return manifests.back() if not manifests.is_empty() else {}
func to_dict() -> Dictionary:return {"source_id":source_id,"movement":movement.to_dict(),"body":body.duplicate(true),"manifests":manifests.duplicate(true)}
static func biological(queen: QueenState, pile_id: String) -> Dictionary:
	return {"identity":queen.queen_id(pile_id),"parent_identity":queen.parent_identity,"generation":queen.generation,"condition":queen.condition,"inherited_traits":queen.inherited_traits.duplicate()}
static func valid_body(record: Variant) -> bool:
	if not record is Dictionary or record.size()!=5 or not record.has_all(["identity","parent_identity","generation","condition","inherited_traits"]):return false
	if not record.identity is String or not record.identity.begins_with("queen:") or record.identity.length()>160 or not record.parent_identity is String or record.parent_identity.length()>160 or record.identity==record.parent_identity:return false
	if not WorkerLedger.valid_count(record.generation) or (record.generation==0)!=(record.parent_identity=="") or not WorkerLedger.valid_count(record.condition) or record.condition<1 or record.condition>QueenState.CONFIG.maximum_condition:return false
	if not record.inherited_traits is Array:return false
	var traits: Array[String]=[]
	for value: Variant in record.inherited_traits:
		if not value is String or not AdaptationRules.valid_trait(value) or value in traits:return false
		traits.append(value)
	return AdaptationRules.compatible(traits)
func restore(data: Variant, connection: ConnectionTrafficState, colony: ColonyState, camp: FoundingState, tick: int) -> bool:
	if not data is Dictionary or data.size()!=4 or not data.has_all(to_dict().keys()) or not data.source_id is String or not data.body is Dictionary or not data.manifests is Array or data.manifests.size()>LIMIT:return false
	if data.source_id.is_empty():
		var empty:=WorkerReinforcementState.new()
		return data.manifests.is_empty() and data.body.is_empty() and data.movement is Dictionary and empty.restore(data.movement,colony,camp,connection.supplies[connection.parent_id],tick,connection.parent_id) and empty.to_dict()==movement.to_dict()
	if connection.target(data.source_id).is_empty() or not data.movement is Dictionary:return false
	var parsed:=WorkerReinforcementState.new()
	if not parsed.restore(data.movement,colony,camp,connection.supplies[data.source_id],tick,data.source_id):return false
	if parsed.trips_started!=data.manifests.size() or parsed.trips_started==0:return false
	var records: Array[Dictionary]=[];var previous: int=0;var arrivals: int=0
	var leg: int=camp.leg_ticks
	for value: Variant in data.manifests:
		if not value is Dictionary or value.size()!=7 or not value.has_all(["reason","departed_tick","arrived_tick","reported_tick","source_id","body","previous_mother"]) or value.reason not in ["","landing","escorts"] or value.source_id!=data.source_id or not valid_body(value.body) or not value.previous_mother is Dictionary:return false
		for key: String in ["departed_tick","arrived_tick","reported_tick"]:
			if not WorkerLedger.valid_count(value[key]) or value[key]>tick:return false
		if value.departed_tick<colony.piles[camp.destination_pile].foundation.founded_tick or (not records.is_empty() and value.departed_tick<previous):return false
		if value.arrived_tick!=0:
			if not value.reason.is_empty():return false
			if value.arrived_tick!=value.departed_tick+leg or value.previous_mother.size()!=3 or not QueenState.valid_mother(value.previous_mother):return false
			arrivals+=1
		elif not value.previous_mother.is_empty():return false
		if value.reported_tick!=0 and (value.reported_tick<value.arrived_tick+leg if value.arrived_tick!=0 else value.reported_tick<value.departed_tick):return false
		if value.reported_tick==0 and records.size()!=data.manifests.size()-1:return false
		previous=int(value.reported_tick)
		var record: Dictionary=value.duplicate(true)
		for key: String in ["departed_tick","arrived_tick","reported_tick"]:record[key]=int(record[key])
		record.body=canonical_body(record.body)
		if not record.previous_mother.is_empty():record.previous_mother=QueenState.parse_mothers([record.previous_mother])[0]
		records.append(record)
	var latest: Dictionary=records.back()
	if latest.source_id!=data.source_id or latest.departed_tick!=parsed.departed_tick or (latest.reported_tick==0)!=parsed.active() or arrivals!=parsed.arrivals:return false
	if parsed.active() and (latest.arrived_tick>0)!=parsed.settled:return false
	if (parsed.active() and not parsed.settled)!=(not data.body.is_empty()):return false
	if not data.body.is_empty() and (not valid_body(data.body) or canonical_body(data.body)!=latest.body):return false
	if not parsed.active() and latest.reported_tick!=parsed.last_reported_tick:return false
	source_id=data.source_id;movement=parsed;body=canonical_body(data.body) if not data.body.is_empty() else {};manifests=records
	return true

static func canonical_body(record: Dictionary) -> Dictionary:
	var result: Dictionary=record.duplicate(true);var traits: Array[String]=[]
	traits.assign(record.inherited_traits);result.inherited_traits=traits
	result.generation=int(record.generation);result.condition=int(record.condition)
	return result

func last_report() -> Dictionary:
	for index: int in range(manifests.size()-1,-1,-1):
		if manifests[index].reported_tick>0:return manifests[index]
	return {}
