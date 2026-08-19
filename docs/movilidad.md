# Movilidad

El controlador de [`player_character.gd`](../Player_Controller/scripts/Player_Character/player_character.gd)
sigue el modelo de Quake que usa Counter-Strike 1.6: se corre siempre, no hay
estamina, y la velocidad se gobierna con friccion y aceleracion vectorial en vez
de interpolar hacia una velocidad objetivo.

## Velocidades

| Modo | Velocidad | Equivalente en unidades de CS |
| --- | --- | --- |
| Correr (por defecto) | 6.4 m/s | ~250 u/s |
| Caminar (Shift) | 3.4 m/s | ~134 u/s |
| Agachado | 2.3 m/s | ~90 u/s |

No existe el sprint: correr es el estado normal y Shift sirve para lo contrario,
moverse despacio para apuntar mejor y hacer menos ruido.

## Suelo: friccion y aceleracion

`apply_friction()` copia `sv_friction`: cada frame quita una porcion de la
velocidad proporcional a ella misma, con un piso definido por `stop_speed` para
que el ultimo tramo no se eternice. Al soltar las teclas el jugador se detiene en
unos 0.28 s y 0.74 m: se nota el derrape, pero es corto.

`accelerate()` copia `sv_accelerate`: solo suma lo que falta para llegar a la
velocidad deseada **medido en la direccion pedida**. Desde parado se llega al 95%
de la velocidad plena en 0.15 s.

## Aire: strafe y bunny hop

En el aire se usa la misma funcion con `air_speed_cap` (0.8 m/s) como velocidad
deseada. Ese tope bajo es lo que hace que girar la vista mientras se mantiene una
tecla lateral sume velocidad en lugar de reemplazarla, o sea el airstrafe de toda
la vida.

Con `auto_bhop` activo, mantener el salto vuelve a saltar en el primer frame en
que se toca el suelo, y como ese frame no aplica friccion, la velocidad se
conserva entre saltos. Encadenando saltos con strafe la velocidad sube unos
0.65 m/s por salto hasta `max_air_speed` (9.6 m/s, 1.5 veces la de correr), que
esta ahi para que no se descontrole. Poner `auto_bhop = false` obliga a pulsar
salto en cada rebote.

## Salto

`jump_height` (1.15 m) y `jump_gravity` (20.5 m/s²) dan un salto de 0.67 s en el
aire, practicamente el de CS 1.6. `fall_gravity_scale` hace la caida un poco mas
rapida que la subida para que no se sienta flotante.

Dos ayudas modernas que no estan en CS pero se agradecen:

- `coyote_time`: se puede saltar hasta 0.1 s despues de dejar un borde.
- `jump_buffer_time`: un salto pulsado hasta 0.15 s antes de aterrizar sale solo
  al tocar el suelo.

Al aterrizar de una caida fuerte la vista se hunde (`landing_dip`) y se recupera
sola, usando el mismo sistema que el retroceso del arma.

## Relacion con la punteria

La velocidad del jugador alimenta la dispersion del arma: correr abre la mira,
saltar la abre mucho mas y agacharse la cierra. Los valores viven en el
`RecoilProfile` del arma, no aca. Ver [`docs/arma.md`](arma.md).

## Pruebas

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/player_movement_smoke_test.gd`

Mide el arranque, la frenada, la altura y duracion del salto, que el aire
conserve el impulso, que mantener el salto encadene rebotes y que no quede rastro
del sistema de estamina.
