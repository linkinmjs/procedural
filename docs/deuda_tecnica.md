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

## Pantallas que faltan

- [ ] **Selector de niveles.** El boton `SELECCIONAR NIVEL` del menu principal y
  la entrada `Seleccionar nivel` del menu de inicio estan deshabilitados a
  proposito, y el icono `niveles` del escritorio solo hace parpadear la ventana.
  Los datos ya existen: `LevelSequence` da el catalogo y `ScoreRecords` el
  puntaje, el rango y los intentos de cada nivel.
  **Fix:** un `MenuScreen` mas, con la piel que le pasen como hace
  `OptionsMenu`, listando los niveles con su record. Al elegir uno,
  `LevelSequence` tiene que poder saltar a un indice: hoy solo sabe avanzar,
  retroceder y volver al primero.
  El diseno esta en `docs/gdd_atractivo_y_progresion_ANEXO_menus.md`, §3.

## Limpieza pendiente

- [ ] `scenes/player/player_character.tscn` conserva material blaster *embebido*
  (meshes y animaciones como sub_resources, y nodos bajo `Weapons_Models`) que
  no dependia de los archivos blaster ya borrados. Limpiarlo requiere abrir la
  escena en el editor; hasta entonces solo abulta el `.tscn`.
- [ ] Los JSON de nivel siguen con guiones (`nivel-1.json`, `level-sequence.json`)
  porque el nombre de archivo hace de ID de contenido. Renombrarlos a snake_case
  implica tocar los `id` del catalogo.
