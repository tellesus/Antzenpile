class_name InterfaceText
extends RefCounted
## Player vocabulary at the presentation boundary; legacy command reasons stay compatible.

static func reason(value: String) -> String:
	return {
		"Honeydew producers have not been exploited": "Harvest honeydew before assigning tenders",
		"Not enough workers to protect the producers": "Not enough available workers to tend producers",
		"Protection commitment unavailable": "Tending assignment unavailable",
		"Could not commit protection workers": "Could not assign tending workers"
	}.get(value, value)


static func resource(id: String) -> String:
	return {"carbohydrate": "carbs", "protein": "protein", "water": "water"}.get(id, id)


static func duration(seconds: float) -> String:
	var elapsed: int = maxi(0, roundi(seconds))
	return "%ds" % elapsed if elapsed < 60 else "%dm %02ds" % [elapsed / 60, elapsed % 60]


static func local_shortage(status: Dictionary, costs: Dictionary, workers: int) -> String:
	var available: int = status.get("workers_available", status.get("available_workers", 0))
	if available < workers: return "Need %d more available workers" % (workers - available)
	for id: String in ["carbohydrate", "protein", "water"]:
		var shortage: float = float(costs.get(id, 0.0)) - float(status.get("resources", {}).get(id, 0.0))
		if shortage > 0.00001: return "Need %.1f more %s" % [ceilf(shortage * 10.0) / 10.0, resource(id)]
	return ""
