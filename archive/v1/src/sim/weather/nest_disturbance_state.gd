class_name NestDisturbanceState
extends RefCounted
## One physical pressure event and actual local observations/loss receipts.
const CONFIG=preload("res://data/weather/roadside_nest_disturbance.tres")
const DEFINITIONS={"ground_v1":CONFIG,"ground_v2":preload("res://data/weather/roadside_nest_disturbance_v2.tres")}
var definition_id: String="ground_v2"
var enabled: bool=false
var scent_disturbed: bool=false
var records: Dictionary[String,Dictionary]={}
func definition() -> NestDisturbanceDefinition:return DEFINITIONS[definition_id]
func phase(tick: int) -> String:
	var config: NestDisturbanceDefinition=definition()
	if not enabled or tick<config.warning_tick:return "dormant"
	if tick<config.warning_tick+config.warning_ticks:return "warning"
	return "pressure" if tick<config.warning_tick+config.warning_ticks+config.pressure_ticks else "settled"
func to_dict() -> Dictionary:return {"definition_id":definition_id,"enabled":enabled,"scent_disturbed":scent_disturbed,"records":records.duplicate(true)}
func restore(data: Variant, colony: ColonyState, tick: int, scenario: String) -> bool:
	if not data is Dictionary or data.size()!=3+int(data.has("definition_id")) or not data.has_all(["enabled","scent_disturbed","records"]) or not data.enabled is bool or not data.scent_disturbed is bool or not data.records is Dictionary:return false
	var profile: Variant=data.get("definition_id","ground_v1")
	if not profile is String or not DEFINITIONS.has(profile):return false
	var config: NestDisturbanceDefinition=DEFINITIONS[profile]
	if data.enabled and scenario!="roadside" or not data.enabled and (data.scent_disturbed or not data.records.is_empty()):return false
	if data.scent_disturbed and tick<config.warning_tick+config.warning_ticks:return false
	var parsed: Dictionary[String,Dictionary]={}
	for id: Variant in data.records:
		var record: Variant=data.records[id]
		if not id is String or not colony.piles.has(id) or not record is Dictionary or record.size()!=7 or not record.has_all(["warned","impacted","settled","workers","brood","royals","queen_injury"]):return false
		for key: String in record:
			if not WorkerLedger.valid_count(record[key]):return false
		if record.warned<config.warning_tick or record.warned>tick or record.impacted>tick or record.settled>tick:return false
		if record.impacted>0 and (record.impacted<maxi(int(record.warned),config.warning_tick+config.warning_ticks) or record.impacted>=config.warning_tick+config.warning_ticks+config.pressure_ticks):return false
		if record.settled>0 and record.settled<config.warning_tick+config.warning_ticks+config.pressure_ticks:return false
		if record.queen_injury>config.queen_injury or record.royals not in [0.0,3.0,6.0] or record.brood>colony.piles[id].brood_lost_total or record.workers>colony.piles[id].workers.lost_total:return false
		if record.impacted==0 and (record.workers>0 or record.brood>0 or record.royals>0 or record.queen_injury>0):return false
		if colony.piles[id].position.distance_to(config.position)>config.radius:return false
		parsed[id]=record.duplicate()
		for key: String in record:parsed[id][key]=int(record[key])
	definition_id=profile;enabled=data.enabled;scent_disturbed=data.scent_disturbed;records=parsed;return true
