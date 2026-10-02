class_name MusicState
extends RefCounted
## Detached audio intent, derived from colony state. Never serialized as gameplay state.

var development_level: int = 0
var nursery_gain: float = 0.0
var midden_gain: float = 0.0
var food_gain: float = 0.0


static func from_food_exchange(state: String) -> MusicState:
	var result := MusicState.new()
	result.development_level = 1 if state == "developed" else 0
	result.food_gain = float(result.development_level)
	return result


static func from_summary(summary: Dictionary, focus: String = "") -> MusicState:
	var result: MusicState = from_food_exchange(summary.get("food_exchange_state", "primitive"))
	if summary.get("nursery_state", "") == "developed":
		var condition: float = minf(summary.get("humidity", {}).get("larval_rate", 1.0), summary.get("midden", {}).get("larval_rate", 1.0))
		for cohort: Dictionary in summary.get("brood", []):
			condition = minf(condition, minf(cohort.get("nutrition", 1.0), cohort.get("care", 1.0)))
		result.nursery_gain = 0.55 + 0.45 * clampf(condition, 0.0, 1.0)
	if summary.get("midden", {}).get("state", "") == "developed":
		result.midden_gain = 1.0
	if focus in ["food_exchange", "nursery", "midden"]:
		result.food_gain *= 1.0 if focus == "food_exchange" else 0.85
		result.nursery_gain *= 1.0 if focus == "nursery" else 0.85
		result.midden_gain *= 1.0 if focus == "midden" else 0.85
	return result
