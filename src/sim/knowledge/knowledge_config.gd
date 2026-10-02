class_name KnowledgeConfig
extends Resource

@export var corroboration_window: float = 300.0
@export var corroboration_limit: int = 3
@export var corroboration_bonus: float = 0.06
@export var confidence_ceiling: float = 0.95
@export var uncertainty_floor: float = 0.25
@export var conflicting_confidence_multiplier: float = 0.75

@export var confirmed_confidence: float = 0.9
@export var cue_confidence: float = 0.55
@export var uncertainty_scale: float = 4.0
@export var confidence_half_life: float = 300.0
