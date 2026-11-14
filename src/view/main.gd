extends Node2D
## Phase 1 view: the map as the colony senses it, ants as points of light,
## and the scent brush. Reads the simulation and sends it paint commands only.

const CELL_PX := 8
const BRUSH_NAMES: Array[String] = ["Attract", "Alarm", "Repel", "Seek", "Erase"]
const BRUSH_KINDS: Array[int] = [Colony.Scent.ATTRACT, Colony.Scent.ALARM, Colony.Scent.REPEL, Colony.Scent.SEEK, Colony.ERASE]
const BRUSH_COLORS: Array[Color] = [
	Color(1.0, 0.72, 0.2), Color(1.0, 0.25, 0.2), Color(0.72, 0.4, 1.0),
	Color(0.3, 0.85, 1.0), Color(0.75, 0.75, 0.75)]
const SPEEDS: Array[int] = [1, 2, 4]

var world: SimWorld
var _accumulator := 0.0
var _anim_time := 0.0
var _paused := false
var _speed_index := 0
var _brush := 0
var _brush_radius := 3
var _painting := false
var _dragging := false

var _camera: Camera2D
var _material: ShaderMaterial
var _images := {}
var _textures := {}
var _ants: MultiMesh
var _status: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	world = SimWorld.new(20261113)
	_add_environment()
	_add_world_quad()
	_add_ants()
	_add_camera()
	_add_hud()
	_upload_fields()


func _process(delta: float) -> void:
	_anim_time += delta
	if not _paused:
		_accumulator += delta * SPEEDS[_speed_index]
	var step_time := 1.0 / SimWorld.TICKS_PER_SECOND
	var stepped := false
	var guard := 0
	while _accumulator >= step_time and guard < 8:
		_accumulator -= step_time
		world.step()
		stepped = true
		guard += 1
	if guard == 8:
		_accumulator = 0.0
	if _painting:
		_paint_at_mouse()
		stepped = true
	if stepped:
		_upload_fields()
	_material.set_shader_parameter("now_tick", float(world.tick))
	_material.set_shader_parameter("anim_time", _anim_time)
	_draw_ants(clampf(_accumulator / step_time, 0.0, 1.0))

	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_camera.position += pan * 900.0 * delta / _camera.zoom.x
	var c := world.colony
	_status.text = "Ants %d    Food %d    %s    %d fps" % [
		c.count * 5, int(c.food_stored),
		"paused" if _paused else "%dx" % SPEEDS[_speed_index],
		Engine.get_frames_per_second()]
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / 1.15)
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_painting = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_camera.position -= event.relative / _camera.zoom.x
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				_select_brush(event.keycode - KEY_1)
			KEY_SPACE:
				_paused = not _paused
			KEY_TAB:
				_speed_index = (_speed_index + 1) % SPEEDS.size()
			KEY_BRACKETLEFT:
				_brush_radius = maxi(1, _brush_radius - 1)
			KEY_BRACKETRIGHT:
				_brush_radius = mini(10, _brush_radius + 1)


func _draw() -> void:
	# Nest marker.
	var centre := (Vector2(world.nest_cell) + Vector2(0.5, 0.5)) * CELL_PX
	var pulse := 0.75 + 0.25 * sin(_anim_time * 1.5)
	draw_circle(centre, CELL_PX * 2.2, Color(1.0, 0.55, 0.10, 0.10))
	draw_circle(centre, CELL_PX * 0.9, Color(3.0 * pulse, 1.5 * pulse, 0.3, 1.0))
	# Brush outline.
	var col: Color = BRUSH_COLORS[_brush]
	col.a = 0.9 if _painting else 0.5
	draw_arc(get_global_mouse_position(), (_brush_radius + 0.5) * CELL_PX, 0.0, TAU, 48, col, 1.5)


func _mouse_cell() -> Vector2i:
	var p := get_global_mouse_position() / CELL_PX
	return Vector2i(int(floor(p.x)), int(floor(p.y)))


func _paint_at_mouse() -> void:
	world.colony.paint(BRUSH_KINDS[_brush], _mouse_cell(), _brush_radius, 0.12)


func _select_brush(index: int) -> void:
	_brush = index
	for i in _buttons.size():
		_buttons[i].modulate = Color(1, 1, 1, 1.0 if i == index else 0.45)


func _zoom_by(factor: float) -> void:
	var z := clampf(_camera.zoom.x * factor, 0.4, 6.0)
	_camera.zoom = Vector2(z, z)


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.15
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 1.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	var node := WorldEnvironment.new()
	node.environment = env
	add_child(node)


func _add_world_quad() -> void:
	var w := world.width
	var h := world.height
	_material = ShaderMaterial.new()
	_material.shader = load("res://src/view/world.gdshader")
	_material.set_shader_parameter("grid", Vector2(w, h))
	var terrain_image := Image.create_from_data(w, h, false, Image.FORMAT_R8, world.terrain)
	_material.set_shader_parameter("terrain_tex", ImageTexture.create_from_image(terrain_image))
	for key in ["known", "food", "trail", "attract", "alarm", "repel", "seek"]:
		var image := Image.create_empty(w, h, false, Image.FORMAT_RF)
		_images[key] = image
		_textures[key] = ImageTexture.create_from_image(image)
		_material.set_shader_parameter(key + "_tex", _textures[key])

	var white := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var quad := Sprite2D.new()
	quad.texture = ImageTexture.create_from_image(white)
	quad.centered = false
	quad.scale = Vector2(w, h) * CELL_PX
	quad.material = _material
	quad.z_index = -1
	add_child(quad)


func _upload_fields() -> void:
	var c := world.colony
	_upload("known", c.known_tick)
	_upload("food", c.known_food)
	_upload("trail", c.trail)
	_upload("attract", c.scents[Colony.Scent.ATTRACT])
	_upload("alarm", c.scents[Colony.Scent.ALARM])
	_upload("repel", c.scents[Colony.Scent.REPEL])
	_upload("seek", c.scents[Colony.Scent.SEEK])


func _upload(key: String, data: PackedFloat32Array) -> void:
	var image: Image = _images[key]
	image.set_data(world.width, world.height, false, Image.FORMAT_RF, data.to_byte_array())
	(_textures[key] as ImageTexture).update(image)


func _add_ants() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1, 1)
	_ants = MultiMesh.new()
	_ants.transform_format = MultiMesh.TRANSFORM_2D
	_ants.use_colors = true
	_ants.mesh = mesh
	_ants.instance_count = Colony.MAX_ANTS
	_ants.visible_instance_count = 0
	var node := MultiMeshInstance2D.new()
	node.multimesh = _ants
	add_child(node)


## Draws only ants the colony is in contact with. Scouts out in the dark are
## not shown; they reappear when they reconnect.
func _draw_ants(blend: float) -> void:
	var c := world.colony
	var shown := 0
	var carry_col := Color(2.6, 1.7, 0.5)
	var out_col := Color(0.95, 1.05, 1.15)
	var scout_col := Color(0.5, 1.3, 1.6)
	var size := Vector2(CELL_PX * 0.55, CELL_PX * 0.26)
	for i in c.count:
		if c.aconnected[i] == 0:
			continue
		var pos := Vector2(
			lerpf(c.px[i], c.ax[i], blend), lerpf(c.py[i], c.ay[i], blend)) * CELL_PX
		var xf := Transform2D(c.aheading[i], size, 0.0, pos)
		_ants.set_instance_transform_2d(shown, xf)
		var col: Color = out_col
		if c.acarry[i] > 0.0:
			col = carry_col
		elif c.arole[i] == Colony.Role.SCOUT:
			col = scout_col
		_ants.set_instance_color(shown, col)
		shown += 1
	_ants.visible_instance_count = shown


func _add_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = (Vector2(world.nest_cell) + Vector2(0.5, 0.5)) * CELL_PX
	_camera.zoom = Vector2(1.6, 1.6)
	add_child(_camera)
	_camera.make_current()


func _add_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(24, 16)
	_status.modulate = Color(0.8, 0.8, 0.8)
	layer.add_child(_status)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -20.0
	layer.add_child(bar)
	for i in BRUSH_NAMES.size():
		var b := Button.new()
		b.text = "%d  %s" % [i + 1, BRUSH_NAMES[i]]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(120, 40)
		b.add_theme_color_override("font_color", BRUSH_COLORS[i])
		b.add_theme_color_override("font_hover_color", BRUSH_COLORS[i])
		b.add_theme_color_override("font_pressed_color", BRUSH_COLORS[i])
		b.pressed.connect(_select_brush.bind(i))
		bar.add_child(b)
		_buttons.append(b)
	_select_brush(0)

	var help := Label.new()
	help.text = "Left-drag paint   Right-drag pan   Wheel zoom   [ ] brush size   Space pause   Tab speed"
	help.modulate = Color(0.5, 0.5, 0.5)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(24, 0)
	help.offset_top = -92.0
	help.offset_bottom = -68.0
	layer.add_child(help)
