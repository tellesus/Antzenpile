class_name GuestSystem
extends RefCounted
## At most one aggregate guest; fresh external intrusion can follow a quiet interval.

const CONFIG = preload("res://data/ecology/backyard_guest.tres")
var _run: RunState
var _brood_loss: Callable
var last_error: String = ""


func _init(run_state: RunState, brood_loss: Callable) -> void:
	_run = run_state
	_brood_loss = brood_loss


func start_rejection() -> bool:
	var state: GuestState = _run.guest
	var pile: PileState = _run.colony.piles.home
	if state.phase != "tolerated" or state.encounter_losses < 1:
		return _reject("No unresolved nursery loss evidence")
	if pile.workers_assignable < CONFIG.rejection_workers:
		return _reject("Four available workers required")
	if not pile.workers.create_commitment("rejection:home", "internal", "home"):
		return _reject("Rejection effort unavailable")
	var allocated: bool = pile.allocate_workers("rejection:home", CONFIG.rejection_workers)
	assert(allocated)
	state.phase = "rejecting"
	# Odor acquisition pauses during effort. Recalculate only when restarting after toleration.
	state.recognition_share = _run.recognition_share("home")
	state.rejection_duration_ticks = AdaptationRules.rejection_duration(state.integration_ticks, state.recognition_share)
	if state.rejection_ticks >= state.rejection_duration_ticks:
		state.rejection_ticks = state.rejection_duration_ticks
		_purge()
	last_error = ""
	return true


func stop_rejection() -> bool:
	if _run.guest.phase != "rejecting":
		return _reject("No rejection effort active")
	_release()
	_run.guest.phase = "tolerated"
	last_error = ""
	return true


func tick() -> void:
	var state: GuestState = _run.guest
	if state.phase == "absent":
		if _run.clock.tick_count < CONFIG.first_tick:
			return
		_enter()
	if state.phase == "purged":
		if _run.clock.tick_count < state.next_entry_tick or state.encounters_total >= WorkerLedger.MAX_COUNT:
			return
		_enter()
	if state.phase == "tolerated":
		state.integration_ticks = mini(CONFIG.integration_ticks, state.integration_ticks + 1)
		# Retained work, but the longer-tolerated guest can acquire more odor before restart.
		if state.rejection_duration_ticks > 0:
			state.rejection_duration_ticks = AdaptationRules.rejection_duration(state.integration_ticks, state.recognition_share)
	else:
		state.rejection_ticks += 1
		if state.rejection_ticks >= state.rejection_duration_ticks:
			_purge()
			return
	state.damage_ticks += 1
	if state.damage_ticks < CONFIG.damage_ticks:
		return
	state.damage_ticks = 0
	if _brood_loss.call("home"):
		state.reported_losses += 1
		state.encounter_losses += 1
		var threshold: int = AdaptationRules.evidence_losses(_run.recognition_share("home"))
		state.recognition_threshold = mini(state.recognition_threshold, threshold) if state.observation == "foreign" else threshold
		state.observation = "foreign" if state.encounter_losses >= state.recognition_threshold else "loss"


func _enter() -> void:
	var state: GuestState = _run.guest
	state.phase = "tolerated"
	state.observation = "tolerated"
	state.entry_tick = _run.clock.tick_count
	state.next_entry_tick = 0
	state.encounters_total += 1
	state.encounter_losses = 0
	state.integration_ticks = 0
	state.damage_ticks = 0
	state.rejection_ticks = 0
	state.rejection_duration_ticks = 0
	state.recognition_share = 0.0
	state.recognition_threshold = CONFIG.recognition_losses
	_run.colony.piles.home.recognition_experience = true


func _purge() -> void:
	var state: GuestState = _run.guest
	state.phase = "purged"
	state.observation = "purged"
	state.next_entry_tick = _run.clock.tick_count + CONFIG.quiet_interval_ticks
	_release()


func _release() -> void:
	var ledger: WorkerLedger = _run.colony.piles.home.workers
	var released: bool = ledger.release("rejection:home", CONFIG.rejection_workers)
	assert(released)
	var retired: bool = ledger.retire_commitment("rejection:home")
	assert(retired)


func _reject(reason: String) -> bool:
	last_error = reason
	return false
