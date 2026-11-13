class_name ActivationFeedback
extends RefCounted
## Acknowledgment/outcome of a control tap; acceptance never claims remote success.
var position: Vector2 = Vector2.ZERO
var expires_at: int = 0
var status: String = "neutral"
const DURATION: int = 300
func begin() -> void: status="neutral"
func outcome(result: Variant) -> void:
	if result is Dictionary and result.has("accepted"):
		status="rejected" if not result.accepted else "queued" if result.get("queued",false) else "accepted"
func attach(view: Node2D, suppressed: Callable = Callable()) -> void:
	view.draw.connect(func() -> void:
		if not suppressed.is_valid() or not suppressed.call(): draw(view))
func tap(at: Vector2) -> void:
	position = at; expires_at = Time.get_ticks_msec() + DURATION
func draw(view: Node2D) -> void:
	var remaining: int = expires_at - Time.get_ticks_msec()
	if remaining <= 0: return
	var alpha: float = float(remaining) / DURATION
	var color: Color={"neutral":Color("bbc6aa"),"accepted":Color("b5d1a3"),"queued":Color("d9bd80"),"rejected":Color("d9927d")}.get(status,Color("bbc6aa"))
	view.draw_arc(position,12+6*(1-alpha),0,TAU,24,Color(color,alpha*0.7),1.4,true)
