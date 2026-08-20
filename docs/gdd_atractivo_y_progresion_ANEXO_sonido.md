# GDD — Anexo de sonido

## Estado del documento

Documento de trabajo para definir, producir e integrar el sonido de `procedural`.
Esta primera versión es un inventario funcional: enumera qué debe oírse, cuándo
debe sonar y qué tan importante es. No fija todavía librerías, mezcla final ni
valores definitivos de volumen.

Estados de producción:

- **Integrado:** el recurso existe, está conectado al juego y puede probarse.
- **Pendiente:** hace falta conseguir o crear el audio y conectarlo.
- **Futuro:** corresponde a una pantalla o sistema todavía no implementado.
- **Descartado:** se evaluó y se decidió no usarlo.

Prioridades:

- **P0 — esencial:** comunica una acción, un peligro o un cambio de estado que el
  jugador necesita entender.
- **P1 — identidad y respuesta:** vuelve satisfactorias las acciones frecuentes y
  refuerza la estética del juego.
- **P2 — profundidad:** variedad, ambiente y terminación; puede esperar al primer
  pase funcional.

## 1. Objetivos del sonido

El audio debe cumplir cuatro funciones, en este orden:

1. **Informar:** munición, daño, peligro, puertas, objetivos, combo y fin de ronda.
2. **Confirmar:** cada acción del jugador debe tener una respuesta inmediata.
3. **Dar ritmo:** el combo, las oleadas y el conteo de resultados deben construir
   una cadencia arcade reconocible.
4. **Dar identidad:** unir la interfaz de escritorio, las ventanas disparables y
   el FPS bajo una misma fantasía de sistema operativo inestable.

La dirección inicial propone combinar sonidos físicos secos y legibles —arma,
pasos, impactos y mecanismos— con una capa digital de sistema —errores, avisos,
confirmaciones y glitches—. La referencia a Windows debe ser evocativa, no una
copia de sonidos protegidos de Microsoft.

## 2. Estado actual

Hoy solo está integrado el disparo de la Glock mediante
`resources/audio/glock_shoot.tres`, que elige al azar entre tres muestras WAV.
`glock.tres` ya admite un sonido de arma vacía, pero esa propiedad está vacía.
No se encontraron otros efectos, ambientes ni música integrados.

| ID | Evento | Estado | Nota |
| --- | --- | --- | --- |
| `wpn_glock_fire` | Disparo de Glock | **Integrado** | Tres variaciones; falta revisar mezcla y cola en interiores. |

## 3. Inventario de sonidos

### 3.1 Interfaz común

Estos sonidos deben compartirse entre todos los menús, con una variante más
orgánica/digital para la piel del juego y otra de sistema para el escritorio.

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `ui_focus` | Un botón recibe foco con teclado o mando | P1 | 2D | Pendiente | Muy corto; no sonar al reconstruir la pantalla. |
| `ui_hover` | El puntero entra a una opción activa | P2 | 2D | Pendiente | Sutil y distinto de confirmar. Puede unificarse con `ui_focus`. |
| `ui_confirm` | Se activa una opción válida | P0 | 2D | Pendiente | Respuesta inmediata, antes del cambio de escena. |
| `ui_back` | Volver, cerrar o cancelar | P0 | 2D | Pendiente | Descendente y más suave que confirmar. |
| `ui_disabled` | Se intenta usar una opción deshabilitada | P1 | 2D | Pendiente | Error corto; aplicar cooldown para evitar spam. |
| `ui_toggle_on` | Activar una casilla o ajuste | P1 | 2D | Futuro | Debe diferenciarse de `toggle_off`. |
| `ui_toggle_off` | Desactivar una casilla o ajuste | P1 | 2D | Futuro | Pareja tonal descendente. |
| `ui_slider_tick` | Mover un control deslizante | P2 | 2D | Futuro | Limitar la frecuencia mientras se arrastra. |
| `ui_tab_change` | Cambiar pestaña o categoría | P1 | 2D | Futuro | Útil para opciones, niveles y récords. |
| `ui_error` | Una operación no se puede completar | P0 | 2D | Pendiente | Reservarlo para errores reales, no para cada botón deshabilitado. |

### 3.2 Escritorio y menú principal existentes

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `desktop_boot` | Entrada al menú principal | P1 | 2D | Pendiente | Firma breve de arranque; no una secuencia larga. |
| `desktop_icon_select` | Clic simple selecciona un icono | P1 | 2D | Pendiente | Click seco de escritorio. |
| `desktop_icon_open` | Doble clic abre un icono | P0 | 2D | Pendiente | Dos clicks legibles más confirmación de apertura si corresponde. |
| `desktop_window_open` | Aparece la ventana de `procedural` | P1 | 2D | Pendiente | Movimiento corto de sistema. |
| `desktop_window_close` | La X oculta la ventana | P1 | 2D | Pendiente | No debe parecer destrucción de un objetivo. |
| `desktop_start_open` | Se abre el menú Inicio | P1 | 2D | Pendiente | Un único sonido por apertura. |
| `desktop_start_close` | Se cierra el menú Inicio | P2 | 2D | Pendiente | Más suave que la apertura. |
| `desktop_task_toggle` | Botón de tarea oculta o recupera la ventana | P1 | 2D | Pendiente | Confirmar el cambio de visibilidad. |
| `desktop_attention` | Un icono sin destino hace parpadear la tarea | P0 | 2D | Pendiente | Aviso reconocible, una vez por solicitud; no en cada parpadeo. |
| `desktop_shutdown` | Salir desde Inicio o desde el juego | P1 | 2D | Pendiente | Sonido propio antes del cierre de la aplicación. |
| `menu_play` | Jugar inicia la carga del nivel | P0 | 2D | Pendiente | Confirmación más contundente que un botón común. |

### 3.3 Pantallas de juego existentes

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `level_intro_in` | Entra el velo con el número de nivel | P1 | 2D | Pendiente | Ataque corto que anuncie desafío. |
| `level_intro_skip` | El jugador salta la presentación | P2 | 2D | Pendiente | Corte limpio; puede usar `ui_confirm`. |
| `level_intro_out` | El velo libera el control | P0 | 2D | Pendiente | Debe marcar con precisión cuándo empieza a jugarse. |
| `pause_open` | Escape abre la pausa | P0 | 2D | Pendiente | Frenada o filtro breve; la música puede atenuarse. |
| `pause_resume` | Reanudar | P0 | 2D | Pendiente | Inverso de la pausa, sin retrasar el control. |
| `retry` | Reintento instantáneo | P0 | 2D | Pendiente | Sonido corto de reinicio; tolerar repetición frecuente. |
| `confirm_open` | Aparece confirmación de abandono | P1 | 2D | Pendiente | Atención sin comunicar peligro de combate. |
| `confirm_accept` | Se confirma abandonar | P0 | 2D | Pendiente | Cierre definitivo. |
| `confirm_cancel` | Se cancela el abandono | P0 | 2D | Pendiente | Puede reutilizar `ui_back`. |
| `results_open_success` | Abren resultados de nivel completado | P0 | 2D | Pendiente | Resolución positiva antes del desglose. |
| `results_open_failure` | Abren resultados por tiempo agotado | P0 | 2D | Pendiente | Debe comunicar intento fallido sin sonar a muerte. |
| `results_row_reveal` | Aparece cada línea del desglose | P1 | 2D | Pendiente | Tick corto, con variación de tono o pitch. |
| `results_total` | Se revela el total | P0 | 2D | Pendiente | Golpe de cierre más grande. |
| `results_rank` | Se revela el rango | P0 | 2D | Pendiente | Escalar por rango; `KERNEL` debe sentirse excepcional. |
| `results_new_record` | El intento supera el récord | P0 | 2D | Pendiente | Celebración inequívoca y breve. |
| `results_skip` | Una tecla revela todo de inmediato | P1 | 2D | Pendiente | Resolver en un golpe, sin reproducir todos los ticks juntos. |

### 3.4 Menús y pantallas por implementar

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `level_select_open` | Abrir selección de nivel | P1 | 2D | Futuro | Entrada de carpeta o explorador. |
| `level_select_move` | Cambiar el nivel resaltado | P1 | 2D | Futuro | Navegación rápida, tolerante a repetición. |
| `level_locked` | Intentar abrir un nivel bloqueado | P0 | 2D | Futuro | Cerradura/error distinto del botón deshabilitado. |
| `level_launch` | Confirmar un nivel | P0 | 2D | Futuro | Puede compartir familia con `menu_play`. |
| `options_open` | Abrir Opciones | P1 | 2D | Futuro | Entrada de panel de control. |
| `options_apply` | Aplicar cambios | P0 | 2D | Futuro | Confirmación clara. |
| `options_reset` | Restaurar valores | P1 | 2D | Futuro | Requiere confirmación si borra personalización. |
| `records_open` | Abrir récords/estadísticas | P1 | 2D | Futuro | Acceso a datos del sistema. |
| `credits_open` | Abrir créditos | P2 | 2D | Futuro | Puede iniciar una pieza musical propia. |
| `loading_start` | Comienza una carga perceptible | P1 | 2D | Futuro | Solo si existe pantalla de carga. |
| `loading_complete` | La carga termina | P0 | 2D | Futuro | Sincronizar con la disponibilidad del nivel. |

### 3.5 Glock y combate cercano

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `wpn_glock_fire` | Disparo válido | P0 | 3D/FP | **Integrado** | Tres variaciones existentes; preservar pegada y lectura. |
| `wpn_glock_fire_tail_room` | Cola del disparo en interiores | P2 | 3D | Pendiente | Puede resolverse con reverb de bus en vez de otro sample. |
| `wpn_glock_dry` | Intentar disparar sin balas | P0 | FP | Pendiente | La propiedad `empty_sound` ya existe pero está vacía. |
| `wpn_reload_mag_out` | Extraer cargador | P0 | FP | Pendiente | Sincronizar con la animación, no con la tecla R. |
| `wpn_reload_mag_in` | Insertar cargador | P0 | FP | Pendiente | Punto principal de la recarga. |
| `wpn_reload_slide` | Manipular o liberar corredera | P1 | FP | Pendiente | Ajustar a la animación real disponible. |
| `wpn_reload_complete` | El arma vuelve a estar disponible | P1 | FP | Pendiente | Puede ser el cierre mecánico de la corredera. |
| `wpn_reload_no_reserve` | R sin munición de reserva | P0 | FP | Pendiente | Comunicar que recargar no es posible. |
| `wpn_melee_swing` | Ataque cuerpo a cuerpo al aire | P0 | FP | Pendiente | Sonido de movimiento rápido. |
| `wpn_melee_hit_target` | Melee impacta un objetivo | P0 | 3D/FP | Pendiente | Combinar golpe físico con respuesta digital del blanco. |
| `wpn_melee_hit_surface` | Melee impacta geometría | P1 | 3D/FP | Pendiente | Variar por material si se implementa la detección. |
| `wpn_ammo_pickup` | Recoger caja de munición | P0 | 2D/FP | Pendiente | Confirmar adquisición incluso sin mirar el HUD. |
| `wpn_ammo_full` | Intentar recoger munición con reserva completa | P2 | 2D/FP | Pendiente | Feedback suave; evitar un error agresivo. |

### 3.6 Disparos e impactos

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `impact_target_valid` | Bala acierta una zona válida | P0 | 3D + 2D | Pendiente | Capa espacial del impacto más tick de confirmación. |
| `impact_window_close` | Bala acierta X o botón que cierra | P0 | 3D | Pendiente | Más definitivo que una zona intermedia. |
| `impact_window_action` | Bala acierta zona válida que no cierra | P1 | 3D | Pendiente | Permitir ventanas de varias etapas. |
| `impact_window_trap` | Bala activa una zona trampa | P0 | 3D + 2D | Pendiente | Alarma clara; no confundir con daño físico. |
| `impact_ball_destroy` | Se destruye una pelota | P0 | 3D | Pendiente | Pop corto, con variante para pelota de penalización. |
| `impact_surface_hard` | Bala acierta pared, piso o techo duro | P1 | 3D | Pendiente | Dos o más variantes para evitar repetición. |
| `impact_surface_metal` | Bala acierta puerta, marco o superficie metálica | P2 | 3D | Pendiente | Agregar cuando existan materiales identificables. |
| `impact_miss_feedback` | El disparo resuelto baja la cadena por fallo | P0 | 2D | Pendiente | Sonar por la penalización, no por cada impacto ambiental. |

### 3.7 Movimiento del jugador

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `move_footstep_hard` | Paso sobre piso duro | P0 | FP/3D | Pendiente | Mínimo 4 variaciones; cadencia según velocidad real. |
| `move_footstep_metal` | Paso sobre metal | P2 | FP/3D | Pendiente | Para salas o pasillos que lo justifiquen. |
| `move_footstep_soft` | Paso sobre superficie blanda | P2 | FP/3D | Pendiente | Incorporar solo si aparece ese material. |
| `move_jump` | Despegue | P0 | FP | Pendiente | Corto para tolerar bunny hop frecuente. |
| `move_land_light` | Aterrizaje normal | P0 | FP/3D | Pendiente | Intensidad basada en velocidad de caída. |
| `move_land_heavy` | Aterrizaje fuerte | P0 | FP/3D | Pendiente | Sincronizar con el hundimiento de cámara existente. |
| `move_crouch_down` | Agacharse | P1 | FP | Pendiente | Ropa/equipo, sin exagerar. |
| `move_crouch_up` | Levantarse | P1 | FP | Pendiente | No sonar si el techo impide levantarse. |
| `move_lean` | Inclinarse a izquierda o derecha | P2 | FP | Pendiente | Solo si mejora la sensación; no es información crítica. |
| `move_air_rush` | Alta velocidad sostenida en bunny hop | P2 | 2D/FP | Pendiente | Capa dinámica, no un sample por salto. |

Los pasos de caminar despacio y agachado deberían reutilizar la misma familia con
menor volumen y una cadencia más lenta. No hace falta producir sonidos separados
salvo que las pruebas demuestren que el sigilo necesita una firma propia.

### 3.8 Daño, vida, tiempo y estado de ronda

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `player_damage` | El jugador pierde HP | P0 | 2D/FP | Pendiente | Golpe físico y alarma del HUD; intensidad por daño. |
| `player_health_low` | La vida cruza un umbral crítico | P0 | 2D | Pendiente | Activarse una vez al cruzar el umbral, no en bucle molesto. |
| `player_death` | La vida llega a cero | P0 | 2D/FP | Pendiente | Preparado aunque hoy el cierre típico sea por tiempo. |
| `timer_start` | Empieza efectivamente el cronómetro | P0 | 2D | Pendiente | Importante porque puede empezar al dejar la entrada. |
| `timer_warning` | Queda poco tiempo | P0 | 2D | Pendiente | Avisos escalonados, por ejemplo 10 y 5 segundos. |
| `timer_tick_final` | Últimos segundos | P1 | 2D | Pendiente | No tapar disparos ni feedback de combo. |
| `timer_expired` | Tiempo agotado | P0 | 2D | Pendiente | Debe cortar el ritmo y anticipar resultados fallidos. |
| `round_complete` | Se resuelve la última habitación | P0 | 2D | Pendiente | Victoria inmediata; resultados llegan tres segundos después. |

### 3.9 Objetivos, bloques, oleadas y habitaciones

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `room_enter` | Se activa una sala con encuentro | P0 | 2D + 3D | Pendiente | Marca el comienzo de la prueba de sala. |
| `room_lock` | Las barreras cierran los vanos | P0 | 3D | Pendiente | Mecanismo contundente y localizable. |
| `room_unlock` | Se abren las barreras al limpiar | P0 | 3D | Pendiente | Liberación clara; acompañar la dirección de salida. |
| `room_clear` | Se limpia la habitación | P0 | 2D | Pendiente | Celebración breve antes del cobro de combo. |
| `wave_spawn` | Aparece una nueva oleada | P0 | 3D + 2D | Pendiente | Aviso de reactivación; escalar si es la última. |
| `wave_clear` | Cae el último objetivo de una oleada | P1 | 2D | Pendiente | No confundir con sala completa si quedan oleadas. |
| `window_close` | Una ventana disparable desaparece | P0 | 3D | Pendiente | Firma digital/vidrio; distinta de cerrar una ventana de menú. |
| `penalty_target_warning` | Pelota azul está por expirar | P0 | 3D | Pendiente | Localizable; acelerar cerca del vencimiento. |
| `penalty_target_expire` | El objetivo se escapa y aplica daño | P0 | 3D + 2D | Pendiente | Combinar fuga, daño y pérdida de cadena sin amontonarlos. |
| `block_move` | Un bloque avanza | P1 | 3D | Pendiente | Loop con inicio y fin limpios; volumen según distancia. |
| `block_close` | Se resuelve y desaparece/cierra un bloque | P0 | 3D | Pendiente | Peso mecánico; puede coincidir con `room_unlock`. |
| `block_cross_damage` | El jugador atraviesa un bloque | P0 | 2D + 3D | Pendiente | Impacto peligroso y distinto de un objetivo expirado. |
| `door_close` | Una puerta o barrera se cierra | P0 | 3D | Pendiente | Usar la señal `closed_changed`. |
| `door_open` | Una puerta o barrera se abre | P0 | 3D | Pendiente | Localización útil para encontrar la salida. |

### 3.10 Puntuación y combo

El combo es el sistema que más necesita una gramática musical consistente. Sus
sonidos deben compartir timbre y escalar en intensidad, sin reproducir una
fanfarria por cada impacto.

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `score_hit_tick` | Un objetivo válido suma al pozo | P0 | 2D | Pendiente | Tick muy breve; subir sutilmente con el escalón. |
| `score_step_up` | La cadena alcanza un multiplicador nuevo | P0 | 2D | Pendiente | Variantes coherentes de ×1.5 a ×8. |
| `score_miss_drop` | Un fallo baja escalones | P0 | 2D | Pendiente | Caída tonal; intensidad según escalones perdidos. |
| `score_chain_warning` | La gracia de cadena está por vencer | P1 | 2D | Pendiente | Pulsos discretos; no sonar antes del primer acierto. |
| `score_chain_timeout` | La cadena vence y cobra a ×1 | P0 | 2D | Pendiente | Resolución negativa, distinta de recibir daño. |
| `score_chain_damage` | El daño fuerza el cobro a ×1 | P0 | 2D | Pendiente | Tachar o romper la firma ascendente del combo. |
| `score_chain_trap` | Una trampa fuerza el cobro a ×1 | P0 | 2D | Pendiente | Compartir familia negativa, con carácter de error digital. |
| `score_bank` | La sala cobra `pozo × multiplicador` | P0 | 2D | Pendiente | Escalar por multiplicador; ×8 debe sentirse como evento. |
| `score_total_count` | Los puntos vuelan al total | P1 | 2D | Pendiente | Conteo con límite de frecuencia y cierre definido. |
| `score_bonus` | Se obtiene un bono de sala o nivel | P1 | 2D | Pendiente | Una firma común; no una distinta por bono. |
| `score_perfect_room` | Sala perfecta | P0 | 2D | Pendiente | Celebración excepcional y corta. |
| `score_perfect_level` | Nivel perfecto | P0 | 2D | Pendiente | Reservar el mayor gesto del sistema. |

### 3.11 Ambientes

| ID | Evento o disparador | Prioridad | Espacio | Estado | Criterio inicial |
| --- | --- | --- | --- | --- | --- |
| `amb_desktop_room` | Fondo constante del escritorio | P2 | 2D | Pendiente | Casi imperceptible: ventilador, disco o sala doméstica. |
| `amb_level_base` | Cama ambiental general del nivel | P1 | 2D/3D | Pendiente | Evitar silencio absoluto entre encuentros. |
| `amb_computer_hum` | Ventanas u objetos electrónicos | P2 | 3D | Pendiente | Localizable y muy suave. |
| `amb_fluorescent` | Luces interiores | P2 | 3D | Pendiente | Solo en luminarias cercanas; no uno por cada luz. |
| `amb_wind_exterior` | Salas abiertas o cielo expuesto | P2 | 2D/3D | Pendiente | Depender del tipo de sala. |
| `amb_room_variant` | Variación por tema de nivel | P2 | 2D | Futuro | Permite identidad sin componer música nueva para todo. |

### 3.12 Música

| ID | Uso | Prioridad | Estado | Criterio inicial |
| --- | --- | --- | --- | --- |
| `mus_desktop` | Escritorio y menú principal | P1 | Pendiente | Loop discreto, nostálgico y ligeramente extraño. |
| `mus_level_base` | Exploración y combate de nivel | P1 | Pendiente | Debe sostener concentración y repetición de intentos. |
| `mus_level_pressure` | Poco tiempo o alta intensidad | P2 | Pendiente | Capa o stem sincronizado, no cambio brusco de tema. |
| `mus_results_success` | Resultados completados | P1 | Pendiente | Dejar espacio para conteos, rango y récord. |
| `mus_results_failure` | Resultados fallidos | P1 | Pendiente | Breve y neutral: debe invitar a reintentar. |
| `mus_credits` | Créditos | P2 | Futuro | Puede desarrollar el motivo del escritorio. |

## 4. Paquete mínimo para el primer pase

Antes de producir ambientes, materiales múltiples o música adaptativa, el juego
necesita un pase P0 que cubra:

1. Interfaz: confirmar, volver, opción inválida, pausa y reanudar.
2. Glock: disparo existente, gatillo vacío y los momentos principales de recarga.
3. Movimiento: pasos sobre piso duro, salto y dos intensidades de aterrizaje.
4. Impactos: objetivo válido, ventana cerrada, pelota, trampa y superficie dura.
5. Estado: daño, tiempo crítico, tiempo agotado y ronda completada.
6. Flujo: sala activada, barrera cerrada/abierta, oleada nueva y sala limpia.
7. Puntaje: acierto, nuevo escalón, caída por fallo, cobro, pérdida por daño y
   revelación de total/rango.

Este paquete alcanza para que una partida completa pueda entenderse sin mirar el
feed de texto. P1 agrega personalidad; P2 evita repetición y termina el espacio.

## 5. Reglas de reproducción y mezcla

- Los sonidos que representan objetos del mundo usan reproducción **3D**. Menús,
  HUD, daño propio, combo y resultados usan **2D** para ser siempre legibles.
- Disparo, daño, peligro y fin de tiempo tienen prioridad sobre pasos, ambiente y
  ticks de interfaz.
- Un mismo evento frecuente necesita variaciones: mínimo 3 para disparos e
  impactos y 4 para pasos. Se puede sumar una variación pequeña de pitch.
- No reproducir un sonido por cada frame, parpadeo visual o unidad del contador.
  Los loops y conteos deben limitar su frecuencia.
- La pausa atenúa o filtra juego, ambiente y música, pero mantiene la interfaz.
- Un fallo de puntería debe sonar cuando el sistema confirma la pérdida de
  multiplicador. El impacto contra una pared puede sonar en 3D, pero no debe
  duplicar la penalización del combo.
- Si coinciden destrucción de objetivo, fin de oleada, sala limpia y cobro, la
  mezcla debe escalonarlos o agruparlos. Cuatro golpes simultáneos no comunican
  cuatro cosas.
- Todos los loops deben tener puntos de entrada y salida limpios. Ningún loop
  puede quedar vivo al reintentar, pausar o cambiar de escena.

## 6. Buses propuestos

| Bus | Contenido | Control del jugador |
| --- | --- | --- |
| `Master` | Salida general | Volumen maestro |
| `Music` | Música y capas musicales | Volumen de música |
| `SFX` | Padre de efectos | Volumen de efectos |
| `Weapons` | Disparos, recarga, melee e impactos cercanos | Hereda de efectos |
| `World` | Pasos ajenos, objetivos, puertas, bloques y ambientes 3D | Hereda de efectos |
| `UI` | Menús, HUD, combo y resultados | Volumen de interfaz |
| `Ambience` | Camas y loops ambientales | Hereda de efectos o control propio futuro |

La pantalla de Opciones debería exponer inicialmente `Master`, `Music` y `SFX`.
Separar `UI` puede agregarse si el combo resulta cansador en sesiones largas.

## 7. Convención de archivos

Propuesta para mantener el catálogo buscable:

```text
assets/audio/
  sfx/
    ui/
    weapons/glock/
    movement/
    impacts/
    targets/
    world/
    score/
  ambience/
  music/

resources/audio/
  ui/
  weapons/
  movement/
  impacts/
  targets/
  world/
  score/
  ambience/
  music/
```

Los archivos crudos usan el ID del inventario más un número de variación, por
ejemplo `move_footstep_hard_001.wav`. Los `AudioStreamRandomizer` reutilizables
viven en `resources/audio/` con el ID sin sufijo numérico.

## 8. Ficha para completar cada sonido

Cuando un sonido pase a producción, registrar:

| Campo | Valor |
| --- | --- |
| ID |  |
| Evento exacto |  |
| Prioridad | P0 / P1 / P2 |
| Estado | Pendiente / Integrado / Descartado |
| Archivo o recurso Godot |  |
| Origen y licencia |  |
| Bus |  |
| Reproducción | 2D / 3D / primera persona |
| Variaciones |  |
| Loop | Sí / No |
| Volumen y pitch iniciales |  |
| Señal, método o animación que lo dispara |  |
| Notas de mezcla |  |
| Prueba o escena de validación |  |

## 9. Preguntas abiertas

- ¿La identidad sonora apunta a PC de fines de los 90, Windows XP, glitch moderno
  o una mezcla con una regla clara para cada capa?
- ¿La música debe reaccionar al multiplicador, al tiempo restante o solo al estado
  de la habitación?
- ¿Los pasos son importantes como información jugable si no existen enemigos que
  puedan oírlos, o solo como sensación de movimiento?
- ¿El tick de cada objetivo mejora el ritmo o fatiga en salas con muchos blancos?
- ¿Conviene usar reverb por habitación o una sola mezcla interior por nivel?
- ¿La pelota de penalización debe emitir un aviso continuo localizable desde que
  aparece, o solo cuando está cerca de expirar?
- ¿Los sonidos del escritorio y los de las ventanas disparables comparten timbre
  o deben distinguir con claridad “interfaz segura” de “objetivo del mundo”?
- ¿El juego tendrá soporte de mando? Si lo tiene, foco y navegación pasan de P1 a
  P0 y deben probarse sin mouse.

