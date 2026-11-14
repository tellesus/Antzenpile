class_name Colony
extends RefCounted
## One colony: its ants, the scent it has laid, and what it knows of the map.
##
## Each simulated ant stands for a small squad. Ants are never commanded.
## They wander, smell their surroundings and react; the player only lays scent.
##
## Knowledge rule: an ant that is "connected" (near the nest or standing on a
## live trail) reports what it touches at once. Any other ant keeps a private
## log that reaches the colony only when the ant reconnects.

enum Scent { ATTRACT, ALARM, REPEL, SEEK }
enum State { OUT, RETURN }
enum Role { FORAGER, SCOUT }

const ERASE := -1
const MAX_ANTS := 1500
const SCOUT_SHARE := 0.07
const FOOD_PER_NEW_ANT := 6.0

const SPEED := 0.45
const SENSE_DIST := 2.5
const SENSE_ANGLE := 0.6
const FORAGER_TRIP_TICKS := 110
const SCOUT_TRIP_TICKS := 220

const TRAIL_DEPOSIT := 0.3
const TRAIL_MAX := 3.0
const TRAIL_DECAY := 0.985        # applied every 5 ticks
const SCENT_DECAY := 0.992        # applied every 5 ticks
const CONNECT_TRAIL := 0.05
const CONNECT_NEST_DIST := 12.0
const SEE_RADIUS := 2
const LOG_LIMIT := 400
const LINGER_TICKS := 80
const HOT_LEVEL := 0.15
const HOT_SAMPLES := 16

var world: SimWorld
var food_stored: float = 0.0
var food_delivered_total: float = 0.0

var count: int = 0
var ax := PackedFloat32Array()
var ay := PackedFloat32Array()
var px := PackedFloat32Array()   # position at the previous tick, for drawing
var py := PackedFloat32Array()
var aheading := PackedFloat32Array()
var acarry := PackedFloat32Array()
var astate := PackedByteArray()
var arole := PackedByteArray()
var aconnected := PackedByteArray()
var atimer := PackedInt32Array()
var alog: Array[PackedInt32Array] = []

var trail: PackedFloat32Array
var scents: Array[PackedFloat32Array] = []
var known_tick: PackedFloat32Array   # tick a cell was last reported; -1e5 = never
var known_food: PackedFloat32Array   # food amount when last reported

var _growth_bank: float = 0.0
var atx := PackedFloat32Array()  # cell an outbound ant is answering a call to; -1 = none
var aty := PackedFloat32Array()
var _hot: Array[PackedInt32Array] = []  # per scent: a sample of strongly scented cells
var _w: int
var _h: int
var _nest: Vector2


func _init(p_world: SimWorld, start_ants: int) -> void:
	world = p_world
	_w = world.width
	_h = world.height
	_nest = Vector2(world.nest_cell) + Vector2(0.5, 0.5)
	var n: int = _w * _h
	trail = PackedFloat32Array()
	trail.resize(n)
	for k in 4:
		var f := PackedFloat32Array()
		f.resize(n)
		scents.append(f)
		_hot.append(PackedInt32Array())
	known_tick = PackedFloat32Array()
	known_tick.resize(n)
	known_tick.fill(-1.0e5)
	known_food = PackedFloat32Array()
	known_food.resize(n)
	for i in start_ants:
		add_ant()
	_see_around(world.nest_cell.x, world.nest_cell.y, 6)


func add_ant() -> bool:
	if count >= MAX_ANTS:
		return false
	var rng := world.rng
	ax.append(_nest.x)
	ay.append(_nest.y)
	px.append(_nest.x)
	py.append(_nest.y)
	aheading.append(rng.randf() * TAU)
	acarry.append(0.0)
	astate.append(State.OUT)
	arole.append(Role.SCOUT if rng.randf() < SCOUT_SHARE else Role.FORAGER)
	aconnected.append(1)
	atimer.append(0)
	atx.append(-1.0)
	aty.append(-1.0)
	alog.append(PackedInt32Array())
	count += 1
	return true


## Player command. Lays (or erases) scent in a disc. Scent only takes on ground
## the colony knows. Returns the number of cells changed.
func paint(kind: int, cell: Vector2i, radius: int, amount: float) -> int:
	var changed := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var d2: int = dx * dx + dy * dy
			if d2 > radius * radius:
				continue
			var x: int = cell.x + dx
			var y: int = cell.y + dy
			if x < 0 or y < 0 or x >= _w or y >= _h:
				continue
			var i: int = y * _w + x
			if known_tick[i] < 0.0 or world.passable[i] == 0:
				continue
			var falloff: float = 1.0 - sqrt(float(d2)) / float(radius + 1)
			if kind == ERASE:
				for k in 4:
					scents[k][i] *= 1.0 - falloff
			else:
				scents[kind][i] = minf(1.0, scents[kind][i] + amount * falloff)
			changed += 1
	return changed


func step() -> void:
	px = ax.duplicate()
	py = ay.duplicate()
	for i in count:
		if astate[i] == State.OUT:
			_step_out(i)
		else:
			_step_return(i)
	_decay_one_field()


func total_carried() -> float:
	var s := 0.0
	for i in count:
		s += acarry[i]
	return s


func state_hash() -> int:
	return hash([count, food_stored, hash(ax), hash(ay), hash(aheading), hash(acarry),
		hash(astate), hash(arole), hash(atimer), hash(atx), hash(aty), hash(trail), hash(scents[0]),
		hash(scents[1]), hash(scents[2]), hash(scents[3]), hash(known_tick), hash(known_food)])


func _step_out(i: int) -> void:
	var rng := world.rng
	var x: float = ax[i]
	var y: float = ay[i]
	var h: float = aheading[i]
	var scout: bool = arole[i] == Role.SCOUT
	var cx: int = int(x)
	var cy: int = int(y)
	var ci: int = cy * _w + cx

	var called: bool = atx[i] >= 0.0
	var trip: int = SCOUT_TRIP_TICKS if scout else FORAGER_TRIP_TICKS
	atimer[i] += 1
	if atimer[i] > (trip * 5 / 2 if called else trip):
		astate[i] = State.RETURN
		atx[i] = -1.0
		return

	var food := world.food
	if food[ci] > 0.0:
		var take: float = minf(1.0, food[ci])
		food[ci] -= take
		world.food = food
		acarry[i] = take
		astate[i] = State.RETURN
		atx[i] = -1.0
		_observe(i, ci, cx, cy)
		return

	var dist := world.nest_dist
	var here_dist: float = dist[ci]
	var attract := scents[Scent.ATTRACT]
	var alarm := scents[Scent.ALARM]
	var repel := scents[Scent.REPEL]
	var seek := scents[Scent.SEEK]
	# Ants standing in a called area mill about there instead of pushing on.
	var held: bool = attract[ci] > 0.1 or alarm[ci] > 0.1 or (scout and seek[ci] > 0.1)
	if alarm[ci] > 0.1:
		atimer[i] -= 1   # ants answering an alarm hold their ground while it lasts
	var target_dist: float = 0.0
	if called:
		target_dist = Vector2(x, y).distance_to(Vector2(atx[i], aty[i]))
		if held or target_dist < 3.0:
			# Arrived: stop travelling, linger a while, then head home.
			called = false
			atx[i] = -1.0
			atimer[i] = maxi(atimer[i], trip - LINGER_TICKS)
	var outward: float = 0.0 if (held or called) else (0.08 if scout else 0.015)
	var trail_weight: float = 0.15 if scout else 1.0
	var noise: float = 0.25 if scout else 0.35

	var best: float = -1.0e9
	var best_h: float = h
	for k in 3:
		var a: float = h + (k - 1) * SENSE_ANGLE
		var sx: int = int(x + cos(a) * SENSE_DIST)
		var sy: int = int(y + sin(a) * SENSE_DIST)
		var score: float = -5.0
		if sx >= 0 and sy >= 0 and sx < _w and sy < _h:
			var si: int = sy * _w + sx
			if world.passable[si] == 1:
				score = minf(trail[si], 2.0) * trail_weight
				score += attract[si] * 3.0 + alarm[si] * 5.0 - repel[si] * 8.0
				if scout:
					score += seek[si] * 2.0
				if food[si] > 0.0:
					score += 10.0
				score += outward * (dist[si] - here_dist)
				if called:
					score += 0.9 * (target_dist - Vector2(sx + 0.5, sy + 0.5).distance_to(Vector2(atx[i], aty[i])))
				score += rng.randf() * noise
		if score > best:
			best = score
			best_h = a

	h = best_h + rng.randf_range(-0.12, 0.12)
	var nx: float = x + cos(h) * SPEED
	var ny: float = y + sin(h) * SPEED
	if _blocked(nx, ny):
		h += rng.randf_range(1.5, 4.5)
	else:
		ax[i] = nx
		ay[i] = ny
		cx = int(nx)
		cy = int(ny)
		ci = cy * _w + cx
	aheading[i] = h
	_observe(i, ci, cx, cy)


func _step_return(i: int) -> void:
	var rng := world.rng
	var x: float = ax[i]
	var y: float = ay[i]
	var cx: int = int(x)
	var cy: int = int(y)
	var ci: int = cy * _w + cx
	var dist := world.nest_dist
	var carrying: bool = acarry[i] > 0.0

	if carrying:
		trail[ci] = minf(trail[ci] + TRAIL_DEPOSIT, TRAIL_MAX)

	if dist[ci] <= 1.5:
		_arrive_home(i, carrying)
		return

	# Head straight for the nest when the way ahead is open and really is
	# closer; otherwise step down the walking-distance field.
	var target: float = atan2(_nest.y - y, _nest.x - x)
	var lx: int = int(x + cos(target) * SENSE_DIST)
	var ly: int = int(y + sin(target) * SENSE_DIST)
	var li: int = ly * _w + lx
	var direct_ok: bool = lx >= 0 and ly >= 0 and lx < _w and ly < _h \
		and world.passable[li] == 1 and dist[li] < dist[ci]
	if not direct_ok:
		var best: float = dist[ci]
		var bx: int = cx
		var by: int = cy
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var qx: int = cx + dx
				var qy: int = cy + dy
				if qx < 0 or qy < 0 or qx >= _w or qy >= _h:
					continue
				var qd: float = dist[qy * _w + qx]
				if qd < best:
					best = qd
					bx = qx
					by = qy
		target = atan2(by + 0.5 - y, bx + 0.5 - x)

	var h: float = target + rng.randf_range(-0.1, 0.1)
	var nx: float = x + cos(h) * SPEED
	var ny: float = y + sin(h) * SPEED
	if _blocked(nx, ny):
		nx = x + cos(target) * SPEED
		ny = y + sin(target) * SPEED
	if not _blocked(nx, ny):
		ax[i] = nx
		ay[i] = ny
		cx = int(nx)
		cy = int(ny)
		ci = cy * _w + cx
	aheading[i] = h
	_observe(i, ci, cx, cy)


func _arrive_home(i: int, carrying: bool) -> void:
	var rng := world.rng
	if carrying:
		var cargo: float = acarry[i]
		acarry[i] = 0.0
		food_stored += cargo
		food_delivered_total += cargo
		_growth_bank += cargo
		# Growth is free in phase 1; upkeep arrives with the colony phase.
		while _growth_bank >= FOOD_PER_NEW_ANT:
			_growth_bank -= FOOD_PER_NEW_ANT
			if not add_ant():
				_growth_bank = 0.0
				break
	_flush_log(i)
	astate[i] = State.OUT
	atimer[i] = 0
	var scout: bool = arole[i] == Role.SCOUT
	var h: float
	# Scent strong enough to reach the nest calls departing ants to it.
	var call_kind := -1
	if _hot[Scent.ALARM].size() > 0 and rng.randf() < 0.7:
		call_kind = Scent.ALARM
	elif scout and _hot[Scent.SEEK].size() > 0 and rng.randf() < 0.85:
		call_kind = Scent.SEEK
	elif _hot[Scent.ATTRACT].size() > 0 and rng.randf() < (0.2 if scout else 0.5):
		call_kind = Scent.ATTRACT
	atx[i] = -1.0
	if call_kind >= 0:
		var hot: PackedInt32Array = _hot[call_kind]
		var ci: int = hot[rng.randi() % hot.size()]
		atx[i] = float(ci % _w) + 0.5
		aty[i] = float(ci / _w) + 0.5
		h = atan2(aty[i] - ay[i], atx[i] - ax[i]) + rng.randf_range(-0.25, 0.25)
	elif carrying and not scout:
		h = aheading[i] + PI + rng.randf_range(-0.2, 0.2)   # back out along the trail
	else:
		h = rng.randf() * TAU
	aheading[i] = h


func _blocked(x: float, y: float) -> bool:
	if x < 0.0 or y < 0.0 or x >= _w or y >= _h:
		return true
	return world.passable[int(y) * _w + int(x)] == 0


func _observe(i: int, ci: int, cx: int, cy: int) -> void:
	var connected: bool = trail[ci] > CONNECT_TRAIL or world.nest_dist[ci] < CONNECT_NEST_DIST
	aconnected[i] = 1 if connected else 0
	var phase: int = (world.tick + i) & 3
	if connected:
		if alog[i].size() > 0:
			_flush_log(i)
		if phase == 0:
			_see_around(cx, cy, SEE_RADIUS)
	elif phase == 0 and alog[i].size() < LOG_LIMIT:
		alog[i].append(ci)


## Delivers an ant's private log to the colony. Simplification for phase 1:
## food amounts are read at delivery time, not at the time the ant saw them.
func _flush_log(i: int) -> void:
	var entries: PackedInt32Array = alog[i]
	if entries.size() == 0:
		return
	for ci in entries:
		_see_around(ci % _w, ci / _w, SEE_RADIUS)
	alog[i] = PackedInt32Array()


func _see_around(cx: int, cy: int, radius: int) -> void:
	var now: float = float(world.tick)
	var food := world.food
	for dy in range(-radius, radius + 1):
		var y: int = cy + dy
		if y < 0 or y >= _h:
			continue
		for dx in range(-radius, radius + 1):
			var x: int = cx + dx
			if x < 0 or x >= _w:
				continue
			var i: int = y * _w + x
			known_tick[i] = now
			known_food[i] = food[i]


## Decays one field per tick in rotation, so the cost is spread out.
func _decay_one_field() -> void:
	var n: int = _w * _h
	var which: int = world.tick % 5
	if which == 0:
		for i in n:
			var v: float = trail[i]
			if v > 0.0:
				v *= TRAIL_DECAY
				trail[i] = v if v > 0.002 else 0.0
		return
	var kind: int = which - 1
	var f := scents[kind]
	var hot := PackedInt32Array()
	var seen := 0
	var rng := world.rng
	for i in n:
		var v: float = f[i]
		if v > 0.0:
			v *= SCENT_DECAY
			if v < 0.004:
				v = 0.0
			f[i] = v
			if v > HOT_LEVEL:
				# Reservoir sample, so several painted areas each get callers.
				seen += 1
				if hot.size() < HOT_SAMPLES:
					hot.append(i)
				else:
					var j: int = rng.randi() % seen
					if j < HOT_SAMPLES:
						hot[j] = i
	_hot[kind] = hot
