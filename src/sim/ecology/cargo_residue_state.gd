class_name CargoResidueState
extends RefCounted
## Actual cargo chemistry and one ground witness; manifests do not duplicate stock.
const CONFIG=preload("res://data/ecology/roadside_connection_residue.tres")
var definition_id: String="link_v1"
var contact:=ResidueContactState.new()
var exposed: bool=false
var original_mass: float=0.0
func to_dict() -> Dictionary:return {"definition_id":definition_id,"contact":contact.to_dict(),"exposed":exposed,"original_mass":original_mass}
func restore(data: Variant, tick: int, departed: int, carbohydrate: float, mass: float) -> bool:
	if not data is Dictionary or data.size()!=3+int(data.has("definition_id")) or not data.has_all(["contact","exposed","original_mass"]) or not data.exposed is bool:return false
	var profile: Variant=data.get("definition_id","link_v1")
	if not profile is String or not ConnectionResidueState.DEFINITIONS.has(profile):return false
	var config: ResidueDefinition=ConnectionResidueState.DEFINITIONS[profile]
	if not typeof(data.original_mass) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.original_mass)) or data.original_mass<0 or data.original_mass>carbohydrate:return false
	var saved_contact:=ResidueContactState.new()
	if not saved_contact.restore(data.contact,tick,config) or saved_contact.active() and saved_contact.observed_tick<departed:return false
	if data.exposed:
		if not saved_contact.active() or carbohydrate<=0 or mass!=ResidueZoneState.contaminated(carbohydrate,float(data.original_mass),config):return false
	elif data.original_mass!=0:return false
	definition_id=profile;contact=saved_contact;exposed=data.exposed;original_mass=float(data.original_mass);return true
func report(time: float) -> Dictionary:
	var result: Dictionary=contact.report(time);result.definition_id=definition_id;return result
static func valid_report(data: Variant, time: float) -> bool:
	if not data is Dictionary or data.size()!=3+int(data.has("definition_id")):return false
	var profile: Variant=data.get("definition_id","link_v1")
	if not profile is String or not ConnectionResidueState.DEFINITIONS.has(profile):return false
	return ResidueZoneState.valid_report(known_report(data),time,ConnectionResidueState.DEFINITIONS[profile])
static func known_report(data: Dictionary) -> Dictionary:
	var result: Dictionary=data.duplicate(true);result.erase("definition_id");return result
