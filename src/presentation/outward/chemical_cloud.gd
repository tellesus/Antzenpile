class_name ChemicalCloud
extends Node2D
## One bounded material per visible memory. Never reads a run or world object.

const Art = preload("res://src/presentation/sensory_art.gd")
const FLOW = preload("res://assets/graphics/chemistry/chemical_wisps.gdshader")
const NOISE = preload("res://assets/graphics/chemistry/flow_noise.tres")
const MASKS: Dictionary = {
	"nectar": preload("res://assets/graphics/chemistry/sources/nectar_memory.svg"),
	"honeydew": preload("res://assets/graphics/chemistry/sources/honeydew_memory.svg"),
	"fruit": preload("res://assets/graphics/chemistry/sources/fruit_memory.svg"),
	"seeds": preload("res://assets/graphics/chemistry/sources/seeds_memory.svg"),
	"crumbs": preload("res://assets/graphics/chemistry/sources/crumbs_memory.svg"),
	"dew": preload("res://assets/graphics/chemistry/sources/dew_memory.svg"),
	"puddle": preload("res://assets/graphics/chemistry/sources/puddle_memory.svg"),
	"seep": preload("res://assets/graphics/chemistry/sources/seep_memory.svg"),
	"remains": preload("res://assets/graphics/chemistry/sources/remains_memory.svg"),
	"water": preload("res://assets/graphics/proof/water_impression.svg"),
	"wolf_spider": preload("res://assets/graphics/chemistry/spider_memory.svg"),
	"beetle_hunter": preload("res://assets/graphics/chemistry/beetle_memory.svg"),
}
const SOURCE_FORMS: Dictionary = {
	"flower_nectar":"nectar", "aphid_honeydew":"honeydew", "ripe_fruit":"fruit",
	"cracked_seeds":"seeds", "picnic_crumbs":"crumbs", "dew_drops":"dew",
	"rain_puddle":"puddle", "sheltered_seep":"seep",
	"insect_remains":"remains", "hunted_arthropod":"remains",
}
const SOURCE_ACCENTS: Dictionary = {
	"nectar":Color("ff80d9"), "honeydew":Color("bbff83"), "fruit":Color("ff698e"),
	"seeds":Color("ffe4a0"), "crumbs":Color("ffd28c"), "dew":Color("7dffc4"),
	"puddle":Color("8db8ff"), "seep":Color("b0a5ff"), "remains":Color("72e9ff"),
}
const IDENTITY_FADE_START: float = 120.0
const IDENTITY_FADE_END: float = 1800.0

var cloud_material := ShaderMaterial.new()
var radius: float = 20.0


func _init() -> void:
	cloud_material.shader = FLOW
	cloud_material.set_shader_parameter("flow_noise", NOISE)
	material = cloud_material
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func appearance(signal_data: Dictionary, empty: bool) -> Dictionary:
	var category: String = signal_data.get("category", "unknown")
	var confidence: float = clampf(float(signal_data.get("confidence", 0.0)), 0.0, 1.0)
	var age: float = maxf(0.0, float(signal_data.get("age", 0.0)))
	var freshness: float = 1.0 - smoothstep(IDENTITY_FADE_START, IDENTITY_FADE_END, age)
	var identity: String = ""
	if not empty:
		var source_type: String = signal_data.get("source_type", "")
		if SOURCE_FORMS.has(source_type) and SourceCatalog.accepts(source_type,category):
			identity = SOURCE_FORMS[source_type]
		elif category == "water": identity = "water"
		elif category == "threat" and signal_data.get("threat_kind", "") in ["ambush", "mixed"]:
			var profile: String = signal_data.get("predator_profile", "")
			if profile in ["wolf_spider", "beetle_hunter"]: identity = profile
	var recognition: float = smoothstep(0.35, 0.8, confidence) * freshness if not identity.is_empty() else 0.0
	var strength: float = clampf(float(signal_data.get("strength", 0.0)), 0.0, 1.0)
	var level: float = 0.0 if empty else 0.42 + 0.58 * strength
	if category == "threat": level *= lerpf(0.22, 1.0, freshness)
	return {"identity": identity if recognition > 0.0 else "", "recognition": recognition,
		"level": level, "color": Art.color_for(category),
		"impression_tint": SOURCE_ACCENTS.get(identity,Art.color_for(category)),
		"impression_power": 1.65 if SOURCE_ACCENTS.has(identity) else 2.5,
		"chemistry": ["carbohydrate", "water", "protein", "nest_site", "threat"].find(category)}


func configure(entry: Dictionary, visual_time: float, empty: bool) -> void:
	position = entry.center
	radius = entry.radius
	var style: Dictionary = appearance(entry.signal, empty)
	visible = style.level > 0.0
	cloud_material.set_shader_parameter("visual_time", visual_time)
	cloud_material.set_shader_parameter("phase", float(abs(str(entry.id).hash()) % 1000) / 71.0)
	cloud_material.set_shader_parameter("tint", style.color)
	cloud_material.set_shader_parameter("level", style.level)
	cloud_material.set_shader_parameter("chemistry", style.chemistry)
	cloud_material.set_shader_parameter("recognition", style.recognition)
	cloud_material.set_shader_parameter("impression_tint", style.impression_tint)
	cloud_material.set_shader_parameter("impression_power", style.impression_power)
	cloud_material.set_shader_parameter("impression_mask", MASKS.get(style.identity, MASKS.water))
	queue_redraw()


func _draw() -> void:
	var extent := Vector2.ONE * radius * 4.0
	draw_texture_rect(Art.CLOUD, Rect2(-extent * 0.5, extent), false)
