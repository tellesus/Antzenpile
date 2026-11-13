extends RefCounted
## A small reusable SDR light mask. No world state, RNG or per-frame allocation.

static var _texture: ImageTexture


static func texture() -> ImageTexture:
	if _texture != null: return _texture
	var mask: Image = Image.create(128, 64, false, Image.FORMAT_RGBA8)
	for y: int in mask.get_height():
		var across: float = absf(float(y) / (mask.get_height() - 1) * 2.0 - 1.0)
		var falloff: float = exp(-6.0 * across * across) * (1.0 - smoothstep(0.75, 1.0, across))
		for x: int in mask.get_width():
			var along: float = float(x) / (mask.get_width() - 1)
			var ends: float = smoothstep(0.0, 0.18, along) * smoothstep(0.0, 0.18, 1.0 - along)
			mask.set_pixel(x, y, Color(1.0, 1.0, 1.0, falloff * ends))
	_texture = ImageTexture.create_from_image(mask)
	return _texture
