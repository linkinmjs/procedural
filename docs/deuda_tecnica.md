# Deuda tecnica

Hallazgos de la revision de codigo del 2026-08-19, pendientes de corregir.
Casi todos viven en el codigo heredado del FPS Template de Chaff Games, que
hasta esa fecha estaba aislado en `Player_Controller/` y ahora quedo integrado
al layout del proyecto. El codigo propio (`levels/`, `targets/`, `windows/`,
`gameplay/`, `ui/`) no arrastra estos problemas.

Al corregir algo, borrar su entrada de este archivo.

## Criticos

- [ ] `scripts/weapons/weapon_state_machine.gd:56` — `range(KEY_1, KEY_4)` excluye
  `KEY_4`, asi que la tecla 4 nunca selecciona slot. Ademas arma un `Array`
  nuevo en cada tecla y usa keycodes crudos en vez del Input Map.
  **Fix:** acciones `weapon_slot_1..4` en el Input Map, leidas en
  `_unhandled_input()`.
- [ ] `scripts/weapons/weapon_state_machine.gd:61` — todas las acciones de combate
  se leen en `_input()`, asi que el arma dispara aunque la UI tenga el foco.
  **Fix:** `_unhandled_input()`, como ya hace `playable_level.gd:38`.
- [ ] `scripts/weapons/weapon_state_machine.gd:335` — `get_tree().get_root().add_child()`
  cuelga el arma soltada de la ventana raiz: sobrevive a `change_scene_to_file()`
  y se acumula. Mismo caso con los decals en `scripts/projectiles/projectile.gd:105`.
  **Fix:** `get_tree().current_scene.add_child()` o el nodo del grupo `World`.
- [ ] `scripts/weapons/weapon_state_machine.gd:356` — `_on_pick_up_detection_body_entered()`
  lee `body.weapon` y `body.TYPE` sin validar el tipo: cualquier `RigidBody3D`
  que entre al area revienta el frame.
  **Fix:** `if body is WeaponPickUp` antes de tocar propiedades.
- [ ] `scripts/gameplay/round_controller.gd:59` — ruta profunda hardcodeada
  `"Camera/LeanPivot/MainCamera/Weapons_Manager"`. Si se reordena la escena del
  jugador, el HUD deja de recibir municion y precision y solo avisa con un
  `push_warning`.
  **Fix:** `@export var weapon_manager_path: NodePath`, o que el jugador emita
  una señal al estar listo.

## Mejoras

- [ ] `scripts/weapons/weapon_state_machine.gd:247` y `:257` — `get_parent() as Camera3D`
  acopla el nodo a su posicion en el arbol. **Fix:** `@export var aim_camera: Camera3D`.
- [ ] `scripts/weapons/weapon_state_machine.gd:23` — `@onready var debug_bullet = preload(...)`:
  `@onready` sobre un `preload` no tiene sentido y la variable no se usa.
  **Fix:** borrarla. En `projectile.gd:16` si se usa, pero deberia ser `const`.
- [ ] `scripts/weapons/weapon_state_machine.gd:268` — asigna una coordenada global
  a `position` (local) antes de `add_child()`.
  **Fix:** `add_child()` primero, despues `global_position`.
- [ ] Señales en presente y con typo: `update_ammo`, `update_weapon_stack`,
  `connect_weapon_to_hud`, `add_signal_to_hud`, y `hit_successfull` (dos `l`,
  propagado a `projectile.gd` y `hud.gd`).
  **Fix:** `ammo_changed`, `weapon_stack_changed`, `weapon_equipped`, `hit_registered`.
- [ ] PascalCase en variables y funciones del codigo heredado: `Spread`,
  `Mag_Amount`, `Current_Anim`, `Target`, `Direction`, `Position` en
  weapon_state_machine; `Hit_Scan_Collision()`, `Camera_Ray_Cast()`, `Load_Decal()`
  en projectile.gd; `class_name Spray_Profile` (deberia ser `SprayProfile`).
  **Ojo:** `Hit_Successful()` es el contrato de impacto que implementan targets y
  ventanas; renombrarlo toca 5 archivos y conviene hacerlo de una sola vez.
- [ ] ~25 funciones sin tipos, casi todas en `projectile.gd`, `hud.gd` y los pickups.
- [ ] `scripts/weapons/bullet.gd:9` — `emit_signal("Hit_Successfull")` con string.
  **Fix:** `Hit_Successfull.emit()`.
- [ ] `_get_round_controller()` duplicado literal en `target_block_3d.gd:150`,
  `target_ball.gd:45` y `window_panel_3d.gd:123`, y hace
  `get_tree().get_nodes_in_group()` en cada impacto.
  **Fix:** cachearlo en `_ready()`, o un autoload delgado que exponga el controller activo.
- [ ] `scripts/levels/playable_level.gd:59` y `:78` — `get_node("/root/LevelSequence")`
  sin tipo cuando el autoload ya esta disponible como identificador global.
  **Fix:** usar `LevelSequence` directo, asi el analizador estatico valida los metodos.
- [ ] `scripts/sandbox/block_lab.gd:79` — `_input()` para TAB y las F-keys, mientras
  la escena hermana usa `_unhandled_key_input()`. **Fix:** unificar.
- [ ] `scripts/weapons/pickups/weapon_pick_up.gd:5` declara `@export var TYPE` y
  `reload_clip.gd:6` declara `const TYPE`: dos contratos distintos para lo mismo.
  **Fix:** unificar en una clase base o un enum compartido.
- [ ] `scripts/projectiles/projectile.gd:54` — mascara de colision magica
  `0b11101101` repetida en dos raycasts.
  **Fix:** `@export_flags_3d_physics`, asi se ve con los nombres de capa de `project.godot`.
- [ ] Falta cobertura de tests sobre `WeaponStateMachine`: el recoil y el spread
  estan probados, pero el cambio de arma, el drop y el pickup no. Es justo el
  codigo con mas bugs latentes.

## Progresion y logros

- [ ] **Arte propio de los logros.** `BadgeTile` reusa los seis iconos del pack
  de Windows XP (`assets/textures/ui/xp/icons/`) por el campo `icon` del
  catalogo. El libro que guio el diseño insiste en que cada logro sea una
  pieza visual propia. **Fix:** un icono por logro (o por escalera, con un
  color por tramo), en `assets/textures/ui/badges/`, y `BadgeTile.icon_for`
  leyendo de ahi.
- [ ] `resources/audio/sfx_library.tres` no tiene stream para `badge_unlocked`
  ni `level_up`: los globos salen mudos hasta que se elija un sonido.

## Limpieza pendiente

- [ ] `scenes/player/player_character.tscn` conserva material blaster *embebido*
  (meshes y animaciones como sub_resources, y nodos bajo `Weapons_Models`) que
  no dependia de los archivos blaster ya borrados. Limpiarlo requiere abrir la
  escena en el editor; hasta entonces solo abulta el `.tscn`.
- [ ] Los JSON de nivel siguen con guiones (`nivel-01.json`, `level-sequence.json`)
  porque el nombre de archivo hace de ID de contenido. Renombrarlos a snake_case
  implica tocar los `id` del catalogo.


## Audio (review de la integración de Sfx / packs / SpatialAudio3D)

Mejoras señaladas en el code review y dejadas como deuda a propósito:

- `scripts/player/player_character.gd` — `land` suena en todo aterrizaje,
  incluido cada rebote del auto-bhop y bajar un escalón. Gatear por
  `fall_speed > landing_dip_min_speed * 0.5` y/o escalar el volumen con la
  caída, como hace `apply_landing_dip()`.
- `scripts/autoloads/menu_stack.gd` — `Sfx.wire_ui()` solo cablea los botones
  que existen al abrir el menú; los agregados después (listas en diferido)
  quedan mudos. Conectar `child_entered_tree` o que esos menús llamen a
  `Sfx.wire_ui` tras poblarse, y documentarlo en `MenuScreen`.
- `scripts/audio/sfx.gd` — documentar en `wire_ui()` que usa
  `find_children(..., owned=false)` porque los menús construidos por código no
  tienen `owner`.
- `scripts/weapons/weapon_state_machine.gd` — `_play_weapon_sound()` detecta el
  plugin por `has_method("do_play")` + `call()`; si el plugin cambia, cae a
  `play()` sin reverb en silencio. Resolver `fire_audio is SpatialAudio3D` una
  vez en `_ready()` y usar llamadas tipadas.
- `addons/spatial_audio_3d/spatial_audio_3d.gd` — el parche `output_bus` cae a
  `Master` sin aviso si el bus no existe; agregar `push_warning`.
- `resources/audio/sfx_library.tres` — `land` y `footstep` comparten el mismo
  randomizer; darle a `land` uno propio (`stairs`/`stone` a pitch bajo) cuando
  se escuchen en juego.
- `tests/sfx_library_smoke_test.gd` — para `AudioStreamRandomizer`, iterar
  `get_stream(i)` y exigir no-null; hoy un slot vacío dentro del randomizer no
  se detecta.


## Rendimiento (auditoría del 2026-08-22 con la skill godot-optimization)

Nada de esto se midió con el Profiler todavía: son hallazgos por lectura de
código. Antes de atacar los puntos grandes conviene tomar una línea base en
`nivel-30` (el más cargado: 6 salas, 73 ventanas) con **Debugger > Monitors**
(`Time > Process`, `Render > Total Draw Calls`, `Physics 3D > Active Bodies`)
y repetir después de cada cambio. Lo que ya está bien y no hay que tocar:
Jolt, capas segmentadas, audio pooleado en `Sfx`, materiales cacheados en
`TextureCatalog`, luces sin sombras, environment sin post-proceso, y los
`_process` que se apagan solos (`score_hud`, `room_door_3d`, `download_window`).

### Alto impacto

- [ ] **SubViewports de ventana en `UPDATE_ALWAYS`.** Las 12 escenas de
  `scenes/windows/` y `scenes/targets/blue_screen.tscn` tienen
  `render_target_update_mode = 4`. Con ~20 ventanas vivas por capa, cada una
  redibuja su canvas y cambia de render target todos los frames aunque el
  contenido sea estático. Solo `download_window` (barra) y `popup_window`
  (contador) animan algo, y ambas ya apagan su `_process` al terminar.
  **Fix:** `WHEN_VISIBLE` (3) como mínimo; `ONCE` (1) en las estáticas,
  re-disparándolo cuando cambie el Control. Trivial.
- [ ] **Nivel entero en CSG vivo + colisión trimesh única.**
  `scripts/levels/playable_level.gd:348` mete ~50-65 `CSGBox3D` en un
  `CSGCombiner3D` con `use_collision`, evaluado entero y sincrónico en el
  primer frame tras `_ready()` (hitch al entrar y en cada restart/F3/F6). El
  resultado es una sola `ConcavePolygonShape3D` contra la que pegan todos los
  hitscan y los raycasts del audio espacial; Jolt tiene camino rápido para
  box/convex, contra trimesh paga BVH + triángulo. El árbol CSG además queda
  vivo en memoria.
  **Fix:** al terminar de construir, `_shell.bake_static_mesh()` a un
  `MeshInstance3D`, un único `StaticBody3D` con `BoxShape3D` por caja, y
  liberar el combiner. Es el cambio más grande: hacerlo último, después de
  medir.
- [ ] **`popup_window._refresh_skip()` corre cada frame por cada ad viva**
  (hasta `MAX_LIVE_ADS = 7`). `scripts/windows/popup_window.gd:84` hace
  `tr().format({...})` + asigna `Button.text` (re-shape del SubViewport) y
  `:90` recorre `get_hit_bodies()`, que aloca 2 Arrays, para un valor que
  cambia una vez por segundo.
  **Fix:** cachear `ceili(_remaining)` y tocar el texto solo cuando cambia; el
  `for body in get_hit_bodies()` sobra porque `_skip_zone` ya está cacheado
  justo arriba.
- [ ] **Impactos de bala sin pool.** `scripts/projectiles/projectile.gd:108`
  instancia `bullet_impact.tscn` (Decal + GPUParticles3D) por disparo, con
  `decal_lifetime = 8.0` s y un `SceneTreeTimer` + un Tween cada uno
  (`scripts/effects/bullet_impact.gd:38-41`). Con fuego sostenido son decenas
  de Decals simultáneos, y en Forward+ cada Decal entra al clustering por tile.
  **Fix:** pool circular de 16-24 impactos colgado del nivel, reutilizados por
  índice; liberar con `tween.finished` en vez del timer duplicado.
- [ ] **Un nodo `Projectile` + un `SceneTreeTimer` de 10 s por cada hitscan.**
  `weapon_state_machine.gd:292` instancia la escena por tiro y
  `projectile.gd:25` crea el timer de `Expirey_Time` aunque el nodo se libere
  en el mismo frame (`:91`). Quedan N timers colgados apuntando a objetos
  muertos.
  **Fix:** el hitscan no necesita nodo, escena ni timer: resolver el raycast
  en una función estática o en el propio `WeaponStateMachine`.
- [ ] **Audio espacial: ~900 raycasts/s contra el trimesh.** Hay dos
  `SpatialAudio3D` activos a la vez en gameplay (`player_character.tscn:2370` y
  la radio activa). Cada uno lanza 9 rayos + un sector de 36 a
  `audiophysics_ticks = 10`/s con `max_raycast_distance = 30`. Las radios
  pueden ser varias por nivel, pero `RadioDirector` enciende el addon solo en
  la más cercana y a las demás les apaga el `physics_process` del nodo del
  addon (que mide la sala aunque no suene), así que el costo no escala con la
  cantidad de radios.
  **Fix:** bajar `audiophysics_ticks` a 4-5 en ambos.

### Medio

- [ ] `scripts/weapons/weapon_state_machine.gd:65` — `_input()` sin early-out:
  cada `InputEventMouseMotion` (cientos por segundo) ejecuta 7
  `is_action_pressed` + 1 `is_action_released`. Lo mismo en
  `scripts/player/player_character.gd:157-164`, que consulta el singleton
  `Input` hasta 6 veces por evento (y `is_action_just_released` dentro de
  `_input` puede dispararse varias veces por frame).
  **Fix:** `if event is InputEventMouseMotion: return` al principio; usar
  `event.is_action_released(...)` sobre el evento. Se resuelve junto con el
  pase a `_unhandled_input()` ya anotado en Críticos.
- [ ] `scripts/weapons/weapon_state_machine.gd:264-289` —
  `_current_spread_degrees()` / `_spread_to_pixels()` corren cada frame con
  `get_parent()`, `get_viewport().get_visible_rect()`, `tan()`, dos
  `deg_to_rad()` y dos `body.get("string")` (lookup dinámico de propiedad).
  **Fix:** cachear la cámara (va con el `@export var aim_camera` ya anotado),
  `_pixels_per_radian` recalculado en `viewport.size_changed`, y tipar `owner`
  como `CharacterBody3D` una vez en `_ready()`.
- [ ] `scripts/player/player_character.gd:270` — `lean_collision()` corre en
  cada tick de física aunque `enable_lean == false`, con 4 accesos indexados
  por `String` al `AnimationTree` + 2 `ShapeCast3D.is_colliding()`.
  **Fix:** `if not enable_lean: return`, paths como
  `const LEFT_BLEND := &"parameters/left_collision_blend/blend_amount"`, y
  saltear cuando ambos blends ya están en 0 sin colisión.
- [x] Señales emitidas cada frame que terminan formateando strings:
  `time_changed` + formato `"%02d:%02d"` 60 veces por segundo.
  **Resuelto (rediseño HUD):** `game_hud.gd` guarda `_last_seconds` y sale
  temprano si el segundo no cambió. Pendiente el gemelo `chain_timer_changed`
  en `score_controller.gd:77` (la barra sí consume el valor continuo).
- [ ] `scripts/targets/target_ball.gd:58-93` y `:114-125` — cada bola
  destruida construye `GPUParticles3D` + `ParticleProcessMaterial` +
  `BoxMesh` + `StandardMaterial3D` desde cero, y cada bola viva duplica mesh y
  material (8-20 materiales únicos por volumen: batching imposible).
  **Fix:** escena precargada para el burst; color vía
  `set_instance_shader_parameter` o un material compartido por color.
- [ ] `scripts/windows/window_panel_3d.gd:243-260` — un `StaticBody3D` +
  `CollisionShape3D` + `BoxShape3D` por **zona clickeable** de cada ventana
  (~4 por ventana × 20 = ~80 cuerpos), todos construidos en el mismo frame al
  abrir una capa porque cada ventana hace `await process_frame` (`:89`).
  `rebuild_hit_zones()` (`:104`) los tira y rehace cuando cambia el layout.
  **Fix:** un solo `StaticBody3D` por ventana con N shapes y el `zone_id`
  resuelto por `shape_idx` en el raycast; y/o repartir la construcción de la
  capa en varios frames.
- [ ] `project.godot:147` — `jolt_physics_3d/simulation/areas_detect_static_bodies=true`.
  Todas las Area3D del juego escuchan solo al Player (`collision_mask = 2`,
  cinemático), ninguna necesita detectar estáticos, y el setting es global:
  cada Area3D paga broadphase contra el trimesh del nivel.
  **Fix:** apagarlo, salvo que algo del addon de audio lo requiera (verificar).
- [ ] `scenes/levels/playable_level.tscn` — `DirectionalLight3D` con
  `shadow_enabled` y sin `directional_shadow_max_distance`: cubre el nivel
  entero a resolución default para un nivel casi todo bajo techo.
  **Fix:** acotar la distancia o desactivar sombras en salas techadas.
- [ ] `scripts/targets/target_block_3d.gd:83-91` — `_physics_process` corre en
  todos los bloques aunque no se muevan, y `movement_direction.normalized()`
  recalcula una raíz por frame sobre un vector constante.
  **Fix:** `set_physics_process(moves_to_opposite_side)` en `_ready()` (como
  hace `room_door_3d.gd:49`) y normalizar una vez.
- [x] `game_hud.gd` — cada línea de log reconstruía el `RichTextLabel.text`
  completo con reparseo total del BBCode.
  **Resuelto (rediseño HUD):** el log ahora es un `VBoxContainer` de Labels
  individuales; cada línea entra, vive y muere sola sin tocar a las demás.
- [ ] `scripts/sandbox/block_lab.gd:333` — `use_collision = true` por caja (6
  trimeshes en 6 StaticBody) donde alcanza un `StaticBody3D` con 6
  `BoxShape3D`. Es sandbox, pero es la escena donde se miden los bloques.

### Bajo

- [ ] `scenes/player/player_character.tscn:2251-2260` — el SubViewport del
  viewmodel reserva `positional_shadow_atlas_size = 4096` y su cámara solo ve
  la capa 20, sin luces con sombras: decenas de MB de VRAM para nada. Además el
  `size = 1152×648` es fijo y no sigue la ventana.
  **Fix:** `positional_shadow_atlas_size = 0`; seguir el tamaño de la ventana.
- [ ] `scripts/weapons/weapon_state_machine.gd:132,159,332,424` —
  `update_ammo.emit([mag, reserve])` aloca un Array untyped por disparo y
  obliga a `round_controller.gd:116` a validar `size()` en runtime.
  **Fix:** `signal ammo_changed(magazine: int, reserve: int)` (va con el
  renombre ya anotado).
- [ ] `scripts/projectiles/projectile.gd:45-63` — `Camera_Ray_Cast()` devuelve
  `[collider, position, normal]` por disparo (la escopeta, uno por perdigón).
  **Fix:** devolver el `Dictionary` del `intersect_ray` directo.
- [ ] `scripts/ui/menus/taskbar.gd:150` — el reloj aloca 2 Strings por frame
  (`get_time_string_from_system().substr`) para un valor que cambia por
  minuto. **Fix:** acumulador de delta y chequear cada 1 s.
- [ ] `scripts/windows/popup_window.gd:137` — `load(scene_file_path)` en
  runtime cada vez que un ad clona otro; la primera vez puede ser un hitch de
  disco en pleno combate. **Fix:** `@export var clone_scene: PackedScene` o
  `static var` cacheada.
- [ ] `scripts/targets/target_spawn_volume_3d.gd:177-185` — lambda +
  `positions.all()` por intento, hasta `target_count * 30` Callables en un
  solo frame al abrir una capa. **Fix:** `for` explícito con `break`.
- [ ] `scripts/ui/menus/level_results.gd:58` — `_process` sigue corriendo
  después de revelar todas las filas; falta `set_process(false)` en `:130`.
- [ ] Tweens creados por evento repetitivo: `player_character.gd:400` (uno por
  salto vía `lean(CENTRE)`), `weapon_state_machine.gd:146` (uno por suelta de
  gatillo), `window_panel_3d.gd:327,345` (dos por impacto en ventana).
  **Fix:** reutilizar un tween cacheado o `lerp` manual donde sea continuo.
- [x] `scripts/player/hud.gd` — `current_weapon_stack.text += ...` en bucle.
  **Resuelto (rediseño HUD):** el `debug_hud` completo se eliminó junto con sus
  conexiones y handlers; la munición real ya viajaba por `RoundController`.
- [ ] `String` donde va `StringName` en hot paths: `is_in_group("Target")` en
  `projectile.gd` y `weapon_state_machine.gd:350`, `const TARGET_GROUP :=
  "Target"` en `window_panel_3d.gd:30`, `Input.get_vector("left",...)` /
  `is_action_pressed("walk"|"crouch"|"ui_accept")` en `player_character.gd`
  (5-7 por tick), `match Projectile_Type` sobre `String` en `projectile.gd:34`
  (debería ser enum), `Sfx.play(event: String)` con claves `String` en
  `sfx_library.gd:38` (suena decenas de veces por segundo).
  **Fix:** prefijar con `&`, enum para el tipo de proyectil, `StringName` en la
  firma y las claves de `Sfx`.
- [ ] Firmas de input mal tipadas: `weapon_state_machine.gd:56`,
  `playable_level.gd:81`, `dungeon_test.gd:21`, `weapon_test.gd:16` declaran
  `event: InputEvent` y acceden a `keycode`/`pressed`/`echo` (lookup dinámico
  por tecla). **Fix:** `event: InputEventKey`.
- [ ] `resources/environment/world_environment.tres:14,18` — `sdfgi_use_occlusion`
  y `volumetric_fog_emission` huérfanos (ambos sistemas apagados, no cuestan
  nada hoy). Trampa: activar SDFGI sobre CSG sería carísimo. Además este
  `.tres` no lo usa el nivel jugable, que tiene su Environment inline.
  **Fix:** borrar las propiedades o el archivo.
