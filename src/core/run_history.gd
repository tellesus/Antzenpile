class_name RunHistory
extends RefCounted
## Bounded, detached physical keyframes. Never consulted by gameplay systems.

const INTERVAL_TICKS: int = 60
const MAX_FRAMES: int = 128
const MAX_EVENTS: int = 128
const MAX_BYTES: int = 768 * 1024
const EVENT_NAMES: Array[String] = ["worker_loss", "brood_loss", "emergence", "pile_established", "trail_changed", "findings_returned", "rain_start", "rain_end", "surface_impact", "predator_loss", "impact_loss", "rival_loss", "predator_killed", "food_toxicity_loss"]
var ended: bool = false
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var thinned: bool = false
var omitted_events: int = 0
var _encoded_frames: Array[String] = []
var _encoded_bytes: int = 0

static func _brood_count(pile) -> int:
	var result: int = 0
	for cohort in pile.brood_cohorts: result+=cohort.count
	return result

static func _point(at: Vector2) -> Array:
	return [snappedf(at.x,0.00001), snappedf(at.y,0.00001)]

static func _rounded(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values: result.append(snappedf(float(value),0.00001))
	return result

static func frame(run) -> Dictionary:
	var piles: Array = []; var nodes: Array = []; var trails: Array = []; var scouts: Array = []
	var stats: Array = [0,0,0,0,run.predator.kills_total,run.swarm.player_losses,run.surface_impact.kills_total,0,0,run.knowledge.nodes.size(),0,int(run.predator.killed),run.surface_impact.serial]
	var ids: Array = run.colony.piles.keys(); ids.sort()
	for id: String in ids:
		var pile = run.colony.piles[id]
		piles.append({"id":id,"position":_point(pile.position),"workers":pile.workers_total,"brood":_brood_count(pile),"stores":_rounded([pile.resources.carbohydrate,pile.resources.protein,pile.resources.water])})
		stats[0]+=pile.workers_total; stats[1]+=pile.workers.lost_total; stats[2]+=pile.brood_lost_total; stats[3]+=pile.brood_matured_total; stats[10]+=pile.food_toxicity.losses
	stats[7]=piles.size()
	ids=run.world.nodes.keys(); ids.sort()
	for id: String in ids:
		var node = run.world.nodes[id]
		nodes.append({"id":id,"kind":node.definition_id,"position":_point(node.position),"quantity":snappedf(node.quantity,0.00001),"active":node.active,"known":run.knowledge.nodes.has("known:"+id)})
	ids=run.trails.segments.keys(); ids.sort()
	for id: String in ids:
		var segment = run.trails.segments[id]; var points: Array = []
		for at: Vector2 in segment.points(): points.append(_point(at))
		trails.append({"id":id,"points":points,"scent":snappedf(segment.pheromone_strength,0.00001),"traffic":segment.traffic})
	stats[8]=trails.size()
	ids=run.scouts.keys(); ids.sort()
	for id: String in ids:
		var scout = run.scouts[id]
		if not scout.lost: scouts.append({"id":id,"position":_point(scout.position)})
	return {"tick":str(run.clock.tick_count),"piles":piles,"nodes":nodes,"trails":trails,"scouts":scouts,"rain":run.rain.phase=="raining","impact":run.surface_impact.active(run.clock.tick_count,run.run_seed),"predator":not run.predator.killed and run.predator.defeated_at==0,"rival":run.rival.direction!="dormant","stats":stats}

func record(run, force: bool = false) -> void:
	if ended: return
	var tick: int = run.clock.tick_count
	# Sample every 15 simulated seconds plus detected major changes; no RNG work.
	if not force and not frames.is_empty() and tick % INTERVAL_TICKS != 0:
		var old: Dictionary = frames.back()
		var changed: bool = run.rain.phase=="raining" and not old.rain or run.rain.phase!="raining" and old.rain or run.surface_impact.active(tick,run.run_seed)!=old.impact or run.surface_impact.serial!=int(old.stats[12]) or int(run.predator.killed)!=int(old.stats[11])
		var totals: Array = [0,0,0,0,run.predator.kills_total,run.swarm.player_losses,run.surface_impact.kills_total,run.colony.piles.size(),run.trails.segments.size(),run.knowledge.nodes.size(),0]
		for pile in run.colony.piles.values():
			totals[0]+=pile.workers_total; totals[1]+=pile.workers.lost_total; totals[2]+=pile.brood_lost_total; totals[3]+=pile.brood_matured_total; totals[10]+=pile.food_toxicity.losses
		if not changed and totals==old.stats.slice(0,11): return
	var next: Dictionary = frame(run)
	if not frames.is_empty():
		var old: Dictionary = frames.back()
		if old.tick==next.tick:
			frames[-1]=next
			_encoded_bytes-=_encoded_size(_encoded_frames[-1])
			_encoded_frames[-1]=JSON.stringify(next,"",true,true)
			_encoded_bytes+=_encoded_size(_encoded_frames[-1])
			return
		for pair: Array in [[1,"worker_loss"],[2,"brood_loss"],[3,"emergence"],[4,"predator_loss"],[5,"rival_loss"],[6,"impact_loss"],[7,"pile_established"],[8,"trail_changed"],[9,"findings_returned"],[10,"food_toxicity_loss"]]:
			var amount: int = int(next.stats[pair[0]]-old.stats[pair[0]])
			if amount>0: _event(next.tick,pair[1],amount)
		if next.trails.size()==old.trails.size() and next.trails!=old.trails:
			for index: int in next.trails.size():
				if next.trails[index].points!=old.trails[index].points: _event(next.tick,"trail_changed",1); break
		if next.rain!=old.rain: _event(next.tick,"rain_start" if next.rain else "rain_end",1)
		if next.stats[11]>old.stats[11]: _event(next.tick,"predator_killed",1)
		if next.stats[12]>old.stats[12]: _event(next.tick,"surface_impact",0)
	frames.append(next)
	_encoded_frames.append(JSON.stringify(next,"",true,true))
	_encoded_bytes+=_encoded_size(_encoded_frames[-1])
	while frames.size()>MAX_FRAMES or _encoded_bytes+32768>MAX_BYTES:
		if frames.size()<=2: break
		# Preserve the beginning and recent half; older samples become coarser.
		var retained: Array[Dictionary] = [frames[0]]
		var encoded: Array[String] = [_encoded_frames[0]]
		for index: int in range(1,frames.size()):
			if index>=frames.size()/2 or index%2==0:
				retained.append(frames[index]); encoded.append(_encoded_frames[index])
		frames=retained; _encoded_frames=encoded; thinned=true
		_encoded_bytes=0
		for value: String in _encoded_frames: _encoded_bytes+=_encoded_size(value)

func _event(tick: String, kind: String, amount: int) -> void:
	events.append({"tick":tick,"kind":kind,"amount":amount})
	if events.size()>MAX_EVENTS: events.pop_front(); omitted_events+=1

func to_dict() -> Dictionary:
	return {"ended":ended,"frames":_encoded_frames.duplicate(),"events":events.duplicate(true),"thinned":thinned,"omitted_events":omitted_events}

func review_dict() -> Dictionary:
	var result: Dictionary = to_dict()
	result.frames=frames.duplicate(true)
	return result

static func _encoded_size(value: String) -> int:
	return JSON.stringify(value).to_utf8_buffer().size()+1

func restore(data: Variant, tick: int, bounds: Rect2, paused: bool) -> bool:
	if not data is Dictionary or data.size()!=5 or not data.has_all(["ended","frames","events","thinned","omitted_events"]): return false
	if not data.ended is bool or not data.thinned is bool or not WorkerLedger.valid_count(data.omitted_events): return false
	if not data.frames is Array or data.frames.size()>MAX_FRAMES or not data.events is Array or data.events.size()>MAX_EVENTS: return false
	if JSON.stringify(data,"",true,true).to_utf8_buffer().size()>MAX_BYTES: return false
	var decoded: Array[Dictionary] = []
	for value: Variant in data.frames:
		if not value is String: return false
		var entry: Variant = JSON.parse_string(value)
		if not entry is Dictionary: return false
		decoded.append(entry)
	var previous: int = -1
	for entry: Variant in decoded:
		if not entry is Dictionary or entry.size()!=10 or not entry.has_all(["tick","piles","nodes","trails","scouts","rain","impact","predator","rival","stats"]): return false
		if not _tick_valid(entry.tick, tick) or entry.tick.to_int()<=previous: return false
		previous=entry.tick.to_int()
		for flag: String in ["rain","impact","predator","rival"]:
			if not entry[flag] is bool: return false
		if not entry.stats is Array or entry.stats.size()!=13: return false
		for number: Variant in entry.stats:
			if not WorkerLedger.valid_count(number): return false
		if not _records(entry.piles,"piles",2,bounds) or not _records(entry.nodes,"nodes",64,bounds) or not _records(entry.trails,"trails",32,bounds) or not _records(entry.scouts,"scouts",8,bounds): return false
		if entry.piles.is_empty() or entry.stats[7]!=entry.piles.size() or entry.stats[8]!=entry.trails.size(): return false
	if data.ended and (data.frames.is_empty() or previous!=tick or not paused): return false
	previous=-1
	for entry: Variant in data.events:
		if not entry is Dictionary or entry.size()!=3 or not entry.has_all(["tick","kind","amount"]): return false
		if not _tick_valid(entry.tick,tick) or entry.tick.to_int()<previous or not entry.kind in EVENT_NAMES or not WorkerLedger.valid_count(entry.amount): return false
		if data.frames.is_empty() or entry.tick.to_int()<decoded[0].tick.to_int() or entry.tick.to_int()>decoded.back().tick.to_int(): return false
		previous=entry.tick.to_int()
	ended=data.ended; thinned=data.thinned; omitted_events=int(data.omitted_events)
	frames=decoded; events.assign(data.events.duplicate(true))
	# JSON has one numeric type; restore canonical integer counters before sampling.
	for entry: Dictionary in frames:
		for index: int in entry.stats.size(): entry.stats[index]=int(entry.stats[index])
		for pile: Dictionary in entry.piles:
			pile.workers=int(pile.workers); pile.brood=int(pile.brood)
			pile.position=_rounded(pile.position); pile.stores=_rounded(pile.stores)
		for node: Dictionary in entry.nodes:
			node.position=_rounded(node.position); node.quantity=snappedf(float(node.quantity),0.00001)
		for scout: Dictionary in entry.scouts: scout.position=_rounded(scout.position)
		for trail: Dictionary in entry.trails:
			trail.traffic=int(trail.traffic); trail.scent=snappedf(float(trail.scent),0.00001)
			for index: int in trail.points.size(): trail.points[index]=_rounded(trail.points[index])
	for entry: Dictionary in events: entry.amount=int(entry.amount)
	_encoded_frames.clear(); _encoded_bytes=0
	for entry: Dictionary in frames:
		_encoded_frames.append(JSON.stringify(entry,"",true,true))
		_encoded_bytes+=_encoded_size(_encoded_frames[-1])
	return true

static func _tick_valid(value: Variant, maximum: int) -> bool:
	return value is String and value.is_valid_int() and str(value.to_int())==value and value.to_int()>=0 and value.to_int()<=maximum

static func _records(values: Variant, kind: String, maximum: int, bounds: Rect2) -> bool:
	if not values is Array or values.size()>maximum: return false
	var ids: Array = []
	for item: Variant in values:
		if not item is Dictionary or not item.has("id") or not item.id is String or item.id.is_empty() or item.id.length()>96 or item.id in ids: return false
		ids.append(item.id)
		match kind:
			"piles":
				if item.size()!=5 or not item.has_all(["position","workers","brood","stores"]) or not _point_valid(item.position,bounds) or not WorkerLedger.valid_count(item.workers) or not WorkerLedger.valid_count(item.brood) or not _numbers(item.stores,3): return false
			"nodes":
				if item.size()!=6 or not item.has_all(["position","kind","quantity","active","known"]) or not _point_valid(item.position,bounds) or not item.kind in ["carbohydrate","protein","water","nest_site"] or not _numbers([item.quantity],1) or not item.active is bool or not item.known is bool: return false
			"trails":
				if item.size()!=4 or not item.has_all(["points","scent","traffic"]) or not item.points is Array or item.points.size()<2 or item.points.size()>8 or not _numbers([item.scent],1) or item.scent>1 or not WorkerLedger.valid_count(item.traffic): return false
				for point: Variant in item.points:
					if not _point_valid(point,bounds): return false
			"scouts":
				if item.size()!=2 or not item.has("position") or not _point_valid(item.position,bounds): return false
	return true

static func _point_valid(value: Variant, bounds: Rect2) -> bool:
	return _numbers(value,2) and bounds.has_point(Vector2(value[0],value[1]))

static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for number: Variant in value:
		if not typeof(number) in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(number)) or number<0: return false
	return true
