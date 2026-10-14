class_name SourceProfile
extends Resource
## Immutable content metadata; simulation stores only the stable identity.
@export var id: String = ""
@export var resource_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var yields: Dictionary[String,float] = {}
@export var bulk: float = 1.0
