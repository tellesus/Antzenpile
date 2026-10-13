class_name RoyalTransportState
extends RefCounted
## One original paid young-queen/male group; manifests are history, never extra bodies.
const LIMIT: int=64
var source_id: String=""
var movement:=WorkerReinforcementState.new()
var body: Dictionary={}
var manifests: Array[Dictionary]=[]
func active() -> bool:return movement.active()
func current() -> Dictionary:return manifests.back() if not manifests.is_empty() else {}
func last_report() -> Dictionary:
	for index: int in range(manifests.size()-1,-1,-1):
		if manifests[index].reported_tick>0:return manifests[index]
	return {}
func to_dict() -> Dictionary:return {"source_id":source_id,"movement":movement.to_dict(),"body":body.duplicate(true),"manifests":manifests.duplicate(true)}
static func canonical_body(value: Variant) -> Variant:
	if not value is Dictionary or not PileState.valid_id(value.get("origin_pile")) or not WorkerLedger.valid_count(value.get("transport_count")) or value.transport_count<1:return null
	var group:=ReproductionState.new();var ledger:=WorkerLedger.new();var owner: String=value.origin_pile
	if value.get("phase") in ["egg","larva","pupa"]:
		ledger.add_living_workers("available",ReproductionState.CONFIG.nurses,"Transport validation")
		ledger.create_commitment("reproduction:"+owner,"internal",owner);ledger.allocate("reproduction:"+owner,ReproductionState.CONFIG.nurses)
	var all_traits: Array[String]=[];all_traits.assign(TraitCatalog.IDS)
	if not group.restore(value,ledger,owner,all_traits,ReproductionState.CONFIG.emerged_required,"developed","developed",1) or group.phase=="none":return null
	return group.to_dict()
func restore(data: Variant, connection: ConnectionTrafficState, colony: ColonyState, camp: FoundingState, tick: int) -> bool:
	if not data is Dictionary or data.size()!=4 or not data.has_all(to_dict().keys()) or not data.source_id is String or not data.body is Dictionary or not data.manifests is Array or data.manifests.size()>LIMIT or not data.movement is Dictionary:return false
	var parsed:=WorkerReinforcementState.new()
	var payer: String=connection.parent_id if data.source_id.is_empty() else data.source_id
	if connection.target(payer).is_empty() or not parsed.restore(data.movement,colony,camp,connection.supplies[payer],tick,payer):return false
	if data.source_id.is_empty():return data.manifests.is_empty() and data.body.is_empty() and parsed.to_dict()==movement.to_dict()
	if parsed.trips_started!=data.manifests.size() or parsed.trips_started==0:return false
	var records: Array[Dictionary]=[];var arrivals: int=0;var previous: int=0
	for value: Variant in data.manifests:
		if not value is Dictionary or value.size()!=6 or not value.has_all(["source_id","departed_tick","arrived_tick","reported_tick","reason","body"]) or value.source_id!=data.source_id or value.reason not in ["","landing","escorts"]:return false
		for key: String in ["departed_tick","arrived_tick","reported_tick"]:
			if not WorkerLedger.valid_count(value[key]) or value[key]>tick:return false
		var payload: Variant=canonical_body(value.body)
		if payload==null or value.departed_tick<colony.piles[camp.destination_pile].foundation.founded_tick or (not records.is_empty() and value.departed_tick<previous):return false
		if value.arrived_tick>0:
			if value.arrived_tick!=value.departed_tick+camp.leg_ticks or not value.reason.is_empty():return false
			arrivals+=1
		if value.reported_tick>0 and (value.reported_tick<value.arrived_tick+camp.leg_ticks if value.arrived_tick>0 else value.reported_tick<value.departed_tick):return false
		if value.reported_tick==0 and records.size()!=data.manifests.size()-1:return false
		var record: Dictionary=value.duplicate(true);record.body=payload
		for key: String in ["departed_tick","arrived_tick","reported_tick"]:record[key]=int(record[key])
		previous=record.reported_tick;records.append(record)
	var latest: Dictionary=records.back()
	if latest.departed_tick!=parsed.departed_tick or (latest.reported_tick==0)!=parsed.active() or arrivals!=parsed.arrivals:return false
	if parsed.active() and (latest.arrived_tick>0)!=parsed.settled:return false
	if (parsed.active() and not parsed.settled)!=(not data.body.is_empty()):return false
	var payload: Variant=canonical_body(data.body) if not data.body.is_empty() else {}
	if payload==null or not data.body.is_empty() and payload!=latest.body:return false
	if not parsed.active() and latest.reported_tick!=parsed.last_reported_tick:return false
	source_id=data.source_id;movement=parsed;body=payload;manifests=records
	return true
