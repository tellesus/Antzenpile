class_name ResidueContactState
extends RefCounted
## One captured ground contact, owned by one physical journey.
var observed_tick: int = 0
var position: Vector2 = Vector2.ZERO
func active() -> bool:return observed_tick>0
func capture(point: Vector2, tick: int) -> void:
	if active():return
	position=point;observed_tick=tick
func to_dict() -> Dictionary:return {"observed_tick":observed_tick,"position":[position.x,position.y]}
func report(time: float) -> Dictionary:
	var estimate: Vector2=position.round()
	return {"observed_at":observed_tick*SimulationClock.TICK_INTERVAL,"received_at":time,"estimated_position":[estimate.x,estimate.y]}
func restore(data: Variant, tick: int, config: ResidueDefinition=ResidueZoneState.CONFIG) -> bool:
	if not data is Dictionary or data.size()!=2 or not data.has_all(["observed_tick","position"]) or not WorkerLedger.valid_count(data.observed_tick) or data.observed_tick>tick:return false
	if not data.position is Array or data.position.size()!=2:return false
	for value: Variant in data.position:
		if not typeof(value) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return false
	var point:=Vector2(data.position[0],data.position[1])
	if data.observed_tick==0:
		if point!=Vector2.ZERO:return false
	elif data.observed_tick<config.first_tick or data.observed_tick>=config.first_tick+config.duration_ticks or point.distance_to(config.position)>config.radius+0.00001:return false
	observed_tick=int(data.observed_tick);position=point;return true
