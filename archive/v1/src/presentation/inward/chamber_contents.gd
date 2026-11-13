class_name ChamberContents
extends RefCounted

const QUEEN = preload("res://assets/graphics/colony/queen.png")
const EGG = preload("res://assets/graphics/colony/brood_egg.png")
const LARVA = preload("res://assets/graphics/colony/brood_larva.png")
const PUPA = preload("res://assets/graphics/colony/brood_pupa.png")

static func queen(canvas: Node2D, at: Vector2, time: float, scale: float = 1.0) -> void:
	canvas.draw_set_transform(at + Vector2(sin(time*0.4),cos(time*0.3))*1.2, -PI*0.28)
	canvas.draw_texture_rect(QUEEN,Rect2(-Vector2.ONE*48*scale,Vector2.ONE*96*scale),false,Color(1.08,1.03,0.92))
	canvas.draw_set_transform(Vector2.ZERO)

static func brood(canvas: Node2D, at: Vector2, stage: String, health: float, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = LARVA if stage == "larva" else PUPA if stage == "pupa" else EGG
	canvas.draw_circle(at,14,Color(0.3,0.9,0.62,0.045*health))
	canvas.draw_texture_rect(texture, Rect2(at-Vector2.ONE*16,Vector2.ONE*32), false, Color(tint,lerpf(0.65,1.0,health)))

static func store(canvas: Node2D, at: Vector2, tint: Color) -> void:
	# Colored stores are aggregate nutrient marks, not eggs in the Food Exchange.
	canvas.draw_circle(at,8,Color(tint,0.06))
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-4,2),at+Vector2(-2,-5),at+Vector2(3,-4),at+Vector2(5,2),at+Vector2(0,5)]),Color(tint,0.58))
	canvas.draw_line(at+Vector2(-1,-3),at+Vector2(2,1),Color(tint.lightened(.4),.9),1.2,true)
