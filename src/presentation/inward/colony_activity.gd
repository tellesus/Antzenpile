class_name ColonyActivity
extends RefCounted
## Detached activity suggestions, never physical cargo or worker identities.

const MAX_ANTS: int = 12
const MAX_BROOD: int = 6
const Pressure = preload("res://src/presentation/colony_pressure.gd")


static func health(status: Dictionary, organ: String) -> float:
	# These are already-known functional rates, not a new health simulation.
	if organ == "midden":
		return clampf(status.get("midden", {}).get("larval_rate", 1.0), 0.0, 1.0)
	if organ != "nursery":
		return 1.0
	var result: float = minf(status.get("humidity", {}).get("larval_rate", 1.0), status.get("midden", {}).get("larval_rate", 1.0))
	for cohort: Dictionary in status.get("brood", []):
		result = minf(result, minf(cohort.get("nutrition", 1.0), cohort.get("care", 1.0)))
	return clampf(result, 0.0, 1.0)


static func pulse(health_rate: float, time: float) -> float:
	var strain: float = 1.0 - clampf(health_rate, 0.0, 1.0)
	return sin(time * 1.4) * (1.0 - strain) + sin(time * 2.3 + sin(time * 0.7)) * strain


static func jobs(status: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if status.get("nursery_occupied_space", 0) > 0 and status.get("nursery_care_capacity", 0) > 0:
		result.append({"role": "nursing", "from": "queen", "to": "nursery", "color": Color("c6cbb2")})
	if status.get("trail_workers", 0) > 0:
		result.append({"role": "circulation", "from": "entrance", "to": "food_exchange", "color": Color("dcb477")})
	var midden: Dictionary = status.get("midden", {})
	if midden.get("revealed", false) and midden.get("cleaners", 0) > 0 and midden.get("burden", 0.0) > 0:
		result.append({"role": "cleanup", "from": "entrance", "to": "midden", "color": Color("bd927a")})
	if status.get("nursery_state", "") == "developed" and status.get("humidity", {}).get("carers", 0) > 0:
		result.append({"role": "climate", "from": "food_exchange", "to": "nursery", "color": Color("7fbfcf")})
	for organ: String in ["food_exchange", "nursery", "midden"]:
		var developing: bool = midden.get("state", "") == "developing" if organ == "midden" else status.get(organ + "_state", "") == "developing"
		if organ == "nursery": developing = developing or status.get("nursery_expansion", {}).get("state", "") == "developing"
		if developing and (organ != "midden" or midden.get("revealed", false)):
			result.append({"role": "excavation", "from": "entrance", "to": organ, "color": Color("a69f7c")})
	if status.get("guest", {}).get("rejection_active", false):
		result.append({"role": "rejection", "from": "guest", "to": "nursery", "color": Color("bba6c8")})
	return result


static func representatives(status: Dictionary, centers: Dictionary, time: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var active: Array[Dictionary] = jobs(status)
	# One per job before adding a second, so a busy organ cannot hide other work.
	for pass_index: int in 2:
		for index: int in active.size():
			if result.size() >= MAX_ANTS:
				return result
			var job: Dictionary = active[index]
			var start: Vector2 = centers[job.from]
			var finish: Vector2 = centers[job.to]
			var control: Vector2 = (start + finish) * 0.5 + Vector2(12, -18)
			var t: float = fposmod(time * 0.05 + pass_index * 0.5 + index * 0.13, 1.0)
			result.append({"role": job.role, "color": job.color,
				"position": start * pow(1 - t, 2) + control * 2 * (1 - t) * t + finish * t * t,
				"direction": (control - start) * (1 - t) + (finish - control) * t})
	return result


static func brood_stages(status: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var cohorts: Array = status.get("brood", [])
	var groups: int = mini(4, cohorts.size())
	for index: int in groups:
		var cohort: Dictionary = cohorts[index]
		var quota: int = MAX_BROOD / groups + (1 if index < MAX_BROOD % groups else 0)
		for glyph: int in mini(quota, int(cohort.get("count", 0))):
			result.append(cohort.get("stage", "egg"))
	return result


static func pressure(status: Dictionary, organ: String) -> String:
	var midden: Dictionary = status.get("midden", {})
	if organ == "midden":
		return "REFUSE PRESSURE" if midden.get("larval_rate", 1.0) < 1.0 else ""
	if organ == "guest":
		return "REJECTION" if status.get("guest", {}).get("rejection_active", false) else ""
	if organ != "nursery":
		return ""
	return " / ".join(Pressure.nursery_causes(status))


static func project_progress(status: Dictionary, organ: String) -> float:
	var expansion: Dictionary = status.get("nursery_expansion", {})
	if organ == "nursery" and expansion.get("state", "") == "developing":
		return clampf(expansion.get("progress_seconds", 0.0) / maxf(expansion.get("duration", 1.0), 0.001), 0.0, 1.0)
	if organ == "midden":
		var midden: Dictionary = status.get("midden", {})
		return clampf(midden.get("progress", 0.0), 0.0, 1.0) if midden.get("state", "") == "developing" else -1.0
	if status.get(organ + "_state", "") != "developing":
		return -1.0
	var duration: float = status.get(organ + ("_build_duration" if organ == "nursery" else "_duration"), 1.0)
	return clampf(status.get(organ + "_progress", 0.0) / maxf(duration, 0.001), 0.0, 1.0)
