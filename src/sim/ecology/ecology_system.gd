class_name EcologySystem
extends RefCounted
## Authored physical renewals; saved clock ticks determine the entire schedule.

signal resource_pulsed(source_id: String, amount: float)
signal resource_appeared(source_id: String, amount: float)
signal resource_expired(source_id: String, amount_removed: float)

const PULSE = preload("res://data/ecology/backyard_nectar.tres")
const EPISODE = preload("res://data/ecology/picnic_crumbs.tres")
var _run: RunState


func _init(run_state: RunState) -> void:
	_run = run_state
	assert(PULSE.first_tick > 0 and PULSE.interval_ticks > 0 and PULSE.quantity > 0.0 and PULSE.capacity > 0.0)
	assert(EPISODE.first_tick > 0 and EPISODE.interval_ticks > EPISODE.duration_ticks and EPISODE.duration_ticks > 0 and EPISODE.quantity > 0.0)


func tick(_delta: float) -> void:
	var now: int = _run.clock.tick_count
	if _run.scenario_id != "backyard_slice":
		return
	_tick_nectar(now)
	_tick_picnic(now)


func _tick_nectar(now: int) -> void:
	if not _run.world.nodes.has(PULSE.source_id):
		return
	if now < PULSE.first_tick or (now - PULSE.first_tick) % PULSE.interval_ticks != 0:
		return
	var node: WorldNodeState = _run.world.nodes[PULSE.source_id]
	var added: float = minf(PULSE.quantity, maxf(0.0, PULSE.capacity - node.quantity))
	if added <= 0.0:
		return
	node.quantity += added
	node.active = true
	resource_pulsed.emit(node.id, added)


func _tick_picnic(now: int) -> void:
	if not _run.world.nodes.has(EPISODE.source_id) or now < EPISODE.first_tick:
		return
	var phase: int = (now - EPISODE.first_tick) % EPISODE.interval_ticks
	var node: WorldNodeState = _run.world.nodes[EPISODE.source_id]
	if phase == 0:
		node.quantity = EPISODE.quantity
		node.active = true
		resource_appeared.emit(node.id, node.quantity)
	elif phase == EPISODE.duration_ticks:
		var removed: float = node.quantity
		node.quantity = 0.0
		node.active = false
		resource_expired.emit(node.id, removed)
