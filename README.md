# Procedural Map prototype

Prototipo para Godot 4.7 que integra SimpleDungeons y el FPS Template de Chaff Games.

## Escenas

- `scenes/dungeon_test.tscn`: genera un dungeon recorrible y coloca al jugador en la sala de entrada.
- `scenes/weapon_test.tscn`: poligono con pickups y blancos reutilizables.

## Controles

- WASD: mover; Espacio: saltar; Shift: correr; C: agacharse; Q/E: inclinarse.
- Mouse izquierdo: disparar; R: recargar; F: melee; G: soltar arma.
- Rueda o teclas 1-4: cambiar arma.
- F1: dungeon; F2: armas; F3: reiniciar escena; F5: regenerar dungeon.

## Direccion de desarrollo

Las habitaciones de `addons/SimpleDungeons/sample_dungeons` son material de prototipo. Para convertir el generador en una base del juego conviene crear un kit propio de `DungeonRoom3D` con conectores coherentes y usar `dungeon_done_generating` para poblar enemigos, objetivos, loot y encuentros despues de cerrar el layout.
