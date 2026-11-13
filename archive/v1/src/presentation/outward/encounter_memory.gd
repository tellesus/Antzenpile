class_name EncounterMemory
extends RefCounted
## Resolved returned memories fade; no hidden combat phase is consumed.
const Memory = preload("res://src/presentation/outward/source_memory.gd")
const FADE_SECONDS: float = 3.0
var _baselined: bool = false
var _fades: Dictionary = {}
var _receipts: Dictionary = {}

func reset() -> void:
	_baselined=false; _fades.clear(); _receipts.clear()

static func resolved_at(signal_data: Dictionary, status: Dictionary) -> float:
	if signal_data.get("category")!="threat": return -1
	var route: Dictionary={}
	for candidate: Dictionary in status.get("trails",[]):
		if candidate.destination_knowledge_id==signal_data.get("source_knowledge_id",""): route=candidate; break
	if route.is_empty(): return -1
	var state: Dictionary=status.get("journey_response",{})
	var report: Dictionary=state.get("reports",{}).get(route.get("id",""),{})
	var latest: float=maxf(float(route.get("last_loss_time",0)),float(route.get("last_witness_time",0)))
	if signal_data.get("threat_kind","") in ["ambush","mixed"] and Memory.predator_addressed(route,state):
		var at: float=state.outcomes[route.id].received_at
		return at if at>=latest else -1.0
	if signal_data.get("threat_kind","")=="foreign" and route.get("conflict_report","") in ["secured","dispersed"]:
		var at: float=route.get("conflict_received_at",0)
		return at if at>=maxf(latest,float(report.get("received_at",0))) else -1.0
	return -1

func apply(signals: Array[Dictionary], status: Dictionary, delta: float) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var present: Dictionary={}
	for source: Dictionary in signals:
		present[source.id]=true
		var signal_data: Dictionary=source.duplicate(true)
		var receipt: float=resolved_at(signal_data,status)
		if receipt>=0:
			var fade: Dictionary=_fades.get(source.id,{"receipt":receipt,"elapsed":FADE_SECONDS if not _baselined else 0.0})
			if fade.receipt!=receipt: fade={"receipt":receipt,"elapsed":0.0}
			fade.elapsed=minf(FADE_SECONDS,fade.elapsed+maxf(0,delta))
			_fades[source.id]=fade
			if fade.elapsed>=FADE_SECONDS: continue
			signal_data.memory_alpha=1.0-smoothstep(0,FADE_SECONDS,fade.elapsed)
			signal_data.memory_resolved=true
		else: _fades.erase(source.id)
		result.append(signal_data)
	for id: String in _fades.keys():
		if not present.has(id): _fades.erase(id)
	_baselined=true
	return result

func notices(status: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	var state: Dictionary=status.get("journey_response",{})
	for route_id: String in state.get("outcomes",{}):
		var outcome: Dictionary=state.outcomes[route_id]
		var key: String=route_id+":response"
		if _receipts.has(key) and _receipts[key]!=outcome.received_at:
			result.append("%s · %d/%d returned, %d lost. See Journey reports." % [Memory.defense_label(outcome),outcome.sent-outcome.lost,outcome.sent,outcome.lost])
		elif _receipts.get("ready",false) and not _receipts.has(key):
			result.append("%s · %d/%d returned, %d lost. See Journey reports." % [Memory.defense_label(outcome),outcome.sent-outcome.lost,outcome.sent,outcome.lost])
		_receipts[key]=outcome.received_at
	for route: Dictionary in status.get("trails",[]):
		if route.get("conflict_report","").is_empty(): continue
		var key: String=route.id+":junction"
		if _receipts.get("ready",false) and _receipts.get(key,-1)!=route.get("conflict_received_at",0):
			result.append({"secured":"Foreign ants withdrew; the encounter is over.","dispersed":"Encounter dispersed.","withdrew":"Our ants withdrew; the route is not secured.","holding":"Returned report: our gatherers hold the junction.","resisted":"Returned report: strong resistance."}.get(route.conflict_report,"New junction report returned.")+" See Journey reports.")
		_receipts[key]=route.get("conflict_received_at",0)
	_receipts.ready=true
	return result
