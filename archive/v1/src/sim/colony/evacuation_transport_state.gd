class_name EvacuationTransportState
extends RefCounted
## Final one-way adult custody; only the receiver can confirm successful arrival.
const LIMIT: int=64
var movement:=WorkerReinforcementState.new()
var source_id: String=""
var manifests: Array[Dictionary]=[]
func _init() -> void:movement.messengers=0
func active() -> bool:return movement.active()
func current() -> Dictionary:return manifests.back() if not manifests.is_empty() else {}
func to_dict() -> Dictionary:return {"source_id":source_id,"movement":movement.to_dict(),"manifests":manifests.duplicate(true)}
func restore(data: Variant, connection: ConnectionTrafficState, colony: ColonyState, camp: FoundingState, tick: int) -> bool:
	if not data is Dictionary or data.size()!=3 or not data.has_all(to_dict().keys()) or not data.source_id is String or not data.movement is Dictionary or not data.manifests is Array or data.manifests.size()>LIMIT:return false
	var payer: String=connection.parent_id if data.source_id.is_empty() else data.source_id;var parsed:=WorkerReinforcementState.new()
	if connection.target(payer).is_empty() or not parsed.restore(data.movement,colony,camp,connection.supplies[payer],tick,payer,0):return false
	if data.source_id.is_empty():return data.manifests.is_empty() and parsed.to_dict()==movement.to_dict()
	if data.manifests.is_empty():return false
	var records: Array[Dictionary]=[];var paid: int=0;var arrivals: int=0;var moved: int=0;var profiles: Dictionary[String,int]={};var previous: int=0
	for raw: Variant in data.manifests:
		if not raw is Dictionary or raw.size()!=9 or not raw.has_all(["sequence","departed_tick","arrived_tick","returned_tick","workers","profiles","left_stores","left_organs","reason"]) or raw.reason not in ["","landing","escorts","recalled"]:return false
		for key: String in ["sequence","departed_tick","arrived_tick","returned_tick","workers"]:
			if not WorkerLedger.valid_count(raw[key]) or key not in ["sequence","workers"] and raw[key]>tick:return false
		if raw.sequence<1 or not records.is_empty() and raw.sequence<=records.back().sequence:return false
		if raw.departed_tick<colony.piles[camp.destination_pile].foundation.founded_tick or raw.departed_tick<previous:return false
		if not raw.left_stores is Dictionary or not StoreTransportState._same_packet(raw.left_stores,raw.left_stores) or not raw.left_stores.has_all(PileState.RESOURCE_IDS) or raw.left_stores.size()!=3:return false
		for amount: Variant in raw.left_stores.values():
			if amount<0:return false
		if not raw.left_organs is Array or not raw.profiles is Dictionary:return false
		var organs: Array[String]=[]
		for value: Variant in raw.left_organs:
			if not value is String or value not in ["nursery","food_exchange","midden"]+ChamberCatalog.DEFINITIONS.keys() or value in organs:return false
			organs.append(value)
		var bundles: Dictionary[String,int]={};var count: int=0
		for key: Variant in raw.profiles:
			if not key is String or not WorkerLedger.valid_count(raw.profiles[key]) or raw.profiles[key]<1 or GeneticRepertoire.profile(GeneticRepertoire.traits_for(key))!=key:return false
			bundles[key]=int(raw.profiles[key]);count+=bundles[key]
		if count!=raw.workers or raw.arrived_tick>0 and raw.returned_tick>0:return false
		if raw.workers==0:
			if data.manifests.size()!=1 or parsed.trips_started!=0 or raw.arrived_tick!=raw.departed_tick or raw.returned_tick!=0:return false
		else:
			paid+=1
			if raw.arrived_tick>0:
				if raw.arrived_tick!=raw.departed_tick+camp.leg_ticks or not raw.reason.is_empty():return false
				arrivals+=1;moved+=int(raw.workers)
				for key: String in bundles:profiles[key]=profiles.get(key,0)+bundles[key]
			if raw.returned_tick>0 and raw.returned_tick<raw.departed_tick:return false
		if raw.arrived_tick==0 and raw.returned_tick==0 and records.size()!=data.manifests.size()-1:return false
		var record: Dictionary=raw.duplicate(true);record.profiles=bundles;record.left_organs=organs
		for key: String in ["sequence","departed_tick","arrived_tick","returned_tick","workers"]:record[key]=int(record[key])
		for key: String in PileState.RESOURCE_IDS:record.left_stores[key]=float(record.left_stores[key])
		previous=record.returned_tick;records.append(record)
	var latest: Dictionary=records.back()
	if parsed.trips_started!=paid or parsed.arrivals!=arrivals or parsed.moved_workers!=moved or parsed.moved_profiles!=profiles:return false
	if paid>0 and (parsed.departed_tick!=latest.departed_tick or parsed.settlers!=latest.workers or (latest.arrived_tick==0 and latest.returned_tick==0)!=parsed.active()):return false
	if parsed.active() and parsed.party_profiles!=latest.profiles:return false
	if not parsed.active() and paid>0 and parsed.last_reported_tick!=maxi(latest.arrived_tick,latest.returned_tick):return false
	source_id=data.source_id;movement=parsed;manifests=records;return true
