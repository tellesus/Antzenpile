class_name TerrainDefinition
extends Resource

@export var id: String = ""
@export var bounds: Rect2
@export_range(0.0, 1.0) var exposure: float = 0.0
@export var traversable: bool = true
@export var movement_cost: float = 1.0
