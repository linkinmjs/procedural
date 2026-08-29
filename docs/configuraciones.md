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
| `radio` por sala | `level_designs/levels/*.json` → `rooms[].radio` | `{ enabled, corner }` | Qué salas tienen radio y en qué esquina (`ne`/`nw`/`se`/`sw`); se edita en el Level Workshop. |
| `RADIO_CORNER_MARGIN` | `scripts/levels/playable_level.gd` | 0.5 m | Distancia de la radio a la cara interior de cada pared de su esquina. Mira al centro en diagonal. |
| `poll_seconds` / `switch_hysteresis` | `scripts/props/radio_director.gd` | 0.5 s / 4 m | Cada cuánto se elige la radio más cercana y cuánto tiene que ganarle a la activa para quitarle la acústica de sala. Cada cambio calla la radio un instante: mejor pocos. En el perfil sin audio espacial (Web) no activa ninguna. |
| `crossfade_seconds` | `scripts/props/radio_prop.gd` | 0.25 s | Cruce **en serie** entre el reproductor común y el espacial: el plain se calla y recién entonces arranca el espacial (y al revés). Dos copias a la vez recortaban y, desfasadas, sonaban a flanger. |
| `spatial_audio_enabled()` | `scripts/environment/quality.gd` | alto: sí / medio (Web): no | Si las radios llevan `Speaker` espacial. Sin hilos, el addon (20 buses con delay+reverb+filtro por radio) dejaba sin buffer al audio de la Web. |
| Rotura de la radio | `radio_prop.gd` → `break_radio` | `target_destroyed` a pitch 0.7 | Un disparo la calla, suelta esquirlas y la deja gris. |
| `volume_db` / `unit_size` / `max_db` | `scenes/props/radio.tscn` → nodos `Speaker` y `PlainSpeaker` | -4 / 3 m / 0 | Volumen de la radio y qué tan rápido se atenúa con la distancia. |
| `reverb_volume_db` / `roomsize_multiplicator` / `occlusion_lp_cutoff` | ídem | -10 / 4.0 / 500 Hz | Reverb de sala y cuánto se apaga la música tras una pared. |
| `output_bus` | ídem | `Music` | La radio responde al volumen de música de las opciones aunque sea 3D. |
| `loop` | `assets/audio/music/human_tetris_fade.ogg.import` | on | Repetición de la canción (opción de importación del ogg; ~96 kbps, el original mp3 queda en `assets/_raw/`). |
| Buses `Master` / `Music` / `SFX` | `resources/audio/default_bus_layout.tres` | — | Volúmenes base; los del usuario los maneja `Settings`. `Master` lleva un `AudioEffectHardLimiter` (`ceiling_db` -0.5): techo para la suma de radios y disparos, en vez de recortar en seco. |
| `BASE_HZ` / `WHINE_HZ` / ganancias | `scripts/audio/led_hum_synth.gd` | 60 Hz / 9900 Hz / 0.55·0.18·0.06·0.04 | Timbre del zumbido de pantalla de los bloques (hum de red, octava, silbido, ruido). Se sintetiza una vez y se comparte. |
| `GROWL_HZ` / `THROB_HZ` / `THROB_DEPTH` | ídem | 42 Hz / 3 Hz / 0.4 | Gruñido grave que late, el segundo loop del bloque. Solo se oye pegado al panel. |
| `MIX_RATE` / `LOOP_SECONDS` | ídem | 24000 / 1 s | Resolución y largo del loop; mantener frecuencias múltiplos enteros de 1 Hz para que cierre sin click. |
| `unit_size` / `max_distance` / `attenuation_model` | `scenes/targets/target_block_3d.tscn` → nodo `HumPlayer` | 1.8 m / 11 m / inverso cuadrático | Qué tan rápido se apaga el zumbido con la distancia y desde dónde deja de oírse. |
| `max_distance` / `attenuation_filter_cutoff_hz` | ídem → nodo `GrowlPlayer` | 7 m / 900 Hz | Alcance del gruñido grave: más lejos que esto no existe. |
| `hum_volume_db` / `hum_near_volume_db` | `scripts/targets/target_block_3d.gd` | -16 / -2 dB | Volumen del zumbido lejos y pegado a la pantalla. |
| `hum_near_distance` / `hum_near_detune` / `hum_pitch_jitter` | ídem | 4 m / 0.07 / 0.04 | Desde dónde está a pleno, cuánto baja el tono al acercarse y la variación de tono entre bloques. |
| `growl_near_volume_db` / `growl_near_distance` | ídem | -3 dB / 2 m | Volumen del gruñido pegado al bloque y desde dónde está a pleno (entre 7 m y 2 m sube en curva cuadrática). |

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
| X con skin retro sobre escena XP | `window_skin.gd` → `_style_close_rect` | `button_normal.png` detrás del glifo | La X retro es solo el glifo negro y sobre la barra azul oscura desaparecía (y es la zona que mejor paga): se le dibuja detrás el botón gris de las escenas retro de fábrica, con el glifo centrado. |
| `SHUFFLE_SECONDS` / `SHUFFLE_REDRAW_MARGIN` | `critical_error_window.gd` | 0.16 / 0.1 s | Deslizamiento de los botones del error crítico al barajarse, y cuánto más se mantiene vivo el redibujado de la pantalla (que normalmente es `UPDATE_ONCE`): sin eso quedaba congelada con los botones a mitad de camino, superpuestos. |
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
| `moving_block_speed` / `block_crossing_damage` | `scripts/levels/playable_level.gd` | 0.65 / 40 | Velocidad de bloques móviles y daño al cruzarlos en escenas armadas a mano; un nivel de la campaña usa `DEFAULT_CROSSING_DAMAGE` (40) o su propio `crossingDamage` (`level_definition_loader.gd`, 1–100). |
| `DISCHARGE_FLATTEN_SECONDS` / `DISCHARGE_CLOSE_SECONDS` | `scripts/targets/target_block_3d.gd` | 0.16 / 0.12 s | Apagado del bloque que atravesó al jugador: el panel se aplasta a una línea y la línea se cierra. |
| `melee_enabled` | `scripts/weapons/weapon_state_machine.gd` | false | Golpe cuerpo a cuerpo del template. Apagado: cerraría ventanas sin gastar balas. |

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

## Progresión y logros

| Parámetro | Dónde | Valor | Qué modifica |
|---|---|---|---|
| `xp_values` | `resources/gameplay/progression_settings.tres` | mapa motivo → XP | Cuánto paga cada acción valiosa (zona, cierre, escalón de cadena, sala, nivel, primera vez, sin daño, récord). Disparar y fallar no figuran a propósito. |
| `rank_xp` | ídem | 0/50/100/200/400/600 | XP por índice de rango D…S+ al cerrar el nivel. |
| `score_points_per_xp` | ídem | 100 | Cuántos puntos de puntaje valen 1 XP al cerrar el nivel. |
| `level_thresholds` / `level_names` | ídem | 15 umbrales (0 … 150 000) y sus nombres de hardware | La tabla de niveles de jugador. Los umbrales tienen que crecer; el primero es 0. |
| `elder_growth` | ídem | 1.35 | Cuánto crece cada salto más allá de la tabla (nombres `OC+n`). |
| `xp_log_limit` | ídem | 100 | Entradas del historial de XP que se conservan en el perfil. |
| `save_delay` | ídem | 2.0 s | Espera antes de escribir el perfil (una sala entera = una escritura). |
| `notice_seconds` | ídem | 4.0 s | Cuánto queda a la vista cada globo de aviso. |
| `progression_version` | ídem | 1 | Subirlo al cambiar la tabla de niveles: los perfiles guardados recalculan su nivel desde la XP. |
| `BADGES` | `scripts/progression/achievement_catalog.gd` | 24 filas `{id, stat, threshold, kind, xp, icon}` | Qué logros existen, de qué estadística dependen y cuánto pagan. Agregar uno = una fila + `BADGE_<ID>_NAME/DESC` en el CSV. |
| `LATE_NIGHT_FROM` / `LATE_NIGHT_TO` | `scripts/progression/achievement_tracker.gd` | 2 / 4 | Horas locales que cuentan como "de madrugada" para `CRON JOB`. |
| `PROFILE_PATH` / `TEST_PROFILE_PATH` | `scripts/autoloads/player_profile.gd` | `user://profile.cfg` / `user://profile.test.cfg` | Dónde se guarda el perfil; en headless (smoke tests) se usa el segundo. |
| `LAYER` / `DESKTOP_MARGIN` / `GAME_MARGIN` | `scripts/autoloads/notices.gd` | 130 / (8, barra + 6) / 28 | Capa del globo y a qué distancia del borde se apoya en el escritorio y en partida. |

## Ronda y flujo del nivel

| Parámetro | Dónde | Valor | Qué modifica |
|---|---|---|---|
| `max_health` / `round_duration` | `scripts/gameplay/round_controller.gd` | 100 / 90 s | Vida del jugador y tiempo de la ronda. |
| `AMMO_GRACE_SECONDS` | ídem | 2.5 s | Gracia entre quedarse sin balas (sin disparos por resolver, sin burbujas con balas, con salas de combate abiertas) y perder la ronda por `ammo_depleted`. El HUD parpadea `SIN MUNICION` mientras tanto. |
| `FADE_SECONDS` / `LINE_SECONDS` / `TEXT_FADE_SECONDS` | `scripts/ui/failure_screen.gd` | 0.45 / 0.35 / 0.3 s | Pantalla de derrota: fundido a oscuro, cierre de la línea "monitor apagado" y aparición del motivo. Sin cámara lenta; el jugador queda sin control (`controls_enabled`). |
| `results_delay` | `scripts/levels/playable_level.gd` | 3 s | Espera entre el cierre del nivel y la pantalla de resultados. |
| `SLOWMO_SCALE` / `SLOWMO_FADE_IN_SECONDS` | ídem | 0.25 / 0.8 s | Qué tan lenta queda la cámara lenta del final y cuánto tarda en hundirse. |
| `cleared_light_factor` / `cleared_light_fade_seconds` | ídem | 0.3 / 1.2 s | A cuánto baja la luz de una sala al limpiarla y cuánto tarda. Invita a salir: el pasillo queda más brillante. No bajar de ~0.2 o no se ve la recompensa. |
| `exit_light_factor` | ídem | 0.15 | A cuánto baja la luz de la sala de salida; se funde junto con la cámara lenta (`SLOWMO_FADE_IN_SECONDS`). |
| Reintento de resultados | → `_show_results` | 0.5 s | Cada cuánto reintenta abrir resultados si otro menú está abierto. |
| Intertítulo de nivel | `scripts/ui/level_intro.gd` | 0.5 / 1.15 / 0.55 s | Fade-in, sostén y fade-out del título del nivel. |

## Arranque y monitor del menú

| Parámetro | Dónde | Valor | Qué controla |
| --- | --- | --- | --- |
| `boot_splash/image` / `boot_splash/bg_color` | `project.godot` | `assets/textures/ui/splash/godot_splash.png` / #242424 | Splash del motor. Tiene que ser la misma imagen y el mismo fondo que la primera tarjeta de `BootSequence`; `tests/boot_sequence_smoke_test.gd` lo verifica contra el píxel de la esquina de la imagen. |
| `GODOT_HOLD` / `GODOT_FADE` | `scripts/ui/boot_sequence.gd` | 1.1 / 0.3 s | Cuánto se sostiene el splash de Godot y su fundido a negro. |
| `STUDIO_PAUSE` / `TYPE_SECONDS` / `TYPE_JITTER` / `STUDIO_HOLD` | ídem | 0.4 / 0.075 / ±0.035 / 1.1 s | Espera con el prompt solo, tiempo entre letras (con azar, como alguien tipeando) y sostenido con el nombre completo antes del corte. |
| `CURSOR_BLINK` / `CUT_SECONDS` | ídem | 0.5 / 0.25 s | Parpadeo del `_` y negro entre la terminal y el menú (el monitor se apaga antes de prenderse). |
| `STUDIO_FONT` / `STUDIO_FONT_SIZE` | ídem | `Withheld Data` / 64 | Fuente pixel de la terminal (`assets/fonts/boot/`, importada sin antialiasing para que los píxeles queden secos). |
| `boot_key` / `boot_enter` / `desktop_boot` | `resources/audio/sfx_library.tres` | `ui_minimalist_2` −6 dB / `ui_modern_2` / sin sample | Tic por letra (con variación de tono), enter al terminar y encendido del monitor (hook sin sonido todavía). |
| `POWER_ON_DELAY` / `POWER_ON_SECONDS` | `scripts/ui/crt_overlay.gd` | 0.15 / 0.9 s | Negro antes de que aparezca la línea y duración del encendido del tubo. |
| `LAYER` | ídem | 200 | Por encima de `MenuStack` (128): el vidrio cubre también las ventanas abiertas sobre el escritorio. |
| `scanline_strength` / `scanline_period_px` | `assets/shaders/crt_monitor.gdshader` | 0.10 / 3 px | Cuánto brillo se llevan las líneas de barrido y cada cuántos píxeles reales de pantalla se repiten. |
| `aberration_px` | ídem | 0.7 px | Separación del rojo y el azul en el borde; en el centro es cero para que el texto siga nítido. |
| `vignette_strength` / `vignette_start` / `corner_radius` | ídem | 0.25 / 0.45 / 0.03 | Oscurecimiento de los bordes, desde qué distancia al centro empieza, y esquinas redondeadas del tubo. |
| `flicker_strength` / `band_strength` / `band_speed` / `band_height` / `noise_strength` | ídem | 0.012 / 0.03 / 0.05 / 0.25 / 0.015 | Parpadeo del brillo, banda clara que baja despacio y grano. Todo apenas insinuado: el menú se tiene que leer sin cansar la vista. Sin curvatura a propósito (correría el dibujo respecto del clic). |
| `brightness` | ídem | 1.04 | Compensa lo que se llevan las líneas y la viñeta. |
| `crt` | `user://settings.cfg` → `[screen]` | true | Filtro de monitor (Opciones → «Filtro de monitor»). Apagado, el rectángulo del shader se oculta y no se paga la copia del backbuffer; el escritorio aparece sin encendido. |
