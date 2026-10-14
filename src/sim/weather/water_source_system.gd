class_name WaterSourceSystem
extends RefCounted
## Physical quantities change; only real samples/returns change source memory.
var _run: RunState
func _init(run: RunState) -> void:_run=run
func tick(delta: float, wet_seconds: float) -> void:
	var ids: Array=_run.world.nodes.keys();ids.sort()
	var severe_dry: bool=wet_seconds==0 and HeatSystem.hot_dry(_run)
	for id: String in ids:
		var node: WorldNodeState=_run.world.nodes[id]
		var profile: SourceProfile=SourceCatalog.PROFILES.get(node.source_type)
		if not profile is WaterSourceProfile:continue
		var water: WaterSourceProfile=profile
		var renewed: float=delta*water.renewal_per_second*(water.severe_dry_renewal_multiplier if severe_dry else 1.0)
		var wet: float=wet_seconds*water.wet_refill_per_second
		var evaporated: float=(delta-wet_seconds)*water.evaporation_per_second*(water.severe_dry_evaporation_multiplier if severe_dry else 1.0)
		node.quantity=roundf(clampf(node.quantity+renewed+wet-evaporated,0.0,water.capacity)*100000.0)/100000.0
		node.active=node.quantity>0
