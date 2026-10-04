class_name InterfaceText
extends RefCounted
## Player vocabulary at the presentation boundary; legacy command reasons stay compatible.

static func reason(value: String) -> String:
	return {
		"Honeydew producers have not been exploited": "Harvest honeydew before assigning aphid attendants",
		"Not enough workers to protect the producers": "Not enough available workers for aphid attendants",
		"Protection commitment unavailable": "Tending assignment unavailable",
		"Could not commit protection workers": "Could not assign aphid attendants"
	}.get(value, value)


static func resource(id: String) -> String:
	return {"carbohydrate": "carbs", "protein": "protein", "water": "water", "nest_site": "nest site"}.get(id, id)


static func duration(seconds: float) -> String:
	var elapsed: int = maxi(0, roundi(seconds))
	return "%ds" % elapsed if elapsed < 60 else "%dm %02ds" % [elapsed / 60, elapsed % 60]


static func fit_line(value: String, font: Font, size: int, width: float) -> String:
	if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width: return value
	var shortened: String = value
	while not shortened.is_empty() and font.get_string_size(shortened + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		shortened = shortened.left(shortened.length() - 1)
	return shortened + "…"


static func local_shortage(status: Dictionary, costs: Dictionary, workers: int) -> String:
	var available: int = status.get("workers_available", status.get("available_workers", 0))
	if available < workers: return "Need %d more available workers" % (workers - available)
	for id: String in ["carbohydrate", "protein", "water"]:
		var shortage: float = float(costs.get(id, 0.0)) - float(status.get("resources", {}).get(id, 0.0))
		if shortage > 0.00001: return "Need %.1f more %s" % [ceilf(shortage * 10.0) / 10.0, resource(id)]
	return ""
