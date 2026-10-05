class_name KnowledgeBase
extends RefCounted
## Only delivered evidence and time enter this boundary. Never query hidden truth.

const Known = preload("res://src/sim/knowledge/known_node.gd")
const CONFIG = preload("res://data/knowledge/default_knowledge.tres")
var nodes: Dictionary[String, KnownNode] = {}
var observations: Dictionary[String, Observation] = {}
var _received_at: Dictionary[String, float] = {}
var outcomes: Dictionary[String, Array] = {}
var last_error: String = ""


func consume(inbox: Dictionary[String, Observation], time: float) -> bool:
	if not is_finite(time) or time < 0:
		return _reject("Invalid delivery time")
	# Validate the entire batch before changing archive or inbox.
	for id: String in inbox:
		var evidence: Observation = inbox[id]
		if evidence == null or id != evidence.id or not _valid_evidence(evidence, time):
			return _reject("Invalid delivered evidence")
		if observations.has(id) and observations[id].to_dict() != evidence.to_dict():
			return _reject("Observation ID reused with different evidence")
	var ids: Array = inbox.keys()
	ids.sort()
	for id: String in ids:
		if not observations.has(id):
			observations[id] = inbox[id].detached_copy()
			_received_at[id] = time
			_rebuild_node(inbox[id].source_node_id)
			record_outcome(inbox[id].source_node_id, true, time, "scout")
	inbox.clear()
	last_error = ""
	return true


func record_outcome(source_id: String, available: bool, time: float, method: String) -> bool:
	if not nodes.has("known:" + source_id) or not method in ["scout", "trail"] or not is_finite(time) or time < 0:
		return _reject("Invalid source outcome")
	if not outcomes.has(source_id):
		outcomes[source_id] = []
	var history: Array = outcomes[source_id]
	if not history.is_empty() and time < history.back().time:
		return _reject("Source outcomes must be chronological")
	if not history.is_empty() and history.back().available == available:
		return true
	history.append({"time": time, "available": available, "method": method})
	if history.size() > 16:
		history.pop_front()
	last_error = ""
	return true


func temporal_hint(knowledge_id: String) -> Dictionary:
	if not nodes.has(knowledge_id):
		return {}
	var history: Array = outcomes.get(nodes[knowledge_id].source_node_id, [])
	var saw_positive: bool = false
	var saw_gap: bool = false
	var returned_before: bool = false
	for entry: Dictionary in history:
		if entry.available:
			if saw_gap and saw_positive:
				returned_before = true
			saw_positive = true
			saw_gap = false
		else:
			saw_gap = true
	var last_return_empty: bool = not history.is_empty() and not history.back().available
	var label: String = "Earlier report only"
	if last_return_empty:
		label = "Last return found empty"
	elif returned_before:
		label = "Source found again · reported" if recovery_report(knowledge_id, last_empty_report(knowledge_id)) else "Returned before · timing unknown"
	return {"label": label, "possible_recurrence": returned_before, "has_report": not history.is_empty(), "last_return_empty": last_return_empty,
		"renewed_report": returned_before and recovery_report(knowledge_id, last_empty_report(knowledge_id))}


func last_empty_report(knowledge_id: String) -> float:
	if not nodes.has(knowledge_id):
		return 0.0
	var result: float = 0.0
	for entry: Dictionary in outcomes.get(nodes[knowledge_id].source_node_id, []):
		if not entry.available:
			result = entry.time
	return result

func latest_delivery(knowledge_id: String) -> Dictionary:
	if not nodes.has(knowledge_id): return {}
	var selected: Observation;var received: float=-1
	for id: String in nodes[knowledge_id].evidence_ids:
		if _received_at[id]>received or _received_at[id]==received and (selected==null or _preferred(observations[id],selected)):
			selected=observations[id];received=_received_at[id]
	return {"evidence":selected.detached_copy(),"received_at":received} if selected!=null else {}


func recovery_report(knowledge_id: String, after: float) -> bool:
	if not nodes.has(knowledge_id):
		return false
	var node: KnownNode = nodes[knowledge_id]
	var history: Array = outcomes.get(node.source_node_id, [])
	if history.is_empty() or not history.back().available:
		return false
	for id: String in node.evidence_ids:
		var evidence: Observation = observations[id]
		if evidence.proximity_confirmed and evidence.observed_at > after and _received_at[id] > after:
			return true
	return false


static func _valid_evidence(evidence: Observation, time: float) -> bool:
	if not SourceCatalog.accepts(evidence.source_type, evidence.definition_id) or not evidence.source_type.is_empty() and not evidence.proximity_confirmed: return false
	if evidence.id != evidence.scout_id + ":" + evidence.source_node_id or evidence.scout_id.is_empty() or evidence.source_node_id.is_empty() or evidence.origin_pile.is_empty() or evidence.definition_id.is_empty():
		return false
	for value: float in [evidence.first_observed_at, evidence.observed_at, evidence.uncertainty_radius, evidence.closest_distance]:
		if not is_finite(value) or value < 0:
			return false
	return evidence.estimated_position.is_finite() and evidence.uncertainty_radius > 0 and evidence.first_observed_at <= evidence.observed_at and evidence.observed_at <= time


func _rebuild_node(source_id: String) -> void:
	var node := Known.new()
	node.id = "known:" + source_id
	node.source_node_id = source_id
	if nodes.has(node.id): node.label_index = nodes[node.id].label_index
	else:
		for known: KnownNode in nodes.values(): node.label_index = maxi(node.label_index, known.label_index)
		node.label_index += 1
	node.first_observed_at = INF
	node.first_delivered_at = INF
	var selected: Observation
	var ids: Array = observations.keys()
	ids.sort()
	for id: String in ids:
		var evidence: Observation = observations[id]
		if evidence.source_node_id != source_id:
			continue
		if not evidence.source_type.is_empty(): node.source_type = evidence.source_type
		node.evidence_ids.append(id)
		node.first_observed_at = minf(node.first_observed_at, evidence.first_observed_at)
		node.first_delivered_at = minf(node.first_delivered_at, _received_at[id])
		node.last_delivered_at = maxf(node.last_delivered_at, _received_at[id])
		if selected == null or _preferred(evidence, selected):
			selected = evidence
	node.definition_id = selected.definition_id
	node.estimated_position = selected.estimated_position
	node.uncertainty_radius = selected.uncertainty_radius
	node.last_observed_at = selected.observed_at
	node.selected_evidence_id = selected.id
	var baseline: float = CONFIG.confirmed_confidence if selected.proximity_confirmed else CONFIG.cue_confidence
	node.confidence = clampf(baseline / (1.0 + selected.uncertainty_radius / CONFIG.uncertainty_scale), 0.0, 1.0)
	if selected.collective_search:
		_corroborate(node, selected)
	nodes[node.id] = node


func _corroborate(node: KnownNode, selected: Observation) -> void:
	var recent: Array[Observation] = []
	for id: String in node.evidence_ids:
		var evidence: Observation = observations[id]
		if evidence.collective_search and selected.observed_at - evidence.observed_at <= CONFIG.corroboration_window:
			recent.append(evidence)
	recent.sort_custom(func(a: Observation, b: Observation) -> bool: return _preferred(a,b))
	var weight: float = 0.0
	var estimate: Vector2 = Vector2.ZERO
	var count: int = 0
	var conflict: bool = false
	var baseline: float = CONFIG.cue_confidence
	for evidence: Observation in recent:
		if selected.estimated_position.distance_to(evidence.estimated_position) > selected.uncertainty_radius + evidence.uncertainty_radius:
			conflict = true
			continue
		if count >= CONFIG.corroboration_limit:
			continue
		var contribution: float = 1.0 / (evidence.uncertainty_radius * evidence.uncertainty_radius)
		weight += contribution
		estimate += evidence.estimated_position * contribution
		count += 1
		if evidence.proximity_confirmed:
			baseline = CONFIG.confirmed_confidence
	if count > 1:
		node.estimated_position = estimate / weight
		node.uncertainty_radius = roundf(maxf(CONFIG.uncertainty_floor, sqrt(1.0 / weight)) * 1e10) / 1e10
		node.confidence = minf(CONFIG.confidence_ceiling, baseline / (1.0 + node.uncertainty_radius / CONFIG.uncertainty_scale) + CONFIG.corroboration_bonus * (count - 1))
	if conflict:
		node.confidence *= CONFIG.conflicting_confidence_multiplier


static func _preferred(candidate: Observation, current: Observation) -> bool:
	if candidate.observed_at != current.observed_at:
		return candidate.observed_at > current.observed_at
	if candidate.uncertainty_radius != current.uncertainty_radius:
		return candidate.uncertainty_radius < current.uncertainty_radius
	if candidate.proximity_confirmed != current.proximity_confirmed:
		return candidate.proximity_confirmed
	return candidate.id < current.id


func to_dict() -> Dictionary:
	var records: Array[Dictionary] = []
	var ids: Array = observations.keys()
	ids.sort()
	for id: String in ids:
		records.append({"evidence": observations[id].to_dict(), "received_at": _received_at[id]})
	var known: Array[Dictionary] = []
	ids = nodes.keys()
	ids.sort()
	for id: String in ids:
		known.append(nodes[id].to_dict())
	var history_records: Array[Dictionary] = []
	ids = outcomes.keys()
	ids.sort()
	for source_id: String in ids:
		history_records.append({"source_id": source_id, "visits": outcomes[source_id].duplicate(true)})
	return {"observations": records, "nodes": known, "outcomes": history_records}


func restore(data: Dictionary, validated_evidence: Dictionary[String, Observation], time: float) -> bool:
	if not is_finite(time) or time < 0 or not data.has_all(["observations", "nodes"]) or not data.observations is Array or not data.nodes is Array:
		return _reject("Malformed knowledge snapshot")
	var candidate := KnowledgeBase.new()
	for record: Variant in data.observations:
		if not record is Dictionary or not record.has_all(["evidence", "received_at"]) or not record.evidence is Dictionary or not record.evidence.has("id"):
			return _reject("Malformed archive record")
		var id: Variant = record.evidence.id
		if not id is String or not validated_evidence.has(id) or candidate.observations.has(id):
			return _reject("Unknown or duplicate archive evidence")
		if not _valid_evidence(validated_evidence[id], time) or not _matches_quantized_position(record.evidence, validated_evidence[id].to_dict()):
			return _reject("Archive evidence mismatch")
		if not typeof(record.received_at) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(record.received_at)) or record.received_at < validated_evidence[id].observed_at or record.received_at > time:
			return _reject("Invalid evidence delivery time")
		candidate.observations[id] = validated_evidence[id].detached_copy()
		candidate._received_at[id] = float(record.received_at)
	if candidate.observations.size() != validated_evidence.size():
		return _reject("Archive evidence mismatch")
	for evidence: Observation in candidate.observations.values():
		candidate._rebuild_node(evidence.source_node_id)
	var labeled: int = 0
	var used_labels: Dictionary = {}
	for record: Variant in data.nodes:
		if not record is Dictionary or not record.get("id") is String or not candidate.nodes.has(record.id): return _reject("Unknown known-node label")
		if record.has("label_index"):
			if not WorkerLedger.valid_count(record.label_index) or record.label_index < 1 or record.label_index > data.nodes.size() or used_labels.has(int(record.label_index)): return _reject("Invalid or duplicate memory label")
			used_labels[int(record.label_index)] = true; labeled += 1
			candidate.nodes[record.id].label_index = int(record.label_index)
	if labeled != 0 and labeled != data.nodes.size(): return _reject("Incomplete memory labels")
	if labeled == 0:
		var memories: Array = candidate.nodes.values()
		memories.sort_custom(func(a: KnownNode,b: KnownNode) -> bool: return a.first_delivered_at < b.first_delivered_at if a.first_delivered_at != b.first_delivered_at else a.id < b.id)
		for index: int in memories.size(): memories[index].label_index = index + 1
	var rebuilt_nodes: Array = candidate.to_dict().nodes
	if rebuilt_nodes.size() != data.nodes.size():
		return _reject("Known nodes disagree with their evidence")
	for index: int in rebuilt_nodes.size():
		if not data.nodes[index] is Dictionary or not _matches_quantized_position(data.nodes[index], rebuilt_nodes[index]):
			return _reject("Known nodes disagree with their evidence")
	var history_records: Variant = data.get("outcomes", [])
	if not history_records is Array:
		return _reject("Malformed source history")
	for record: Variant in history_records:
		if not record is Dictionary or not record.has_all(["source_id", "visits"]) or not record.source_id is String or not candidate.nodes.has("known:" + record.source_id) or candidate.outcomes.has(record.source_id) or not record.visits is Array or record.visits.is_empty() or record.visits.size() > 16:
			return _reject("Invalid source history")
		var visits: Array = []
		var previous_time: float = -1.0
		var previous_available: Variant = null
		for entry: Variant in record.visits:
			if not entry is Dictionary or not entry.has_all(["time", "available", "method"]) or not typeof(entry.time) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(entry.time)) or entry.time < 0 or entry.time > time or typeof(entry.available) != TYPE_BOOL or not entry.method in ["scout", "trail"]:
				return _reject("Invalid source visit")
			if entry.time < previous_time or entry.available == previous_available:
				return _reject("Nonchronological source visits")
			previous_time = float(entry.time)
			previous_available = entry.available
			visits.append(entry.duplicate(true))
		candidate.outcomes[record.source_id] = visits
	nodes = candidate.nodes
	observations = candidate.observations
	_received_at = candidate._received_at
	outcomes = candidate.outcomes
	last_error = ""
	return true


static func _matches_quantized_position(record: Dictionary, expected: Dictionary) -> bool:
	# JSON writes Vector2's float32 components as decimals; parsing can differ by
	# a last double-precision bit. Quantize that one field before exact comparison.
	if not record.has("estimated_position") or not record.estimated_position is Array or record.estimated_position.size() != 2:
		return false
	for value: Variant in record.estimated_position:
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	var comparable: Dictionary = record.duplicate(true)
	if expected.has("collective_search") and not comparable.has("collective_search"):
		comparable.collective_search = false
	if expected.has("source_type") and not comparable.has("source_type"): comparable.source_type = ""
	if expected.has("label_index"):
		comparable.label_index = int(comparable.get("label_index", expected.label_index))
	var position := Vector2(record.estimated_position[0], record.estimated_position[1])
	comparable.estimated_position = [position.x, position.y]
	for field: String in ["uncertainty_radius", "closest_distance"]:
		if expected.has(field) and comparable.has(field) and typeof(comparable[field]) in [TYPE_INT, TYPE_FLOAT] and absf(float(comparable[field]) - float(expected[field])) <= 1e-15:
			comparable[field] = expected[field]
	# Derived division results can parse one float64 bit away even with full JSON
	# precision. Rebuild from validated evidence; accept only representation noise.
	if expected.has("confidence"):
		if not comparable.has("confidence") or not typeof(comparable.confidence) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(comparable.confidence)) or absf(float(comparable.confidence) - float(expected.confidence)) > 0.000000000000001:
			return false
		comparable.confidence = expected.confidence
	return comparable == expected


func _reject(reason: String) -> bool:
	last_error = reason
	return false
