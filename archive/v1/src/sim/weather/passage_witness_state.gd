class_name PassageWitnessState
extends RefCounted
## Private supported footprint/odor evidence carried by a real party.
var serial: int=0
var observed_at: float=0.0
var position: Vector2=Vector2.ZERO
func active() -> bool:return serial>0
func capture(value: int, point: Vector2, time: float) -> void:
	if value<serial or value==serial and point.distance_to(SurfaceImpactState.CONFIG.position)>=position.distance_to(SurfaceImpactState.CONFIG.position):return
	serial=value;position=point;observed_at=time
func to_dict() -> Dictionary:return {"serial":serial,"observed_at":observed_at,"position":[position.x,position.y]}
func restore(data: Variant, time: float) -> bool:
	if not data is Dictionary or data.size()!=3 or not data.has_all(to_dict().keys()) or not WorkerLedger.valid_count(data.serial):return false
	if not typeof(data.observed_at) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.observed_at)) or data.observed_at<0 or data.observed_at>time:return false
	if not data.position is Array or data.position.size()!=2:return false
	for value: Variant in data.position:
		if not typeof(value) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return false
	var point:=Vector2(data.position[0],data.position[1])
	if data.serial==0:
		if data.observed_at!=0 or point!=Vector2.ZERO:return false
	elif data.observed_at==0 or point.distance_to(SurfaceImpactState.CONFIG.position)>SurfaceImpactState.CONFIG.confirmation_radius+0.00001:return false
	serial=int(data.serial);position=point;observed_at=float(data.observed_at);return true
