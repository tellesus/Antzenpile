class_name GuestSystem
extends RefCounted
## One aggregate internal guest; workers observe symptoms before association.

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
	if state.phase != "tolerated" or state.reported_losses < 1:
		return _reject("No unresolved nursery loss evidence")
	if pile.workers_available < CONFIG.rejection_workers:
		return _reject("Four available workers required")
	if not pile.workers.create_commitment("rejection:home", "internal", "home"):
		return _reject("Rejection effort unavailable")
	var allocated: bool = pile.workers.allocate("rejection:home", CONFIG.rejection_workers)
	assert(allocated)
	state.phase = "rejecting"
	# Odor acquisition pauses during effort. Recalculate only when restarting after toleration.
	state.rejection_duration_ticks = ceili((CONFIG.purge_seconds + CONFIG.integrated_extra_seconds * float(state.integration_ticks) / CONFIG.integration_ticks) / SimulationClock.TICK_INTERVAL)
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
		state.phase = "tolerated"
		state.observation = "tolerated"
	if state.phase == "purged":
		return
	if state.phase == "tolerated":
		state.integration_ticks = mini(CONFIG.integration_ticks, state.integration_ticks + 1)
		# Retained work, but the longer-tolerated guest can acquire more odor before restart.
		if state.rejection_duration_ticks > 0:
			state.rejection_duration_ticks = ceili((CONFIG.purge_seconds + CONFIG.integrated_extra_seconds * float(state.integration_ticks) / CONFIG.integration_ticks) / SimulationClock.TICK_INTERVAL)
	else:
		state.rejection_ticks += 1
		if state.rejection_ticks >= state.rejection_duration_ticks:
			state.phase = "purged"
			state.observation = "purged"
			_release()
			return
	state.damage_ticks += 1
	if state.damage_ticks < CONFIG.damage_ticks:
		return
	state.damage_ticks = 0
	if _brood_loss.call("home"):
		state.reported_losses += 1
		state.observation = "foreign" if state.reported_losses >= CONFIG.recognition_losses else "loss"


func _release() -> void:
	var ledger: WorkerLedger = _run.colony.piles.home.workers
	var released: bool = ledger.release("rejection:home", CONFIG.rejection_workers)
	assert(released)
	var retired: bool = ledger.retire_commitment("rejection:home")
	assert(retired)


func _reject(reason: String) -> bool:
	last_error = reason
	return false
