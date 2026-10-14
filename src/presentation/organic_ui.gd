class_name OrganicUI
extends RefCounted
## Shared, bounded canvas skin. No blur, lights or interaction ownership.

static var _styles: Dictionary = {}

static func surface(canvas: CanvasItem, rect: Rect2, tint: Color, outline: bool = false) -> void:
	var key: String = tint.to_html() + str(outline)
	if not _styles.has(key):
		if _styles.size() >= 64: _styles.clear()
		var style := StyleBoxFlat.new()
		style.draw_center = not outline
		var emphasized: bool = maxf(tint.r,maxf(tint.g,tint.b)) > 0.25
		style.bg_color = Color("0b1115").lerp(tint, 0.36 if emphasized else 0.20)
		style.bg_color.a = 0.97
		style.border_color = Color("a68b61").lerp(tint.lightened(0.3), 0.35)
		style.border_color.a = 0.80 if emphasized else 0.42
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		style.corner_detail = 6
		_styles[key] = style
	canvas.draw_style_box(_styles[key], rect)
