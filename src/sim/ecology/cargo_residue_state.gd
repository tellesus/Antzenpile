class_name CargoResidueState
extends RefCounted
## Actual cargo chemistry and one ground witness; manifests do not duplicate stock.
const CONFIG=preload("res://data/ecology/roadside_connection_residue.tres")
var contact:=ResidueContactState.new()
var exposed: bool=false
var original_mass: float=0.0
func to_dict() -> Dictionary:return {"contact":contact.to_dict(),"exposed":exposed,"original_mass":original_mass}
func restore(data: Variant, tick: int, departed: int, carbohydrate: float, mass: float) -> bool:
	if not data is Dictionary or data.size()!=3 or not data.has_all(to_dict().keys()) or not data.exposed is bool:return false
	if not typeof(data.original_mass) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.original_mass)) or data.original_mass<0 or data.original_mass>carbohydrate:return false
	var saved_contact:=ResidueContactState.new()
	if not saved_contact.restore(data.contact,tick,CONFIG) or saved_contact.active() and saved_contact.observed_tick<departed:return false
	if data.exposed:
		if not saved_contact.active() or carbohydrate<=0 or mass!=ResidueZoneState.contaminated(carbohydrate,float(data.original_mass),CONFIG):return false
	elif data.original_mass!=0:return false
	contact=saved_contact;exposed=data.exposed;original_mass=float(data.original_mass);return true
