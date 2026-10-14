class_name RivalContinuityState
extends RefCounted
## A bounded food-funded group belongs to the rival's independent economy.
const CONFIG = preload("res://data/ecology/backyard_rival.tres")
var enabled: bool = true
var brood_count: int = 0
var remaining_ticks: int = 0
var funded_tick: int = 0
var emerged_total: int = 0
var replacement_spent: float = 0.0
var rest_until_tick: int = 0

func to_dict() -> Dictionary:
	return {"enabled":enabled, "brood_count":brood_count, "remaining_ticks":remaining_ticks,
		"funded_tick":funded_tick, "emerged_total":emerged_total, "replacement_spent":replacement_spent, "rest_until_tick":rest_until_tick}

func restore(data: Variant, ledger: WorkerLedger, tick: int) -> bool:
	if not data is Dictionary or data.size()!=7 or not data.has_all(to_dict().keys()) or not data.enabled is bool: return false
	for key: String in ["brood_count", "remaining_ticks", "funded_tick", "emerged_total", "rest_until_tick"]:
		if not WorkerLedger.valid_count(data[key]): return false
	if data.rest_until_tick>tick+CONFIG.retreat_ticks or data.rest_until_tick>0 and data.rest_until_tick<CONFIG.first_tick+CONFIG.retreat_ticks: return false
	if not typeof(data.replacement_spent) in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(data.replacement_spent)): return false
	if data.brood_count>CONFIG.replacement_group or data.emerged_total>WorkerLedger.MAX_COUNT-CONFIG.population: return false
	if ledger.total+ledger.lost_total!=CONFIG.population+data.emerged_total or ledger.total+data.brood_count>CONFIG.population: return false
	if absf(data.replacement_spent-(data.emerged_total+data.brood_count)*CONFIG.replacement_cost)>0.00001: return false
	var pool: Dictionary = ledger.to_dict().commitments.get("rival:brood",{})
	if data.brood_count==0:
		if data.remaining_ticks!=0 or data.funded_tick!=0 or not pool.is_empty(): return false
	else:
		if data.funded_tick<CONFIG.first_tick or data.funded_tick>tick or data.remaining_ticks<1 or data.remaining_ticks!=CONFIG.replacement_ticks-(tick-data.funded_tick): return false
		if pool.get("count",0)!=CONFIG.replacement_carers or pool.get("kind","")!="internal" or pool.get("owner_id","")!="rival_brood": return false
	if data.emerged_total>maxi(0,floori(float(tick-CONFIG.first_tick)/(CONFIG.replacement_ticks+1)))*CONFIG.replacement_group: return false
	if not data.enabled and (data.brood_count!=0 or data.emerged_total!=0 or data.replacement_spent!=0 or data.rest_until_tick!=0): return false
	enabled=data.enabled;brood_count=int(data.brood_count);remaining_ticks=int(data.remaining_ticks)
	funded_tick=int(data.funded_tick);emerged_total=int(data.emerged_total);replacement_spent=float(data.replacement_spent)
	rest_until_tick=int(data.rest_until_tick)
	return true
