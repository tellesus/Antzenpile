class_name InterpileSupplyState
extends RefCounted
## One aggregate Home party. Cargo and private travel are separate from returned reports.
const CONFIG=preload("res://data/resources/default_interpile_supply.tres")
const TRAILS=preload("res://data/trails/default_trails.tres")
var enabled: bool=false
var phase: String="none"
var elapsed_ticks: int=0
var departed_tick: int=0
var trips_started: int=0
var trips_reported: int=0
var first_reported_tick: int=0
var last_reported_tick: int=0
var cargo: Dictionary[String,float]={}
var last_payload: Dictionary[String,float]={}
var delivered_units: Dictionary[String,int]={"carbohydrate":0,"protein":0,"water":0}
var energy_multiplier: float=1.0
var carry_multiplier: float=1.0
var chemistry_fraction: float=0.0
var contaminant_mass: float=0.0
func travelling() -> bool: return phase in ["outbound","returning"]
func assigned() -> int: return CONFIG.workers if phase!="none" else 0
func delivered_total() -> float:
 return float(delivered_units.carbohydrate+delivered_units.protein+delivered_units.water)/100000.0
func receipt() -> Dictionary:
 if trips_reported==0: return {}
 return {"first_at":first_reported_tick*SimulationClock.TICK_INTERVAL,"last_at":last_reported_tick*SimulationClock.TICK_INTERVAL,"last_amount":last_payload.carbohydrate+last_payload.protein+last_payload.water,"earlier_unrecorded":false}
func to_dict() -> Dictionary:
 return {"enabled":enabled,"phase":phase,"elapsed_ticks":elapsed_ticks,"departed_tick":departed_tick,"trips_started":trips_started,"trips_reported":trips_reported,"first_reported_tick":first_reported_tick,"last_reported_tick":last_reported_tick,"cargo":cargo.duplicate(),"last_payload":last_payload.duplicate(),"delivered_units":delivered_units.duplicate(),"energy_multiplier":energy_multiplier,"carry_multiplier":carry_multiplier,"chemistry_fraction":chemistry_fraction,"contaminant_mass":contaminant_mass}
func restore(data: Dictionary, colony: ColonyState, founding: FoundingState, tick: int) -> bool:
 if data.size()!=15 or not data.has_all(to_dict().keys()): return false
 if not data.enabled is bool or not data.phase is String or data.phase not in ["none","waiting","outbound","returning"]: return false
 for key: String in ["elapsed_ticks","departed_tick","trips_started","trips_reported","first_reported_tick","last_reported_tick"]:
  if not WorkerLedger.valid_count(data[key]): return false
 for key: String in ["energy_multiplier","carry_multiplier","chemistry_fraction","contaminant_mass"]:
  if not typeof(data[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])): return false
 if data.energy_multiplier<0.7 or data.energy_multiplier>1.2 or data.carry_multiplier<0.85 or data.carry_multiplier>1.3 or data.chemistry_fraction<0 or data.chemistry_fraction>1 or data.contaminant_mass<0: return false
 if data.phase=="none" and data.enabled or data.phase=="waiting" and not data.enabled: return false
 if data.departed_tick>tick or data.last_reported_tick>tick or data.first_reported_tick>data.last_reported_tick: return false
 var away: bool=data.phase in ["outbound","returning"]
 if data.trips_started!=data.trips_reported+(1 if away else 0): return false
 var parsed_cargo: Dictionary[String,float]={}; var parsed_last: Dictionary[String,float]={}
 for packet: Variant in [data.cargo,data.last_payload]:
  if not packet is Dictionary: return false
  # Parse independently below; empty dictionaries retain their explicit phase meaning.
  if not packet.is_empty():
   if packet.size()!=3 or not packet.has_all(PileState.RESOURCE_IDS): return false
   for id: String in PileState.RESOURCE_IDS:
    if not typeof(packet[id]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(packet[id])) or packet[id]<=0: return false
 if away==data.cargo.is_empty() or (data.trips_reported>0)==data.last_payload.is_empty(): return false
 if away:
  for id: String in PileState.RESOURCE_IDS:
   if absf(data.cargo[id]-CONFIG.pack(data.carry_multiplier)[id])>0.000000001: return false
   parsed_cargo[id]=CONFIG.pack(data.carry_multiplier)[id]
  if data.contaminant_mass>parsed_cargo.carbohydrate: return false
 else:
  if data.elapsed_ticks!=0 or data.contaminant_mass!=0 or data.energy_multiplier!=1 or data.carry_multiplier!=1 or data.chemistry_fraction!=0: return false
 if data.trips_reported>0:
  var factor: float=float(data.last_payload.protein)/CONFIG.protein
  if factor<0.85 or factor>1.3: return false
  for id: String in PileState.RESOURCE_IDS:
   if absf(data.last_payload[id]-CONFIG.pack(factor)[id])>0.000000001: return false
   parsed_last[id]=CONFIG.pack(factor)[id]
 elif data.first_reported_tick!=0 or data.last_reported_tick!=0: return false
 if not data.delivered_units is Dictionary or data.delivered_units.size()!=3 or not data.delivered_units.has_all(PileState.RESOURCE_IDS): return false
 var units: Dictionary[String,int]={}
 for id: String in PileState.RESOURCE_IDS:
  if not WorkerLedger.valid_count(data.delivered_units[id]): return false
  units[id]=int(data.delivered_units[id])
  if units[id]<data.trips_reported*CONFIG.pack(0.85)[id]*100000 or units[id]>data.trips_reported*CONFIG.pack(1.3)[id]*100000: return false
  if data.trips_reported==1 and units[id]!=roundi(parsed_last[id]*100000): return false
 if units.carbohydrate!=2*units.protein or units.water!=units.protein: return false
 if data.trips_started==0 and data.departed_tick!=0: return false
 if data.phase!="none" or data.trips_started>0:
  if founding.phase!="established" or not colony.piles.has("satellite_1"): return false
  var parent: PileState=colony.piles.home; var daughter: PileState=colony.piles.satellite_1
  var leg: int=TRAILS.leg_ticks(parent.position.distance_to(daughter.position))
  if data.trips_reported>floori(float(tick-daughter.foundation.founded_tick)/(2*leg)) or data.trips_started>1+floori(float(tick-daughter.foundation.founded_tick)/(2*leg)): return false
  if data.trips_started>0 and data.departed_tick<daughter.foundation.founded_tick+2*leg*(data.trips_started-1): return false
  if away:
   if data.elapsed_ticks>=leg or data.departed_tick+data.elapsed_ticks+(leg if data.phase=="returning" else 0)>tick: return false
   if data.trips_reported>0 and data.last_reported_tick>=data.departed_tick: return false
   if data.chemistry_fraction>0 and "persistent" not in parent.genetics.established: return false
   var fraction: float=0.0
   if parent.adaptation_repertoire=="lean": fraction=(1.0-data.energy_multiplier)/0.3
   elif parent.adaptation_repertoire=="load": fraction=(data.energy_multiplier-1.0)/0.2
   if fraction<-0.00002 or fraction>1.00002 or absf(data.carry_multiplier-AdaptationRules.carry_multiplier(parent.adaptation_repertoire,fraction))>0.00002 or (parent.adaptation_repertoire=="" and data.energy_multiplier!=1): return false
  elif data.trips_reported>0 and data.last_reported_tick!=data.departed_tick+2*leg: return false
  if data.trips_reported>0 and (data.first_reported_tick<daughter.foundation.founded_tick+2*leg or data.last_reported_tick-data.first_reported_tick<2*leg*(data.trips_reported-1)): return false
 enabled=data.enabled;phase=data.phase;elapsed_ticks=int(data.elapsed_ticks);departed_tick=int(data.departed_tick)
 trips_started=int(data.trips_started);trips_reported=int(data.trips_reported);first_reported_tick=int(data.first_reported_tick);last_reported_tick=int(data.last_reported_tick)
 cargo=parsed_cargo;last_payload=parsed_last;delivered_units=units
 energy_multiplier=snappedf(float(data.energy_multiplier),0.00001);carry_multiplier=snappedf(float(data.carry_multiplier),0.00001);chemistry_fraction=snappedf(float(data.chemistry_fraction),0.00001);contaminant_mass=roundf(float(data.contaminant_mass)*100000000.0)/100000000.0
 return true
func valid_route(route: TrailRouteState) -> bool:
 return route.purpose=="interpile" and route.allocated_workers==assigned() and route.active_workers==(CONFIG.workers if travelling() else 0) and route.desired_workers==(CONFIG.workers if enabled else 0) and route.status==("inactive" if phase=="none" else "active" if enabled else "recalling") and is_equal_approx(route.delivered_total,delivered_total()) and _valid_receipt(route.receipt)
func _valid_receipt(saved: Dictionary) -> bool:
 var expected: Dictionary=receipt()
 if expected.is_empty(): return saved.is_empty()
 if saved.size()!=4 or not saved.has_all(expected.keys()) or saved.earlier_unrecorded!=false: return false
 for key: String in ["first_at","last_at","last_amount"]:
  if absf(saved[key]-expected[key])>0.000000001: return false
 return true
