class_name SanitationState
extends RefCounted
## Fixed integer material accounting; isolated refuse is not a usable resource.
const CONFIG = preload("res://data/resources/default_sanitation.tres")
var generated_units: int = 0
var isolated_units: int = 0
var remainder_quarters: int = 0
var revealed: bool = false
var cleaners: int = 0
var state: String = "primitive"
var progress_ticks: int = 0
var burden_units: int:
	get: return generated_units - isolated_units
func larval_rate() -> float:
	return CONFIG.heavy_larval_rate if burden_units >= CONFIG.heavy_units else CONFIG.strained_larval_rate if burden_units >= CONFIG.strain_units else 1.0
func to_dict() -> Dictionary:
	return {"generated_units": generated_units, "isolated_units": isolated_units,
		"remainder_quarters": remainder_quarters, "revealed": revealed, "cleaners": cleaners,
		"state": state, "progress_ticks": progress_ticks}
func restore(data: Dictionary, ledger: WorkerLedger, pile_id: String) -> bool:
	if not data.has_all(["generated_units", "isolated_units", "remainder_quarters", "revealed", "cleaners", "state", "progress_ticks"]):
		return false
	for key: String in ["generated_units", "isolated_units", "remainder_quarters", "cleaners", "progress_ticks"]:
		if not WorkerLedger.valid_count(data[key]):
			return false
	if data.isolated_units > data.generated_units or data.remainder_quarters > 3 or data.cleaners > CONFIG.cleaner_cap or not data.revealed is bool or data.revealed != (data.generated_units >= CONFIG.reveal_units):
		return false
	if not data.state in ["primitive", "developing", "developed"] or not data.revealed and (data.state != "primitive" or data.cleaners > 0):
		return false
	if data.progress_ticks > CONFIG.build_ticks or data.state == "primitive" and data.progress_ticks != 0 or data.state == "developing" and data.progress_ticks >= CONFIG.build_ticks or data.state == "developed" and data.progress_ticks != CONFIG.build_ticks:
		return false
	var commitments: Dictionary = ledger.to_dict().commitments
	for key: String in ["sanitation:" + pile_id, "midden:" + pile_id]:
		var expected: int = int(data.cleaners) if key.begins_with("sanitation:") else CONFIG.build_workers if data.state == "developing" else 0
		if expected == 0 and commitments.has(key) or expected > 0 and commitments.get(key, {}) != {"kind": "internal", "owner_id": pile_id, "count": expected}:
			return false
	generated_units = int(data.generated_units)
	isolated_units = int(data.isolated_units)
	remainder_quarters = int(data.remainder_quarters)
	revealed = data.revealed
	cleaners = int(data.cleaners)
	state = data.state
	progress_ticks = int(data.progress_ticks)
	return true
