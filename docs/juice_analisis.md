# Análisis de "juice": dónde y cómo hacer que el juego se sienta mejor

Relevamiento de todos los puntos del juego donde falta feedback audiovisual,
con las opciones evaluadas y lo que se decidió. La primera tanda ya está
implementada (ver al final); el resto queda como backlog priorizado.

## Diagnóstico

El único momento con juice completo era el **disparo de la Glock** (muzzle
flash + luz, casquillos, 3 variaciones de sonido, recoil estilo CS 1.6,
crosshair dinámico). Todo lo que ocurre después de que la bala sale carecía de
feedback: impactos, muertes de objetivos, oleadas, daño recibido, pickups y UI.

La arquitectura ya estaba lista para engancharlo: `RoundController` emite
`shot_resolved`, `target_resolved`, `damage_taken`, `room_entered`,
`room_cleared`, y `ScoreController` emite `chain_changed` / `chain_banked`
con motivo diferenciado — pero solo alimentaban labels de texto.

## Decisión transversal: audio diferido con ganchos listos

El sonido se integra en una instancia final. Para no retrabajar, existe la
clase estática **`Sfx`** (`scripts/audio/sfx.gd`): cada efecto llama
`Sfx.play("evento")` o `Sfx.play_at("evento", posicion)` con un nombre
estable. Los streams viven en `resources/audio/sfx_library.tres`; un evento
sin stream **no suena y no falla**. Integrar el audio del juego = llenar ese
recurso. La lista de eventos vive en `scripts/audio/sfx_library.gd`.

Nota: `Sfx` es una clase con métodos estáticos y no un autoload a propósito —
los smoke tests corren con `-s` y compilan los scripts antes de que los
autoloads existan, así que un identificador de autoload no compila ahí. El
host con los reproductores (pools de `AudioStreamPlayer`/`3D`, bus `SFX`) se
cuelga solo del árbol la primera vez que algo suena.

Fuentes sugeridas para ese momento: híbrido temático — packs CC0 de Kenney
(Impact / Interface / Digital Audio) para lo físico, sonidos estilo
retro/Windows para ventanas y UI. Inventario priorizado en
`docs/gdd_atractivo_y_progresion_ANEXO_sonido.md`.

## Mapa de oportunidades

### 1. Impacto de bala ✅ implementado
Era un sprite de debug de 1 s sin orientar. Ahora: `scenes/effects/bullet_impact.tscn`
(Decal orientado a la normal con fade + chispas GPUParticles3D + gancho
`impact_wall`). Contra objetivos no deja decal (moriría flotando). De paso se
corrigió el `queue_free()` mal indentado de `projectile.gd` (los tiros a pared
vivían 10 s).
- Descartado por ahora: sistema de impacto por material (chispas en metal,
  polvo en pared) — no hay metadata de superficie todavía.

### 2. Muerte de objetivos ✅ implementado
- **Bolas** (`target_ball.gd`): pop (infla → colapsa) + esquirlas emisivas del
  color de la bola + gancho `target_destroyed`. Colisión apagada al morir.
- **Ventanas** (`window_panel_3d.gd`): animación por familia, para que la
  muerte comunique qué se mató:
  - genérica / descarga → **minimizar** (se encoge y cae, estilo escritorio)
  - publicidad, error crítico y firewall → **apagado CRT** (colapsa a una
    línea y se apaga, estilo monitor viejo)
- Catálogo evaluado para variantes futuras: glitch/corrupción (shader),
  disolución en píxeles (shader), "no responde" (velo blanco), caída física,
  rastro fantasma XP, "a la papelera". El shatter de cristal se descartó por
  costo/beneficio frente al CRT.

### 3. Juice de ventanas (interacción) ✅ implementado
- **Botón presionado estilo Windows**: al acertar una zona, su Control real se
  hunde 1 px y se oscurece un instante (el contenido es UI de verdad en un
  SubViewport). Gancho `window_button`.
- **Sacudida de pantalla** al recibir cualquier tiro (mueve solo el quad, no el
  nodo raíz: la posición del raíz es estado del raise/bloque).
- **Firewall**: flash del tinte azul + gancho `shield_blocked` cuando un tiro
  rebota; al caer el firewall, el tinte de las hermanas se funde con tween en
  vez de saltar (era invisible el momento más táctico del juego).
- **Error crítico**: el shuffle de botones ahora se desliza animado (antes se
  teletransportaba y parecía un glitch) + flash rojo + gancho `window_error`.
- **Publicidad**: el botón SKIP pulsa al quedar disponible + gancho
  `ad_skip_ready`.
- **Aparición**: todas las ventanas nacen con scale-in rápido estilo XP.

### 4. Camera shake ✅ implementado
Sistema trauma-based en `player_character.gd`: `add_trauma(0..1)`, amplitud
trauma², tres canales de FastNoiseLite (pitch/yaw/roll), decaimiento solo.
Integrado dentro de `apply_view_rotation()` porque la Basis se reconstruye ahí
(un offset externo se pisaría). Hoy lo alimenta el daño recibido; queda listo
para explosiones, crashes de bloque y sellado de puertas.
- Descartado: tweens puntuales por evento (no componen entre sí).

### 5. Daño recibido ✅ implementado
Antes el jugador no percibía el golpe. Ahora: vignette roja radial (generada
por código sobre el `Overlay` que el template dejó cableado a una señal
muerta) + trauma de cámara + gancho `player_hurt`. Conectado a
`RoundController.damage_taken` por grupo.
- Pendiente evaluar: indicador direccional de daño (solo si el daño gana
  dirección en el gameplay).

### 6. Hitmarker ✅ implementado
Era un flicker de 0.05 s. Ahora: entra a 1.6x, asienta con ease y se funde
(~0.25 s total) + gancho `hitmarker`.
- Pendiente: variante para kill/destrucción (necesita plumbing: la señal
  `Hit_Successfull` del proyectil no distingue si el objetivo murió).

### 7. Combos ✅ implementado (`score_hud.gd`)
- **Escalar**: punch de escala + destello blanco→color al subir de escalón;
  gancho `combo_step_up` con pitch creciente por escalón (la escalada se oye
  sin mirar el HUD).
- **Mantener**: la barra del timer funde a rojo cerca del final y parpadea en
  el tramo crítico; gancho `chain_tick` de urgencia. **"Salvada"**: acierto
  con el timer bajo el 15% → punch + gancho `chain_saved`.
- **Perder**: caída de escalón → sacudida + destello rojo (`combo_drop`).
  Cierre forzado (daño/trampa/timeout, cobra a x1) → color por motivo (rojo,
  naranja, gris) + sacudida si fue golpe + **"(-N)" con lo perdido**: el costo
  de oportunidad a la vista es el motivador real para cuidar la racha. Gancho
  `chain_lost`.
- **Cobrar** (sala limpiada): dorado + punch grande + **rolling counter** (el
  número rueda de 0 al total, y el marcador global también rueda siempre).
  Gancho `bank`.

## Backlog priorizado (tandas siguientes)

1. **Números flotantes 3D** ("+80") en el punto de impacto con el color del
   escalón — el jugador ve el valor donde mira. `Label3D` billboard + tween.
2. **HUD de vitals animado** (`game_hud.gd`): barra de HP con ghost bar
   (segunda barra que baja con delay), punch del contador de munición al
   disparar, parpadeo real de low-ammo.
3. **Puertas de sala** (`room_door_3d.gd`): materializarse con tween de
   emisión/alpha (~0.3 s) + trauma leve al sellarse. Hoy es un toggle de
   `visible`.
4. **Spawn de bloques/oleadas**: scale-in de bloques; banner central breve de
   oleada ("OLEADA 2/3") reutilizando el patrón de `level_intro.gd`.
5. **Pickup de munición**: rotación + bobbing + glow, toast "+N munición".
6. **Transiciones de escena** (`level_sequence.gd`): fade a negro global; hoy
   es corte seco.
7. **Polish del arma**: `empty_sound` (campo ya existe, vacío), humo de cañón,
   sway al caminar, corredera trabada al vaciar.
8. **Pantalla azul del bloque** (`target_block_3d.gd`): flicker de encendido +
   sonido.
9. **Variantes de muerte de ventana con shader**: glitch/corrupción y
   disolución en píxeles (requieren pasar el material del quad a
   `ShaderMaterial` conservando la ViewportTexture; ojo con el alpha scissor).
10. **Integración de audio**: llenar `resources/audio/sfx_library.tres` con
    los eventos listados en `scripts/audio/sfx_library.gd` + los sonidos de
    arma que van por `AnimationPlayer` (recarga, click en seco).

## Deuda técnica relacionada

- `round_controller.gd:59` usa la ruta hardcodeada
  `"Camera/LeanPivot/MainCamera/Weapons_Manager"` — frágil ante cualquier
  reorganización de la jerarquía de cámara.
- `weapon_state_machine.gd:23` preloadea `hit_debug.tscn` sin usarlo (muerto
  tras el reemplazo por `bullet_impact.tscn`).
