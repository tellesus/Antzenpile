class_name BroodHealthSystem
extends RefCounted
const CONFIG = preload("res://data/resources/default_brood_health.tres")
const SANITATION = preload("res://data/resources/default_sanitation.tres")
const HUMIDITY = preload("res://data/resources/default_humidity.tres")
var _run: RunState
var _lose_brood: Callable

func _init(run_state: RunState, lose_brood: Callable) -> void:
	_run = run_state
	_lose_brood = lose_brood

func exposed(pile: PileState) -> bool:
	return pile.midden.burden_units >= SANITATION.heavy_units and not pile.brood_cohorts.filter(func(cohort): return cohort.stage == "larva").is_empty()

func tick() -> void:
	var ids: Array = _run.colony.piles.keys()
	ids.sort()
	for id: String in ids:
		var pile: PileState = _run.colony.piles[id]
		var state: BroodHealthState = pile.brood_health
		if exposed(pile):
			var damp: bool = pile.nursery_state == "developed" and pile.humidity.moisture > HUMIDITY.favorable_high
			state.burden = mini(CONFIG.maximum, state.burden + CONFIG.exposure_per_tick + (CONFIG.damp_extra_per_tick if damp else 0))
		else:
			state.burden = maxi(0, state.burden - CONFIG.recovery_per_tick)
		var larvae: bool = not pile.brood_cohorts.filter(func(cohort): return cohort.stage == "larva").is_empty()
		state.severe_ticks = state.severe_ticks + 1 if larvae and state.burden >= CONFIG.severe_threshold else 0
		if state.severe_ticks >= CONFIG.loss_ticks:
			state.severe_ticks = 0
			if state.losses < WorkerLedger.MAX_COUNT and _lose_brood.call(id, "larva"):
				state.losses += 1
				state.last_loss_tick = _run.clock.tick_count

func summary(pile_id: String) -> Dictionary:
	if not _run.colony.piles.has(pile_id): return {}
	var pile: PileState = _run.colony.piles[pile_id]
	var state: BroodHealthState = pile.brood_health
	var condition: String = "stable"
	if state.burden >= CONFIG.symptom_threshold:
		condition = "severe" if state.burden >= CONFIG.severe_threshold else "strained"
		if not exposed(pile): condition = "recovering"
	return {"condition": condition, "larval_rate": state.larval_rate(), "losses": state.losses}
