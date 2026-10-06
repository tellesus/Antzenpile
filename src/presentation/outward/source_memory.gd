class_name SourceMemory
extends RefCounted
const Copy = preload("res://src/presentation/interface_text.gd")
const SORTS: Array[String]=["label","recent","intake","labor","risk"]
const SORT_NAMES: Dictionary={"label":"LABEL","recent":"RECENT REPORT","intake":"TOTAL INTAKE","labor":"WORKER TARGET","risk":"ALARM FIRST"}
## Returned memories only; browsing never validates current world availability.

static func entries(signals: Array[Dictionary], status: Dictionary, category: String, order: String="label") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for signal_data: Dictionary in signals:
		if signal_data.category not in ["carbohydrate","protein","water","nest_site"]: continue
		var route: Dictionary = {}
		for trail: Dictionary in status.get("trails", []):
			if trail.destination_knowledge_id == signal_data.source_knowledge_id:
				route = trail
				break
		var nutrients: Dictionary=route.get("nutrient_receipts",{})
		if signal_data.category!=category and category not in SourceCatalog.roles(signal_data.get("source_type",""),signal_data.category) and not nutrients.has(category): continue
		var category_receipt: Dictionary=nutrients.get(category,{})
		var total: float=category_receipt.get("total",route.get("delivered_total",0.0) if signal_data.category==category else 0.0)
		var hint: Dictionary = status.get("temporal_hints", {}).get(signal_data.source_knowledge_id, {})
		var reported_empty: bool = hint.get("last_return_empty", route.get("status", "") == "depleted")
		var state: String = "Reported empty" if reported_empty else "Previously delivered" if total > 0 else "Trace reported"
		if category == "nest_site": state = "Last recheck unconfirmed" if reported_empty else "Possible shelter reported"
		result.append({"id": signal_data.id, "knowledge_id": signal_data.source_knowledge_id, "category": category,
			"source_type":signal_data.get("source_type",""),"memory_label":signal_data.get("memory_label",""),
			"bearing": signal_data.get("bearing"), "age": signal_data.age, "state": state,
			"workers": route.get("allocated_workers", 0),
			"waiting_workers":route.get("waiting_workers",0),
			"route_id": route.get("id", ""), "route_status": route.get("status", "none"), "desired_workers": route.get("desired_workers", 0),
			"receipt": category_receipt.duplicate(true) if not category_receipt.is_empty() else route.get("receipt", {}).duplicate(true) if signal_data.category==category else {},
			"delivered_total": total,
			"danger": route.get("journey_alarm",route.get("reported_losses", 0) > 0 and not route.get("ambusher_addressed",false) or route.get("foreign_reports", 0) > 0),
			"honeydew": status.get("honeydew", {}).get("knowledge_id", "") == signal_data.source_knowledge_id})
	sort_entries(result,order)
	return result

static func sort_entries(result: Array, order: String) -> void:
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match order:
			"recent": if a.age!=b.age: return a.age<b.age
			"intake": if a.delivered_total!=b.delivered_total: return a.delivered_total>b.delivered_total
			"labor": if a.desired_workers!=b.desired_workers: return a.desired_workers>b.desired_workers
			"risk": if a.danger!=b.danger: return a.danger
			"label":
				var left: int=_label_order(a.get("memory_label",""));var right: int=_label_order(b.get("memory_label",""))
				if left!=right: return left<right
		return a.knowledge_id<b.knowledge_id)

static func _label_order(label: String) -> int:
	var order: int=0
	for index: int in label.length(): order=order*26+label.unicode_at(index)-64
	return order

static func next_sort(order: String) -> String: return SORTS[(SORTS.find(order)+1)%SORTS.size()]
static func staffing_label(entry: Dictionary) -> String:
	return "Target %d · %d assigned · %d wait" % [entry.get("desired_workers",0),entry.get("workers",0),entry.get("waiting_workers",0)]
static func intake_label(entry: Dictionary) -> String:
	return "Received %.1f total · historical intake" % entry.get("delivered_total",0) if entry.get("delivered_total",0)>0 else "No intake yet · yield unproven"

static func bundle_label(route: Dictionary) -> String:
	var parts: Array[String]=[]
	for id: String in PileState.RESOURCE_IDS:
		if route.get("nutrient_receipts",{}).has(id): parts.append("%.1f %s" % [route.nutrient_receipts[id].total,Copy.resource(id)])
	return "Intake: "+" · ".join(parts)


static func display_name(entry: Dictionary) -> String:
	var type: String = entry.get("source_type", "")
	var name: String = SourceCatalog.PROFILES[type].display_name if SourceCatalog.PROFILES.has(type) else "Aphid honeydew" if entry.get("honeydew",false) else "Protein remains" if entry.get("knowledge_id",entry.get("source_knowledge_id",""))=="known:ambusher_carcass" else {"carbohydrate":"Sweet trace","protein":"Protein trace","water":"Water trace","nest_site":"Shelter memory"}.get(entry.get("category",""),"Unidentified trace")
	var label: String = entry.get("memory_label", "")
	return name + (" " + label if not label.is_empty() else "")

static func description(entry: Dictionary) -> String:
	var type: String = entry.get("source_type", "")
	return SourceCatalog.PROFILES[type].description if SourceCatalog.PROFILES.has(type) else "Identity unconfirmed · return a sample"


static func receipt_label(entry: Dictionary, time: float, destination: String = "home") -> String:
	if entry.get("category") == "nest_site": return "Occupants and safety unknown"
	var receipt: Dictionary = entry.get("receipt", {})
	if receipt.is_empty():
		return "Delivery dates unrecorded" if entry.get("delivered_total", 0.0) > 0 else "No delivery %s yet" % destination
	return "Delivered %.1f %s · %s ago" % [receipt.last_amount, Copy.resource(entry.get("category", "")), Copy.duration(time - receipt.last_at)]


static func first_receipt_label(entry: Dictionary, time: float) -> String:
	var receipt: Dictionary = entry.get("receipt", {})
	if receipt.is_empty(): return ""
	return "%s %s ago" % ["Records began" if receipt.earlier_unrecorded else "First delivery", Copy.duration(time - receipt.first_at)]


static func defense_label(outcome: Dictionary) -> String:
	if outcome.get("goal", "clear") == "hunt" and outcome.get("outcome", "") == "secured": return "Predator killed · protein reported"
	return {"secured": "Ambusher driven off", "withdrew": "Defenders withdrew", "not_found": "No ambusher found"}.get(outcome.get("outcome", ""), "No defensive return yet")


static func defense_is_latest(outcome: Dictionary, route: Dictionary) -> bool:
	return not outcome.is_empty() and float(outcome.get("received_at", 0.0)) >= maxf(float(route.get("last_loss_time", 0.0)), float(route.get("last_witness_time", 0.0)))
