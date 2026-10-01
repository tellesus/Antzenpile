class_name ReturnedLossEvidence
extends RefCounted
## Words derived only from delivered journey reports, never hidden cause state.


static func lines(route: Dictionary, time: float) -> Array[String]:
	var result: Array[String] = []
	var attacks: int = int(route.get("attack_reports", 0))
	var fights: int = int(route.get("fighting_reports", 0))
	var missing: int = int(route.get("missing_workers", 0))
	var losses: int = int(route.get("reported_losses", 0))
	if losses == 0:
		return result
	var reason: String = "Workers missing · cause unknown" if missing == losses else "Loss reported · cause unknown"
	if attacks > 0 and fights > 0:
		reason = "Attack and foreign fighting reported"
	elif attacks > 0:
		reason = "Repeated attacks reported on journey" if attacks > 1 else "Sudden attack reported on journey"
	elif fights > 0:
		reason = "Foreign-ant fighting reported"
	result.append(reason)
	result.append("%d missing · no witnesses" % missing if missing == losses else "%d losses · %d missing without witnesses" % [losses, missing] if missing > 0 else "%d %s lost along journey" % [losses, "worker" if losses == 1 else "workers"])
	var report_time: float = float(route.get("last_witness_time", 0.0)) if attacks + fights > 0 else float(route.get("last_loss_time", 0.0))
	var conflict: String = str(route.get("conflict_report", ""))
	var outcome: String = " · contested" if conflict == "contested" else " · foreign withdrew" if conflict == "secured" else " · withdrew" if conflict == "withdrew" else " · dispersed" if conflict == "dispersed" else ""
	result.append("Report %.0fs ago%s" % [maxf(0.0, time - report_time), outcome])
	return result
