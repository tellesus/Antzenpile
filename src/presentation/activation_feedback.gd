class_name ActivationFeedback
extends RefCounted
## Neutral acknowledgment of a control tap; never claims dispatch or changes a run.
var position: Vector2 = Vector2.ZERO
var expires_at: int = 0
const DURATION: int = 300
func tap(at: Vector2) -> void:
	position = at; expires_at = Time.get_ticks_msec() + DURATION
func draw(view: Node2D) -> void:
	var remaining: int = expires_at - Time.get_ticks_msec()
	if remaining <= 0: return
	var alpha: float = float(remaining) / DURATION
	view.draw_arc(position,12+6*(1-alpha),0,TAU,24,Color(0.82,0.88,0.77,alpha*0.7),1.4,true)
