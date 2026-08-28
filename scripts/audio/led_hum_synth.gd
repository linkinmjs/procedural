class_name LedHumSynth
extends RefCounted

## Zumbido de pantalla LED vieja, sintetizado una sola vez en memoria.
##
## Es el sonido propio de los bloques: un hum grave de red electrica con su
## segundo armonico, un silbido agudo tipo flyback apenas presente y un hilo de
## ruido. El loop dura un segundo exacto y todas las frecuencias son multiplos
## enteros de 1 Hz, asi que cierra sin click. Los bloques comparten este mismo
## stream y se diferencian por pitch y por la modulacion de cercania.
##
## Clase estatica, como Sfx, para que los smoke tests puedan usarla sin
## autoloads. Los valores de tuning estan en docs/configuraciones.md.

const MIX_RATE := 24000
const LOOP_SECONDS := 1.0
## Hum de red: 60 Hz y su octava.
const BASE_HZ := 60.0
const BASE_GAIN := 0.55
const HARMONIC_GAIN := 0.18
## Silbido de transformador: agudo y muy bajo, es lo que inquieta de cerca.
const WHINE_HZ := 9900.0
const WHINE_GAIN := 0.06
const NOISE_GAIN := 0.04
## Semilla fija: el stream es identico en cada corrida (y en los tests).
const NOISE_SEED := 0x1ED

## Gruñido grave que solo se oye pegado al bloque: un sub de 42 Hz con su
## octava, latiendo tres veces por segundo. Tambien entero en Hz, cierra limpio.
const GROWL_HZ := 42.0
const GROWL_GAIN := 0.7
const GROWL_OCTAVE_GAIN := 0.22
const THROB_HZ := 3.0
const THROB_DEPTH := 0.4

static var _stream: AudioStreamWAV
static var _growl_stream: AudioStreamWAV


static func get_stream() -> AudioStreamWAV:
	if _stream == null:
		_stream = _build()
	return _stream


static func get_growl_stream() -> AudioStreamWAV:
	if _growl_stream == null:
		_growl_stream = _build_growl()
	return _growl_stream


static func _build_growl() -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in sample_count:
		var t := float(index) / MIX_RATE
		var throb := 1.0 - THROB_DEPTH * (0.5 + 0.5 * sin(TAU * THROB_HZ * t))
		var value := GROWL_GAIN * sin(TAU * GROWL_HZ * t)
		value += GROWL_OCTAVE_GAIN * sin(TAU * GROWL_HZ * 2.0 * t)
		value = tanh(value * throb)
		data.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return _wrap(data, sample_count)


static func _wrap(data: PackedByteArray, sample_count: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = data
	return stream


static func _build() -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	for index in sample_count:
		var t := float(index) / MIX_RATE
		var value := BASE_GAIN * sin(TAU * BASE_HZ * t)
		value += HARMONIC_GAIN * sin(TAU * BASE_HZ * 2.0 * t)
		value += WHINE_GAIN * sin(TAU * WHINE_HZ * t)
		value += NOISE_GAIN * (rng.randf() * 2.0 - 1.0)
		# Recorte suave: la suma de ganancias queda bajo 1, esto solo redondea
		# los picos del ruido.
		value = tanh(value)
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, sample)
	return _wrap(data, sample_count)
