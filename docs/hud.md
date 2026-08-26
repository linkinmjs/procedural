# HUD in-game

Rediseño basado en *Game Interface Design* (Brent Fox, `docs/pdfs/`): mínimo
espacio de pantalla, centro despejado, información agrupada por esquina, un
único focal point (el combo), display gráfico sobre números, contenido dinámico
que se atenúa cuando no es relevante, y animación con ease/anticipación/stagger
siempre por debajo del segundo.

## Layout: esquinas limpias

```
┌─────────────────────────────────────────────┐
│ NIVEL · estado ronda        SCORE   12 450  │  arriba-izq: LevelInfoPanel (auto-hide)
│ (auto-hide)                  ×3 ▂▂▂▂▂▂      │  centro-arriba: ComboBox (focal point)
│                                             │  arriba-der: ScorePanel
│                  ✛  centro despejado        │
│                                             │
│ ♥ ████████░░ 80          · headshot +150    │  abajo-izq: VitalsPanel (dim 0.55)
│ ⬦ 12/30   ⏱ 1:24         · líneas fade 6s   │  abajo-der: LogPanel (líneas efímeras)
└─────────────────────────────────────────────┘
```

La **precisión no vive en el HUD**: viaja en el summary de `level_scored`
(`hits`, `attacks`, `accuracy_percent`, agregados en
`scripts/gameplay/score_controller.gd`) y la muestra la pantalla de resultados
vía `ScoreBreakdown.rows_for` (`SCORE_ACCURACY`).

### Capas de CanvasLayer

| Capa | Dueño |
|---|---|
| 1 | HUD del jugador (crosshair, hitmarker, vignette) — `scenes/player/player_character.tscn` |
| 10 | `LevelInterface` (LevelInfoPanel) — `scenes/levels/playable_level.tscn` |
| 20 | `GameHUD` (vitals + log) — `scenes/ui/round_hud.tscn` |
| 21 | `ScoreHUD` (combo + score) — `scenes/ui/score_hud.tscn` |
| 64 | `LevelIntro` |
| 128 | `MenuStack` |

### Estructura por capa

Cada CanvasLayer de HUD repite el mismo esqueleto, porque un CanvasLayer no es
Control y **no propaga theme**:

```
CanvasLayer
└─ HudRoot (Control full-rect, theme = hud_theme.tres, mouse_filter IGNORE)
   └─ SafeArea (MarginContainer full-rect, márgenes 20/16)
      └─ Layout (Control full-rect)
         └─ paneles anclados por esquina
```

Los paneles inferiores viven dentro de un **slot** (`VitalsSlot`/`LogSlot`, un
`VBoxContainer` anclado como columna con `alignment = END`): el slot abraza al
panel a su tamaño mínimo y lo apoya contra el borde inferior. Sin el slot, un
panel anclado abajo cuyo contenido supera el alto autorado crece hacia abajo y
se sale de pantalla (la expansión por min-size no respeta `grow_vertical`).
Las animaciones de posición (entrada, sacudida) mueven al **slot** —que no está
gobernado por ningún container— y nunca al panel.

## Fuente de verdad del estilo: `HudStyle`

`scripts/ui/hud_style.gd` (`class_name HudStyle`, clase estática) concentra:

- **Paleta semántica**: `ACCENT`, `ACCENT_BRIGHT`, `ACCENT_GOLD`, `DANGER`,
  `WARNING`, `SUCCESS`, `TEXT_PRIMARY/DIM/FAINT`, `PANEL_BG/BORDER`,
  `BAR_BG/BORDER`, `HEALTH_FILL`, `VEIL`, `OUTLINE`, más los diccionarios
  dinámicos (`STEP_COLORS`, `LOST_COLORS`, `LOG_COLORS`, colores del timer).
- **Constantes de animación**: duraciones, stagger, `DIM_ALPHA`, umbrales
  (`HEALTH_CRITICAL_RATIO`, `AMMO_LOW_RATIO`, `TIME_URGENT_SECONDS`).

Es clase estática y no autoload a propósito: los smoke tests headless compilan
los scripts antes de que existan los autoloads. Consumidores actuales:
`game_hud.gd`, `score_hud.gd`, `level_info_panel.gd`, `level_intro.gd`,
`menus/level_results.gd`, `menus/game_panel.gd`.

`resources/themes/hud_theme.tres` **espeja** esos valores para los estilos
estáticos (fuentes, tamaños, colores base, `PanelDark`). Ante una discrepancia,
manda `HudStyle`; si cambiás un color ahí, actualizá el theme.

Los estilos de las barras (`HealthFill`, `TimerFill`) quedan como SubResources
por escena con `resource_local_to_scene`, porque los scripts les mutan
`bg_color` en runtime (flash, urgencia): no pueden ser recursos compartidos del
theme.

## Tipografía

`assets/fonts/hud/` (importadas con MSDF para escalar nítido):

- **Charge Vector** (Regular/Bold/Black/Thin): números y títulos. Dígitos de
  ancho uniforme: los contadores no "bailan" al rodar.
- **CQ Mono**: log y cuentas (`HudPending`), monoespaciada.

Ambas cubren los glifos de es/pt/en. El pack completo de fuentes
(`assets/fonts/<Categoría>/`) está excluido del import con un `.gdignore` por
carpeta: Godot no debe importar ~1200 fuentes. **Para usar una fuente nueva**:
copiala a `assets/fonts/hud/` (fuera de las carpetas ignoradas), verificá
cobertura de glifos es/pt/en, importá con MSDF y sumala al theme. Nunca pongas
`.gdignore` en la raíz de `assets/fonts/` (ahí vive `tahoma.ttf`, del theme XP).

### Type variations del theme (Labels)

| Variation | Uso |
|---|---|
| `HudTitle` | Nombre del nivel (20px Bold) |
| `HudHeader` | Headers `// ...` de paneles (11px) |
| `HudRowLabel` | Rótulos HP/AMMO/TIME (12px cian) |
| `HudValue` | Valores de vitals (18px Bold) |
| `HudScore` | Total del marcador (26px Bold) |
| `HudComboHits` / `HudComboMult` | Contador del combo (44/30px Black + outline) |
| `HudPending` | Cuenta del pozo (14px CQ Mono + outline) |
| `HudLog` | Líneas del log (12px CQ Mono) |
| `HudStatus` | Estado de ronda (10px verde) |

Los colores que son **estado de juego** (escalón del combo, kind del log, HP
crítico) se pintan con `add_theme_color_override` desde el script, nunca con
`LabelSettings` (pisa theme y modulate; ya no queda ninguno en el HUD).

## Dinamismo y juice

| Elemento | Trigger | Animación | Principio (Fox) |
|---|---|---|---|
| Paneles | bind inicial | slide-in desde su borde + fade, stagger 0.08s (nivel→score→vitals→log) | entrada en cascada |
| Vitals en reposo | — | `modulate.a = DIM_ALPHA` (0.55) | espacio negativo |
| Vitals al cambiar | `health/ammo/time_changed` | alpha 1, hold 1.2s, settle 0.4s | contenido dinámico |
| HealthBar | daño | value tweened + flash blanco→color + shake ±4px del slot | gráfico > números |
| HP crítico ≤25% | `health_changed` | panel fijo en alpha 1 + pulso (tween en loop) | color-coding DANGER |
| Munición | disparo | punch 1.08; ≤20% cargador WARNING; 0 DANGER | feedback por disparo |
| Tiempo ≤10s | `time_changed` | tick por segundo: punch 1.15 + DANGER | urgencia |
| Log | `log_added` | fade-in 0.2s; vive 6s; fade-out 0.8s; máx 5 líneas | nunca acumular ruido |
| Score | `score_changed` | roll 0.4s + punch 1.12 (pivot derecho) | el marcador cobra |
| Combo | `chain_changed`/`chain_banked` | punch con anticipación (0.96 por 0.05s), shake, flash, cobro dorado rodando, fade-out 0.25s al retirarse | anticipación / focal point |
| LevelInfoPanel | ronda/salas | visible 4s tras `round_started`, reaparece 2.5s por evento de sala, fade 0.5s | auto-ocultar |

Convenciones: todo tween se guarda en una variable y se hace `kill()` antes de
recrear; los tweens de líneas del log cuelgan de la línea (`line.create_tween()`)
y mueren con ella; los pulsos en loop son tweens `set_loops()`, no cálculos por
frame.

## Conexión con gameplay

Sin event bus: cada pieza se auto-bindea por grupo con `call_deferred`
(`round_controller` / `score_controller`) y escucha señales. Un `bind()`
explícito manda sobre el grupo. Piezas: `game_hud.gd`, `score_hud.gd`,
`level_info_panel.gd`, `scripts/player/hud.gd` (solo `damage_taken`).

## Agregar cosas

- **Un panel nuevo**: elegí esquina; colgalo de `Layout` con preset de esquina
  (arriba) o dentro de un slot (abajo); `CyberPanel` para el marco; labels con
  type variation; entrada con `_enter_panel`-style + stagger; colores de
  `HudStyle`.
- **Un kind de log nuevo**: color en `HudStyle.LOG_COLORS` y listo
  (`RoundController.add_log(msg, kind)`).

## Tests

```
# estructura y dinamismo (headless)
Godot_v4.7...console.exe --headless --path . -s res://tests/hud_structure_smoke_test.gd
# capturas (con ventana; PNGs en .godot/)
Godot_v4.7...console.exe --path . res://tests/hud_visual_smoke_test.tscn
Godot_v4.7...console.exe --path . res://tests/score_hud_visual_smoke_test.tscn
```

El binario vive en `C:/Users/Mauri/Godot/Godot_4.7/`. Los nombres de nodos
`RoundController`, `ScoreController`, `ScoreHUD` y `ComboBox` son contrato de
los tests: no renombrarlos.
