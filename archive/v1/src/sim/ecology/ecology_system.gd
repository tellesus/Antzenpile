class_name EcologySystem
extends RefCounted
## Authored physical renewals; saved clock ticks determine the entire schedule.

signal resource_pulsed(source_id: String, amount: float)
signal resource_appeared(source_id: String, amount: float)
signal resource_expired(source_id: String, amount_removed: float)

const PULSE = preload("res://data/ecology/backyard_nectar.tres")
const EPISODE = preload("res://data/ecology/picnic_crumbs.tres")
const HONEYDEW = preload("res://data/ecology/backyard_honeydew.tres")
var last_error: String = ""
var _run: RunState


func _init(run_state: RunState) -> void:
	_run = run_state
	assert(PULSE.first_tick > 0 and PULSE.interval_ticks > 0 and PULSE.quantity > 0.0 and PULSE.capacity > 0.0)
	assert(EPISODE.first_tick > 0 and EPISODE.interval_ticks > EPISODE.duration_ticks and EPISODE.duration_ticks > 0 and EPISODE.quantity > 0.0)
	assert(HONEYDEW.interval_ticks > 0 and HONEYDEW.source_capacity > 0.0 and HONEYDEW.protection_workers > 0 and HONEYDEW.tended_output > HONEYDEW.untended_output)


func start_tending(pile_id: String) -> bool:
	var service:=ProducerServiceSystem.new(_run)
	var count: int=AdaptationRules.protection_workers(HONEYDEW.protection_workers,_run.recognition_share(pile_id)) if _run.colony.piles.has(pile_id) else HONEYDEW.protection_workers
	var accepted: bool=service.set_target(pile_id,count);last_error=service.last_error;return accepted
func stop_tending(pile_id: String) -> bool:
	var service:=ProducerServiceSystem.new(_run);var accepted: bool=service.set_target(pile_id,0);last_error=service.last_error;return accepted
func set_tending_target(pile_id: String, target: Variant) -> bool:
	var service:=ProducerServiceSystem.new(_run);var accepted: bool=service.set_target(pile_id,target);last_error=service.last_error;return accepted

func tick(_delta: float) -> void:
	ProducerServiceSystem.new(_run).tick()
	var now: int = _run.clock.tick_count
	if not ScenarioCatalog.uses_backyard_ecology(_run.scenario_id):
		return
	_tick_nectar(now)
	_tick_picnic(now)
	_tick_honeydew(now)


func _tick_nectar(now: int) -> void:
	if not _run.world.nodes.has(PULSE.source_id):
		return
	if now < PULSE.first_tick or (now - PULSE.first_tick) % PULSE.interval_ticks != 0:
		return
	var node: WorldNodeState = _run.world.nodes[PULSE.source_id]
	var multiplier: float = HeatSystem.CONFIG.dry_producer_multiplier if HeatSystem.hot_dry(_run) else 1.0
	var added: float = minf(PULSE.quantity * multiplier, maxf(0.0, PULSE.capacity - node.quantity))
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


func _tick_honeydew(now: int) -> void:
	if not _run.world.nodes.has(HONEYDEW.source_id):
		return
	var state: HoneydewState = _run.honeydew
	if state.relationship == "unknown":
		var route: TrailRouteState = _run.trails.find_route("home", "known:" + HONEYDEW.source_id)
		if route != null and route.delivered_total > 0.0:
			state.relationship = "exploited"
	if now <= 0 or now % HONEYDEW.interval_ticks != 0:
		return
	var effort: float=0.0
	for party: ProducerServiceState in state.services.values():effort+=party.contribution()
	effort=minf(2.0,effort)
	state.condition=clampf(state.condition+HONEYDEW.protected_gain_per_interval*effort-HONEYDEW.pressure_loss_per_interval*(1.0-minf(1.0,effort)),HONEYDEW.minimum_condition,100.0)
	var node: WorldNodeState = _run.world.nodes[HONEYDEW.source_id]
	var rate: float=HONEYDEW.untended_output+(HONEYDEW.tended_output-HONEYDEW.untended_output)*effort
	var multiplier: float = HeatSystem.CONFIG.dry_producer_multiplier if HeatSystem.hot_dry(_run) else 1.0
	var produced: float = roundf(rate * state.condition * multiplier * 1000.0) / 100000.0
	var added: float = minf(produced, maxf(0.0, HONEYDEW.source_capacity - node.quantity))
	if added <= 0.0:
		return
	node.quantity = minf(HONEYDEW.source_capacity, roundf((node.quantity + added) * 100000.0) / 100000.0)
	node.active = true
	resource_pulsed.emit(node.id, added)


func _reject(reason: String) -> bool:
	last_error = reason
	return false
