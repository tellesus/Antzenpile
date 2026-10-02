class_name ColonyPressure
extends RefCounted
## Already-known local causes; no extra simulation or advice about hidden reality.

static func nursery_causes(status: Dictionary) -> Array[String]:
	var causes: Array[String] = []
	var humidity: Dictionary = status.get("humidity", {})
	if humidity.get("larval_rate", 1.0) < 1.0:
		causes.append("DRY" if humidity.get("moisture", 65.0) < 45.0 else "DAMP")
	if status.get("midden", {}).get("larval_rate", 1.0) < 1.0: causes.append("REFUSE")
	var food: bool = false
	var care: bool = false
	for cohort: Dictionary in status.get("brood", []):
		food = food or cohort.get("nutrition", 1.0) < 1.0
		care = care or cohort.get("care", 1.0) < 1.0
	if food: causes.append("FOOD")
	if care: causes.append("CARE")
	return causes

static func attention(status: Dictionary) -> Dictionary:
	var causes: Array[String] = nursery_causes(status)
	if causes.is_empty(): return {}
	var organ: String = "midden" if causes == ["REFUSE"] and status.get("midden", {}).get("revealed", false) else "nursery"
	return {"organ": organ, "causes": causes, "title": "CHECK " + organ.to_upper()}
