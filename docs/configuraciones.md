# Índice de configuraciones ajustables

Parámetros que se tocan a mano para afinar cómo se siente y se juega el
juego. Cada fila dice **dónde** vive el valor, cuál es hoy y qué cambia. Los
`@export` se editan en el Inspector (o en el `.tscn`/`.tres`); las `const` y
los números inline se editan en el script.

Convención de "dónde": `archivo → nodo/sección/función`.

## Audio

| Parámetro | Dónde | Valor | Qué modifica |
|---|---|---|---|
| `reverb_volume_db` | `scenes/player/player_character.tscn` → nodo `FireAudio` | -9 | Volumen de la reverb de sala del disparo (más negativo = más seca). |
| `roomsize_multiplicator` | ídem | 4.0 | Largo de la cola de reverb respecto del tamaño medido de la sala. |
| `reverb_fadeintime` / `reverb_fadeouttime` | ídem | 0.25 / 0.6 s | Qué tan rápido aparece y desaparece la reverb al cambiar de sala. |
| `occlusion_lp_cutoff` | ídem | 600 Hz | Cuánto se apaga el disparo con una pared entre la fuente y el oído. |
| `bass_proximity` | ídem | 4 m | Distancia a una pared desde la que el disparo gana graves. |
| `max_raycast_distance` | ídem | 30 m | Alcance de los rayos que buscan paredes para la reverb. |
| `output_bus` | ídem | `SFX` | Bus al que van los buses generados por el plugin (parche local). |
| `random_pitch` / `random_volume_offset_db` | `resources/audio/glock_shoot.tres` | 1.05 / 1.0 dB | Variación entre los cuatro disparos aleatorios. |
| `volume_db` | `player_character.tscn` → nodo `ReloadAudio` | -3 | Volumen de cargador y corredera en la recarga. |
| `tracks/4` (tiempos) | `resources/animations/glock_animation.tres` → animación `Reload` | 0.30 / 0.86 / 1.04 s | Instante en que suenan `unload`, `load` y `recharge`. |
| `empty_sound` | `resources/weapons/glock.tres` | `wood_block_3` (placeholder) | Click en seco al disparar sin balas. |
| `streams` | `resources/audio/sfx_library.tres` | mapa evento → sonido | Qué sample suena en cada evento (lista en `scripts/audio/sfx_library.gd`). |
| `volumes_db` | ídem | mapa evento → dB | Nivel relativo por evento (nivelación entre packs). |
| Pitch de `impact_wall` | `scripts/effects/bullet_impact.gd` → `place()` | 1.45–1.75 | Agudiza el paso de piedra para que suene a esquirla. |
| `POOL_2D_SIZE` / `POOL_3D_SIZE` | `scripts/audio/sfx.gd` | 6 / 12 | Sonidos simultáneos antes de robar el más viejo. |
| `step_distance` | `player_character.gd` → `Footsteps` | 2.1 m | Metros entre paso y paso corriendo (se acorta con la velocidad). |
| Pitch de `land` | `player_character.gd` → `_physics_process` | 0.7–0.8 | Grave del aterrizaje respecto del paso. |
| `spawn_exit_radio` | `scripts/levels/playable_level.gd` | on | Experimental: radio con música en loop en la sala de salida de cada nivel. |
| Posición de la radio | `playable_level.gd` → `_spawn_exit_radio` | pared norte, 0.6 m adentro | Dónde aparece la radio dentro de la sala de salida. |
| `volume_db` / `unit_size` / `max_db` | `scenes/props/radio.tscn` → nodo `Speaker` | -4 / 3 m / 0 | Volumen de la radio y qué tan rápido se atenúa con la distancia. |
| `reverb_volume_db` / `roomsize_multiplicator` / `occlusion_lp_cutoff` | ídem | -10 / 4.0 / 500 Hz | Reverb de sala y cuánto se apaga la música tras una pared. |
| `output_bus` | ídem | `Music` | La radio responde al volumen de música de las opciones aunque sea 3D. |
| `loop` | `assets/audio/music/human_tetris_fade.mp3.import` | on | Repetición de la canción (opción de importación del mp3). |
| Buses `Master` / `Music` / `SFX` | `resources/audio/default_bus_layout.tres` | — | Volúmenes base; los del usuario los maneja `Settings`. |

## Cámara y feedback del jugador

| Parámetro | Dónde | Valor | Qué modifica |
|---|---|---|---|
| `shake_decay` | `player_character.gd` → `Camera Shake` | 1.9 | Qué tan rápido se descarga el trauma (más alto = sacudidas más cortas). |
| `shake_max_degrees` | ídem | (3.2, 3.2, 2.4) | Amplitud máxima de la sacudida en pitch / yaw / roll. |
| `shake_frequency` | ídem | 22 | Velocidad de vibración de la sacudida. |
| Trauma por daño | `scripts/player/hud.gd` → `_on_damage_taken` | 0.65 | Fuerza de la sacudida al recibir daño (la amplitud es trauma²). |
| Vignette de daño | `hud.gd` → `_build_damage_texture` y tween | 0.45 s | Color, intensidad y duración del flash rojo. |
| Hitmarker | `hud.gd` → `_on_weapons_manager_hit_successfull` | 1.6x, 0.07 + 0.18 s | Escala de entrada y duración del marcador de acierto. |
| `landing_dip` / `_min_speed` / `_max_speed` | `player_character.gd` → `Jump Parameters` | 1.8° / 5 / 14 | Hundimiento de la vista al aterrizar según la caída. |
| `line_length` / `minimum_gap` / `follow_speed` | `scripts/player/dynamic_crosshair.gd` | 9 / 4 / 14 | Tamaño, apertura mínima y reacción de la mira dinámica. |
| `ads_fov` / `ads_speed` | `scripts/weapons/weapon_state_machine.gd` → `Aim Down Sights` | 55° / 12 | Zoom al apuntar con click derecho (la cámara parte de 75°) y velocidad del fundido. La sensibilidad del mouse baja sola en la relación `fov_actual / fov_base`. |
| `ads_offset` / `ads_rotation_degrees` | ídem | (-0.155, 0.096, 0.1) / (0, -2.86, 0) | Pose del rig del arma al apuntar, relativa a la cámara. Calibrar con `glock-ads.png` del test visual: la mira trasera tiene que quedar en el centro. |
| `enable_ads` | ídem | on | Apaga el apuntado por completo. |

## Arma (Glock)

| Parámetro | Dónde | Valor | Qué modifica |
|---|---|---|---|
| `magazine` / `max_ammo` | `resources/weapons/glock.tres` | 10 / 60 | Balas por cargador y reserva. |
| `damage` / `fire_range` | ídem | 25 / 120 | Daño por bala y alcance del hitscan. |
| `vertical_kick` / `horizontal_kick` | `resources/weapons/glock_recoil.tres` | 1.1° / 0.18° | Patada de cámara por disparo. |
| `*_kick_growth` / `max_*_kick` | ídem | 0.35, 0.15 / 3.5, 1.2 | Cuánto crece la patada en ráfaga y su tope. |
| `kick_snappiness` / `recovery_speed` | ídem | 26 / 4.5 | Qué tan rápido entra la patada y vuelve la vista. |
| `spread_per_shot` / `max_shot_spread` / `spread_recovery` | ídem | 0.75 / 3.0 / 2.5 | Dispersión acumulada por ráfaga y su recuperación. |
| `move_spread` / `air_spread` / `crouch_multiplier` | ídem | 1.8 / 3.0 / 0.55 | Dispersión por moverse, saltar y agacharse. |
| `ads_multiplier` | ídem | 0.6 | Multiplicador de toda la dispersión mientras se apunta (se combina con el de agachado). |
| `shot_reset_time` | ídem | 0.35 s | Pausa que reinicia el contador de ráfaga. |
| Decal de impacto | `scenes/effects/bullet_impact.tscn` → `Decal`; `bullet_impact.gd` | 0.14 m, 8 s, fade 1.5 s | Tamaño y vida de la marca en la pared. |
| Chispas | `bullet_impact.tscn` → `Sparks` | 10 partículas, 0.4 s | Cantidad y vida de las chispas de impacto. |

## Movimiento

| Parámetro | Dónde | Valor | Qué modifica |
|---|---|---|---|
| `run_speed` / `walk_speed` / `crouch_speed` | `player_character.gd` → `Speed Parameters` | 6.4 / 3.4 / 2.3 | Velocidades base. |
| `ground_acceleration` / `ground_friction` / `stop_speed` | → `Acceleration Parameters` | 10 / 6 / 3 | Arranque y frenada en el suelo (estilo Quake). |
| `air_acceleration` / `air_speed_cap` / `max_air_speed` | ídem | 12 / 0.8 / 9.6 | Control en el aire y techo del strafe / bhop. |
| `jump_height` / `jump_gravity` / `fall_gravity_scale` | → `Jump Parameters` | 1.15 / 20.5 / 1.1 | Altura del salto y peso de la caída. |
| `auto_bhop` / `coyote_time` / `jump_buffer_time` | ídem | on / 0.1 / 0.15 s | Encadenar saltos y márgenes de perdón del salto. |

## Ventanas y objetivos

| Parámetro | Dónde | Valor | Qué modifica |
|---|---|---|---|
| Apertura | `scripts/windows/window_panel_3d.gd` → `_play_open_animation` | 0.14 s | Duración del scale-in al aparecer. |
| Minimizar | → `_animate_minimize` | 0.1 s, caída 0.45 m | Velocidad y recorrido del cierre genérico. |
| Apagado CRT | → `_animate_crt_off` | 0.1 + 0.09 s | Colapso vertical y apagado de la línea. |
| `close_style` por familia | `popup_window.gd`, `critical_error_window.gd`, `firewall_window.gd` → `_ready` | `CLOSE_STYLE_CRT` | Qué animación de cierre usa cada familia. |
| Sacudida al impacto | → `_shake_screen` | ±0.025 m, 3 golpes | Fuerza y cantidad de sacudidas del panel por tiro. |
| Botón presionado | → `_press_zone_control` | 1 px, 0.08 s | Hundimiento y duración del efecto de clic. |
| `SHIELD_TINT` y fundido | `window_panel_3d.gd` | azul, 0.35 s | Color del firewall y velocidad con que se funde al caer. |
| Shuffle del error crítico | `critical_error_window.gd` → `_shuffle` | 0.16 s | Velocidad con que se deslizan los botones tras un trap. |
| `skip_seconds` | `popup_window.gd` y variantes `.tscn` | 5 (10 en la lenta) | Espera del SKIP de la publicidad. |
| `MAX_LIVE_ADS` | `popup_window.gd` | 7 | Tope de publicidades simultáneas por capa. |
| `download_seconds` | `download_window.gd` y variantes `.tscn` | 12 s | Duración de la descarga. |
| Pop de bola | `scripts/targets/target_ball.gd` → `_play_destruction` | 1.22x, 0.05 + 0.11 s | Inflado y colapso al destruirse. |
| Esquirlas de bola | → `_spawn_burst` | 14 partículas, 0.55 s | Cantidad, velocidad y vida de las esquirlas. |
| `barrier_color` / `safe_close_distance` | `scripts/levels/room_door_3d.gd` | rojo / 2 m | Color de la puerta sellada y distancia para cerrarse. |
| `moving_block_speed` / `block_crossing_damage` | `scripts/levels/playable_level.gd` | 0.65 / 15 | Velocidad de bloques móviles y daño al cruzarlos. |

## Puntaje y combos

| Parámetro | Dónde | Valor | Qué modifica |
|---|---|---|---|
| `zone_values` / `ball_value` | `resources/gameplay/score_settings.tres` | close 100, trap -150, bola 50… | Puntos por zona de ventana y por bola. |
| `chain_thresholds` / `chain_multipliers` | ídem | 3, 6, 10, 14, 19, 25 / x1…x8 | Hits por escalón y multiplicador de cada uno. |
| `grace_seconds` | ídem | 3 s | Tiempo sin acertar antes de que la cadena empiece a caer. |
| `miss_step_drops` / `timeout_step_drop` | ídem | 2, 3, 4 / 1 | Escalones perdidos por fallo (1.º, 2.º, 3.º seguido) y por timeout. |
| Bonos de sala y de nivel | ídem | 500, 800, 300 / 2000, 1000, 2500 | Sala limpia, una sola cadena, intacta; nivel sin daño, todo limpio, perfecto. |
| `par_seconds_per_target` / `par_second_bonus` | ídem | 1.8 / 10 | Tiempo par por objetivo y puntos por segundo ahorrado. |
| `rank_thresholds` / `rank_letters` | ídem | 0.35…1 / D…S+ | Cortes de rango sobre el techo del nivel. |
| `BANK_HOLD_SECONDS` | `scripts/ui/score_hud.gd` | 2.5 s | Cuánto queda el cobro a la vista. |
| `TIMER_DANGER_RATIO` / `SAVE_RATIO` | ídem | 0.25 / 0.15 | Desde qué fracción del timer parpadea; hasta cuál un acierto es "salvada". |
| `STEP_COLORS` / `LOST_COLORS` / `BANK_COLOR` | ídem | — | Colores del contador por escalón, por motivo de pérdida y del cobro. |
| Punch / shake / roll | ídem → `_punch`, `_shake`, `_roll_pending`, `_on_score_changed` | 1.28–1.35x / ±9 px / 0.55 s / 0.4 s | Intensidad del contador al subir, caer y cobrar; velocidad del número rodante. |
| Pitch por escalón | ídem → `_celebrate_step_up` | 1.0 + 0.12 · escalón | Cuánto sube el tono del sonido al escalar. |

## Ronda y flujo del nivel

| Parámetro | Dónde | Valor | Qué modifica |
|---|---|---|---|
| `max_health` / `round_duration` | `scripts/gameplay/round_controller.gd` | 100 / 90 s | Vida del jugador y tiempo de la ronda. |
| `results_delay` | `scripts/levels/playable_level.gd` | 3 s | Espera entre el cierre del nivel y la pantalla de resultados. |
| `SLOWMO_SCALE` / `SLOWMO_FADE_IN_SECONDS` | ídem | 0.25 / 0.8 s | Qué tan lenta queda la cámara lenta del final y cuánto tarda en hundirse. |
| Reintento de resultados | → `_show_results` | 0.5 s | Cada cuánto reintenta abrir resultados si otro menú está abierto. |
| Intertítulo de nivel | `scripts/ui/level_intro.gd` | 0.5 / 1.15 / 0.55 s | Fade-in, sostén y fade-out del título del nivel. |
