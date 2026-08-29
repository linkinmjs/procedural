class_name SkyCatalog
extends RefCounted

## Cielos disponibles para los niveles.
##
## Cada entrada arma el material del shader de cielo y ademas coloca la luz
## direccional: el shader deduce la hora del dia de LIGHT0_DIRECTION, asi que
## mover el sol es lo que cambia el cielo de dia a noche y lo que hace que la
## iluminacion de la escena acompanie a lo que se ve arriba.
##
## Los identificadores tienen que coincidir con los que ofrece la herramienta en
## tools/level-editor/level-format.js.

const SKY_SHADER := preload("res://assets/skies/sky.gdshader")
const CLOUD_TEXTURES := [
	preload("res://assets/skies/clouds/clouds_01.tres"),
	preload("res://assets/skies/clouds/clouds_02.tres"),
	preload("res://assets/skies/clouds/clouds_03.tres"),
	preload("res://assets/skies/clouds/clouds_04.tres"),
]

## El que se usa cuando el nivel no declara ninguno.
const DEFAULT_ID := "clear-day"

const SKIES := {
	"clear-day": {
		"label": "Dia despejado",
		"sky_day": Color(0.06, 0.35, 0.75),
		"horizon_day": Color(0.72, 0.84, 0.9),
		"sky_sunset": Color(0.15, 0.2, 0.4),
		"horizon_sunset": Color(0.9, 0.45, 0.15),
		"sky_night": Color(0.05, 0.1, 0.15),
		"horizon_night": Color(0.1, 0.15, 0.2),
		"cloud_color": Color(0.97, 0.98, 1.0),
		"cloud_density": 0.55,
		"cloud_tiling": Vector2(1.0, 1.0),
		"wind_speed": Vector2(0.5, 0.3),
		"light_rotation": Vector3(-55.0, -35.0, 0.0),
		"light_color": Color(1.0, 0.96, 0.9),
		"light_energy": 1.1,
		"ambient_color": Color(0.55, 0.68, 0.82),
		"ambient_energy": 0.7,
	},
	"overcast": {
		"label": "Nublado",
		"sky_day": Color(0.32, 0.38, 0.45),
		"horizon_day": Color(0.6, 0.64, 0.68),
		"sky_sunset": Color(0.22, 0.24, 0.3),
		"horizon_sunset": Color(0.55, 0.45, 0.42),
		"sky_night": Color(0.05, 0.07, 0.1),
		"horizon_night": Color(0.12, 0.14, 0.18),
		"cloud_color": Color(0.62, 0.66, 0.72),
		"cloud_density": 1.9,
		"cloud_tiling": Vector2(0.7, 0.7),
		"wind_speed": Vector2(0.9, 0.6),
		"light_rotation": Vector3(-50.0, 20.0, 0.0),
		"light_color": Color(0.85, 0.88, 0.95),
		"light_energy": 0.5,
		"ambient_color": Color(0.55, 0.6, 0.68),
		"ambient_energy": 1.0,
	},
	"sunset": {
		"label": "Atardecer",
		"sky_day": Color(0.1, 0.32, 0.62),
		"horizon_day": Color(0.8, 0.7, 0.6),
		"sky_sunset": Color(0.22, 0.16, 0.38),
		"horizon_sunset": Color(0.98, 0.42, 0.12),
		"sky_night": Color(0.05, 0.08, 0.16),
		"horizon_night": Color(0.12, 0.1, 0.18),
		"cloud_color": Color(0.95, 0.6, 0.45),
		"cloud_density": 0.9,
		"cloud_tiling": Vector2(1.2, 1.2),
		"wind_speed": Vector2(0.35, 0.2),
		"light_rotation": Vector3(-7.0, 115.0, 0.0),
		"light_color": Color(1.0, 0.68, 0.42),
		"light_energy": 1.0,
		"ambient_color": Color(0.6, 0.45, 0.45),
		"ambient_energy": 0.7,
	},
	"night": {
		"label": "Noche",
		"sky_day": Color(0.06, 0.35, 0.75),
		"horizon_day": Color(0.5, 0.6, 0.7),
		"sky_sunset": Color(0.12, 0.14, 0.3),
		"horizon_sunset": Color(0.35, 0.22, 0.3),
		"sky_night": Color(0.03, 0.05, 0.11),
		"horizon_night": Color(0.06, 0.09, 0.16),
		"cloud_color": Color(0.3, 0.34, 0.45),
		"cloud_density": 0.45,
		"cloud_tiling": Vector2(1.0, 1.0),
		"wind_speed": Vector2(0.25, 0.15),
		# El sol queda bajo el horizonte: el shader pinta la noche y dibuja la
		# luna del lado opuesto.
		"light_rotation": Vector3(24.0, -40.0, 0.0),
		"light_color": Color(0.55, 0.66, 0.95),
		"light_energy": 0.35,
		"ambient_color": Color(0.3, 0.4, 0.6),
		"ambient_energy": 0.5,
	},
}


static func get_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in SKIES:
		ids.append(str(id))
	return ids


static func has_sky(id: String) -> bool:
	return SKIES.has(id)


## Devuelve la configuracion pedida, o la del cielo por defecto si el nivel no
## declara ninguno o nombra uno que ya no existe.
static func resolve(id: String) -> Dictionary:
	return SKIES.get(id, SKIES[DEFAULT_ID]) as Dictionary


static func build_material(id: String) -> ShaderMaterial:
	var preset := resolve(id)
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("sky_day", preset.sky_day)
	material.set_shader_parameter("horizon_day", preset.horizon_day)
	material.set_shader_parameter("sky_sunset", preset.sky_sunset)
	material.set_shader_parameter("horizon_sunset", preset.horizon_sunset)
	material.set_shader_parameter("sky_night", preset.sky_night)
	material.set_shader_parameter("horizon_night", preset.horizon_night)
	material.set_shader_parameter("use_directional_light", true)
	material.set_shader_parameter("cloud_color", preset.cloud_color)
	material.set_shader_parameter("cloud_density", preset.cloud_density)
	material.set_shader_parameter("cloud_tiling", preset.cloud_tiling)
	material.set_shader_parameter("wind_speed", preset.wind_speed)
	material.set_shader_parameter("cloud_tex_01", CLOUD_TEXTURES[0])
	material.set_shader_parameter("cloud_tex_02", CLOUD_TEXTURES[1])
	material.set_shader_parameter("night_noise_01", CLOUD_TEXTURES[2])
	material.set_shader_parameter("night_noise_02", CLOUD_TEXTURES[3])
	return material


## Aplica el cielo al entorno y mueve la luz direccional para que coincida.
static func apply(id: String, world_environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var preset := resolve(id)
	if world_environment != null and world_environment.environment != null:
		var environment := world_environment.environment
		var sky := Sky.new()
		sky.sky_material = build_material(id)
		environment.sky = sky
		environment.background_mode = Environment.BG_SKY
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = preset.ambient_color
		environment.ambient_light_energy = preset.ambient_energy
	if sun != null:
		sun.rotation_degrees = preset.light_rotation
		sun.light_color = preset.light_color
		sun.light_energy = preset.light_energy
		Quality.apply_to_sun(sun)
