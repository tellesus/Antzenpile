class_name NestDisturbanceState
extends RefCounted
## One physical pressure event and actual local observations/loss receipts.
const CONFIG=preload("res://data/weather/roadside_nest_disturbance.tres")
var enabled: bool=false
var scent_disturbed: bool=false
var records: Dictionary[String,Dictionary]={}
func phase(tick: int) -> String:
	if not enabled or tick<CONFIG.warning_tick:return "dormant"
	if tick<CONFIG.warning_tick+CONFIG.warning_ticks:return "warning"
	return "pressure" if tick<CONFIG.warning_tick+CONFIG.warning_ticks+CONFIG.pressure_ticks else "settled"
func to_dict() -> Dictionary:return {"enabled":enabled,"scent_disturbed":scent_disturbed,"records":records.duplicate(true)}
func restore(data: Variant, colony: ColonyState, tick: int, scenario: String) -> bool:
	if not data is Dictionary or data.size()!=3 or not data.has_all(to_dict().keys()) or not data.enabled is bool or not data.scent_disturbed is bool or not data.records is Dictionary:return false
	if data.enabled and scenario!="roadside" or not data.enabled and (data.scent_disturbed or not data.records.is_empty()):return false
	if data.scent_disturbed and tick<CONFIG.warning_tick+CONFIG.warning_ticks:return false
	var parsed: Dictionary[String,Dictionary]={}
	for id: Variant in data.records:
		var record: Variant=data.records[id]
		if not id is String or not colony.piles.has(id) or not record is Dictionary or record.size()!=7 or not record.has_all(["warned","impacted","settled","workers","brood","royals","queen_injury"]):return false
		for key: String in record:
			if not WorkerLedger.valid_count(record[key]):return false
		if record.warned<CONFIG.warning_tick or record.warned>tick or record.impacted>tick or record.settled>tick:return false
		if record.impacted>0 and (record.impacted<maxi(int(record.warned),CONFIG.warning_tick+CONFIG.warning_ticks) or record.impacted>=CONFIG.warning_tick+CONFIG.warning_ticks+CONFIG.pressure_ticks):return false
		if record.settled>0 and record.settled<CONFIG.warning_tick+CONFIG.warning_ticks+CONFIG.pressure_ticks:return false
		if record.queen_injury>CONFIG.queen_injury or record.royals not in [0.0,3.0,6.0] or record.brood>colony.piles[id].brood_lost_total or record.workers>colony.piles[id].workers.lost_total:return false
		if record.impacted==0 and (record.workers>0 or record.brood>0 or record.royals>0 or record.queen_injury>0):return false
		if colony.piles[id].position.distance_to(CONFIG.position)>CONFIG.radius:return false
		parsed[id]=record.duplicate()
		for key: String in record:parsed[id][key]=int(record[key])
	enabled=data.enabled;scent_disturbed=data.scent_disturbed;records=parsed;return true
