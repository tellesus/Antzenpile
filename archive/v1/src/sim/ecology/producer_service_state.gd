class_name ProducerServiceState
extends RefCounted
## One source-owned aggregate service party; private arrival is not a UI fact.
const CONFIG=preload("res://data/ecology/backyard_honeydew.tres")
const CAP: int=16
var failure_goal_hidden: bool=false
var private_failure: bool=false
var target: int=0
var count: int=0
var phase: String="none"
var elapsed_ticks: int=0
var leg_ticks: int=0
var destination: Vector2=Vector2.ZERO
var departed_tick: int=0
var recall_tick: int=0
var last_returned_tick: int=0
var last_result: String=""
var recognition_share: float=0.0
var required: int=0
var energy_multiplier: float=1.0
var legacy_onsite: bool=false
func known_target() -> int:return count if failure_goal_hidden and phase=="returning" else target
func contribution() -> float:return minf(2.0,float(count)/required) if phase=="working" and required>0 else 0.0
func to_dict() -> Dictionary:
	return {"failure_goal_hidden":failure_goal_hidden,"private_failure":private_failure,"target":target,"count":count,"phase":phase,"elapsed_ticks":elapsed_ticks,"leg_ticks":leg_ticks,"destination":[destination.x,destination.y],"departed_tick":departed_tick,"recall_tick":recall_tick,"last_returned_tick":last_returned_tick,"last_result":last_result,"recognition_share":recognition_share,"required":required,"energy_multiplier":energy_multiplier,"legacy_onsite":legacy_onsite}
func restore(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=16 or not data.has_all(to_dict().keys()) or data.phase not in ["none","outbound","working","returning"] or not data.failure_goal_hidden is bool or not data.private_failure is bool or not data.legacy_onsite is bool or data.last_result not in ["","returned","not_found"]:return false
	for key: String in ["target","count","elapsed_ticks","leg_ticks","departed_tick","recall_tick","last_returned_tick","required"]:
		if not WorkerLedger.valid_count(data[key]):return false
	if data.target>CAP or data.count>CAP or data.private_failure and data.phase!="returning" or data.failure_goal_hidden and (not data.private_failure or data.target!=0):return false
	for key: String in ["recognition_share","energy_multiplier"]:
		if not typeof(data[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])):return false
	if absf(data.recognition_share)>1 or data.energy_multiplier<0.7 or data.energy_multiplier>1.5 or not WorldState._numbers(data.destination,2):return false
	if data.phase=="none":
		if data.count!=0 or data.elapsed_ticks!=0 or data.leg_ticks!=0 or data.departed_tick!=0 or data.recall_tick!=0 or data.required!=0 or data.recognition_share!=0 or data.energy_multiplier!=1 or data.legacy_onsite or data.destination!=[0.0,0.0]:return false
	else:
		if data.count<1 or data.leg_ticks<1 or data.elapsed_ticks>=data.leg_ticks or data.required!=AdaptationRules.protection_workers(CONFIG.protection_workers,data.recognition_share):return false
		if data.phase=="working" and data.elapsed_ticks!=0 or data.phase!="returning" and data.recall_tick!=0:return false
		if data.phase in ["outbound","working"] and data.target!=data.count:return false
		if data.legacy_onsite and (data.phase=="outbound" or data.departed_tick!=0 or data.energy_multiplier!=1):return false
	failure_goal_hidden=data.failure_goal_hidden;private_failure=data.private_failure;target=int(data.target);count=int(data.count);phase=data.phase;elapsed_ticks=int(data.elapsed_ticks);leg_ticks=int(data.leg_ticks);destination=Vector2(data.destination[0],data.destination[1]);departed_tick=int(data.departed_tick);recall_tick=int(data.recall_tick);last_returned_tick=int(data.last_returned_tick);last_result=data.last_result;recognition_share=float(data.recognition_share);required=int(data.required);energy_multiplier=float(data.energy_multiplier);legacy_onsite=data.legacy_onsite
	return true
