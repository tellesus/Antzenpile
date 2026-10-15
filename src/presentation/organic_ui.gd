class_name OrganicUI
extends RefCounted
## Shared, bounded canvas skin. No blur, lights or interaction ownership.

static var _styles: Dictionary = {}
static var _heading_font: SystemFont

static func heading(canvas: CanvasItem, at: Vector2, title: String, place: String) -> void:
	if _heading_font == null:
		_heading_font = SystemFont.new()
		_heading_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "sans-serif"])
		_heading_font.font_weight = 600
	canvas.draw_string(_heading_font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("e9f6fa"))
	var width: float = _heading_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	canvas.draw_line(at + Vector2(width + 18, -19), at + Vector2(width + 18, 0), Color("39727c"), 1.0)
	canvas.draw_string(ThemeDB.fallback_font, at + Vector2(width + 32, -3), place.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8fced4"))

static func surface(canvas: CanvasItem, rect: Rect2, tint: Color, outline: bool = false) -> void:
	var hovered: bool = rect.size.y <= 80 and rect.size.x <= 360 and rect.has_point(canvas.get_local_mouse_position())
	var key: String = tint.to_html() + str(outline) + str(hovered)
	if not _styles.has(key):
		if _styles.size() >= 64: _styles.clear()
		var style := StyleBoxFlat.new()
		style.draw_center = not outline
		var emphasized: bool = maxf(tint.r,maxf(tint.g,tint.b)) > 0.25
		style.bg_color = Color("07101b").lerp(tint, 0.30 if emphasized else 0.14)
		style.bg_color.a = 0.98
		style.border_color = Color("5f929c").lerp(tint.lightened(0.45), 0.25)
		style.border_color.a = 0.65 if emphasized or hovered else 0.30
		style.shadow_color = Color(0.025, 0.10, 0.14, 0.35 if hovered else 0.18)
		style.shadow_size = 9 if hovered else 5
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.corner_detail = 6
		_styles[key] = style
	canvas.draw_style_box(_styles[key], rect)
