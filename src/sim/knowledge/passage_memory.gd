class_name PassageMemory
extends RefCounted
## Delivered distinct-passage evidence; elapsed time never raises recognition.
var count: int=0
var serial: int=0
var observed_at: float=0.0
var received_at: float=0.0
var estimate: Vector2=Vector2.ZERO
func impression() -> String:return "dog_like" if count>=2 else "large_animal" if count==1 else ""
func remember(witness: PassageWitnessState, time: float) -> void:
	if not witness.active() or witness.serial<serial:return
	if witness.serial>serial:
		if count>=WorkerLedger.MAX_COUNT:return
		count+=1;serial=witness.serial
	elif witness.observed_at<observed_at:return
	observed_at=witness.observed_at;received_at=time;estimate=witness.position.round()
func to_dict() -> Dictionary:return {"count":count,"serial":serial,"observed_at":observed_at,"received_at":received_at,"estimate":[estimate.x,estimate.y]}
func summary() -> Dictionary:
	return {"impression":impression(),"observed_at":observed_at,"received_at":received_at,"estimated_position":[estimate.x,estimate.y]} if count>0 else {}
func restore(data: Variant, time: float) -> bool:
	if not data is Dictionary or data.size()!=5 or not data.has_all(to_dict().keys()) or not WorkerLedger.valid_count(data.count) or not WorkerLedger.valid_count(data.serial) or data.count>data.serial:return false
	for key: String in ["observed_at","received_at"]:
		if not typeof(data[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])) or data[key]<0:return false
	if data.observed_at>data.received_at or data.received_at>time:return false
	if not data.estimate is Array or data.estimate.size()!=2:return false
	for value: Variant in data.estimate:
		if not typeof(value) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return false
	var point:=Vector2(data.estimate[0],data.estimate[1])
	if data.count==0:
		if data.serial!=0 or data.observed_at!=0 or data.received_at!=0 or point!=Vector2.ZERO:return false
	elif data.observed_at==0 or point!=point.round() or point.distance_to(SurfaceImpactState.CONFIG.position)>SurfaceImpactState.CONFIG.confirmation_radius+1:return false
	count=int(data.count);serial=int(data.serial);observed_at=float(data.observed_at);received_at=float(data.received_at);estimate=point;return true
