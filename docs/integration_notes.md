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

## Blancos flotantes

El sistema inicial esta dividido en tres responsabilidades:

- `TargetBall` representa una pelota estatica y solo conoce cómo destruirse al recibir un impacto.
- `TargetSpawnVolume3D` distribuye una cantidad configurable de pelotas dentro de un volumen, respeta una separación minima y dibuja el bloque de debug.
- `EntryAwareTargetEncounter3D` decide qué volumen activar. En modo `OPPOSITE_ENTRY_WALL` elige el volumen mas lejano al punto por el que ingreso el jugador; en modo `ALL_VOLUMES` activa todos, que es la configuracion prevista para los dos laterales de un pasillo.

Los prefabs futuros de habitación podrán colocar cuatro volúmenes junto a sus paredes y un trigger central. Los pasillos colocarán solamente los dos laterales. En esta iteración el polígono usa un único volumen con spawn inmediato; no hay movimiento, respawn, puntaje ni reglas de dificultad.

El dungeon de prueba ya incorpora `DungeonTargetPopulator3D`: después de generar, añade encuentros a todas las habitaciones salvo la sala inicial. Una habitación activa el volumen más lejano al punto de entrada; un corredor activa los dos volúmenes perpendiculares al eje por el que entró el jugador. Cada encuentro es de una sola activación y las pelotas destruidas no reaparecen.

Se revisó FlickSense como referencia externa. Su `TargetManager` descuenta el tamaño del blanco al muestrear el volumen, consulta solapamientos físicos y reutiliza blancos visibles; también separa VFX mediante un pool. Adoptamos únicamente el concepto de margen interior configurable (`edge_padding`) porque evita que una esfera sobresalga del bloque. Pooling y consultas físicas se evaluarán cuando existan respawn continuo, obstáculos internos o movimiento. No se incorporó código ni assets de FlickSense porque el repositorio no declara una licencia.

## HUD de ronda

`RoundController` mantiene el estado de la ronda sin depender de la interfaz: vida, tiempo restante, ataques, impactos y feed de eventos. `GameHUD` escucha sus señales y presenta tres paneles inferiores: logs, precisión y vitales. El mismo prefab `round_hud.tscn` se usa en el dungeon y en el polígono de armas.

La precisión se calcula como impactos confirmados divididos por ataques realmente ejecutados. El `Weapons_Manager` expone `attack_fired` y `target_hit`, evitando que el HUD consulte input, munición o proyectiles directamente.

Para el modo de entrenamiento, `enable_weapon_spread` está desactivado en el player: el rayo sale siempre por el centro de `MainCamera` y coincide con la mira. El template conserva el soporte de spray como opción exportada para armas o modos futuros.

`TargetBall` admite `lifetime_seconds` y `damage_on_leave`. La variante `blue_penalty_ball.tscn` dura 8 segundos y resta 15 HP al desaparecer; ambos valores son configurables. El volumen de spawn decide cuántas variantes de penalización incluye mediante `penalty_target_count`.

El diseño toma como referencia conceptual la composición del repositorio `hi-godot/cyberpunk-hud-demo`: paneles oscuros, acentos cian y feed reactivo por señales. No se copiaron scripts ni recursos porque el repositorio no publica una licencia visible.

## Riesgos observados

- El generador puede fallar para algunas combinaciones de tamaño y rooms; por eso la escena permite varios reintentos y muestra estado.
- La generacion actual es sincrona. Para mapas grandes puede probarse `generate_threaded`, pero todo acceso al arbol debe respetar las restricciones de threads indicadas por el addon.
- Los samples sirven para validar conectividad, pero su identidad visual y distribucion no deberian convertirse accidentalmente en diseño final.
