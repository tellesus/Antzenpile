class_name ReportJournal
extends RefCounted
## Bounded semantic records of delivered/local facts; never physical replay data.
const LIMIT: int = 192
const SEEN_LIMIT: int = 512
const KINDS: Array[String] = ["source","intake","loss","conflict","survey","pressure","defense","approach","brood","trait","project","camp","supplies","dispatch","order","gathering","investment"]
var initialized: bool = false
var since: float = 0.0
var next_id: int = 1
var omitted: int = 0
var seen: Dictionary = {}
var entries: Array[Dictionary] = []
var _serialized: Array[String] = []

func changed(key: String, value: Variant) -> bool:
	if typeof(value) in [TYPE_INT,TYPE_FLOAT]: value=float(value)
	if seen.get(key) == value: return false
	if not seen.has(key) and seen.size() >= SEEN_LIMIT: return false
	seen[key] = value; return true

func add(kind: String, pile: String, subject: String, observed: float, received: float, detail: String = "", amount: float = 0, total: float = 0, recording: bool = true) -> void:
	if not recording or next_id >= WorkerLedger.MAX_COUNT: return
	amount=_quantity(amount);total=_quantity(total)
	if kind == "intake":
		for index: int in entries.size():
			var existing: Dictionary = entries[index]
			if existing.kind == kind and existing.subject_id == subject:
				existing.observed_at=observed; existing.received_at=received; existing.amount=amount
				existing.total=_quantity(existing.total+amount); existing.repeats=mini(WorkerLedger.MAX_COUNT,existing.repeats+1)
				_serialized[index]=JSON.stringify(existing,"",true,true); return
	var entry: Dictionary={"id":next_id,"kind":kind,"pile_id":pile,"subject_id":subject,"observed_at":observed,"received_at":received,"detail":detail,"amount":amount,"total":total,"repeats":1,"unread":true}
	entries.append(entry);_serialized.append(JSON.stringify(entry,"",true,true));next_id+=1
	if entries.size()>LIMIT: entries.pop_front();_serialized.pop_front();omitted+=1

func unread_count(pile: String = "") -> int:
	var count: int=0
	for entry: Dictionary in entries:
		if entry.unread and (pile.is_empty() or entry.pile_id==pile): count+=1
	return count

func mark_read(id: int = 0, pile: String = "") -> bool:
	var found: bool=false
	for index: int in entries.size():
		var entry: Dictionary=entries[index]
		if (id==0 or entry.id==id) and (pile.is_empty() or entry.pile_id==pile):
			entry.unread=false;_serialized[index]=JSON.stringify(entry,"",true,true);found=true
	return found or id==0

func project(pile: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for entry: Dictionary in entries:
		if pile.is_empty() or entry.pile_id==pile: result.append(entry.duplicate())
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.received_at>b.received_at if a.received_at!=b.received_at else a.id>b.id)
	return result

func to_dict() -> Dictionary:
	return {"initialized":initialized,"since":since,"next_id":next_id,"omitted":omitted,"seen":seen.duplicate(),"records":_serialized.duplicate()}

func restore(data: Variant, colony: ColonyState, knowledge: KnowledgeBase, trails: TrailNetwork, time: float) -> bool:
	if not data is Dictionary or data.size()!=6 or not data.has_all(["initialized","since","next_id","omitted","seen","records"]) or not data.initialized is bool: return false
	if not _number(data.since) or data.since>time or not WorkerLedger.valid_count(data.next_id) or data.next_id<1 or not WorkerLedger.valid_count(data.omitted): return false
	if not data.seen is Dictionary or data.seen.size()>SEEN_LIMIT or not data.records is Array or data.records.size()>LIMIT: return false
	if not data.initialized and (data.since!=0 or data.next_id!=1 or data.omitted!=0 or not data.seen.is_empty() or not data.records.is_empty()): return false
	var restored: Array[Dictionary]=[];var encoded: Array[String]=[];var previous: int=0
	for text: Variant in data.records:
		if not text is String or text.length()>2048: return false
		var entry: Variant=JSON.parse_string(text)
		if not _valid_entry(entry,colony,knowledge,trails,time) or entry.id<=previous or entry.id>=data.next_id or entry.received_at<data.since: return false
		entry.id=int(entry.id);entry.repeats=int(entry.repeats);entry.amount=_quantity(entry.amount);entry.total=_quantity(entry.total);entry.observed_at=float(entry.observed_at);entry.received_at=float(entry.received_at)
		previous=entry.id;restored.append(entry);encoded.append(text)
	for key: Variant in data.seen:
		if not key is String or key.length()>160 or key.get_slice("/",0) not in KINDS+ ["reproduction","nursery","expansion","midden","exchange"]: return false
		var value: Variant=data.seen[key]
		if value is String:
			if value.length()>160: return false
		elif not _number(value): return false
	initialized=data.initialized;since=float(data.since);next_id=int(data.next_id);omitted=int(data.omitted);seen=data.seen.duplicate();entries=restored;_serialized=encoded
	for key: String in seen:
		if typeof(seen[key]) in [TYPE_INT,TYPE_FLOAT]: seen[key]=float(seen[key])
	return true

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value>=0

static func _quantity(value: float) -> float:
	# These are report-display quantities, never gameplay stores. Canonical decimals
	# avoid one-bit JSON changes in cached records and later grouped totals.
	return float(String.num(value,5))

static func _valid_entry(entry: Variant, colony: ColonyState, knowledge: KnowledgeBase, trails: TrailNetwork, time: float) -> bool:
	if not entry is Dictionary or entry.size()!=11 or not entry.has_all(["id","kind","pile_id","subject_id","observed_at","received_at","detail","amount","total","repeats","unread"]): return false
	if not WorkerLedger.valid_count(entry.id) or entry.id<1 or entry.kind not in KINDS or not entry.pile_id is String or not colony.piles.has(entry.pile_id): return false
	if not entry.subject_id is String or not entry.detail is String or not entry.unread is bool or not WorkerLedger.valid_count(entry.repeats) or entry.repeats<1: return false
	for key: String in ["observed_at","received_at","amount","total"]:
		if not _number(entry[key]): return false
	if entry.observed_at>entry.received_at or entry.received_at>time: return false
	match entry.kind:
		"source":
			if not knowledge.nodes.has(entry.subject_id): return false
			var node: KnownNode=knowledge.nodes[entry.subject_id]
			return entry.amount in [0.0,1.0] and SourceCatalog.accepts(entry.detail,node.definition_id) and (entry.detail.is_empty() or entry.detail==node.source_type)
		"trait": return entry.subject_id in AdaptationRules.TRAITS and entry.detail=="established" and entry.subject_id in colony.piles[entry.pile_id].genetics.established
		"project": return entry.subject_id in ["nursery","food_exchange","midden","queen"] and entry.detail in ["developed","expanded","ready"]
		"brood": return entry.subject_id==entry.pile_id and entry.detail in ["emerged","lost"] and WorkerLedger.valid_count(entry.amount) and WorkerLedger.valid_count(entry.total)
		"supplies": return colony.piles.has(entry.subject_id) and entry.detail=="returned"
		"investment": return entry.subject_id==entry.pile_id and entry.detail in ["none","adaptation","reproduction","adaptation_laid","reproduction_laid"] and entry.amount in [0.0,1.0,2.0]
	if not trails.routes.has(entry.subject_id) or trails.routes[entry.subject_id].origin_pile!=entry.pile_id: return false
	match entry.kind:
		"intake": return entry.detail in PileState.RESOURCE_IDS and entry.total>=entry.amount
		"loss": return entry.detail=="reported" and WorkerLedger.valid_count(entry.amount) and entry.amount<=entry.total and entry.total<=trails.routes[entry.subject_id].reported_losses
		"conflict": return entry.detail in ["contested","holding","resisted","reinforced","secured","withdrew","dispersed"]
		"survey": return entry.detail in ["ambush","mixed","foreign","surface","inconclusive"]
		"pressure": return entry.detail in ["holding","resisted"] and WorkerLedger.valid_count(entry.amount)
		"defense": return entry.detail in ["clear:secured","clear:withdrew","clear:not_found","hunt:secured","hunt:withdrew","hunt:not_found"] and WorkerLedger.valid_count(entry.amount) and WorkerLedger.valid_count(entry.total) and entry.amount<=entry.total
		"approach": return entry.detail in ["found","danger","unconfirmed"]
		"camp": return entry.detail in ["ready","failed","established"]
		"dispatch": return entry.detail in ["investigate","defend"] and WorkerLedger.valid_count(entry.amount)
		"order": return entry.detail in ["clear","hunt"] and WorkerLedger.valid_count(entry.amount)
		"gathering": return entry.detail=="target" and WorkerLedger.valid_count(entry.amount)
	return false
