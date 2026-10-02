class_name SourceMemory
extends RefCounted
const Copy = preload("res://src/presentation/interface_text.gd")
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
		var state: String = "Reported empty" if reported_empty else "Previously delivered" if route.get("delivered_total", 0.0) > 0 else "Trace reported"
		result.append({"id": signal_data.id, "knowledge_id": signal_data.source_knowledge_id, "category": category,
			"bearing": signal_data.get("bearing"), "age": signal_data.age, "state": state,
			"workers": route.get("allocated_workers", 0),
			"receipt": route.get("receipt", {}).duplicate(true),
			"delivered_total": route.get("delivered_total", 0.0),
			"danger": route.get("reported_losses", 0) > 0 and not route.get("ambusher_addressed",false) or route.get("foreign_reports", 0) > 0,
			"honeydew": status.get("honeydew", {}).get("knowledge_id", "") == signal_data.source_knowledge_id})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.knowledge_id < b.knowledge_id)
	return result


static func display_name(entry: Dictionary) -> String:
	# A stable memory tag, independent of page/filter/order and hidden source names.
	var tag: String = str(entry.get("knowledge_id", "")).sha256_text().left(4).to_upper()
	return ("Honeydew" if entry.get("honeydew", false) else Copy.resource(entry.get("category", "")).capitalize()) + " #" + tag


static func receipt_label(entry: Dictionary, time: float) -> String:
	var receipt: Dictionary = entry.get("receipt", {})
	if receipt.is_empty():
		return "Delivery dates unrecorded" if entry.get("delivered_total", 0.0) > 0 else "No delivery home yet"
	return "Delivered %.1f %s · %s ago" % [receipt.last_amount, Copy.resource(entry.get("category", "")), Copy.duration(time - receipt.last_at)]


static func first_receipt_label(entry: Dictionary, time: float) -> String:
	var receipt: Dictionary = entry.get("receipt", {})
	if receipt.is_empty(): return ""
	return "%s %s ago" % ["Records began" if receipt.earlier_unrecorded else "First delivery", Copy.duration(time - receipt.first_at)]


static func defense_label(outcome: Dictionary) -> String:
	return {"secured": "Ambusher driven off", "withdrew": "Defenders withdrew", "not_found": "No ambusher found"}.get(outcome.get("outcome", ""), "No defensive return yet")
