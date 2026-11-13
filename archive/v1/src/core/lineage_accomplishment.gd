class_name LineageAccomplishment
extends RefCounted
## One dated highest-generation receipt; original maternal identity is retained.
var generation: int=0
var tick: int=0
var pile_id: String=""
var parent_id: String=""
var count: int=0
func observe(pile: PileState, brood: BroodCohort, at_tick: int) -> void:
	if brood.parent_generation<=generation or brood.parent_queen_id.is_empty() or brood.count<1:return
	generation=brood.parent_generation;tick=at_tick;pile_id=pile.id;parent_id=brood.parent_queen_id;count=brood.count
func to_dict() -> Dictionary:
	return {"generation":generation,"tick":tick,"pile_id":pile_id,"parent_id":parent_id,"count":count}
func restore(data: Variant, colony: ColonyState, at_tick: int) -> bool:
	if not data is Dictionary or data.size()!=5 or not data.has_all(to_dict().keys()) or not data.pile_id is String or not data.parent_id is String:return false
	for key: String in ["generation","tick","count"]:
		if not WorkerLedger.valid_count(data[key]):return false
	if data.generation==0:
		if data.tick!=0 or data.count!=0 or data.pile_id!="" or data.parent_id!="":return false
	else:
		if data.tick<1 or data.tick>at_tick or data.count<1 or data.count>8 or not colony.piles.has(data.pile_id) or colony.piles[data.pile_id].brood_matured_total<data.count:return false
		var parts: PackedStringArray=data.parent_id.split(":")
		if parts.size() not in [3,4] or parts[0]!="queen" or not colony.piles.has(parts[1]):return false
		if parts.size()==3 and parts[2]!="founder":return false
		if parts.size()==4 and (parts[2]!="raised" or not parts[3].is_valid_int() or parts[3].to_int()<0 or parts[3].to_int()>data.tick):return false
		var known: bool=false
		for pile: PileState in colony.piles.values():
			if pile.queen.queen_id(pile.id)==data.parent_id and pile.queen.generation==data.generation:known=true
			# The existing maternal contract admits captured older generations even
			# when a local succession did not retain a full retired-mother record.
			if pile.queen.generation>data.generation and QueenState.known_parent(data.parent_id,int(data.generation),pile.queen.queen_id(pile.id),pile.queen.generation,pile.queen.previous_mothers):known=true
			for mother: Dictionary in pile.queen.previous_mothers:
				if mother.identity==data.parent_id and mother.generation==data.generation:known=true
		if not known:return false
	generation=int(data.generation);tick=int(data.tick);pile_id=data.pile_id;parent_id=data.parent_id;count=int(data.count)
	return true
