class_name ChamberContents
extends RefCounted

const QUEEN = preload("res://assets/graphics/colony/queen.png")
const EGG = preload("res://assets/graphics/colony/brood_egg.png")
const LARVA = preload("res://assets/graphics/colony/brood_larva.png")
const PUPA = preload("res://assets/graphics/colony/brood_pupa.png")

static func queen(canvas: Node2D, at: Vector2, time: float) -> void:
	canvas.draw_set_transform(at + Vector2(sin(time*0.4),cos(time*0.3))*1.2, -PI*0.28)
	canvas.draw_texture_rect(QUEEN,Rect2(-Vector2.ONE*48,Vector2.ONE*96),false,Color(1.08,1.03,0.92))
	canvas.draw_set_transform(Vector2.ZERO)

static func brood(canvas: Node2D, at: Vector2, stage: String, health: float, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = LARVA if stage == "larva" else PUPA if stage == "pupa" else EGG
	canvas.draw_texture_rect(texture, Rect2(at-Vector2.ONE*16,Vector2.ONE*32), false, Color(tint,lerpf(0.65,1.0,health)))
