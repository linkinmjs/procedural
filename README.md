# Procedural Map prototype

Prototipo para Godot 4.7 que integra SimpleDungeons y el FPS Template de Chaff Games.

## Escenas

- `scenes/dungeon_test.tscn`: genera un dungeon recorrible y coloca al jugador en la sala de entrada.
- `scenes/weapon_test.tscn`: poligono con pickups y blancos reutilizables.
- `scenes/targets/target_spawn_volume_3d.tscn`: volumen configurable que distribuye pelotas estaticas y muestra sus limites de debug.
- `scenes/ui/round_hud.tscn`: HUD reutilizable de vida, tiempo, precision y eventos de ronda.

## Controles

- WASD: mover; Espacio: saltar; Shift: correr; C: agacharse; Q/E: inclinarse.
- Mouse izquierdo: disparar; R: recargar; F: melee; G: soltar arma.
- Rueda o teclas 1-4: cambiar arma.
- F1: dungeon; F2: armas; F3: reiniciar escena; F5: regenerar dungeon.

Las pelotas del bloque celeste se destruyen con un impacto. Las variantes azules de penalizacion desaparecen a los 8 segundos y restan 15 HP si no son destruidas. En esta primera prueba no se mueven ni reaparecen.

## Documentacion

- [`docs/guia_simple_dungeons.md`](docs/guia_simple_dungeons.md): funcionamiento del generador, habitaciones, puertas y alternativas para niveles procedurales, predefinidos o mixtos.
- [`docs/integration_notes.md`](docs/integration_notes.md): estado tecnico de la integracion y proximos pasos.

Prueba automatizada del sistema:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/target_system_smoke_test.gd`

## Direccion de desarrollo

Las habitaciones de `addons/SimpleDungeons/sample_dungeons` son material de prototipo. Para convertir el generador en una base del juego conviene crear un kit propio de `DungeonRoom3D` con conectores coherentes y usar `dungeon_done_generating` para poblar enemigos, objetivos, loot y encuentros despues de cerrar el layout.
