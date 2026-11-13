class_name PredatorMotionState
extends RefCounted
## One bounded physical patrol; saved progress never drives colony knowledge.
var position: Vector2
var previous: Vector2
var start: Vector2
var destination: Vector2
var phase: String = "waiting"
var progress: int = 0
var leg_ticks: int = 1
var remaining_pause: int = 0
var pause_total: int = 0
var started_tick: int = 0

func initialize(config: PredatorDefinition) -> void:
	position=config.position; previous=position
	_begin(config.patrol_end,config,0,"waiting")

func _begin(to: Vector2, config: PredatorDefinition, tick: int, next_phase: String) -> void:
	start=position;destination=to;progress=0;remaining_pause=0;pause_total=0;started_tick=tick;phase=next_phase
	leg_ticks=maxi(1,ceili(start.distance_to(destination)/(config.speed*SimulationClock.TICK_INTERVAL)))

func settle(predator: PredatorState, tick: int) -> void:
	previous=position
	if predator.killed: phase="killed"
	else: _begin(predator.definition().retreat_position,predator.definition(),tick,"fleeing")

func tick(run: RunState) -> void:
	previous=position
	var config: PredatorDefinition=run.predator.definition()
	var tick_count: int=run.clock.tick_count
	if tick_count<config.first_tick or phase in ["gone","killed"]: return
	if phase=="fleeing": _advance();return
	# An actual encounter pins this creature, not a remote command or stale sighting.
	if run.journey_response.phase=="fighting": return
	if phase=="waiting": _begin(config.patrol_end,config,tick_count,"patrolling");return
	if phase=="paused":
		remaining_pause-=1
		if remaining_pause==0: _begin(config.position if position==config.patrol_end else config.patrol_end,config,tick_count,"patrolling")
		return
	_advance()
	if progress==leg_ticks:
		phase="paused";started_tick=tick_count
		var feeding: bool=false
		for node: WorldNodeState in run.world.nodes.values():
			if node.definition_id=="carbohydrate" and node.active and node.quantity>0 and node.position.distance_to(position)<=config.feeding_radius: feeding=true;break
		pause_total=run.rng.randi_range(maxi(1,config.pause_ticks/2),config.pause_ticks)*(2 if feeding else 1)
		remaining_pause=pause_total

func _advance() -> void:
	progress=mini(leg_ticks,progress+1)
	position=start.lerp(destination,float(progress)/leg_ticks)
	if phase=="fleeing" and progress==leg_ticks: phase="gone"

func to_dict() -> Dictionary:
	return {"position":[position.x,position.y],"previous":[previous.x,previous.y],"start":[start.x,start.y],"destination":[destination.x,destination.y],"phase":phase,"progress":progress,"leg_ticks":leg_ticks,"remaining_pause":remaining_pause,"pause_total":pause_total,"started_tick":started_tick}

func restore(data: Variant, config: PredatorDefinition, predator: PredatorState, tick_count: int) -> bool:
	if not data is Dictionary or data.size()!=10 or not data.has_all(to_dict().keys()) or data.phase not in ["waiting","patrolling","paused","fleeing","gone","killed"]: return false
	for key: String in ["progress","leg_ticks","remaining_pause","pause_total","started_tick"]:
		if not WorkerLedger.valid_count(data[key]): return false
	if data.leg_ticks<1 or data.progress>data.leg_ticks or data.remaining_pause>data.pause_total or data.pause_total>config.pause_ticks*2 or data.started_tick>tick_count: return false
	var points: Dictionary={}
	for key: String in ["position","previous","start","destination"]:
		if not data[key] is Array or data[key].size()!=2: return false
		for value: Variant in data[key]:
			if not typeof(value) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return false
		points[key]=Vector2(data[key][0],data[key][1])
	if points.position!=points.start.lerp(points.destination,float(data.progress)/data.leg_ticks) or points.previous.distance_to(points.position)>config.speed*SimulationClock.TICK_INTERVAL+0.00001: return false
	if data.leg_ticks!=maxi(1,ceili(points.start.distance_to(points.destination)/(config.speed*SimulationClock.TICK_INTERVAL))): return false
	if data.phase in ["fleeing","gone"]:
		if predator.defeated_at<=0 or predator.killed or points.destination!=config.retreat_position or data.started_tick!=roundi(predator.defeated_at/SimulationClock.TICK_INTERVAL): return false
		if Geometry2D.get_closest_point_to_segment(points.start,config.position,config.patrol_end).distance_to(points.start)>0.00001: return false
		if data.progress>tick_count-data.started_tick or data.phase=="gone" and data.progress!=data.leg_ticks: return false
	else:
		if points.start not in [config.position,config.patrol_end] or points.destination not in [config.position,config.patrol_end] or points.start==points.destination: return false
		if (data.phase=="killed") != predator.killed or predator.defeated_at>0 and not predator.killed: return false
		if data.phase=="waiting" and (data.started_tick!=0 or data.progress!=0 or data.pause_total!=0 or tick_count>=config.first_tick): return false
		if data.phase=="patrolling" and (data.pause_total!=0 or data.progress>=data.leg_ticks or data.progress>tick_count-data.started_tick): return false
		if data.phase=="paused" and (data.progress!=data.leg_ticks or data.remaining_pause<1 or data.pause_total<maxi(1,config.pause_ticks/2) or data.pause_total-data.remaining_pause>tick_count-data.started_tick): return false
		if data.phase!="waiting" and data.started_tick<config.first_tick: return false
	position=points.position;previous=points.previous;start=points.start;destination=points.destination;phase=data.phase;progress=int(data.progress);leg_ticks=int(data.leg_ticks);remaining_pause=int(data.remaining_pause);pause_total=int(data.pause_total);started_tick=int(data.started_tick)
	return true
