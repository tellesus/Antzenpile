class_name FoundingState
extends RefCounted
## Physical camp and private expedition evidence; original ledger owns all settlers.
const CONFIG = preload("res://data/resources/default_founding.tres")
var phase: String = "none"
var route_id: String = ""
var elapsed_ticks: int = 0
var leg_ticks: int = 0
var departed_tick: int = 0
var reported_tick: int = 0
var reproductive_group: Dictionary = {}
var contaminant_mass: float = 0.0
func awaiting() -> bool: return phase in ["outbound","settling","messenger","returning"]
func assigned() -> int: return CONFIG.workers-1 if phase=="ready" else CONFIG.workers if awaiting() else 0
func to_dict() -> Dictionary:
	return {"phase":phase,"route_id":route_id,"elapsed_ticks":elapsed_ticks,"leg_ticks":leg_ticks,"departed_tick":departed_tick,"reported_tick":reported_tick,"reproductive_group":reproductive_group.duplicate(true),"contaminant_mass":contaminant_mass}
func restore(data: Dictionary, colony: ColonyState, tick: int) -> bool:
	if data.size()!=8 or not data.has_all(to_dict().keys()): return false
	if not data.phase is String or data.phase not in ["none","outbound","settling","messenger","ready","returning","failed"] or not data.route_id is String: return false
	for key: String in ["elapsed_ticks","leg_ticks","departed_tick","reported_tick"]:
		if not WorkerLedger.valid_count(data[key]): return false
	if not data.reproductive_group is Dictionary or not typeof(data.contaminant_mass) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.contaminant_mass)) or data.contaminant_mass<0 or data.contaminant_mass>CONFIG.carbohydrate: return false
	if data.phase=="none": return data.route_id.is_empty() and data.elapsed_ticks==0 and data.leg_ticks==0 and data.departed_tick==0 and data.reported_tick==0 and data.reproductive_group.is_empty() and data.contaminant_mass==0
	if data.route_id.is_empty() or data.leg_ticks<1 or data.departed_tick>tick: return false
	var parent: PileState=colony.piles.home
	var group:=ReproductionState.new()
	if not group.restore(data.reproductive_group,WorkerLedger.new(),"home",parent.genetics.established,parent.brood_matured_total,parent.nursery_state,parent.food_exchange_state,parent.queen_count) or group.phase!="ready": return false
	if group.laid_tick+group.CONFIG.egg_ticks+group.CONFIG.larva_ticks+group.CONFIG.pupa_ticks>data.departed_tick: return false
	var minimum: int=data.elapsed_ticks
	if data.phase=="outbound":
		if data.elapsed_ticks>=data.leg_ticks: return false
	elif data.phase=="settling":
		if data.elapsed_ticks>=CONFIG.preparation_ticks: return false
		minimum+=data.leg_ticks
	elif data.phase in ["messenger","returning"]:
		if data.elapsed_ticks>=data.leg_ticks: return false
		minimum+=data.leg_ticks+(CONFIG.preparation_ticks if data.phase=="messenger" else 0)
	else:
		if data.elapsed_ticks!=0 or data.reported_tick<data.departed_tick+2*data.leg_ticks+(CONFIG.preparation_ticks if data.phase=="ready" else 0) or data.reported_tick>tick: return false
		minimum=2*data.leg_ticks+(CONFIG.preparation_ticks if data.phase=="ready" else 0)
	if minimum>tick-data.departed_tick or (data.phase not in ["ready","failed"] and data.reported_tick!=0): return false
	if data.phase!="failed" and parent.reproduction.phase!="none": return false
	phase=data.phase; route_id=data.route_id; elapsed_ticks=int(data.elapsed_ticks); leg_ticks=int(data.leg_ticks)
	departed_tick=int(data.departed_tick); reported_tick=int(data.reported_tick); reproductive_group=group.to_dict()
	contaminant_mass=roundf(float(data.contaminant_mass)*100000000.0)/100000000.0
	return true
func valid_route(route: TrailRouteState) -> bool:
	return route.id==route_id and route.purpose=="founding" and route.origin_pile=="home" and route.allocated_workers==assigned() and route.active_workers==assigned() and route.desired_workers==assigned() and route.status==("inactive" if phase=="failed" else "active") and not route.reported_depleted and route.delivered_total==0 and route.receipt.is_empty() and route.reported_losses==0 and route.foreign_reports==0 and route.conflict_report.is_empty() and not route.energy_limited and not route.resume_on_report and route.departure_cooldown_ticks==0
