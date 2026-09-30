class_name EcologySystem
extends RefCounted
## Authored physical renewals; saved clock ticks determine the entire schedule.

signal resource_pulsed(source_id: String, amount: float)

const PULSE = preload("res://data/ecology/backyard_nectar.tres")
var _run: RunState


func _init(run_state: RunState) -> void:
	_run = run_state
	assert(PULSE.first_tick > 0 and PULSE.interval_ticks > 0 and PULSE.quantity > 0.0 and PULSE.capacity > 0.0)


func tick(_delta: float) -> void:
	var now: int = _run.clock.tick_count
	if _run.scenario_id != "backyard_slice" or not _run.world.nodes.has(PULSE.source_id):
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
