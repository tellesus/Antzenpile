class_name WorkerReinforcementState
extends RefCounted
## Physical migration plus independently returned expedition reports.
const CONFIG=preload("res://data/resources/default_interpile_supply.tres")
const TRAILS=preload("res://data/trails/default_trails.tres")
var phase: String="none"
var elapsed_ticks: int=0
var departed_tick: int=0
var settled: bool=false
var trips_started: int=0
var trips_reported: int=0
var arrivals: int=0
var last_reported_tick: int=0
var last_settled: int=0
var moved_profiles: Dictionary[String,int]={}
func active() -> bool:return phase!="none"
func assigned() -> int:return (CONFIG.reinforcement_messengers if settled else CONFIG.reinforcement_workers+CONFIG.reinforcement_messengers) if active() else 0
func reported_arrivals() -> int:return arrivals-(1 if active() and settled else 0)
func to_dict() -> Dictionary:
 return {"phase":phase,"elapsed_ticks":elapsed_ticks,"departed_tick":departed_tick,"settled":settled,"trips_started":trips_started,"trips_reported":trips_reported,"arrivals":arrivals,"last_reported_tick":last_reported_tick,"last_settled":last_settled,"moved_profiles":moved_profiles.duplicate()}
func restore(data: Dictionary, colony: ColonyState, founding: FoundingState, supply: InterpileSupplyState, tick: int) -> bool:
 if data.size()!=10 or not data.has_all(to_dict().keys()) or data.phase not in ["none","outbound","returning"] or not data.settled is bool or not data.moved_profiles is Dictionary:return false
 for key: String in ["elapsed_ticks","departed_tick","trips_started","trips_reported","arrivals","last_reported_tick","last_settled"]:
  if not WorkerLedger.valid_count(data[key]):return false
 var away: bool=data.phase!="none"
 if data.trips_started!=data.trips_reported+(1 if away else 0) or data.arrivals>data.trips_started or int(data.last_settled) not in [0,CONFIG.reinforcement_workers]:return false
 if data.last_reported_tick>tick or data.departed_tick>tick or (data.trips_reported==0 and (data.last_reported_tick!=0 or data.last_settled!=0)):return false
 if data.phase!="returning" and data.settled or data.phase=="none" and data.elapsed_ticks!=0:return false
 if data.trips_started==0 and (data.departed_tick!=0 or data.arrivals!=0):return false
 if data.arrivals-(1 if data.settled else 0)<0 or data.arrivals-(1 if data.settled else 0)>data.trips_reported:return false
 if data.last_settled>0 and data.arrivals-(1 if data.settled else 0)==0:return false
 var history: Dictionary[String,int]={};var total: int=0
 for profile: Variant in data.moved_profiles:
  if not profile is String or not WorkerLedger.valid_count(data.moved_profiles[profile]) or data.moved_profiles[profile]<=0:return false
  history[profile]=int(data.moved_profiles[profile]);total+=history[profile]
 if total!=data.arrivals*CONFIG.reinforcement_workers:return false
 if data.trips_started>0:
  if founding.phase!="established" or not colony.piles.has("satellite_1"):return false
  var h: PileState=colony.piles.home;var d: PileState=colony.piles.satellite_1
  var leg: int=TRAILS.leg_ticks(h.position.distance_to(d.position))
  if data.departed_tick<d.foundation.founded_tick or (data.trips_reported>0 and data.last_reported_tick<d.foundation.founded_tick):return false
  if data.arrivals>floori(float(tick-d.foundation.founded_tick+leg)/(2*leg)):return false
  if not away and data.last_reported_tick<data.departed_tick+(2*leg if data.last_settled>0 else 0):return false
  if away:
   if supply.phase!="none" or data.elapsed_ticks>=leg:return false
   var minimum: int=data.elapsed_ticks if data.phase=="outbound" else leg+data.elapsed_ticks if data.settled else leg-data.elapsed_ticks
   if data.departed_tick+minimum>tick:return false
   if data.trips_reported>0 and data.last_reported_tick>data.departed_tick:return false
  for profile: String in history:
   if history[profile]>h.genetics.exported.get(profile,0) or history[profile]>d.genetics.imported.get(profile,0):return false
 phase=data.phase;elapsed_ticks=int(data.elapsed_ticks);departed_tick=int(data.departed_tick);settled=data.settled
 trips_started=int(data.trips_started);trips_reported=int(data.trips_reported);arrivals=int(data.arrivals);last_reported_tick=int(data.last_reported_tick);last_settled=int(data.last_settled);moved_profiles=history
 return true
func valid_route(route: TrailRouteState, supply: InterpileSupplyState) -> bool:
 return active() and route.purpose=="interpile" and route.allocated_workers==assigned() and route.active_workers==assigned() and route.desired_workers==assigned() and route.status=="active" and is_equal_approx(route.delivered_total,supply.delivered_total()) and supply._valid_receipt(route.receipt)
