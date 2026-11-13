extends Node2D
## Phase 0 view: draws the terrain dimly, a glowing nest marker, and a camera.
## Reads the simulation; never writes to it except by calling step().

const CELL_PX := 8
const TERRAIN_COLORS := {
	SimWorld.Terrain.SOIL: Color(0.050, 0.038, 0.030),
	SimWorld.Terrain.GRASS: Color(0.022, 0.055, 0.030),
	SimWorld.Terrain.STONE: Color(0.060, 0.062, 0.070),
	SimWorld.Terrain.WATER: Color(0.012, 0.030, 0.075),
	SimWorld.Terrain.SAND: Color(0.075, 0.064, 0.036),
}

var world: SimWorld
var _accumulator := 0.0
var _camera: Camera2D
var _label: Label
var _dragging := false


func _ready() -> void:
	world = SimWorld.new(20261113)
	_add_environment()
	_add_terrain_sprite()
	_add_camera()
	_add_label()


func _process(delta: float) -> void:
	_accumulator += delta
	var step_time := 1.0 / SimWorld.TICKS_PER_SECOND
	while _accumulator >= step_time:
		_accumulator -= step_time
		world.step()
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_camera.position += pan * 900.0 * delta / _camera.zoom.x
	_label.text = "Antzenpile 2.0  phase 0   seed %d   tick %d   %d fps" % [
		world.world_seed, world.tick, Engine.get_frames_per_second()]
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / 1.15)
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_camera.position -= event.relative / _camera.zoom.x


func _draw() -> void:
	# Nest marker. Colour values above 1.0 are what the bloom picks up.
	var centre := (Vector2(world.nest_cell) + Vector2(0.5, 0.5)) * CELL_PX
	var pulse := 0.75 + 0.25 * sin(world.tick * 0.15)
	draw_circle(centre, CELL_PX * 2.2, Color(1.0, 0.55, 0.10, 0.10))
	draw_circle(centre, CELL_PX * 0.9, Color(3.0 * pulse, 1.5 * pulse, 0.3, 1.0))


func _zoom_by(factor: float) -> void:
	var z := clampf(_camera.zoom.x * factor, 0.4, 6.0)
	_camera.zoom = Vector2(z, z)


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var node := WorldEnvironment.new()
	node.environment = env
	add_child(node)


func _add_terrain_sprite() -> void:
	var image := Image.create(world.width, world.height, false, Image.FORMAT_RGBA8)
	for y in world.height:
		for x in world.width:
			image.set_pixel(x, y, TERRAIN_COLORS[world.terrain_at(Vector2i(x, y))])
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.scale = Vector2(CELL_PX, CELL_PX)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -1
	add_child(sprite)


func _add_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = (Vector2(world.nest_cell) + Vector2(0.5, 0.5)) * CELL_PX
	add_child(_camera)
	_camera.make_current()


func _add_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.modulate = Color(0.7, 0.7, 0.7)
	layer.add_child(_label)
