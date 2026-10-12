class_name FoundingState
extends RefCounted
## Physical camp and private expedition evidence; original ledger owns all settlers.
const CONFIG = preload("res://data/resources/default_founding.tres")
var phase: String = "none"
var origin_pile: String="home"
var destination_pile: String="satellite_1"
var settler_profiles: Dictionary[String,int]={}
var profiles_recorded: bool=true
var route_id: String = ""
var elapsed_ticks: int = 0
var leg_ticks: int = 0
var departed_tick: int = 0
var reported_tick: int = 0
var reproductive_group: Dictionary = {}
var contaminant_mass: float = 0.0
var site_profile: String = ""
var preparation_ticks: int = CONFIG.preparation_ticks
var quoted_site_profile: String = ""
var preparation_from_pack: bool = false
var site_report: Observation
func carried_supplies() -> Dictionary:
	var result: Dictionary=CONFIG.supplies()
	if preparation_from_pack: result.carbohydrate-=SiteCatalog.get_profile(site_profile).extra_carbohydrate
	return result
func awaiting() -> bool: return phase in ["outbound","settling","messenger","returning"]
func assigned() -> int: return CONFIG.workers-1 if phase=="ready" else CONFIG.workers if awaiting() else 0
func to_dict() -> Dictionary:
	var record: Dictionary={"origin_pile":origin_pile,"destination_pile":destination_pile,"phase":phase,"route_id":route_id,"elapsed_ticks":elapsed_ticks,"leg_ticks":leg_ticks,"departed_tick":departed_tick,"reported_tick":reported_tick,"reproductive_group":reproductive_group.duplicate(true),"contaminant_mass":contaminant_mass,"site_profile":site_profile,"preparation_ticks":preparation_ticks,"quoted_site_profile":quoted_site_profile,"preparation_from_pack":preparation_from_pack,"site_report":site_report.to_dict() if site_report!=null else null}
	if profiles_recorded: record.settler_profiles=settler_profiles.duplicate()
	return record
func restore(data: Dictionary, colony: ColonyState, tick: int, world: WorldState) -> bool:
	if data.size()!=8+int(data.has("site_profile"))+int(data.has("preparation_ticks"))+int(data.has("quoted_site_profile"))+int(data.has("preparation_from_pack"))+int(data.has("site_report"))+int(data.has("origin_pile"))+int(data.has("destination_pile"))+int(data.has("settler_profiles")) or not data.has_all(["phase","route_id","elapsed_ticks","leg_ticks","departed_tick","reported_tick","reproductive_group","contaminant_mass"]): return false
	var origin: Variant=data.get("origin_pile","home");var destination: Variant=data.get("destination_pile","satellite_1")
	if not origin is String or not colony.piles.has(origin) or not PileState.valid_id(destination) or destination=="home" or destination==origin: return false
	var profiles: Variant=data.get("settler_profiles",{})
	if not profiles is Dictionary: return false
	var restored_profiles: Dictionary[String,int]={};var transferred: int=0
	for key: Variant in profiles:
		if not key is String or not WorkerLedger.valid_count(profiles[key]) or profiles[key]<1 or GeneticRepertoire.profile(GeneticRepertoire.traits_for(key))!=key: return false
		for trait_id: String in GeneticRepertoire.traits_for(key):
			if trait_id not in colony.piles[origin].genetics.established: return false
		restored_profiles[key]=int(profiles[key]);transferred+=int(profiles[key])
	if data.phase!="established" and transferred!=0 or data.phase=="established" and data.has("settler_profiles") and transferred!=CONFIG.workers-1: return false
	if not data.phase is String or data.phase not in ["none","outbound","settling","messenger","ready","returning","failed","established"] or not data.route_id is String: return false
	for key: String in ["elapsed_ticks","leg_ticks","departed_tick","reported_tick"]:
		if not WorkerLedger.valid_count(data[key]): return false
	if not data.reproductive_group is Dictionary or not typeof(data.contaminant_mass) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.contaminant_mass)) or data.contaminant_mass<0 or data.contaminant_mass>CONFIG.carbohydrate: return false
	var profile: Variant=data.get("site_profile","");var preparation: Variant=data.get("preparation_ticks",CONFIG.preparation_ticks)
	if not SiteCatalog.accepts(profile,"nest_site") or not WorkerLedger.valid_count(preparation) or preparation!=SiteCatalog.get_profile(profile).preparation_ticks: return false
	var quote: Variant=data.get("quoted_site_profile",profile);var from_pack: Variant=data.get("preparation_from_pack",false)
	if not SiteCatalog.accepts(quote,"nest_site") or not from_pack is bool: return false
	var report: Observation
	if data.get("site_report")!=null:
		report=Observation.new()
		if not data.site_report is Dictionary or not report.restore(data.site_report,world,colony,tick*SimulationClock.TICK_INTERVAL) or report.origin_pile!=origin or report.definition_id!="nest_site" or report.site_profile!=profile or not report.proximity_confirmed or data.phase in ["none","outbound"]: return false
	if quote!=profile and (quote!="" or report==null): return false
	if report!=null and (quote!="" or profile.is_empty() or report.observed_at!=(data.departed_tick+data.leg_ticks)*SimulationClock.TICK_INTERVAL): return false
	if from_pack!=(quote!=profile and SiteCatalog.get_profile(profile).extra_carbohydrate>0): return false
	if data.contaminant_mass>CONFIG.carbohydrate-(SiteCatalog.get_profile(profile).extra_carbohydrate if from_pack else 0.0): return false
	if data.phase=="none" and (report!=null or quote!="" or from_pack): return false
	if data.phase=="none" and (profile!="" or preparation!=CONFIG.preparation_ticks): return false
	if data.phase=="none": return data.route_id.is_empty() and data.elapsed_ticks==0 and data.leg_ticks==0 and data.departed_tick==0 and data.reported_tick==0 and data.reproductive_group.is_empty() and data.contaminant_mass==0
	if data.route_id.is_empty() or data.leg_ticks<1 or data.departed_tick>tick: return false
	var parent: PileState=colony.piles[origin]
	var group:=ReproductionState.new()
	if not group.restore(data.reproductive_group,WorkerLedger.new(),origin,parent.genetics.established,parent.brood_matured_total,parent.nursery_state,parent.food_exchange_state,parent.queen_count) or group.phase!="ready": return false
	if group.laid_tick+group.CONFIG.egg_ticks+group.CONFIG.larva_ticks+group.CONFIG.pupa_ticks>data.departed_tick: return false
	var minimum: int=data.elapsed_ticks
	if data.phase=="outbound":
		if data.elapsed_ticks>=data.leg_ticks: return false
	elif data.phase=="settling":
		if data.elapsed_ticks>=preparation: return false
		minimum+=data.leg_ticks
	elif data.phase in ["messenger","returning"]:
		if data.elapsed_ticks>=data.leg_ticks: return false
		minimum+=data.leg_ticks+(int(preparation) if data.phase=="messenger" else 0)
	else:
		if data.elapsed_ticks!=0 or data.reported_tick<data.departed_tick+2*data.leg_ticks+(int(preparation) if data.phase in ["ready","established"] else 0) or data.reported_tick>tick: return false
		minimum=2*data.leg_ticks+(int(preparation) if data.phase in ["ready","established"] else 0)
	if minimum>tick-data.departed_tick or (data.phase not in ["ready","failed","established"] and data.reported_tick!=0): return false
	if data.phase not in ["failed","established"] and parent.reproduction.phase!="none": return false
	origin_pile=origin;destination_pile=destination;settler_profiles=restored_profiles;profiles_recorded=data.has("settler_profiles")
	phase=data.phase; route_id=data.route_id; elapsed_ticks=int(data.elapsed_ticks); leg_ticks=int(data.leg_ticks)
	departed_tick=int(data.departed_tick); reported_tick=int(data.reported_tick); reproductive_group=group.to_dict()
	site_profile=profile;preparation_ticks=int(preparation)
	quoted_site_profile=quote;preparation_from_pack=from_pack;site_report=report
	contaminant_mass=roundf(float(data.contaminant_mass)*100000000.0)/100000000.0
	return true
func valid_route(route: TrailRouteState) -> bool:
	if site_report!=null and "known:"+site_report.source_node_id!=route.destination_knowledge_id: return false
	if site_report!=null and (site_report.estimated_position!=route.estimated_destination or site_report.uncertainty_radius!=preload("res://data/trails/default_trails.tres").interaction_radius): return false
	if route.id!=route_id or route.origin_pile!=origin_pile or route.purpose!=("interpile" if phase=="established" else "founding"): return false
	if route.reported_depleted or route.reported_losses!=0 or route.foreign_reports!=0 or not route.conflict_report.is_empty() or route.energy_limited or route.resume_on_report or route.departure_cooldown_ticks!=0: return false
	# The physical supply owner validates active interpile labor/cargo/receipts separately.
	if phase=="established": return true
	return route.allocated_workers==assigned() and route.active_workers==assigned() and route.desired_workers==assigned() and route.status==("inactive" if phase=="failed" else "active") and route.delivered_total==0 and route.receipt.is_empty()
