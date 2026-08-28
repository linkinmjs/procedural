class_name MusicTheory
extends RefCounted

## Teoria musical minima para las actividades: notas en cifrado americano,
## escalas, acordes e intervalos.
##
## Todo se calcula sobre clases de altura (0 = C ... 11 = B), asi que las
## tablas son listas de semitonos y agregar una escala o un acorde es una
## entrada mas. Las notas se nombran con sostenidos; las teclas negras se
## muestran ademas con su enarmonico (C#/Db) para que nadie tenga que
## traducir mentalmente.
##
## Clase estatica, como Sfx y LedHumSynth, para que los smoke tests la usen
## sin autoloads.

const NOTE_NAMES: PackedStringArray = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NATURAL_NAMES: PackedStringArray = ["C", "D", "E", "F", "G", "A", "B"]
## Nombre con bemol de cada tecla negra, para mostrar los dos.
const FLAT_NAMES := {"C#": "Db", "D#": "Eb", "F#": "Gb", "G#": "Ab", "A#": "Bb"}

## Escalas por grados en semitonos desde la tonica. Las claves son las que
## declara `mode` en level_designs/music-activities.json.
const SCALES := {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"harmonic-minor": [0, 2, 3, 5, 7, 8, 11],
	"major-pentatonic": [0, 2, 4, 7, 9],
	"minor-pentatonic": [0, 3, 5, 7, 10],
	"chromatic": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
}

## Acordes por semitonos desde la fundamental. Las claves son las de
## `qualities` en las actividades.
const CHORDS := {
	"major": [0, 4, 7],
	"minor": [0, 3, 7],
	"diminished": [0, 3, 6],
	"augmented": [0, 4, 8],
	"dominant-7": [0, 4, 7, 10],
	"major-7": [0, 4, 7, 11],
	"minor-7": [0, 3, 7, 10],
}

## Intervalos por semitonos. Las claves son las de `intervals` en las
## actividades: minuscula para menor, mayuscula para mayor, P para justo.
const INTERVALS := {
	"m2": 1, "M2": 2, "m3": 3, "M3": 4, "P4": 5, "TT": 6,
	"P5": 7, "m6": 8, "M6": 9, "m7": 10, "M7": 11, "P8": 12,
}

## Frecuencia de A4, la referencia de afinacion.
const A4_HZ := 440.0


## Clase de altura de un nombre de nota: acepta sostenidos, bemoles y
## minusculas ("C#", "Db", "bb"). Devuelve -1 si no es una nota.
static func pitch_class(note_name: String) -> int:
	var cleaned := note_name.strip_edges()
	if cleaned.is_empty():
		return -1
	var letter := cleaned.substr(0, 1).to_upper()
	var index := NATURAL_NAMES.find(letter)
	if index < 0:
		return -1
	var pitch := SCALES["major"][index] as int
	for accidental in cleaned.substr(1):
		match accidental:
			"#":
				pitch += 1
			"b", "B":
				pitch -= 1
			_:
				return -1
	return posmod(pitch, 12)


## Nombre con sostenido de una clase de altura.
static func note_name(pitch: int) -> String:
	return NOTE_NAMES[posmod(pitch, 12)]


## Nombre para mostrar: las teclas negras llevan los dos nombres.
static func display_name(pitch: int) -> String:
	var sharp := note_name(pitch)
	if FLAT_NAMES.has(sharp):
		return "%s/%s" % [sharp, FLAT_NAMES[sharp]]
	return sharp


static func is_natural(pitch: int) -> bool:
	return not FLAT_NAMES.has(note_name(pitch))


## Grados de una escala desde la tonica, como clases de altura, sin repetir la
## tonica arriba. Un modo desconocido cae en la escala mayor.
static func scale(root: int, mode: String) -> PackedInt32Array:
	return _transpose(root, SCALES.get(mode, SCALES["major"]))


## Notas de un acorde desde la fundamental. Una calidad desconocida cae en
## el acorde mayor.
static func chord(root: int, quality: String) -> PackedInt32Array:
	return _transpose(root, CHORDS.get(quality, CHORDS["major"]))


## Nota que queda a un intervalo por encima de la raiz. Un intervalo
## desconocido devuelve la raiz.
static func interval(root: int, interval_name: String) -> int:
	return posmod(root + int(INTERVALS.get(interval_name, 0)), 12)


## Frecuencia en Hz de una clase de altura en una octava dada (A4 = 440).
static func frequency(pitch: int, octave := 4) -> float:
	var semitones_from_a4 := (posmod(pitch, 12) - 9) + (octave - 4) * 12
	return A4_HZ * pow(2.0, semitones_from_a4 / 12.0)


static func _transpose(root: int, steps: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for step in steps:
		result.append(posmod(root + int(step), 12))
	return result
