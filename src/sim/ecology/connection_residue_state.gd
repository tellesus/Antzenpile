class_name ConnectionResidueState
extends ResidueZoneState
## Content versions preserve enabled old worlds and captured paid evidence.
const LEGACY=preload("res://data/ecology/roadside_connection_residue.tres")
const CURRENT=preload("res://data/ecology/roadside_connection_residue_v2.tres")
const DEFINITIONS={"link_v1":LEGACY,"link_v2":CURRENT}
var definition_id: String="link_v2"
func _init() -> void:super(CURRENT)
func to_dict() -> Dictionary:return {"enabled":enabled,"definition_id":definition_id}
func restore(data: Variant, scenario: String) -> bool:
	if not data is Dictionary or data.size()!=1+int(data.has("definition_id")):return false
	var profile: Variant=data.get("definition_id","link_v1")
	if not profile is String or not DEFINITIONS.has(profile) or not data.has("enabled"):return false
	if not super.restore({"enabled":data.enabled},scenario):return false
	definition_id=profile;definition=DEFINITIONS[profile];return true
