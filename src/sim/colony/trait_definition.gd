class_name TraitDefinition
extends Resource
## Immutable trait content; simulation hooks are explicit and family-specific.
@export var id: String=""
@export var title: String=""
@export var short_title: String=""
@export var family: String="foraging"
@export var benefit: String=""
@export var tradeoff: String=""
@export var evidence: String=""
@export var carbohydrate: float=12
@export var protein: float=12
@export var water: float=6
@export var energy_change: float=0
@export var carry_change: float=0
@export var larval_food_multiplier: float=1
@export var care_gain: float=0
func costs() -> Dictionary: return {"carbohydrate":carbohydrate,"protein":protein,"water":water}
