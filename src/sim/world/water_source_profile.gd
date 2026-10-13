class_name WaterSourceProfile
extends SourceProfile
## Immutable small-water availability rules, not a fluid simulation.
@export var capacity: float=3.0
@export var renewal_per_second: float=0.0
@export var wet_refill_per_second: float=0.0
@export var evaporation_per_second: float=0.0
@export var severe_dry_renewal_multiplier: float=1.0
@export var severe_dry_evaporation_multiplier: float=2.0
