class_name HeatSystem
extends RefCounted
const CONFIG = preload("res://data/weather/default_heat.tres")
var _run: RunState

func _init(run_state: RunState) -> void: _run = run_state

func ambient() -> int:
	return air_temperature(_run.clock.tick_count, _run.rain.phase == "raining")

static func air_temperature(tick: int, raining: bool) -> int:
	var value: int = CONFIG.baseline
	var elapsed: int = tick - CONFIG.first_tick
	if elapsed >= 0:
		var phase: int = elapsed % CONFIG.interval_ticks
		if phase < CONFIG.duration_ticks:
			var height: int = mini(CONFIG.ramp_ticks, mini(phase, CONFIG.duration_ticks - phase))
			@warning_ignore("integer_division")
			value += (CONFIG.peak - CONFIG.baseline) * height / CONFIG.ramp_ticks
	return value - (CONFIG.rain_cooling if raining else 0)

static func hot_dry(run: RunState) -> bool:
	return run.rain.phase != "raining" and air_temperature(run.clock.tick_count, false) > CONFIG.extreme_high

func home_air() -> String:
	return "Rain-cooled air at Home" if _run.rain.phase == "raining" else "Hot, dry air at Home" if ambient() > CONFIG.extreme_high else "Warm air at Home" if ambient() > CONFIG.favorable_high else ""

func tick() -> void:
	_dry_exterior_water()
	var air: int = ambient()
	var ids: Array = _run.colony.piles.keys()
	ids.sort()
	for id: String in ids:
		var pile: PileState = _run.colony.piles[id]
		if pile.nursery_state != "developed": continue
		var state: TemperatureState = pile.temperature
		state.temperature = int(move_toward(state.temperature, air, CONFIG.drift_per_tick))
		var adjustment: int = mini(maxi(0, state.temperature - CONFIG.baseline), pile.humidity.carers * CONFIG.care_step)
		if adjustment == 0: continue
		# Shared climate labor, but each actual humidity/cooling water debit remains distinct.
		var cost: int = ceili(float(adjustment) * CONFIG.water_units_per_worker_tick / CONFIG.care_step)
		cost = mini(cost, floori(pile.resources.water * 100000.0))
		if cost > WorkerLedger.MAX_COUNT - state.water_used_units: continue
		adjustment = mini(adjustment, floori(float(cost) * CONFIG.care_step / CONFIG.water_units_per_worker_tick))
		if adjustment == 0: continue
		var paid: bool = pile.consume_resources({"water": cost / 100000.0})
		assert(paid)
		state.water_used_units += cost
		state.temperature -= adjustment

func summary(pile_id: String) -> Dictionary:
	if not _run.colony.piles.has(pile_id): return {}
	var state: TemperatureState = _run.colony.piles[pile_id].temperature
	return {"condition": "hot" if state.temperature > CONFIG.extreme_high else "warm" if state.temperature > CONFIG.favorable_high else "steady", "larval_rate": state.larval_rate()}

func _dry_exterior_water() -> void:
	if not hot_dry(_run) or not ScenarioCatalog.uses_backyard_ecology(_run.scenario_id): return
	var source_id: String = preload("res://data/weather/default_rain.tres").exterior_water_source_id
	if not _run.world.nodes.has(source_id): return
	var source: WorldNodeState = _run.world.nodes[source_id]
	source.quantity = float(String.num(maxf(0.0, source.quantity - CONFIG.dry_water_units_per_tick / 100000.0), 5))
	if source.quantity == 0.0: source.active = false
