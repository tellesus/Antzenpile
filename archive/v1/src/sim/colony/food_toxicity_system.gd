class_name FoodToxicitySystem
extends RefCounted
const CONFIG = preload("res://data/resources/default_food_toxicity.tres")
var _run: RunState
func _init(run_state: RunState): _run = run_state

func tick(delta: float) -> void:
	var ids: Array = _run.colony.piles.keys(); ids.sort()
	for id: String in ids:
		var pile: PileState = _run.colony.piles[id]
		var state: FoodToxicityState = pile.food_toxicity
		if state.mass == 0 and state.dose_units == 0: continue
		# Floor at fine precision prevents tiny toxic traces from surviving rounding forever.
		state.mass = minf(pile.resources.carbohydrate, floorf(state.mass * pow(0.5,delta / CONFIG.half_life_seconds) * 100000000.0) / 100000000.0)
		var concentration: float = state.mass / maxf(CONFIG.minimum_mixing_pool,pile.resources.carbohydrate)
		# Recovery competes with exposure; a declining pool can settle without a magic reset.
		state.dose_units = clampi(state.dose_units + roundi((concentration - CONFIG.recovery_per_second) * delta * CONFIG.dose_scale),0,CONFIG.dose_threshold_units)
		if state.dose_units >= CONFIG.dose_threshold_units and pile.workers_available > 0 and state.losses < WorkerLedger.MAX_COUNT:
			var adapted: int = 1 if _run.rng.randf() < pile.adaptation_fraction() else 0
			var phenotype: String = pile.genetics.loss_profile(adapted == 1,pile.adaptation_repertoire,pile.workers_total,_run.rng)
			var removed: bool = pile.lose_workers("available",1,adapted,"home food-sharing failure",phenotype)
			assert(removed)
			if removed:
				state.losses += 1; state.last_loss_tick = _run.clock.tick_count; state.dose_units = 0

func summary(pile_id: String) -> Dictionary:
	if not _run.colony.piles.has(pile_id): return {}
	var state: FoodToxicityState = _run.colony.piles[pile_id].food_toxicity
	var age: float = (_run.clock.tick_count - state.last_loss_tick) * SimulationClock.TICK_INTERVAL
	return {"losses":state.losses,"age":age if state.losses > 0 else 0.0,"recent":state.losses > 0 and age <= CONFIG.recent_evidence_seconds}
