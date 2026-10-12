class_name ConnectionTrafficState
extends RefCounted
## One physical parent/child edge; directional histories never create a second slot.
var route_id: String
var parent_id: String
var child_id: String
var payer_id: String
var supplies: Dictionary[String,InterpileSupplyState]={}
var migrations: Dictionary[String,WorkerReinforcementState]={}
var legacy: bool=false

func _init(camp: FoundingState=null) -> void:
	if camp==null:return
	route_id=camp.route_id;parent_id=camp.origin_pile;child_id=camp.destination_pile;payer_id=parent_id
	for id: String in [parent_id,child_id]:
		supplies[id]=InterpileSupplyState.new();migrations[id]=WorkerReinforcementState.new()

func target(source_id: String) -> String:
	return child_id if source_id==parent_id else parent_id if source_id==child_id else ""

func busy() -> bool:
	for id: String in supplies:
		if supplies[id].phase!="none" or migrations[id].active():return true
	return false

func valid_route(route: TrailRouteState) -> bool:
	if not supplies.has(payer_id):return false
	var jobs: int=0
	for id: String in supplies:
		if supplies[id].phase!="none":jobs+=1
		if migrations[id].active():jobs+=1
		if id!=payer_id and (supplies[id].phase!="none" or migrations[id].active()):return false
	if jobs>1:return false
	return migrations[payer_id].valid_route(route,supplies[payer_id]) if migrations[payer_id].active() else supplies[payer_id].valid_route(route)

func to_dict() -> Dictionary:
	# The original three owners remain canonical root aliases, never duplicated.
	if legacy:return {"migrations":{child_id:migrations[child_id].to_dict()}}
	return {"payer_id":payer_id,"supplies":{parent_id:supplies[parent_id].to_dict(),child_id:supplies[child_id].to_dict()},"migrations":{parent_id:migrations[parent_id].to_dict(),child_id:migrations[child_id].to_dict()}}

func restore(data: Dictionary, colony: ColonyState, camp: FoundingState, tick: int) -> bool:
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
	return true
