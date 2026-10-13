class_name StoreTransportState
extends InterpileSupplyState
## One finite packet; manifests are receipts, never additional owned cargo.
const LIMIT: int=64
var manifests: Array[Dictionary]=[]
func current() -> Dictionary:return manifests.back() if not manifests.is_empty() else {}
func active() -> bool:return travelling()
func receipt() -> Dictionary:
	var deliveries: Array[Dictionary]=manifests.filter(func(record: Dictionary)->bool:return record.arrived>0 and record.reported>0)
	if deliveries.is_empty():return {}
	return {"first_at":deliveries[0].reported*SimulationClock.TICK_INTERVAL,"last_at":deliveries.back().reported*SimulationClock.TICK_INTERVAL,"last_amount":float(deliveries.back().amount),"earlier_unrecorded":false}
func to_dict() -> Dictionary:
	var result: Dictionary=super.to_dict();result.manifests=manifests.duplicate(true);return result
func restore(data: Dictionary, colony: ColonyState, founding: FoundingState, tick: int, source_id: String="home") -> bool:
	if data.size()!=16 or not data.has_all(to_dict().keys()) or not data.enabled is bool or data.enabled!=false or data.phase not in ["none","outbound","returning"]:return false
	if not data.manifests is Array or data.manifests.size()>LIMIT:return false
	for key: String in ["elapsed_ticks","departed_tick","trips_started","trips_reported","first_reported_tick","last_reported_tick"]:
		if not WorkerLedger.valid_count(data[key]):return false
	var parsed: Array[Dictionary]=[];var totals: Dictionary[String,int]={"carbohydrate":0,"protein":0,"water":0}
	var leg: int=0;var reported: int=0;var previous: int=0
	if not data.manifests.is_empty():
		if founding.phase!="established" or not colony.piles.has(founding.destination_pile) or source_id not in [founding.origin_pile,founding.destination_pile]:return false
		leg=TRAILS.leg_ticks(colony.piles[founding.origin_pile].position.distance_to(colony.piles[founding.destination_pile].position))
		previous=int(colony.piles[founding.destination_pile].foundation.founded_tick)
	for raw: Variant in data.manifests:
		if not raw is Dictionary or raw.size()!=10 or not raw.has_all(["resource","amount","departed","arrived","recalled","reported","carry","energy","chemistry","contaminant"]):return false
		if raw.resource not in PileState.RESOURCE_IDS or not WorkerLedger.valid_count(raw.amount) or raw.amount<1:return false
		for key: String in ["departed","arrived","recalled","reported"]:
			if not WorkerLedger.valid_count(raw[key]) or raw[key]>tick:return false
		for key: String in ["carry","energy","chemistry","contaminant"]:
			if not typeof(raw[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw[key])):return false
		if raw.carry<0.85 or raw.carry>1.3 or raw.energy<0.7 or raw.energy>1.2 or raw.chemistry<0 or raw.chemistry>1 or raw.contaminant<0 or raw.contaminant>raw.amount or (raw.resource!="carbohydrate" and raw.contaminant!=0):return false
		if raw.amount>floori((CONFIG.carbohydrate+CONFIG.protein+CONFIG.water)*raw.carry) or raw.departed<previous:return false
		if raw.arrived!=0 and (raw.arrived!=raw.departed+leg or raw.recalled!=0):return false
		if raw.recalled!=0 and (raw.recalled<raw.departed or raw.recalled>=raw.departed+leg):return false
		var due: int=int(raw.departed+2*leg if raw.recalled==0 else 2*raw.recalled-raw.departed)
		if raw.reported!=0:
			if raw.reported!=due or (raw.arrived==0 and raw.recalled==0):return false
			reported+=1;previous=int(raw.reported)
			if raw.arrived>0:totals[raw.resource]+=int(raw.amount)*100000
		elif parsed.size()!=data.manifests.size()-1:return false
		var record: Dictionary=raw.duplicate()
		for key: String in ["amount","departed","arrived","recalled","reported"]:record[key]=int(record[key])
		for key: String in ["carry","energy","chemistry","contaminant"]:record[key]=float(record[key])
		parsed.append(record)
	var away: bool=data.phase!="none"
	if away!=(parsed.size()>reported) or data.trips_started!=parsed.size() or data.trips_reported!=reported or not _same_packet(data.delivered_units,totals):return false
	for key: String in ["elapsed_ticks","departed_tick","trips_started","trips_reported","first_reported_tick","last_reported_tick"]:
		if not WorkerLedger.valid_count(data[key]):return false
	var latest: Dictionary=parsed.back() if not parsed.is_empty() else {}
	var last: Dictionary=parsed[reported-1] if reported>0 else {}
	if data.departed_tick!=latest.get("departed",0) or data.first_reported_tick!=(parsed[0].reported if reported>0 else 0) or data.last_reported_tick!=last.get("reported",0):return false
	var expected_cargo: Dictionary={};var expected_last: Dictionary={}
	if away:
		if latest.reported!=0 or data.elapsed_ticks>=leg:return false
		if data.phase=="outbound" and (latest.arrived!=0 or latest.recalled!=0 or data.departed_tick+data.elapsed_ticks>tick):return false
		if data.phase=="returning" and (latest.arrived==0 and latest.recalled==0):return false
		if latest.recalled>0 and data.elapsed_ticks<leg-(latest.recalled-latest.departed):return false
		var position_time: int=int(latest.arrived+data.elapsed_ticks if latest.recalled==0 else 2*latest.recalled-latest.departed-leg+data.elapsed_ticks)
		if position_time>tick:return false
		expected_cargo=packet(latest.resource,latest.amount)
		if data.energy_multiplier!=latest.energy or data.carry_multiplier!=latest.carry or data.chemistry_fraction!=latest.chemistry or data.contaminant_mass!=latest.contaminant:return false
	else:
		if data.elapsed_ticks!=0 or data.energy_multiplier!=1 or data.carry_multiplier!=1 or data.chemistry_fraction!=0 or data.contaminant_mass!=0:return false
	if reported>0:expected_last=packet(last.resource,last.amount if last.arrived>0 else 0)
	if not _same_packet(data.cargo,expected_cargo) or not _same_packet(data.last_payload,expected_last):return false
	enabled=false;phase=data.phase;elapsed_ticks=int(data.elapsed_ticks);departed_tick=int(data.departed_tick);trips_started=parsed.size();trips_reported=reported;first_reported_tick=int(data.first_reported_tick);last_reported_tick=int(data.last_reported_tick)
	cargo.assign(expected_cargo);last_payload.assign(expected_last);delivered_units=totals;manifests=parsed
	energy_multiplier=float(data.energy_multiplier);carry_multiplier=float(data.carry_multiplier);chemistry_fraction=float(data.chemistry_fraction);contaminant_mass=float(data.contaminant_mass)
	return true
static func packet(resource: String, amount: float) -> Dictionary[String,float]:
	var result: Dictionary[String,float]={"carbohydrate":0.0,"protein":0.0,"water":0.0};result[resource]=amount;return result
static func _same_packet(raw: Variant, expected: Dictionary) -> bool:
	if not raw is Dictionary or raw.size()!=expected.size() or not raw.has_all(expected.keys()):return false
	for key: String in expected:
		if not typeof(raw[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw[key])) or raw[key]!=expected[key]:return false
	return true
