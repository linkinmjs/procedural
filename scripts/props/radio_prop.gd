class_name RadioProp
extends Node3D

## Radio con musica en loop, posicionada en el mundo.
##
## Experimental: existe para escuchar como se comporta el audio 3D con una
## fuente continua. La musica sale por un SpatialAudio3D (reverb y oclusion
## medidas desde la sala) enrutado al bus Music, asi el volumen de musica de
## las opciones la sigue controlando aunque suene posicionada.

@onready var speaker: AudioStreamPlayer3D = $Speaker


func _ready() -> void:
	# El plugin arranca solo con autoplay; si el nodo es un AudioStreamPlayer3D
	# comun (sin el addon), se arranca aca.
	if not speaker.has_method("do_play") and not speaker.playing:
		speaker.play()
