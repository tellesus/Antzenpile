class_name HeatSystem
extends RefCounted
const CONFIG = preload("res://data/weather/default_heat.tres")
var _run: RunState

func _init(run_state: RunState) -> void: _run = run_state

func ambient() -> int:
	var value: int = CONFIG.baseline
	var elapsed: int = _run.clock.tick_count - CONFIG.first_tick
	if elapsed >= 0:
		var phase: int = elapsed % CONFIG.interval_ticks
		if phase < CONFIG.duration_ticks:
			var height: int = mini(CONFIG.ramp_ticks, mini(phase, CONFIG.duration_ticks - phase))
			@warning_ignore("integer_division")
			value += (CONFIG.peak - CONFIG.baseline) * height / CONFIG.ramp_ticks
	return value - (CONFIG.rain_cooling if _run.rain.phase == "raining" else 0)

func tick() -> void:
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
