class_name NoteSynth
extends RefCounted

## Nota de teclado de juguete, sintetizada una sola vez en memoria.
##
## Es lo que suena cuando una actividad musical acierta una tecla: oir la
## nota es parte de memorizarla. Se genera un unico C4 con un par de
## armonicos y una caida corta, y las demas notas salen de `pitch_scale`, que
## resamplea el mismo stream. Misma doctrina que LedHumSynth: clase estatica,
## sin autoloads, semilla y valores fijos para que suene igual en cada corrida.

const MIX_RATE := 22050
const SECONDS := 0.55
## La nota base del stream. Todo lo demas es un multiplo de esta.
const BASE_PITCH := 0
const BASE_OCTAVE := 4
## Armonicos que le dan cuerpo al tono; sin ellos es un pitido de alarma.
const HARMONIC_GAINS := [1.0, 0.38, 0.16, 0.07]
## Ataque casi instantaneo y caida exponencial, como una tecla percutida.
const ATTACK_SECONDS := 0.004
const DECAY_RATE := 6.5
const MASTER_GAIN := 0.6

static var _stream: AudioStreamWAV


static func get_stream() -> AudioStreamWAV:
	if _stream == null:
		_stream = _build()
	return _stream


## Cuanto hay que acelerar el stream base para que suene una clase de altura
## en una octava. Con `octave` 4 el teclado va de C4 a B4.
static func pitch_scale_for(pitch: int, octave := BASE_OCTAVE) -> float:
	var semitones := (posmod(pitch, 12) - BASE_PITCH) + (octave - BASE_OCTAVE) * 12
	return pow(2.0, semitones / 12.0)


static func _build() -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * SECONDS)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var base_hz := MusicTheory.frequency(BASE_PITCH, BASE_OCTAVE)
	for index in sample_count:
		var t := float(index) / MIX_RATE
		var value := 0.0
		for harmonic in HARMONIC_GAINS.size():
			value += float(HARMONIC_GAINS[harmonic]) * sin(TAU * base_hz * (harmonic + 1) * t)
		var envelope := minf(t / ATTACK_SECONDS, 1.0) * exp(-DECAY_RATE * t)
		# Fundido final para que el corte del buffer no haga click.
		var tail := clampf((SECONDS - t) / 0.03, 0.0, 1.0)
		value = tanh(value * envelope * tail * MASTER_GAIN)
		data.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream
