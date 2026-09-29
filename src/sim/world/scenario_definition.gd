class_name ScenarioDefinition
extends Resource

@export var id: String = "backyard_slice"
@export var bounds: Rect2 = Rect2(0, 0, 40, 40)
@export var home_position: Vector2 = Vector2(20, 20)
@export var nodes: Array[WorldNodeDefinition] = []
@export var terrain: Array[TerrainDefinition] = []
