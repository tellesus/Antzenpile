class_name WorldNodeDefinition
extends Resource

@export var id: String = ""
@export var definition: ResourceDefinition
@export var source_profile: SourceProfile
@export var position: Vector2
@export var initial_quantity: float = 100.0
@export var initial_active: bool = true
@export_range(0.0,1.0) var contaminant_fraction: float = 0.0
