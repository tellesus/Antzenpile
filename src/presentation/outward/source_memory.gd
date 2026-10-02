class_name SourceMemory
extends RefCounted
## Returned memories only; browsing never validates current world availability.

static func entries(signals: Array[Dictionary], status: Dictionary, category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for signal_data: Dictionary in signals:
		if signal_data.category != category:
			continue
		var route: Dictionary = {}
		for trail: Dictionary in status.get("trails", []):
			if trail.destination_knowledge_id == signal_data.source_knowledge_id:
				route = trail
				break
		var hint: Dictionary = status.get("temporal_hints", {}).get(signal_data.source_knowledge_id, {})
		var reported_empty: bool = hint.get("last_return_empty", route.get("status", "") == "depleted")
		var state: String = "Reported empty" if reported_empty else "Loaded before" if route.get("delivered_total", 0.0) > 0 else "Trace reported"
		result.append({"id": signal_data.id, "knowledge_id": signal_data.source_knowledge_id,
			"bearing": signal_data.get("bearing"), "age": signal_data.age, "state": state,
			"workers": route.get("allocated_workers", 0),
			"receipt": route.get("receipt", {}).duplicate(true),
			"delivered_total": route.get("delivered_total", 0.0),
			"danger": route.get("reported_losses", 0) > 0 or route.get("foreign_reports", 0) > 0,
			"honeydew": status.get("honeydew", {}).get("knowledge_id", "") == signal_data.source_knowledge_id})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.knowledge_id < b.knowledge_id)
	return result


static func receipt_label(entry: Dictionary, time: float) -> String:
	var receipt: Dictionary = entry.get("receipt", {})
	if receipt.is_empty():
		return "Home dates unrecorded" if entry.get("delivered_total", 0.0) > 0 else "No food delivered home yet"
	return "Home %.1f · %.0fs ago · %s %.0fs" % [receipt.last_amount, time - receipt.last_at,
		"tracked" if receipt.earlier_unrecorded else "first", time - receipt.first_at]
