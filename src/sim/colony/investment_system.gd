class_name InvestmentSystem
extends RefCounted
## Eligible special work takes a laying opportunity before new ordinary brood.
var _run: RunState
var _adaptation: RefCounted
var _reproduction: ReproductionSystem
var last_error: String=""
func _init(run: RunState, adaptation: RefCounted, reproduction: ReproductionSystem) -> void:
	_run=run;_adaptation=adaptation;_reproduction=reproduction
func queue_reproduction(pile_id: String, enabled: Variant) -> bool:
	if not _run.colony.piles.has(pile_id) or not enabled is bool: return _reject("Unknown pile or reproductive intent")
	var pile: PileState=_run.colony.piles[pile_id]
	if not pile.foundation.is_empty(): return _reject("Daughter reproductive generations are not yet available")
	if enabled and pile.queen_count<1: return _reject("No queen can lay reproductive brood")
	pile.investments.reproduction=enabled
	if enabled: pile.investments.add("reproduction")
	else: pile.investments.remove("reproduction")
	last_error="";return true
func prioritize(pile_id: String, kind: Variant) -> bool:
	if not _run.colony.piles.has(pile_id) or not kind is String: return _reject("Unknown pile or investment")
	var pile: PileState=_run.colony.piles[pile_id]
	if kind not in pile.investments.priority: return _reject("Queue this investment before giving it priority")
	pile.investments.priority.erase(kind);pile.investments.priority.push_front(kind)
	last_error="";return true
func next_eligible(pile: PileState) -> String:
	for kind: String in pile.investments.priority:
		if kind=="reproduction" and _reproduction.structural_blocker(pile).is_empty(): return kind
		if kind=="adaptation" and _adaptation.laying_blocker(pile,pile.queued_adaptation) not in ["trial","unavailable"]: return kind
	return ""
func start_next(pile_id: String, automatic: bool=false) -> bool:
	var pile: PileState=_run.colony.piles[pile_id]
	var kind: String=next_eligible(pile) if automatic else pile.investments.first()
	if kind.is_empty(): return _reject("No eligible special investment")
	var accepted: bool=_reproduction.start(pile_id,false) if kind=="reproduction" else _adaptation.start_queued(pile_id,false)
	last_error=_reproduction.last_error if kind=="reproduction" else _adaptation.last_error
	return accepted
func summary(pile_id: String) -> Dictionary:
	if not _run.colony.piles.has(pile_id): return {}
	var pile: PileState=_run.colony.piles[pile_id]
	return {"priority":pile.investments.priority.duplicate(),"next":pile.investments.first(),"eligible":next_eligible(pile),"reproduction":pile.investments.reproduction,"reproduction_wait":_reproduction.blocker(pile,false),"adaptation_wait":_adaptation.queued_status(pile_id).waiting}
func _reject(reason: String) -> bool: last_error=reason;return false
