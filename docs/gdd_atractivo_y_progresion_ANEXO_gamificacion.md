# Anexo — Gamificación: perfil, XP, niveles y logros

## Estado del documento

**Estado:** Para prototipar (fase 1 implementada; fases 2 y 3 en definición).

Complementa el documento madre (`gdd_atractivo_y_progresion.md`) y los anexos
de puntuación y menús. Donde el anexo de puntuación define *cuánto vale una
partida*, este define *qué le deja la partida al jugador*: un perfil que
persiste, experiencia que sólo sube, niveles con nombre, logros y una vitrina
donde todo eso se ve.

Las decisiones salen de aplicar *Gamification by Design* (Zichermann y
Cunningham, 2011; el PDF está en `docs/pdfs/`) sobre lo que el juego ya tenía.
Las decisiones de alcance las tomó el autor el 2026-08-28: fase 1 = cimientos y
feedback; social sólo local, diseñado para crecer; niveles de jugador con tema
de hardware de PC.

---

## 1. Alcance

Fase 1, implementada:

- Perfil persistente del jugador en `user://profile.cfg`.
- XP global con historial auditable, y niveles de jugador por umbrales.
- Catálogo de 24 logros evaluados desde las señales de la ronda, sin tocar el
  gameplay.
- Globo de aviso estilo bandeja de Windows para logros y subidas de nivel.
- Mi PC: la vitrina (nivel, estadísticas, logros ganados y por ganar, últimos
  eventos).
- Progreso de campaña recordado entre sesiones y selector de niveles con
  récords, con desbloqueo por completar.
- Resultados de nivel con lo que la partida le dejó al perfil.

Fuera de alcance por ahora (ver §10): onboarding con nivel 0, desafíos por
nivel, escritorio personalizable, fantasma del mejor intento, multi-perfil,
rendimientos decrecientes y ranking online.

---

## 2. Del libro al juego

El libro es para productos que no son juegos, así que se tomó lo que aplica a
un juego que ya tiene su núcleo (el puntaje) y se descartó lo que no (virtual
economy, badges pagos, viralidad por redes).

| Principio | Cómo se aplica acá |
| --- | --- |
| **XP**: valorar toda acción valiosa; nunca baja, nunca topea; es el mínimo para lanzar; registro auditable | `GameProfile.award()` paga XP tabulada por motivo; `ProfileData.add_xp()` ignora montos negativos; `xp_log` guarda motivo y contexto de cada pago |
| **Niveles** por umbrales acumulados con curva no lineal (los primeros rápidos), nombres con estatus, tabla extensible sin recodear, nivel inicial regalado, barra que nunca llega al 100 % | Tabla `286 → … → QUANTUM` en `ProgressionSettings`; más allá de la tabla se extrapola (`OC+n`); la bienvenida paga 50 XP; `progress().ratio < 1.0` siempre |
| **Logros**: mezcla de predecibles (escaleras con tramos) y sorpresa; bloqueados en gris; jerga de la comunidad; se pierden puntos, no logros; aviso en tiempo real y no intrusivo, "un pop-up simulado en la esquina inferior derecha" | `AchievementCatalog`: escaleras (`END TASK`, `ALT+F4`, `DEFRAG`), únicos y sorpresas ocultas; `Notices` dibuja el globo de la bandeja de Windows en el escritorio y un panel del HUD en partida |
| **Vitrina** y marcador siempre visible | Mi PC (`MyComputerMenu`), `ProfileHeader` en la ventana del menú y nombre del nivel en la bandeja de la barra |
| **Marcador sin desincentivo**: compararse contra uno mismo con delta visible | Selector con récord, rango, % del techo, tiempo e intentos por nivel; resultados con "XP ganada" y "nivel desbloqueado" |
| **SAPS** (status > access > power > stuff) | Status: niveles, logros, rangos. Access: completar abre el siguiente nivel. Power y stuff: fases 2 y 3 |
| **Onboarding**: primer minuto sin explicar, sin poder fallar, premio inmediato | En fase 1, la primera partida regala `HELLO WORLD`, `KILL -9` y `DEFRAG`; hasta fallar paga XP y hay logros por perder. El nivel 0 es fase 2 |
| **Refuerzo variable** más metas fijas; iterar; tablero para el diseñador | Sorpresas ocultas; estadísticas acumuladas visibles; versión de la tabla guardada con el perfil |

Dos cosas que el libro pide y que se descartaron a propósito: XP por
*aparecer* (login diario) y XP por acciones sin valor. Acá disparar, fallar,
recargar y caer en trampas no pagan nada. Lo que el juego quiere ver es cerrar
ventanas, sostener la cadena y limpiar salas; eso es lo único que paga.

---

## 3. Piezas

| Pieza | Archivo | Rol |
| --- | --- | --- |
| `ProgressionSettings` | `scripts/progression/progression_settings.gd`, instancia en `resources/gameplay/progression_settings.tres` | Perillas: XP por motivo, XP por rango, tabla de niveles, extrapolación, límites del perfil |
| `ProfileData` | `scripts/progression/profile_data.gd` | Estado puro: XP, nivel, stats, campaña, logros, historial; `to_dict`/`from_dict` |
| `AchievementCatalog` | `scripts/progression/achievement_catalog.gd` | Tabla declarativa de logros y su validación |
| `AchievementTracker` | `scripts/progression/achievement_tracker.gd`, nodo en `scenes/ui/round_hud.tscn` | Escucha `RoundController` y `ScoreController` y traduce a XP y stats |
| `PlayerProfile` (autoload, `class_name GameProfile`) | `scripts/autoloads/player_profile.gd` | Señales, guardado diferido, evaluación de logros, `record_run()` |
| `Notices` (autoload) | `scripts/autoloads/notices.gd` + `scripts/ui/notice_balloon.gd` | Cola de globos, una a la vez |
| `ProgressionBreakdown` | `scripts/ui/progression_breakdown.gd` | Filas de XP/nivel/logros para `LevelResults` |
| `ProfileHeader`, `BadgeTile` | `scripts/ui/menus/` | Cabecera de nivel con barra; ficha de logro |
| `MyComputerMenu`, `LevelSelectMenu` | `scripts/ui/menus/` | Vitrina y selector, ambos ventanas del escritorio |

Reglas que mantienen todo esto compilable en los smoke tests headless:

- Ningún script usa `PlayerProfile` ni `Notices` como identificador. Se llega
  con `get_node_or_null("/root/PlayerProfile")` o con `MenuScreen.profile()`.
  Sólo los `class_name` (`GameProfile`, `ProfileData`, `ProgressionSettings`,
  `AchievementCatalog`) se usan como tipos.
- El tracker y los menús toleran que el perfil no exista: sin perfil no hacen
  nada. Los tests que no lo cargan siguen pasando.
- El auto-bind del tracker sólo engancha rondas cuyo `level_id` está en el
  catálogo de la campaña (`GameProfile.is_catalog_level`). `round_hud.tscn`
  también lo usan el Block Lab y los bancos de prueba, y jugar ahí no suma XP
  ni logros. Un `bind()` explícito (los tests sintéticos) no pasa por el filtro.
- Los nombres de nodo `RoundController`, `ScoreController`, `ScoreHUD` y
  `ComboBox` siguen siendo contrato; el nodo nuevo se llama
  `AchievementTracker`.

### Flujo

```
RoundController / ScoreController ──señales──▶ AchievementTracker ──award / increment_stat / record_run──▶ PlayerProfile
PlayerProfile.xp_changed / level_up / badge_unlocked ──▶ Notices (globo), ProfileHeader, chip de la barra, log del HUD
PlayableLevel._show_results ──▶ LevelResults.create(summary, título, hay_siguiente, profile.last_run_report)
LevelSequence ──▶ profile.set_catalog_ids() al cargar; profile.set_last_played() al cambiar; is_unlocked(i) consulta al perfil
```

El nivel arma la ronda en su `_ready`, antes de que el bind diferido del
tracker exista; por eso `bind()` abre la cuenta de la partida
(`profile.begin_run`) en el acto y `round_armed` la vuelve a abrir si llega.

---

## 4. Economía de XP

Referencia: una X vale 100 puntos de puntaje. La XP corre a un quinto o un
décimo de eso, para que los dos números no compitan por la misma atención: el
puntaje es el grande y cuenta la partida; la XP es la chica y cuenta la
carrera.

| Motivo (`reason`) | XP | Cuándo |
| --- | --- | --- |
| `welcome` | 50 | Al crear el perfil (nivel 1 con la barra empezada) |
| `zone_hit` | 5 | Toda zona válida acertada |
| `window_closed` | +10 | La zona cerró la ventana |
| `close_zone` | +5 | …y fue la X (la X entera vale 20) |
| `ball` | 5 | Pelota destruida |
| `chain_step` | 10 × escalón | Cada vez que la cadena sube de escalón |
| `room_cleared` / `room_clean` / `room_perfect` | 50 / +25 / +100 | Al cerrar la sala, según el desglose |
| `level_completed` / `level_failed` | 200 / 50 | Al cerrar el nivel. Fallar también paga: no existe "perder" |
| `first_clear` | 300 | Primera vez que se completa ese nivel |
| `no_damage` / `new_record` | 100 / 100 | Del resumen |
| `score` | 1 por cada 100 puntos | Ata la XP al puntaje sin igualarlos |
| `rank` | 0 / 50 / 100 / 200 / 400 / 600 | Por índice de rango D…S+ |
| `badge` | según el logro | Al desbloquearlo |

Nunca pagan: disparar, fallar, recargar, moverse, trampas. Es la primera
contramedida anti-exploit y también la regla higiénica del anexo de
puntuación (§8): lo que no aporta no paga.

Orden de magnitud: `nivel-2` (39 ventanas, 4 salas) bien jugado ronda 1 700 XP;
la primera campaña completa, 4 000 a 5 000 XP más logros.

---

## 5. Niveles de jugador

XP acumulada para entrar a cada nivel. Los saltos crecen (200, 400, 900,
1 500, 2 500, …): los tres primeros niveles llegan dentro de la primera
partida; el sexto, con la campaña completa una vez.

| Nivel | Nombre | XP |
| --- | --- | --- |
| 1 | 286 | 0 |
| 2 | 386 | 200 |
| 3 | 486 | 600 |
| 4 | PENTIUM | 1 500 |
| 5 | PENTIUM II | 3 000 |
| 6 | PENTIUM III | 5 500 |
| 7 | PENTIUM 4 | 9 000 |
| 8 | CORE 2 | 14 000 |
| 9 | CORE i3 | 21 000 |
| 10 | CORE i5 | 30 000 |
| 11 | CORE i7 | 42 000 |
| 12 | CORE i9 | 58 000 |
| 13 | XEON | 80 000 |
| 14 | THREADRIPPER | 110 000 |
| 15 | QUANTUM | 150 000 |

Más allá de la tabla el salto crece por `elder_growth` (1.35) y el nombre se
sigue del último con un sufijo de overclock (`QUANTUM OC+1`, `OC+2`, …). Así
la barra de progreso nunca llega al 100 %: siempre hay un nivel siguiente y no
hace falta diseñar el "elder game" hasta que alguien llegue.

Los nombres son hardware y no se traducen, por la misma razón por la que los
rangos (`GUEST` → `KERNEL`) no se traducen: son usuarios de un sistema
operativo y la máquina que los corre. Rango = qué tan bien se jugó *un* nivel;
nivel de jugador = cuánto camino se recorrió. Son dos progresiones y conviene
que no se parezcan.

`progression_version` viaja en el perfil. Si se cambia la tabla, al cargar se
recalcula el nivel desde la XP (que nunca miente) y se anota un evento
`recalibrated` en el historial.

---

## 6. Catálogo de logros

Cada logro es una fila de `AchievementCatalog.BADGES`:
`{id, stat, threshold, kind, ladder, tier, xp, icon, hidden}`. Toda condición
se reduce a "una estadística del perfil llegó a N", así que agregar un logro es
agregar una fila y dos claves al CSV (`BADGE_<ID>_NAME`, `BADGE_<ID>_DESC`).
El smoke test valida la tabla: ids únicos, escaleras con tramos y umbrales
crecientes, estadísticas conocidas y textos presentes.

| Tipo | Logros | Estadística |
| --- | --- | --- |
| Primer contacto (se regalan en la primera partida) | HELLO WORLD, KILL -9, DEFRAG | `runs_started`, `windows_closed`, `rooms_cleared` |
| Escalera de ventanas | END TASK (5), END PROCESS TREE (25), TASKKILL /F (100), FORMAT C: (500) | `windows_closed` |
| Escalera de cierres por la X | ALT+F4 I/II/III (10, 50, 200) | `closed_close` |
| Escalera de salas | DEFRAG I/II/III (1, 10, 50) | `rooms_cleared` |
| Ejecución | CLEAN BUILD, OVERCLOCK, FIREWALL UP, PIXEL PERFECT | `rooms_perfect`, `banks_at_top`, `no_damage_levels`, `accuracy_100_levels` |
| Rango y campaña | SUDO (S), RING 0 (S+), SYSTEM SHUTDOWN (campaña entera) | `ranks_s`, `ranks_splus`, `campaign_clears` |
| Sorpresa (ocultos hasta ganarlos) | SEGFAULT, BLUE SCREEN, NOT RESPONDING, CTRL+Z, CRON JOB | `traps_hit`, `runs_failed_health`, `runs_failed_time`, `retries`, `late_night_runs` |

Reglas:

- Los nombres son jerga y se escriben igual en los tres idiomas; las
  descripciones sí se traducen. El `id` nunca aparece en pantalla y es contrato
  (viaja en el perfil guardado).
- Un logro se gana una vez y nunca se pierde. Sólo `reset()` los borra, y sólo
  lo usan los tests.
- Los sorpresa convierten fallos en premio: caer en una trampa, quedarse sin
  vida o sin tiempo, reintentar diez veces, jugar de madrugada.
- Los que se evalúan al cerrar el nivel llegan como `quiet`: se listan en la
  pantalla de resultados y no generan globo.

---

## 7. Presentación

- **Globo (`Notices`)**: `CanvasLayer` 130, por encima de los menús y del
  cambio de escena. En el escritorio es el globo amarillo de la bandeja, abajo a
  la derecha sobre la barra; en partida es un panel del HUD, abajo al centro,
  entre los vitales y el log. Cola de a uno, `notice_seconds` (4 s), clic lo
  cierra. Suena `badge_unlocked` o `level_up` si hay stream. Sólo avisa lo que
  pasa en vivo.
- **Log del HUD**: el tracker escribe `LOG_BADGE` y `LOG_LEVEL_UP` en la
  categoría `score`, estén o no en un globo.
- **Cabecera (`ProfileHeader`)**: "NIVEL n — NOMBRE", barra de XP y "x / y XP
  · z XP para SIGUIENTE". Arriba de la ventana del menú principal (abre Mi PC)
  y dentro de la vitrina. El nombre del nivel además vive en la bandeja de la
  barra de tareas.
- **Mi PC (`MyComputerMenu`)**: ventana del escritorio con la cabecera, XP
  total, estadísticas en grilla, contador de logros y grilla de fichas
  (ganados en color, bloqueados en gris con su nombre, ocultos como `???`), y
  los últimos ocho eventos de XP. Se abre desde el icono `mi pc`, el menú de
  inicio y la cabecera.
- **Selector (`LevelSelectMenu`)**: una fila por nivel con rango, % del techo,
  récord, mejor tiempo e intentos (de `ScoreRecords`); `✓` si se completó; los
  bloqueados muestran por qué; un récord de una `formula_version` vieja lleva
  `*` y se atenúa. Se abre desde el botón, el menú de inicio y el icono
  `niveles`.
- **Resultados**: debajo del desglose del puntaje, `ProgressionBreakdown`
  agrega "XP GANADA", "NIVEL DE JUGADOR a → b" o "PRÓXIMO NIVEL: n XP para X",
  una fila por logro nuevo y "NIVEL DESBLOQUEADO" cuando se completó por
  primera vez y hay siguiente. `ScoreBreakdown` no cambia.

---

## 8. Persistencia

`user://profile.cfg` (`ConfigFile`), una sección por bloque de `ProfileData`:

```
[profile]      version, progression_version, created_at, updated_at
[xp]           total, level
[stats]        una clave por estadística (DEFAULT_STATS)
[campaign]     last_played_id, completed, first_clear_at
[achievements] <badge_id> = unix del desbloqueo
[xp_log]       entries (FIFO, xp_log_limit = 100)
```

- Guardado diferido (`save_delay` = 2 s, mismo patrón que `Settings`) y
  `flush()` al cerrar el juego, al cerrar una partida (`record_run`) y antes de
  cada cambio de escena. En la exportación web cada escritura es una
  transacción contra IndexedDB: una sala entera es una sola.
- Un archivo que no existe es un jugador nuevo. Uno ilegible se copia a
  `profile.cfg.bak`, se avisa con `push_warning` y se empieza de nuevo. Uno de
  una versión más nueva se respalda antes de la primera escritura.
- `progression_version` distinto → se recalcula el nivel desde la XP.
- En headless (`DisplayServer.get_name() == "headless"`) el perfil escribe en
  `user://profile.test.cfg`: los smoke tests juegan niveles de verdad y no
  tienen por qué sumarle XP al jugador. Los tests visuales, que no son
  headless, respaldan y restauran el archivo.
- `ScoreRecords` (`user://score_records.cfg`) queda como estaba: es por nivel y
  versionado por fórmula; el perfil es por jugador. Un multi-perfil futuro sólo
  cambia rutas.

Desbloqueo de niveles: derivado, no guardado. El nivel `i` está abierto si
`i == 0` o el nivel `i - 1` figura en `completed`. Así no puede desincronizarse
con el catálogo. Marcar completado lo hace un solo lugar:
`GameProfile.record_run()`.

---

## 9. Anti-exploit

Lo que ya defiende: nada del disparo paga; los logros son de una vez; la XP
de cierre se paga con un solo `record_run` por partida. Contramedidas
anotadas, no implementadas (fase 3), ambas calculables desde `xp_log.ctx` sin
migrar datos:

- Rendimientos decrecientes por repetición de un mismo `level_id` dentro del
  día (×1.0, ×0.8, ×0.6, piso ×0.25).
- Tope diario de XP por nivel.

Primero se mira si hace falta: el libro insiste en no sobrediseñar la policía
antes de tener jugadores.

---

## 10. Fases siguientes

**Fase 2 — Onboarding y metas por nivel.** Un `nivel-0.json` de una sala con
ventanas `close_window`, sin trampas ni daño y sin texto: la primera ventana
enseña, y `HELLO WORLD`, `KILL -9` y `DEFRAG` caen ahí. Desafíos por nivel
declarados en el JSON (`challenges: [{id, type, value}]` — sin daño, ≥ 80 % del
techo, sólo X) evaluados desde el `summary`, con XP fija, visibles en el
selector y en resultados, y editables en el Level Workshop. Récord por sala.

**Fase 3 — Enganche y expansión.** Escritorio personalizable (fondos del pack
XP y temas de ventana desbloqueados por rango y por nivel de jugador; sección
`[desktop]` en el perfil). Fantasma del mejor intento (marcas por sala,
"+3 s / −2 s"). Multi-perfil (`user://profiles/<slot>.cfg` y pantalla de
bienvenida). Rendimientos decrecientes (§9). `run_hash` determinista en
`record_run` para validar rankings online después. Power: el Level Workshop y
el Block Lab como iconos que aparecen al subir de nivel.

---

## 11. Lo que quedó armado

| Pieza | Archivo |
| --- | --- |
| Perillas de progresión | [`resources/gameplay/progression_settings.tres`](../resources/gameplay/progression_settings.tres) |
| Estado del perfil | [`scripts/progression/profile_data.gd`](../scripts/progression/profile_data.gd) |
| Catálogo de logros | [`scripts/progression/achievement_catalog.gd`](../scripts/progression/achievement_catalog.gd) |
| Puente ronda → perfil | [`scripts/progression/achievement_tracker.gd`](../scripts/progression/achievement_tracker.gd) |
| Autoload del perfil | [`scripts/autoloads/player_profile.gd`](../scripts/autoloads/player_profile.gd) |
| Globos de aviso | [`scripts/autoloads/notices.gd`](../scripts/autoloads/notices.gd), [`scripts/ui/notice_balloon.gd`](../scripts/ui/notice_balloon.gd) |
| Filas de XP en resultados | [`scripts/ui/progression_breakdown.gd`](../scripts/ui/progression_breakdown.gd) |
| Cabecera y ficha de logro | [`scripts/ui/menus/profile_header.gd`](../scripts/ui/menus/profile_header.gd), [`scripts/ui/menus/badge_tile.gd`](../scripts/ui/menus/badge_tile.gd) |
| Mi PC | [`scripts/ui/menus/my_computer_menu.gd`](../scripts/ui/menus/my_computer_menu.gd) |
| Selector de niveles | [`scripts/ui/menus/level_select_menu.gd`](../scripts/ui/menus/level_select_menu.gd) |
| Secuencia con posición recordada y desbloqueo | [`scripts/autoloads/level_sequence.gd`](../scripts/autoloads/level_sequence.gd) |
| Textos | [`resources/i18n/strings.csv`](../resources/i18n/strings.csv) (`PROFILE_*`, `XP_*`, `LEVELUP_*`, `BADGE_*`, `SELECT_*`, `LOG_BADGE`, `LOG_LEVEL_UP`) |
| Pruebas | `tests/progression_smoke_test.gd`, `tests/profile_persistence_smoke_test.gd`, `tests/achievements_smoke_test.gd`, `tests/level_select_smoke_test.gd`; vistas en `tests/menu_visual_smoke_test.tscn` |

Deuda anotada: arte propio para los logros (hoy reusan los iconos del pack de
Windows XP).
