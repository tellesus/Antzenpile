class_name BroodEnvironment
extends RefCounted
## Local larval exposure followed by surviving larval progression, not a forecast.
const TRAITS: Array[String] = ["heat_resilience", "moisture_resilience"]
var seen: Array[String] = []
var candidates: Array[String] = []

func observe(pile: PileState, exposure: Array[String]) -> void:
	for id: String in TRAITS:
		var strained: bool = pile.temperature.temperature > pile.temperature.CONFIG.favorable_high if id == "heat_resilience" else pile.humidity.moisture < pile.humidity.CONFIG.favorable_low
		if not strained: continue
		if id not in seen: seen.append(id); seen.sort()
		if id not in exposure: exposure.append(id); exposure.sort()

func survived(exposure: Array[String]) -> void:
	for id: String in exposure:
		if id in seen and id not in candidates: candidates.append(id)
	candidates.sort()

func to_dict() -> Dictionary:
	return {"seen": seen.duplicate(), "candidates": candidates.duplicate()}

static func valid_exposure(value: Variant) -> bool:
	if not value is Array or value.size() > TRAITS.size(): return false
	var checked: Array[String] = []
	for id: Variant in value:
		if not id is String or id not in TRAITS or id in checked: return false
		checked.append(id)
	return true

func restore(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 2 or not data.has_all(["seen", "candidates"]): return false
	if not valid_exposure(data.seen) or not valid_exposure(data.candidates): return false
	for id: String in data.candidates:
		if id not in data.seen: return false
	seen.assign(data.seen); candidates.assign(data.candidates)
	return true

static func larval_rate(pile: PileState, traits: Array[String]) -> float:
	var heat: float = pile.temperature.larval_rate()
	var moisture: float = pile.humidity.larval_rate()
	if "heat_resilience" in traits:
		var definition: TraitDefinition = TraitCatalog.DEFINITIONS.heat_resilience
		# Extreme heat still applies its full penalty; favorable warmth has a cost.
		if pile.temperature.temperature <= pile.temperature.CONFIG.favorable_high:
			heat = definition.comfortable_rate
		elif pile.temperature.temperature <= pile.temperature.CONFIG.extreme_high:
			heat += (1.0 - heat) * definition.warm_relief
	if "moisture_resilience" in traits and pile.humidity.moisture < pile.humidity.CONFIG.favorable_low:
		moisture += (1.0 - moisture) * TraitCatalog.DEFINITIONS.moisture_resilience.dry_relief
	# Independent pressures never cancel one another or exceed normal development.
	return clampf(minf(heat, minf(moisture, minf(pile.brood_health.larval_rate(), pile.midden.larval_rate()))), 0.0, 1.0)
