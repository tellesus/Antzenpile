class_name AdaptationRules
extends RefCounted
## Authored first-web choice; aggregate effects apply only to newly emerged workers.

const TRAITS: Array[String] = ["lean", "load", "persistent", "security", "tolerance"]
const CHEMISTRY = preload("res://data/adaptation/persistent_chemistry.tres")
const RECOGNITION = preload("res://data/adaptation/recognition.tres")
const COSTS: Dictionary = {"carbohydrate": 12.0, "protein": 12.0, "water": 6.0}
const NURSES: int = 2


static func valid_trait(id: String) -> bool:
	return TRAITS.has(id)


static func costs(id: String) -> Dictionary:
	return RECOGNITION.costs() if id in ["security", "tolerance"] else CHEMISTRY.costs() if id == "persistent" else COSTS.duplicate()


static func compatible(traits: Array[String]) -> bool:
	return not (("lean" in traits and "load" in traits) or ("security" in traits and "tolerance" in traits))


static func can_select(pile: PileState, id: String) -> bool:
	if not valid_trait(id) or pile.queen_count < 1 or pile.trial_cohort() != null or id in pile.genetics.established:
		return false
	if id in ["security", "tolerance"]:
		return pile.recognition_candidate and "security" not in pile.genetics.established and "tolerance" not in pile.genetics.established
	return pile.chemistry_candidate if id == "persistent" else pile.adaptation_repertoire == ""


static func protection_workers(base: int, share: float) -> int:
	var change: int = ceili(absf(share) * RECOGNITION.protection_worker_change)
	return maxi(1, base + change * (1 if share > 0 else -1 if share < 0 else 0))


static func rejection_duration(integration: int, share: float) -> int:
	var guest = preload("res://data/ecology/backyard_guest.tres")
	return ceili((guest.purge_seconds + guest.integrated_extra_seconds * float(integration) / guest.integration_ticks) * (1.0 - RECOGNITION.clearing_change * share) / SimulationClock.TICK_INTERVAL)


static func evidence_losses(share: float) -> int:
	var guest = preload("res://data/ecology/backyard_guest.tres")
	return RECOGNITION.security_losses if share > 0.0 else RECOGNITION.tolerance_losses if share < 0.0 else guest.recognition_losses


static func energy_multiplier(id: String, fraction: float) -> float:
	return 1.0 - 0.3 * fraction if id == "lean" else 1.0 + 0.2 * fraction if id == "load" else 1.0


static func carry_multiplier(id: String, fraction: float) -> float:
	return 1.0 - 0.15 * fraction if id == "lean" else 1.0 + 0.3 * fraction if id == "load" else 1.0
