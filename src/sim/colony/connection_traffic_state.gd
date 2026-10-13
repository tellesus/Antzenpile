class_name ConnectionTrafficState
extends RefCounted
## One physical parent/child edge; directional histories never create a second slot.
var route_id: String
var parent_id: String
var child_id: String
var payer_id: String
var supplies: Dictionary[String,InterpileSupplyState]={}
var migrations: Dictionary[String,WorkerReinforcementState]={}
var queens: Dictionary[String,QueenTransportState]={}
var broods: Dictionary[String,BroodTransportState]={}
var royals: Dictionary[String,RoyalTransportState]={}
var stores: Dictionary[String,StoreTransportState]={}
var last_cargo_kind: String="supplies"
var legacy: bool=false

func _init(camp: FoundingState=null) -> void:
	if camp==null:return
	route_id=camp.route_id;parent_id=camp.origin_pile;child_id=camp.destination_pile;payer_id=parent_id
	for id: String in [parent_id,child_id]:
		supplies[id]=InterpileSupplyState.new();migrations[id]=WorkerReinforcementState.new();queens[id]=QueenTransportState.new();broods[id]=BroodTransportState.new();stores[id]=StoreTransportState.new();royals[id]=RoyalTransportState.new()

func target(source_id: String) -> String:
	return child_id if source_id==parent_id else parent_id if source_id==child_id else ""

func busy() -> bool:
	for id: String in supplies:
		if supplies[id].phase!="none" or migrations[id].active() or queens[id].active() or broods[id].active() or stores[id].active() or royals[id].active():return true
	return false

func valid_route(route: TrailRouteState) -> bool:
	if not supplies.has(payer_id):return false
	var jobs: int=0
	for id: String in supplies:
		if supplies[id].phase!="none":jobs+=1
		if migrations[id].active():jobs+=1
		if queens[id].active():jobs+=1
		if broods[id].active():jobs+=1
		if stores[id].active():jobs+=1
		if royals[id].active():jobs+=1
		if id!=payer_id and (supplies[id].phase!="none" or migrations[id].active() or queens[id].active() or broods[id].active() or stores[id].active() or royals[id].active()):return false
	if jobs>1:return false
	if last_cargo_kind=="stores":return stores[payer_id].trips_started>0 and supplies[payer_id].phase=="none" and not migrations[payer_id].active() and not queens[payer_id].active() and not broods[payer_id].active() and not royals[payer_id].active() and stores[payer_id].valid_route(route)
	if royals[payer_id].active():return royals[payer_id].movement.valid_route(route,supplies[payer_id])
	if broods[payer_id].active():return broods[payer_id].movement.valid_route(route,supplies[payer_id])
	if queens[payer_id].active():return queens[payer_id].movement.valid_route(route,supplies[payer_id])
	return migrations[payer_id].valid_route(route,supplies[payer_id]) if migrations[payer_id].active() else supplies[payer_id].valid_route(route)

func to_dict() -> Dictionary:
	# The original three owners remain canonical root aliases, never duplicated.
	var royal_records: Dictionary={parent_id:royals[parent_id].to_dict(),child_id:royals[child_id].to_dict()}
	var store_records: Dictionary={parent_id:stores[parent_id].to_dict(),child_id:stores[child_id].to_dict()}
	var brood_records: Dictionary={parent_id:broods[parent_id].to_dict(),child_id:broods[child_id].to_dict()}
	var queen_records: Dictionary={parent_id:queens[parent_id].to_dict(),child_id:queens[child_id].to_dict()}
	if legacy:return {"royals":royal_records,"last_cargo_kind":last_cargo_kind,"stores":store_records,"broods":brood_records,"queens":queen_records,"migrations":{child_id:migrations[child_id].to_dict()}}
	return {"royals":royal_records,"last_cargo_kind":last_cargo_kind,"stores":store_records,"broods":brood_records,"queens":queen_records,"payer_id":payer_id,"supplies":{parent_id:supplies[parent_id].to_dict(),child_id:supplies[child_id].to_dict()},"migrations":{parent_id:migrations[parent_id].to_dict(),child_id:migrations[child_id].to_dict()}}

func restore(data: Dictionary, colony: ColonyState, camp: FoundingState, tick: int) -> bool:
	data=data.duplicate(true)
	if not data.has("queens"):data.queens={parent_id:queens[parent_id].to_dict(),child_id:queens[child_id].to_dict()}
	if not data.has("broods"):data.broods={parent_id:broods[parent_id].to_dict(),child_id:broods[child_id].to_dict()}
	if not data.has("stores"):data.stores={parent_id:stores[parent_id].to_dict(),child_id:stores[child_id].to_dict()}
	if not data.has("last_cargo_kind"):data.last_cargo_kind="supplies"
	if data.last_cargo_kind not in ["supplies","stores"]:return false
	last_cargo_kind=data.last_cargo_kind
	if not data.has("royals"):data.royals={parent_id:royals[parent_id].to_dict(),child_id:royals[child_id].to_dict()}
	var expected: Array=to_dict().keys()
	if data.size()!=expected.size() or not data.has_all(expected) or not data.migrations is Dictionary:return false
	var ids: Array[String]=[child_id]
	if not legacy:ids.insert(0,parent_id)
	if data.migrations.size()!=ids.size() or not data.migrations.has_all(ids):return false
	if not legacy:
		if data.payer_id not in ids or not data.supplies is Dictionary or data.supplies.size()!=2 or not data.supplies.has_all(ids):return false
		payer_id=data.payer_id
		for id: String in ids:
			if not data.supplies[id] is Dictionary or not supplies[id].restore(data.supplies[id],colony,camp,tick,id):return false
	for id: String in ids:
		if not data.migrations[id] is Dictionary or not migrations[id].restore(data.migrations[id],colony,camp,supplies[id],tick,id):return false
	if not data.queens is Dictionary or data.queens.size()!=2 or not data.queens.has_all([parent_id,child_id]):return false
	for id: String in [parent_id,child_id]:
		if not queens[id].restore(data.queens[id],self,colony,camp,tick) or (not queens[id].source_id.is_empty() and queens[id].source_id!=id):return false
	if not data.broods is Dictionary or data.broods.size()!=2 or not data.broods.has_all([parent_id,child_id]):return false
	for id: String in [parent_id,child_id]:
		if not broods[id].restore(data.broods[id],self,colony,camp,tick) or (not broods[id].source_id.is_empty() and broods[id].source_id!=id):return false
	if not data.stores is Dictionary or data.stores.size()!=2 or not data.stores.has_all([parent_id,child_id]):return false
	for id: String in [parent_id,child_id]:
		if not data.stores[id] is Dictionary or not stores[id].restore(data.stores[id],colony,camp,tick,id):return false
	if not data.royals is Dictionary or data.royals.size()!=2 or not data.royals.has_all([parent_id,child_id]):return false
	for id: String in [parent_id,child_id]:
		if not royals[id].restore(data.royals[id],self,colony,camp,tick) or (not royals[id].source_id.is_empty() and royals[id].source_id!=id):return false
	return true
