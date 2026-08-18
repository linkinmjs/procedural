# Integracion y oportunidades

## Lo que ya queda integrado

`DungeonGenerator3D` recibe un conjunto de escenas `DungeonRoom3D`, una escena especial de corredor 1x1x1, un volumen en voxeles y una semilla. Cuando termina emite `done_generating`; recien entonces se instancia al jugador en el nodo del grupo `player_spawn_point`. Esto evita que el controlador caiga mientras el layout todavia se esta armando.

El dungeon de prueba es deliberadamente horizontal (`8x1x8`) para validar primero el loop FPS. Usa entrada, living, puente y corredor del kit de texturas de desarrollo. F5 genera otra semilla. El jugador entra con cinco armas; el poligono separado obliga a recoger cuatro de ellas para probar tambien el flujo de pickups.

Cada `DungeonRoom3D` recibe una instancia de `room_light.tscn` despues de la generacion. El rango se calcula con el tamaño real del prefab y las luces no proyectan sombras, para que un mapa con muchos corredores no multiplique el costo de shadow maps. En habitaciones finales conviene agregar sockets de luz diseñados a mano y dejar este sistema automatico como fallback.

El template dibujaba el arma mediante un `SubViewport` transparente. En Godot 4.7 ese compuesto dejaba el modelo activo como una silueta negra, aunque los mismos materiales funcionaban en los pickups. El viewmodel ahora se renderiza directamente con la camara principal, conserva su capa 20 exclusiva y tiene una luz de relleno que solo afecta esa capa. No se modificaron las texturas ni se convirtieron los materiales a `unshaded`.

## Como aprovechar SimpleDungeons

La unidad de autoria conveniente es la habitacion, no el mapa entero. Cada prefab puede encapsular:

- geometria, colision y puntos de puerta;
- marcadores semanticos (`enemy_spawn`, `loot_spawn`, `objective_spawn`, `cover_point`);
- reglas de frecuencia mediante `min_count` y `max_count`;
- logica que se activa con `dungeon_done_generating`, cuando ya se sabe que puertas quedaron conectadas.

Eso permite separar dos capas: SimpleDungeons resuelve topologia y conexiones; un `DungeonPopulator` propio interpreta los marcadores y arma encuentros. La semilla debe guardarse junto con el estado de partida para reproducir bugs y runs.

## Proximo corte recomendado

1. Crear un kit propio de 6 a 10 habitaciones modulares con una metrica unica de 10 m por voxel.
2. Reemplazar los CSG de muestra por mallas y colisiones preparadas; los CSG son utiles para prototipos, no para el costo final del nivel.
3. Incorporar salas con rol (inicio, combate, recompensa, objetivo y salida) y seleccionar/poblar contenido despues de `done_generating`.
4. Agregar escaleras solo cuando el kit horizontal sea estable; SimpleDungeons exige un `DungeonRoom3D` de escalera con puertas en al menos dos alturas.
5. Envolver el FPS template detras de una API propia de inventario/daño antes de extender armas. El template usa nombres de animacion y el metodo heredado `Hit_Successful`, que conviene adaptar para no acoplar enemigos futuros a detalles de terceros.

## Riesgos observados

- El generador puede fallar para algunas combinaciones de tamaño y rooms; por eso la escena permite varios reintentos y muestra estado.
- La generacion actual es sincrona. Para mapas grandes puede probarse `generate_threaded`, pero todo acceso al arbol debe respetar las restricciones de threads indicadas por el addon.
- Los samples sirven para validar conectividad, pero su identidad visual y distribucion no deberian convertirse accidentalmente en diseño final.
