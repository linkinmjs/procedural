class_name HudStyle
extends RefCounted

## Fuente de verdad del lenguaje visual del HUD: paleta semantica y constantes
## de animacion. Todo lo que pinta o anima UI in-game lee de aca; el theme
## (resources/themes/hud_theme.tres) espeja estos valores para los estilos
## estaticos, pero ante cualquier duda manda este archivo.
##
## Es una clase estatica y no un autoload a proposito: los smoke tests headless
## compilan los scripts antes de que existan los autoloads, y un identificador
## global romperia la compilacion. `class_name` + constantes funciona en los dos
## mundos y ademas permite usar los valores en expresiones `const` ajenas.

# ---------------------------------------------------------------------------
# Paleta semantica
# ---------------------------------------------------------------------------

## Cian principal: titulos, headers y texto de acento.
const ACCENT := Color(0.42, 0.90, 1.00)
## Cian saturado de las esquinas recortadas y marcas de CyberPanel.
const ACCENT_BRIGHT := Color(0.00, 0.88, 1.00)
## Dorado del dinero: score, cobros, filas de total.
const ACCENT_GOLD := Color(1.00, 0.82, 0.28)
## Danio, HP critico, munición vacia.
const DANGER := Color(1.00, 0.22, 0.30)
## Avisos que no duelen: fallos, municion baja.
const WARNING := Color(1.00, 0.68, 0.20)
## Verde de lo logrado: estado activo, records.
const SUCCESS := Color(0.46, 1.00, 0.56)

## Texto protagonista (valores numericos).
const TEXT_PRIMARY := Color(0.86, 0.96, 1.00)
## Texto secundario (log, detalles, cuentas pendientes).
const TEXT_DIM := Color(0.66, 0.82, 0.88)
## Texto terciario (subtitulos, notas al pie).
const TEXT_FAINT := Color(0.55, 0.68, 0.78)

## Fondo y borde del panel oscuro estandar.
const PANEL_BG := Color(0.015, 0.025, 0.045, 0.93)
const PANEL_BORDER := Color(0.08, 0.46, 0.58, 0.85)
## Fondo y borde de las barras (HP, chain timer).
const BAR_BG := Color(0.025, 0.08, 0.12, 1.0)
const BAR_BORDER := Color(0.05, 0.35, 0.45, 1.0)
## Relleno de la barra de vida sana.
const HEALTH_FILL := Color(0.00, 0.82, 1.00)
## Velo oscuro de la presentacion de nivel.
const VEIL := Color(0.01, 0.02, 0.04)
## Contorno negro de los numeros grandes que flotan sobre el juego.
const OUTLINE := Color(0.0, 0.0, 0.0, 0.75)

## Color por escalon de la cadena. El ultimo se repite si hay mas escalones.
const STEP_COLORS: Array[Color] = [
	Color(0.66, 0.76, 0.84),
	Color(0.42, 0.90, 1.00),
	Color(0.36, 1.00, 0.78),
	Color(0.72, 1.00, 0.38),
	Color(1.00, 0.90, 0.30),
	Color(1.00, 0.58, 0.24),
	Color(1.00, 0.30, 0.42),
]
## Colores del cierre forzado de la cadena, por motivo: el danio y la trampa
## duelen en rojo/naranja, el timeout se apaga en gris sin violencia.
const LOST_COLORS := {
	"damage": Color(1.0, 0.32, 0.32),
	"trap": Color(1.0, 0.52, 0.2),
	"timeout": Color(0.55, 0.6, 0.65),
	"round_ended": Color(0.55, 0.6, 0.65),
}
## Color por tipo de evento del log.
const LOG_COLORS := {
	"system": Color(0.3, 0.85, 1.0),
	"hit": Color(0.45, 1.0, 0.45),
	"miss": Color(1.0, 0.68, 0.2),
	"danger": Color(1.0, 0.22, 0.3),
	"score": Color(1.0, 0.82, 0.28),
	"info": Color(0.72, 0.82, 0.9),
}
## Barra del chain timer: color base y color de urgencia.
const TIMER_BASE_COLOR := Color(0.36, 0.92, 1.0)
const TIMER_DANGER_COLOR := Color(1.0, 0.32, 0.28)

# ---------------------------------------------------------------------------
# Constantes de animacion (Fox: toda transicion < 1s; el jugador nunca espera)
# ---------------------------------------------------------------------------

## Destello corto (flash de color al cambiar algo).
const DUR_FLASH := 0.15
## Punch de escala con retorno TRANS_BACK.
const DUR_PUNCH := 0.22
## Numeros que ruedan hasta su valor nuevo.
const DUR_ROLL := 0.4
## Vuelta al reposo despues de un realce (settle).
const DUR_SETTLE := 0.4
## Fade de salida de un elemento que se retira (en vez de desaparecer seco).
const DUR_HIDE := 0.25
## Micro retroceso antes de un punch grande (anticipacion).
const DUR_ANTICIPATION := 0.05
## Entrada de un panel (slide + fade).
const DUR_SLIDE_IN := 0.35
## Distancia del slide de entrada, en px hacia la esquina propia.
const SLIDE_DISTANCE := 24.0
## Retardo entre paneles al entrar en cascada (stagger).
const STAGGER := 0.08
## Opacidad de los vitales en reposo: presentes pero sin estorbar.
const DIM_ALPHA := 0.55
## Segundos que un vital queda encendido despues de cambiar.
const DIM_HOLD := 1.2
## Vida de una linea del log antes de desvanecerse, y duracion del fade.
const LOG_LIFE := 6.0
const LOG_FADE := 0.8
## Entrada de una linea nueva del log.
const DUR_LOG_IN := 0.2
## Fade del panel de nivel al auto-ocultarse / reaparecer.
const DUR_PANEL_FADE := 0.5
## Segundos que el panel de nivel queda visible tras arrancar la ronda.
const LEVEL_PANEL_HOLD := 4.0
## Segundos que reaparece ante un evento de sala.
const LEVEL_PANEL_PEEK := 2.5
## Umbral de HP critico (fraccion del maximo).
const HEALTH_CRITICAL_RATIO := 0.25
## Umbral de municion baja (fraccion del cargador).
const AMMO_LOW_RATIO := 0.2
## Segundos finales del reloj que disparan el tick de urgencia.
const TIME_URGENT_SECONDS := 10
