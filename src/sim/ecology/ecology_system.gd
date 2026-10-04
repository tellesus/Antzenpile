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
	if pile_id != "home" or not _run.colony.piles.has(pile_id) or not _run.world.nodes.has(HONEYDEW.source_id) or _run.honeydew.relationship != "exploited":
		return _reject("Honeydew producers have not been exploited")
	var route: TrailRouteState = _run.trails.find_route(pile_id, "known:" + HONEYDEW.source_id)
	if route == null or route.delivered_total <= 0.0:
		return _reject("A loaded honeydew return is required")
	var pile: PileState = _run.colony.piles[pile_id]
	var share: float = _run.recognition_share(pile_id)
	var required: int = AdaptationRules.protection_workers(HONEYDEW.protection_workers, share)
	if pile.workers_assignable < required:
		return _reject("Not enough workers to protect the producers")
	var commitment: String = "honeydew:" + pile_id
	if not pile.workers.create_commitment(commitment, "other", HONEYDEW.source_id):
		return _reject("Protection commitment unavailable")
	if not pile.allocate_workers(commitment, required):
		assert(pile.workers.retire_commitment(commitment))
		return _reject("Could not commit protection workers")
	_run.honeydew.relationship = "tended"
	_run.honeydew.protection_workers = required
	_run.honeydew.recognition_share = share
	pile.recognition_experience = true
	last_error = ""
	return true


func stop_tending(pile_id: String) -> bool:
	if pile_id != "home" or not _run.colony.piles.has(pile_id) or _run.honeydew.relationship != "tended":
		return _reject("No tended honeydew relationship")
	var pile: PileState = _run.colony.piles[pile_id]
	var commitment: String = "honeydew:" + pile_id
	assert(pile.workers.release(commitment, _run.honeydew.protection_workers))
	assert(pile.workers.retire_commitment(commitment))
	_run.honeydew.relationship = "exploited"
	_run.honeydew.protection_workers = 0
	_run.honeydew.recognition_share = 0.0
	last_error = ""
	return true


func tick(_delta: float) -> void:
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
	var tended: bool = state.relationship == "tended"
	state.condition = minf(100.0, state.condition + HONEYDEW.protected_gain_per_interval) if tended else maxf(HONEYDEW.minimum_condition, state.condition - HONEYDEW.pressure_loss_per_interval)
	var node: WorldNodeState = _run.world.nodes[HONEYDEW.source_id]
	var rate: float = HONEYDEW.tended_output if tended else HONEYDEW.untended_output
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
