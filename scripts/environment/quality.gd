class_name Quality
extends RefCounted

## Perfil de calidad grafica, decidido por plataforma. Lo especifico de la
## build Web vive aca y en ningun otro lado: sin hilos y sobre WebGL2 no
## alcanza para sombras direccionales ni para renderizar el 3D a la resolucion
## completa de una pantalla HiDPI, asi que la Web arranca en el perfil medio y
## el escritorio en el alto. Es una clase estatica, como Sfx, para que los
## smoke tests la usen sin autoloads.

enum Profile { HIGH, MEDIUM }

## Distancia hasta la que el sol proyecta sombra. Los niveles son salas de 8 a
## 26 m casi siempre techadas: mas lejos que esto no hay nada que sombrear.
const DIRECTIONAL_SHADOW_DISTANCE := 40.0
## Escala del render 3D en el perfil medio. Con canvas_resize_policy siguiendo
## el devicePixelRatio, en una pantalla HiDPI es el ahorro mas grande.
const MEDIUM_RENDER_SCALE := 0.8

## Perfil forzado (por las pruebas o, mas adelante, por las opciones). -1 deja
## decidir a la plataforma.
static var override_profile := -1


static func profile() -> Profile:
	if override_profile >= 0:
		return override_profile as Profile
	return Profile.MEDIUM if OS.has_feature("web") else Profile.HIGH


## El sol proyecta sombra solo en el perfil alto.
static func shadows_enabled() -> bool:
	return profile() == Profile.HIGH


## La acustica de sala del addon spatial_audio_3d (veinte reproductores y
## veinte buses con delay, reverb y filtro por fuente) corre solo en el perfil
## alto. En Web, sin hilos, el audio se mezcla en el hilo principal y esos
## efectos lo dejan sin buffer: se oye como crepitacion y saturacion.
static func spatial_audio_enabled() -> bool:
	return profile() == Profile.HIGH


## Factor de resolucion del render 3D respecto de la ventana.
static func render_scale() -> float:
	return 1.0 if profile() == Profile.HIGH else MEDIUM_RENDER_SCALE


## Aplica el perfil a la luz direccional de un nivel.
static func apply_to_sun(sun: DirectionalLight3D) -> void:
	if sun == null:
		return
	sun.shadow_enabled = shadows_enabled()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = DIRECTIONAL_SHADOW_DISTANCE


## Aplica el perfil al viewport que dibuja el nivel.
static func apply_to_viewport(viewport: Viewport) -> void:
	if viewport == null:
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale()
