class_name JourneyDefenseState
extends RefCounted
## Private combat/meeting data and separately home-delivered intervention history.
const CONFIG = preload("res://data/ecology/default_journey_response.tres")
var mode: String = "investigate"
var sent: int = 0
var lost: int = 0
var adapted_lost: int = 0
var lost_profiles: Dictionary[String,int] = {}
var extra_workers: int = 0
var extra_ticks: int = 0
var round_ticks: int = 0
var rounds: int = 0
var outcome: String = ""
var observed_at: float = 0
var reported_losses: int = 0
var outcomes: Dictionary = {}

func to_dict() -> Dictionary:
	return {"mode":mode,"sent":sent,"lost":lost,"adapted_lost":adapted_lost,"lost_profiles":lost_profiles.duplicate(),
		"extra_workers":extra_workers,"extra_ticks":extra_ticks,"round_ticks":round_ticks,"rounds":rounds,
		"outcome":outcome,"observed_at":observed_at,"reported_losses":reported_losses,"outcomes":outcomes.duplicate(true)}

func pending_trait(trait_id: String) -> int:
	var total: int = 0
	for key: String in lost_profiles:
		if trait_id in GeneticRepertoire.traits_for(key): total += lost_profiles[key]
	return total

func reset_party() -> void:
	mode = "investigate"; sent = 0; lost = 0; adapted_lost = 0; lost_profiles.clear()
	extra_workers = 0; extra_ticks = 0; round_ticks = 0; rounds = 0; outcome = ""; observed_at = 0

func restore(data: Dictionary, party: Dictionary, colony: ColonyState, trails: TrailNetwork, time: float) -> bool:
	if data.size() != 13 or not data.has_all(to_dict().keys()) or data.mode not in ["investigate","defend"] or not data.lost_profiles is Dictionary or not data.outcomes is Dictionary: return false
	for key: String in ["sent","lost","adapted_lost","extra_workers","extra_ticks","round_ticks","rounds","reported_losses"]:
		if not WorkerLedger.valid_count(data[key]): return false
	if data.sent > CONFIG.dispatched_cap or data.lost > data.sent or data.adapted_lost > data.lost or int(data.extra_workers) not in [0,CONFIG.reinforcement_workers] or (data.extra_workers == 0 and data.extra_ticks != 0) or data.round_ticks > CONFIG.round_ticks or data.rounds > CONFIG.max_rounds: return false
	if not data.outcome is String or data.outcome not in ["","secured","withdrew","not_found"] or not typeof(data.observed_at) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.observed_at)) or data.observed_at < 0 or data.observed_at > time or (data.outcome != "") != (data.observed_at > 0): return false
	var profiles: Dictionary[String,int] = {}
	var profile_total: int = 0
	var adapted_total: int = 0
	var pile: PileState = colony.piles.home
	for key: Variant in data.lost_profiles:
		if not key is String or not WorkerLedger.valid_count(data.lost_profiles[key]) or data.lost_profiles[key] <= 0 or data.lost_profiles[key] > pile.genetics.lost.get(key,0): return false
		profiles[key] = int(data.lost_profiles[key]); profile_total += profiles[key]
		if pile.adaptation_repertoire in GeneticRepertoire.traits_for(key): adapted_total += profiles[key]
	if profile_total > data.lost or adapted_total != data.adapted_lost: return false
	var latest_losses: int = 0
	for id: Variant in data.outcomes:
		var record: Variant = data.outcomes[id]
		if not id is String or not trails.routes.has(id) or trails.routes[id].origin_pile != "home" or not record is Dictionary or record.size() != 5 or not record.has_all(["outcome","lost","sent","observed_at","received_at"]): return false
		if record.outcome not in ["secured","withdrew","not_found"] or not WorkerLedger.valid_count(record.lost) or not WorkerLedger.valid_count(record.sent) or record.sent < CONFIG.defense_workers or record.sent > CONFIG.dispatched_cap or record.lost > record.sent: return false
		for key: String in ["observed_at","received_at"]:
			if not typeof(record[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record[key])): return false
		if record.observed_at <= 0 or record.observed_at > record.received_at or record.received_at > time: return false
		latest_losses += int(record.lost)
	if latest_losses > data.reported_losses or data.reported_losses > pile.workers.lost_total: return false
	if party.phase == "idle":
		if data.mode != "investigate" or data.sent != 0 or data.lost != 0 or data.extra_workers != 0 or data.rounds != 0 or data.round_ticks != 0 or data.outcome != "": return false
	elif data.mode == "investigate":
		if party.phase == "fighting" or data.sent != CONFIG.investigation_workers or data.lost != 0 or data.extra_workers != 0 or data.rounds != 0 or data.round_ticks != 0 or data.outcome != "": return false
	else:
		if data.sent < CONFIG.defense_workers or (int(data.sent) - CONFIG.defense_workers) % CONFIG.reinforcement_workers != 0 or party.workers < 1 or party.workers + data.extra_workers + data.lost != data.sent: return false
		if data.observed_at > 0 and data.observed_at < party.departed_at: return false
		if (party.phase == "inbound") != (data.outcome != "") or (party.phase == "fighting") != (data.round_ticks > 0): return false
	mode = data.mode; sent = int(data.sent); lost = int(data.lost); adapted_lost = int(data.adapted_lost); lost_profiles = profiles
	extra_workers = int(data.extra_workers); extra_ticks = int(data.extra_ticks); round_ticks = int(data.round_ticks); rounds = int(data.rounds)
	outcome = data.outcome; observed_at = float(data.observed_at); reported_losses = int(data.reported_losses); outcomes = data.outcomes.duplicate(true)
	return true
