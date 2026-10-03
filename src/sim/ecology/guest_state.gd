class_name GuestState
extends RefCounted

const CONFIG = preload("res://data/ecology/backyard_guest.tres")
var phase: String = "absent"
var integration_ticks: int = 0
var damage_ticks: int = 0
var rejection_ticks: int = 0
var rejection_duration_ticks: int = 0
var reported_losses: int = 0
var observation: String = ""
var recognition_share: float = 0.0
var recognition_threshold: int = CONFIG.recognition_losses
var encounter_losses: int = 0
var encounters_total: int = 0
var entry_tick: int = 0
var next_entry_tick: int = 0


func to_dict() -> Dictionary:
	return {"phase": phase, "integration_ticks": integration_ticks, "damage_ticks": damage_ticks,
		"rejection_ticks": rejection_ticks, "rejection_duration_ticks": rejection_duration_ticks,
		"reported_losses": reported_losses, "observation": observation,
		"recognition_share": recognition_share, "recognition_threshold": recognition_threshold,
		"encounter_losses": encounter_losses, "encounters_total": encounters_total,
		"entry_tick": str(entry_tick), "next_entry_tick": str(next_entry_tick)}


func restore(data: Dictionary, pile: PileState, tick: int) -> bool:
	if not data.has_all(["phase", "integration_ticks", "damage_ticks", "rejection_ticks", "rejection_duration_ticks", "reported_losses", "observation"]) or not data.phase in ["absent", "tolerated", "rejecting", "purged"] or not data.observation in ["", "tolerated", "loss", "foreign", "purged"]:
		return false
	for key: String in ["integration_ticks", "damage_ticks", "rejection_ticks", "rejection_duration_ticks", "reported_losses"]:
		if not WorkerLedger.valid_count(data[key]):
			return false
	var share: Variant = data.get("recognition_share", 0.0)
	var threshold: Variant = data.get("recognition_threshold", CONFIG.recognition_losses)
	if not typeof(share) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(share)) or absf(share) > 1.0 or not WorkerLedger.valid_count(threshold) or threshold < 1 or threshold > 3:
		return false
	if (share > 0 or threshold == 1) and "security" not in pile.genetics.established:
		return false
	if (share < 0 or threshold == 3) and "tolerance" not in pile.genetics.established:
		return false
	# Old version-5 snapshots had one encounter and no future arrival schedule.
	var recurrence_fields: Array[String] = ["encounter_losses", "encounters_total", "entry_tick", "next_entry_tick"]
	var present: int = 0
	for key: String in recurrence_fields:
		present += 1 if data.has(key) else 0
	if present != 0 and present != recurrence_fields.size():
		return false
	var losses: Variant = data.get("encounter_losses", data.reported_losses)
	var encounters: Variant = data.get("encounters_total", 0 if data.phase == "absent" else 1)
	var entry: Variant = data.get("entry_tick", "0" if data.phase == "absent" else str(CONFIG.first_tick))
	var next_entry: Variant = data.get("next_entry_tick", str(tick + CONFIG.quiet_interval_ticks) if data.phase == "purged" else "0")
	if not WorkerLedger.valid_count(losses) or not WorkerLedger.valid_count(encounters):
		return false
	for value: Variant in [entry, next_entry]:
		if not value is String or not value.is_valid_int() or str(value.to_int()) != value or value.to_int() < 0:
			return false
	var arrived: int = entry.to_int()
	var due: int = next_entry.to_int()
	var elapsed: int = maxi(0, tick - arrived + 1)
	var lifetime_elapsed: int = maxi(0, tick - CONFIG.first_tick + 1)
	if losses > data.reported_losses or losses > elapsed / CONFIG.damage_ticks or encounters > 1 + lifetime_elapsed / CONFIG.quiet_interval_ticks or data.reported_losses < encounters - 1:
		return false
	if data.phase == "purged":
		if due <= tick or due - tick > CONFIG.quiet_interval_ticks:
			return false
	elif due != 0:
		return false
	if data.integration_ticks > mini(CONFIG.integration_ticks, elapsed) or data.damage_ticks >= CONFIG.damage_ticks or data.damage_ticks > elapsed or data.reported_losses != pile.brood_lost_total - pile.brood_health.losses or data.reported_losses > lifetime_elapsed / CONFIG.damage_ticks:
		return false
	var commitment: Dictionary = pile.workers.to_dict().commitments.get("rejection:home", {})
	var duration: int = AdaptationRules.rejection_duration(int(data.integration_ticks), float(share))
	if data.rejection_duration_ticks != 0 and data.rejection_duration_ticks != duration:
		return false
	if data.phase == "rejecting":
		if losses < 1 or data.rejection_duration_ticks == 0 or data.rejection_ticks >= data.rejection_duration_ticks or commitment.get("kind") != "internal" or commitment.get("owner_id") != "home" or commitment.get("count") != CONFIG.rejection_workers:
			return false
	elif not commitment.is_empty():
		return false
	if data.rejection_ticks > elapsed or data.rejection_ticks > data.rejection_duration_ticks or (data.rejection_ticks > 0 and data.rejection_duration_ticks == 0):
		return false
	if data.phase == "absent":
		if data.observation != "" or data.integration_ticks != 0 or data.damage_ticks != 0 or data.rejection_ticks != 0 or data.rejection_duration_ticks != 0 or data.reported_losses != 0 or share != 0 or threshold != CONFIG.recognition_losses or losses != 0 or encounters != 0 or arrived != 0:
			return false
	else:
		if arrived < CONFIG.first_tick or arrived > tick or encounters < 1 or arrived < CONFIG.first_tick + (encounters - 1) * CONFIG.quiet_interval_ticks or data.observation == "":
			return false
		var evidence: String = "foreign" if losses >= threshold else "loss" if losses > 0 else "tolerated"
		if data.phase == "purged":
			if losses < 1 or data.observation != "purged" or data.rejection_ticks != data.rejection_duration_ticks or data.rejection_duration_ticks == 0:
				return false
		elif data.observation != evidence or data.rejection_ticks == data.rejection_duration_ticks and data.rejection_duration_ticks > 0:
			return false
	phase = data.phase
	integration_ticks = int(data.integration_ticks)
	damage_ticks = int(data.damage_ticks)
	rejection_ticks = int(data.rejection_ticks)
	rejection_duration_ticks = int(data.rejection_duration_ticks)
	reported_losses = int(data.reported_losses)
	observation = data.observation
	recognition_share = snappedf(float(share), 0.00001)
	recognition_threshold = int(threshold)
	encounter_losses = int(losses)
	encounters_total = int(encounters)
	entry_tick = arrived
	next_entry_tick = due
	return true
