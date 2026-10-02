class_name AdaptationRules
extends RefCounted
## Authored first-web choice; aggregate effects apply only to newly emerged workers.

const TRAITS: Array[String] = ["lean", "load", "persistent"]
const CHEMISTRY = preload("res://data/adaptation/persistent_chemistry.tres")
const COSTS: Dictionary = {"carbohydrate": 12.0, "protein": 12.0, "water": 6.0}
const NURSES: int = 2


static func valid_trait(id: String) -> bool:
	return TRAITS.has(id)


static func costs(id: String) -> Dictionary:
	return CHEMISTRY.costs() if id == "persistent" else COSTS.duplicate()


static func can_select(pile: PileState, id: String) -> bool:
	if not valid_trait(id) or pile.queen_count < 1 or pile.trial_cohort() != null or id in pile.genetics.established:
		return false
	return pile.chemistry_candidate if id == "persistent" else pile.adaptation_repertoire == ""


static func energy_multiplier(id: String, fraction: float) -> float:
	return 1.0 - 0.3 * fraction if id == "lean" else 1.0 + 0.2 * fraction if id == "load" else 1.0


static func carry_multiplier(id: String, fraction: float) -> float:
	return 1.0 - 0.15 * fraction if id == "lean" else 1.0 + 0.3 * fraction if id == "load" else 1.0
