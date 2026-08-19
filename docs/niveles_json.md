# Niveles JSON jugables

La escena inicial `scenes/levels/playable_level.tscn` construye el nivel definido en `level_designs/levels/nivel-1.json` cada vez que comienza la partida.

## Flujo de trabajo

1. Diseñar o importar un nivel en `tools/level-editor/index.html`.
2. Descargar el JSON dentro de `level_designs/levels/`.
3. Agregar su ID y ruta a `level_designs/level-sequence.json` en el orden deseado.
4. Ejecutar el proyecto. No es necesario convertir manualmente el JSON en una escena `.tscn`.

Los niveles que forman parte de la campaña se ordenan en `level_designs/level-sequence.json`. `LevelSequence` conserva el índice actual al recargar la escena y permite navegar manualmente con F7 y F8.

## Qué se construye

- Una sala física por cada entrada de `rooms`, usando sus posiciones y dimensiones en metros.
- Puertas centrales sobre las paredes declaradas por `entry` y `connections`.
- Pasillos transitables entre cada par de salas conectado.
- Iluminación independiente para salas y pasillos.
- Un trigger por sala que despliega sus bloques al ingresar.
- Bloques izquierdo, frontal y derecho relativos a la pared de entrada, con color, velocidad y oleadas propias.
- El jugador dentro de la sala llamada `Entrada`, orientado hacia la primera conexión.
- El armamento del prototipo, el HUD y el tiempo de ronda de `timeLimitSeconds`.

## Responsabilidades

- `LevelDefinitionLoader` valida la versión, las referencias y los valores del JSON.
- `PlayableLevel` construye geometría, conexiones, iluminación, jugador y ronda.
- `ConfiguredRoomEncounter3D` interpreta los bloques de cada sala y los activa una sola vez.

La sala llamada `Salida` funciona actualmente como destino espacial. La futura condición de victoria combinará dos estados: todos los bloques del nivel destruidos y el jugador dentro de la sala final. Hasta implementar formalmente esa coordinación, F7 y F8 permiten probar la secuencia sin validar condiciones ni avanzar automáticamente.

## Configuración de bloques

Cada bloque usa el siguiente contrato desde `schemaVersion: 3`:

- `movement`: `static` u `opposite`.
- `movementSpeed`: velocidad en metros por segundo, entre 0.05 y 5.
- `color`: color hexadecimal aplicado al panel y a sus esferas normales.
- `waves`: lista ordenada de cantidades. Por ejemplo, `[5, 10]` genera cinco objetivos y, al destruir el último, genera diez más.

El bloque se elimina solamente al completar su última oleada. Una lista vacía conserva el comportamiento de bloque sin objetivos, con el control rojo de cierre.
