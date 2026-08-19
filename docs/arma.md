# La Glock

El jugador lleva una sola arma: una Glock semiautomatica con cargador de 10 balas.
Reemplaza a los blasters del FPS Template original, que quedan en el repositorio
como material de referencia pero ya no aparecen en ninguna escena jugable.

## Piezas del sistema

| Archivo | Que define |
| --- | --- |
| [`resources/weapons/glock.tres`](../resources/weapons/glock.tres) | Cargador, reserva, dano, alcance, animaciones y sonido. |
| [`resources/weapons/glock_recoil.tres`](../resources/weapons/glock_recoil.tres) | Retroceso de camara e imprecision dinamica. |
| [`scenes/weapons/glock_view_model.tscn`](../scenes/weapons/glock_view_model.tscn) | Modelo en primera persona, con corredera, cargador y fogonazo. |
| [`resources/animations/glock_animation.tres`](../resources/animations/glock_animation.tres) | Animaciones `Active`, `Shoot`, `Reload`, `De-Activate`, `Drop`, `OOA` y `Melee`. |
| [`scenes/weapons/glock_ammo_pickup.tscn`](../scenes/weapons/glock_ammo_pickup.tscn) | Caja de municion del poligono de armas: suma 10 balas a la reserva. |
| [`resources/audio/glock_shoot.tres`](../resources/audio/glock_shoot.tres) | Randomizador de los tres samples de disparo. |

El arma vive en el `weapon_stack` de
[`player_character.tscn`](../scenes/player/player_character.tscn), con
`max_weapons = 1`. Ninguna escena agrega armas extra al stack.

## Cambiar el cargador

`magazine` en `glock.tres` es el tamano del cargador (hoy 10) y `max_ammo` el
tope de la reserva (hoy 60). Subir `magazine` no requiere tocar nada mas: la
recarga, el HUD y el contador de la ronda leen el mismo valor.

## Retroceso e imprecision

`RecoilProfile` ([`recoil_profile.gd`](../scripts/weapons/recoil_profile.gd))
expresa todo en grados, asi que los valores no dependen de la resolucion ni del
FOV. El comportamiento imita al Counter-Strike 1.6:

- **Patada de camara**: cada disparo empuja la vista hacia arriba y un poco a un
  lado. La patada crece con la rafaga (`vertical_kick_growth`) hasta el tope
  (`max_vertical_kick`) y la vista vuelve sola al punto original al soltar el
  gatillo (`recovery_speed`). Lo aplica `add_recoil()` en
  [`player_character.gd`](../scripts/player/player_character.gd).
- **Imprecision**: el primer disparo quieto y en el suelo es exacto
  (`base_spread = 0`). A partir de ahi suman `spread_per_shot` por disparo,
  `move_spread` segun la velocidad del jugador y `air_spread` mientras esta en
  el aire; agacharse la reduce con `crouch_multiplier`. La dispersion baja sola
  a `spread_recovery` grados por segundo y el contador de rafaga se reinicia
  tras `shot_reset_time` sin disparar.
- **Mira**: `Weapon_State_Machine` emite `spread_changed` con la dispersion ya
  convertida a pixeles y
  [`dynamic_crosshair.gd`](../scripts/player/dynamic_crosshair.gd)
  abre los cuatro trazos exactamente esa cantidad. El hueco de la mira es la
  dispersion real del disparo, no un adorno.

Un arma sin `RecoilProfile` dispara como antes: sin patada y con el
`Spray_Profile` clasico si lo tiene.

## Pruebas

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/glock_weapon_smoke_test.gd`

Revisa el cargador de 10, la recarga completa, las animaciones declaradas, la
patada de camara, la imprecision al moverse o saltar y la recuperacion de la
vista.

Para mirar el arma: `Godot_v4.7-stable_win64_console.exe --path . res://tests/glock_visual_smoke_test.tscn`
guarda en `.godot/` capturas del arma en reposo, disparando, recargando y con la
mira abierta.

## Pendientes conocidos

- No hay sonido de recarga ni de gatillo en seco: `glock.tres` deja
  `empty_sound` vacio a la espera de esos samples.
- La corredera no queda trabada atras al vaciar el cargador.
