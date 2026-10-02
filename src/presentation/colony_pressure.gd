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
		food = food or cohort.get("nutrition", 1.0) < 1.0 and cohort.get("care", 1.0) >= 1.0
		care = care or cohort.get("care", 1.0) < 1.0
	var shortages: Array[String] = food_shortages(status)
	for resource_id: String in shortages: causes.append("CARB" if resource_id == "carbohydrate" else resource_id.to_upper())
	if food and shortages.is_empty(): causes.append("FOOD") # Older reports may have no specific cause.
	if care: causes.append("CARE")
	return causes

static func food_shortages(status: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for resource_id: String in ["carbohydrate", "protein", "water"]:
		for cohort: Dictionary in status.get("brood", []):
			if cohort.get("care", 1.0) >= 1.0 and cohort.get("nutrition", 1.0) < 1.0 and resource_id in cohort.get("nutrition_shortfalls", []):
				result.append(resource_id)
				break
	return result

static func food_names(status: Dictionary) -> String:
	var labels: Array[String] = []
	for resource_id: String in food_shortages(status): labels.append("Carb" if resource_id == "carbohydrate" else resource_id.capitalize())
	return " + ".join(labels)

static func attention(status: Dictionary) -> Dictionary:
	var causes: Array[String] = nursery_causes(status)
	if causes.is_empty(): return {}
	var organ: String = "midden" if causes == ["REFUSE"] and status.get("midden", {}).get("revealed", false) else "nursery"
	return {"organ": organ, "causes": causes, "title": "CHECK " + organ.to_upper()}
