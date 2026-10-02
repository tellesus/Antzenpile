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


func to_dict() -> Dictionary:
	return {"phase": phase, "integration_ticks": integration_ticks, "damage_ticks": damage_ticks,
		"rejection_ticks": rejection_ticks, "rejection_duration_ticks": rejection_duration_ticks,
		"reported_losses": reported_losses, "observation": observation,
		"recognition_share": recognition_share, "recognition_threshold": recognition_threshold}


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
	var elapsed: int = maxi(0, tick - CONFIG.first_tick + 1)
	if data.integration_ticks > mini(CONFIG.integration_ticks, elapsed) or data.damage_ticks >= CONFIG.damage_ticks or data.damage_ticks > elapsed or data.reported_losses != pile.brood_lost_total or data.reported_losses > elapsed / CONFIG.damage_ticks:
		return false
	var commitment: Dictionary = pile.workers.to_dict().commitments.get("rejection:home", {})
	var duration: int = AdaptationRules.rejection_duration(int(data.integration_ticks), float(share))
	if data.rejection_duration_ticks != 0 and data.rejection_duration_ticks != duration:
		return false
	if data.phase == "rejecting":
		if data.reported_losses < 1 or data.rejection_duration_ticks == 0 or data.rejection_ticks >= data.rejection_duration_ticks or commitment.get("kind") != "internal" or commitment.get("owner_id") != "home" or commitment.get("count") != CONFIG.rejection_workers:
			return false
	elif not commitment.is_empty():
		return false
	if data.rejection_ticks > elapsed or data.rejection_ticks > data.rejection_duration_ticks or (data.rejection_ticks > 0 and data.rejection_duration_ticks == 0):
		return false
	if data.phase == "absent":
		if data.observation != "" or data.integration_ticks != 0 or data.damage_ticks != 0 or data.rejection_ticks != 0 or data.rejection_duration_ticks != 0 or data.reported_losses != 0 or share != 0 or threshold != CONFIG.recognition_losses:
			return false
	else:
		if tick < CONFIG.first_tick or data.observation == "":
			return false
		var evidence: String = "foreign" if data.reported_losses >= threshold else "loss" if data.reported_losses > 0 else "tolerated"
		if data.phase == "purged":
			if data.reported_losses < 1 or data.observation != "purged" or data.rejection_ticks != data.rejection_duration_ticks or data.rejection_duration_ticks == 0:
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
	return true
