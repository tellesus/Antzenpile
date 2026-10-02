class_name InterfaceText
extends RefCounted
## Player vocabulary at the presentation boundary; legacy command reasons stay compatible.

static func reason(value: String) -> String:
	return {
		"Honeydew producers have not been exploited": "Harvest honeydew before assigning tenders",
		"Not enough workers to protect the producers": "Not enough available workers to tend producers",
		"Protection commitment unavailable": "Tending assignment unavailable",
		"Could not commit protection workers": "Could not assign tending workers"
	}.get(value, value)
