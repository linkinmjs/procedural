# Anexo — Sistema de puntuación

Anexo del eje 1 de [`gdd_atractivo_y_progresion.md`](gdd_atractivo_y_progresion.md).

**Estado:** En definición. Las fórmulas y los números son propuestas de arranque
pensadas para prototipar y ajustar, no valores finales.

## 1. Alcance

Este documento define **qué mide la puntuación, cómo se calcula, cómo se muestra
y qué se hace con el resultado**. No define el catálogo de ventanas ni el
contenido del lobby; sí define los enganches que esos sistemas van a necesitar.

Todo lo que se propone acá está pensado sobre las mecánicas que el juego ya
tiene: movilidad tipo CS 1.6, una Glock semiautomática, reserva de munición
finita por nivel, salas que se sellan hasta destruir el último objetivo, oleadas
que no reaparecen, y ventanas que sólo se rompen acertando zonas chicas.

---

## 2. Principio rector

Antes de cualquier fórmula hay que contestar una sola pregunta: **¿qué significa
jugar bien en este juego?**

Propuesta:

> Jugar bien es eliminar la amenaza gastando poco: pocas balas, poco tiempo y
> nada de salud. La puntuación mide **eficiencia bajo presión**, no velocidad.

Esta elección no es arbitraria, sale de lo que el juego ya es:

- El arma es semiautomática y de cargador chico. Spamear el gatillo ya se castiga
  solo con el retroceso y la apertura de la mira.
- La reserva de munición es finita y se repone por sala. Cada bala fallada ya es
  un costo real.
- Las ventanas se atraviesan si disparás al centro. El juego ya pide apuntar a
  una zona chica en vez de al bulto.
- Los bloques avanzan y cruzarlos duele. El tiempo ya es una amenaza física, no
  un número.

La puntuación no debería inventar una presión nueva: tiene que **hacer visible la
presión que el juego ya ejerce**. Si la fórmula premiara sólo velocidad,
empujaría al jugador a correr y disparar al bulto, que es exactamente lo que la
Glock y las zonas chicas están diseñadas para castigar. El sistema y el puntaje
se pelearían entre sí.

### Lo que el sistema debe premiar

1. Puntería fina: zonas chicas, distancia, tiros difíciles.
2. Continuidad: no frenarse, no dudar entre objetivos.
3. Lectura de prioridades: atender la amenaza correcta primero.
4. Economía: terminar con balas y salud de sobra.

### Lo que el sistema no debe premiar

- Vaciar el cargador contra una pared.
- Esperar a que la situación sea cómoda.
- Repetir la misma acción trivial muchas veces.
- Memorizar una ruta y correrla sin disparar bien.

---

## 3. Anatomía: tres capas y un pozo

El puntaje se arma en tres capas con propósitos distintos. Separarlas evita el
problema clásico de que "el combo lo es todo" y el resto del juego deje de
importar.

| Capa | Qué mide | Cuándo se otorga | Escala típica |
| --- | --- | --- | --- |
| **1. Pozo** | Qué destruiste y con qué calidad | Se acumula durante la cadena | Miles |
| **2. Cadena** | Con qué continuidad lo hiciste | Multiplica el pozo al cobrarlo | ×1 a ×8 |
| **3. Bonos de cierre** | Con qué estado terminaste | Al cerrar sala y nivel | Centenas–miles |

### 3.1 El pozo: los puntos no se cobran al impactar

Ésta es la decisión estructural del sistema. Al destruir un objetivo, sus puntos
**no van al marcador**: van a un **pozo pendiente** que queda a la vista. El pozo
se cobra recién cuando la cadena se cierra, y en ese momento se multiplica entero.

```
puntaje_de_la_cadena = pozo × multiplicador_al_cierre
puntaje_de_la_sala   = Σ cadenas cobradas + bonos de sala
```

Por qué así y no puntos al impacto:

- **Crea una apuesta.** El pozo visible es dinero que todavía no es tuyo. Cuanto
  más grande, más tenés que perder y más querés seguir. Esa tensión es el motor
  del modo, y es gratis: no hay que agregar ninguna regla para producirla.
- **Le da un clímax al encuentro.** Cobrar es un evento con animación, sonido y
  número grande. Los puntos al impacto no tienen momento; el pozo sí.
- **Hace que el multiplicador se sienta.** Ver `4 100 × 6.0` resolverse en
  `24 600` enseña la mecánica sin tutorial.

Regla clave que se mantiene: **la cadena multiplica sólo el pozo, nunca los bonos
de cierre.** Así, el jugador que sostiene una cadena enorme y el que termina
impecable llegan a puntajes comparables por caminos distintos, y ningún estilo se
vuelve obligatorio.

---

## 4. Capa 1 — Valor por acción

### 4.1 Valor por zona

El sistema de ventanas ya emite `zone_hit(zone_id, ventana)`. El `zone_id` alcanza
para tabular valor sin tocar cada ventana a mano.

| Zona | Valor propuesto | Razón de diseño |
| --- | --- | --- |
| `close` (la X) | 100 | Es el blanco más chico. Cerrar por la X es la jugada experta. |
| `accept` / botón | 60 | Blanco grande. Es la salida segura, y debe pagar menos. |
| Cartel / label | 40 | Blanco muy grande, para cuando la ventana no ofrece otra salida. |
| Pelota | 50 | Objetivo genérico de un impacto. |
| Zona trampa | −150 y rompe cadena | El costo de no leer la ventana. |
| `next` / botón | 10 y no rompe cadena | Podemos pensar como una "vida" del cartel |

Esto le da al diseñador de ventanas una perilla expresiva sin código nuevo: una
ventana con X y con botón ofrece **dos precios por el mismo objetivo**. El jugador
elige entre seguro y barato, o difícil y caro. Es la decisión más rica que el
sistema puede regalar gratis, y conviene que la mayoría de las ventanas la tengan.

### 4.2 Modificadores instantáneos

Se aplican al valor base **antes** de entrar al pozo, y son acumulativos:

| Modificador | Factor | Condición |
| --- | --- | --- |
| Distancia | ×1.0 → ×1.3 | Según el tamaño angular de la zona en pantalla. |
| En el aire | ×1.15 | El disparo conecta sin que el jugador pise el suelo. |
| Último segundo | ×1.25 | La amenaza se destruye cerca de activar su penalización. |
| Repetición | ×0.9 acumulativo, piso ×0.5 | Ver sección 8. |

El bono "en el aire" merece una nota: en este juego la mira se abre muchísimo en
el aire, por diseño. Premiarlo **no** es un exploit, es reconocer un tiro que el
propio sistema de armas vuelve difícil, y le da una razón de puntaje al bunny hop
que hoy sólo sirve para desplazarse.

---

## 5. Capa 2 — Cadena y multiplicador

### 5.1 Vocabulario

Conviene fijar cuatro términos que el documento madre marca como confusos:

- **Cadena:** el contador de acciones válidas seguidas (un entero). Es el número
  de *hits*.
- **Multiplicador:** el factor que la cadena produce, y lo que ve el jugador.
- **Pozo:** los puntos acumulados y todavía no cobrados.
- **Estilo:** el reconocimiento cualitativo de *cómo* se hizo (mensajes, no
  números). Se desarrolla en el anexo del eje 3; acá sólo se le reserva el lugar.

### 5.2 Escalones

En vez de un multiplicador continuo, escalones. Se leen de un vistazo, se
celebran con un sonido propio y hacen que perder uno duela sin ser catastrófico.

| Escalón | Cadena (hits) | Multiplicador |
| --- | --- | --- |
| 1 | 0–2 | ×1.0 |
| 2 | 3–5 | ×1.5 |
| 3 | 6–9 | ×2.0 |
| 4 | 10–13 | ×3.0 |
| 5 | 14–18 | ×4.0 |
| 6 | 19–24 | ×6.0 |
| 7 | 25+ | ×8.0 (techo) |

La tabla está comprimida respecto de un modelo de cadena continua porque **la
cadena ahora vive dentro de una sala** (ver 5.5): los escalones altos tienen que
ser alcanzables con la cantidad de objetivos que una sala realmente contiene.
Cada zona acertada cuenta como un hit, así que una ventana de varias etapas
aporta más de uno.

### 5.3 Qué la afecta

| Evento | Efecto sobre el multiplicador | Efecto sobre el pozo |
| --- | --- | --- |
| Destruir un objetivo | +1 hit | Suma su valor |
| Acertar una zona sin cerrar la ventana | +1 hit | Suma su valor |
| **Disparo fallido** | **Baja 2 escalones o más** | Intacto |
| **Recibir daño** | **Cierra la cadena a ×1.0** | Se cobra a ×1.0 |
| Zona trampa | Cierra la cadena a ×1.0 | −150 y se cobra a ×1.0 |
| Vencimiento del temporizador | Baja 1 escalón | Intacto |
| Sala completada | — | Se cobra al multiplicador vigente |

La distinción importante: **hay dos cosas distintas que se pueden perder.** El
fallo hunde el multiplicador pero nunca toca el pozo. El daño no toca el pozo
tampoco, pero lo cobra al peor precio posible. Son dos castigos con texturas
distintas, y el jugador los va a leer como tales.

### 5.4 El castigo por fallar

Un fallo baja **2 escalones**, y los fallos consecutivos escalan:

| Fallo dentro de la misma cadena | Escalones que baja |
| --- | --- |
| 1º (o el primero después de un acierto) | −2 |
| 2º consecutivo | −3 |
| 3º consecutivo y siguientes | −4 |

El contador de fallos consecutivos se reinicia con cada acierto. El piso es el
escalón 1 (×1.0): **fallar nunca cierra la cadena ni cobra el pozo.**

Definición precisa para implementar, porque acá hay una ambigüedad que muerde:
"bajar N escalones" significa que **el contador de hits se fija en el mínimo del
escalón destino**. Ejemplo: con 17 hits estás en el escalón 5 (×4.0); un fallo te
manda al escalón 3 (×2.0), o sea el contador queda en 6.

Por qué −2 y no −1: con un solo escalón de castigo, el jugador puede fallar
seguido y recuperar el terreno con dos aciertos. La penalización tiene que doler
lo suficiente como para que **valga la pena esperar el tiro bueno** en vez de
tirar por tirar — que es exactamente el hábito que la Glock de este juego premia.

Por qué no rompe: una ventana tiene un centro hueco que el disparo atraviesa. Si
un tiro al centro borrara veinte hits, el jugador racional dejaría de arriesgar
tiros a la X y dispararía siempre al botón grande. La fórmula terminaría
empujando al juego tímido que queremos evitar.

Un efecto secundario que vale la pena notar y conservar: como el pozo se cobra al
multiplicador vigente, **un fallo temprano en la sala es barato y uno tardío es
carísimo**. La tensión sube sola a medida que la sala se vacía, sin que haya que
programar nada. El último objetivo de una sala es siempre el tiro más importante.

### 5.5 Alcance: la cadena vive dentro de la sala

**Una cadena empieza al entrar a una sala y se cierra, como muy tarde, al
completarla.** No se transfiere al pasillo ni a la sala siguiente.

Es la decisión que hace calculable todo el resto del sistema: con la cadena
acotada a la sala, **el puntaje máximo de una sala es un número exacto y
computable a partir de su JSON** (ver sección 7), no una estimación. Eso permite
rangos honestos, un editor de niveles que avisa lo que una sala rinde, y récords
que significan algo. Una cadena que cruza todo el nivel sería más espectacular,
pero volvería el techo del nivel imposible de calcular y los rangos, un número
inventado.

Además le da al nivel una estructura legible: **cada sala es una apuesta cerrada**
con su propio arranque, su propia escalada y su propio cobro. El jugador que
arruina una sala no arrastra el desastre a las siguientes.

La cadena se cierra y cobra en tres situaciones:

| Cierre | Multiplicador aplicado | Sensación buscada |
| --- | --- | --- |
| Sala completada | El vigente | El premio. |
| Daño recibido | ×1.0 | El desastre, pero no la ruina. |
| Temporizador vencido en el escalón 1 | ×1.0 | Se apagó solo. |

Cuando la cadena se cierra por daño o por abandono en medio de una sala, **arranca
una cadena nueva ahí mismo**: la sala puede cobrar más de una vez. Eso mantiene
vivo al jugador que se equivoca temprano, en vez de dejarlo jugando una sala que
ya no vale nada.

### 5.6 Temporizador

- Ventana de gracia: **3 segundos**, que se reinicia con cada acción válida.
- Al vencer, baja 1 escalón y vuelve a arrancar. En el escalón 1, vencer cierra y
  cobra la cadena.

**El temporizador se congela durante las esperas que el juego impone**, y no
durante las que el jugador elige: el intervalo entre la última ventana de una
oleada y la aparición de la siguiente. Castigar una espera obligatoria sería
castigar la estructura del propio encuentro. Recargar, en cambio, **no** congela
nada: es una decisión del jugador y es parte del costo.

---

## 6. Capa 3 — Bonos de cierre

### 6.1 Al cerrar una sala

Se evalúan cuando cae el último objetivo y la barrera se abre. Se suman **después**
del cobro del pozo, sin multiplicar.

| Bono | Puntos | Condición |
| --- | --- | --- |
| Sala limpia | +500 | Sin daño recibido dentro de la sala. |
| Cadena única | +800 | La sala se resolvió con una sola cadena, sin cierres forzados. |
| Cadena intacta | +300 | No se bajó ningún escalón en la sala. |
| Precisión de sala | +100 / +300 / +600 | ≥60 %, ≥80 %, 100 %. |
| Bajo par | +10 por segundo ahorrado | Ver 6.3. |

**Sala perfecta** es la suma de "cadena única" y "cadena intacta": la sala se
cerró en el escalón máximo que su contenido permite. Es el objetivo aspiracional
de cada encuentro y merece su propio anuncio en el feed.

### 6.2 Al cerrar el nivel

| Bono | Puntos | Condición |
| --- | --- | --- |
| Munición sobrante | +5 por bala en reserva | — |
| Tiempo restante | +10 por segundo | — |
| Sin daño | +2000 | Salud intacta en todo el nivel. |
| Todas las salas limpias | +1000 | — |
| **Nivel perfecto** | +2500 | Todas las salas cerradas como sala perfecta. |

El bono por munición sobrante es el que más trabajo hace por su tamaño. Convierte
cada bala fallada en una pérdida **triple** —hunde el multiplicador, no suma al
pozo y no queda en la reserva— usando un recurso que el jugador ya mira en el HUD.
Es la forma más barata de que la precisión importe sin agregar ninguna regla nueva
que explicar.

"Nivel perfecto" reemplaza al viejo bono de cadena continua entre Entrada y
Salida, que dejó de existir al acotar la cadena a la sala. La fantasía sobrevive
intacta —una corrida sin un solo error— pero ahora es verificable.

### 6.3 El par de tiempo por sala

Necesitamos un tiempo de referencia por sala, pero escribirlo a mano en cada JSON
sería una carga de mantenimiento insostenible: los niveles se editan en el editor
web y cambian seguido. Propuesta: **derivarlo del contenido**.

```
par_sala  = (cantidad_de_objetivos × 1.8 s) + 2.5 s de tránsito
par_nivel = suma de par_sala
```

El editor de niveles puede mostrar el par calculado como dato informativo, y el
JSON podría admitir un override opcional para salas atípicas. Queda ajustable con
un solo número global (el 1.8) para todo el juego.

---

## 7. El techo de una sala y los rangos

### 7.1 El techo se calcula, no se estima

Al acotar la cadena a la sala, el máximo teórico deja de ser una heurística y pasa
a ser aritmética sobre el JSON del nivel:

```
hits_sala      = Σ zonas que hay que acertar para vaciar la sala
mult_max_sala  = escalón que corresponde a hits_sala
pozo_max_sala  = Σ (valor de la zona más cara de cada objetivo)
techo_sala     = pozo_max_sala × mult_max_sala + todos los bonos de sala
techo_nivel    = Σ techo_sala + todos los bonos de nivel
```

Se calcula con los modificadores instantáneos en neutro (×1.0). O sea: **el techo
es lo que rinde una corrida impecable jugada de forma normal**, y el jugador que
además tira desde lejos y en el aire puede pasarlo. Ver "108 % del máximo" en la
pantalla de resultados es una de las mejores recompensas que el sistema puede dar,
y sale gratis de esta definición.

Esto le da al editor de niveles una herramienta concreta: mostrar el techo de cada
sala y avisar cuando una sala **no tiene objetivos suficientes para alcanzar un
escalón alto**. Una sala de 6 ventanas topea en ×2.0, y eso es un dato de diseño
que hoy no se ve en ninguna parte.

### 7.2 Tabla de rangos

Con un techo real, el rango es directamente el porcentaje alcanzado.

| Rango | Proporción del techo | Lectura para el jugador |
| --- | --- | --- |
| **D** | Completó el nivel | Llegaste. |
| **C** | ≥ 0.35 | Lo resolviste. |
| **B** | ≥ 0.55 | Lo resolviste bien. |
| **A** | ≥ 0.75 | Dominás el nivel. |
| **S** | ≥ 0.90 | Corrida ejecutada, no jugada. |
| **S+** | ≥ 1.00 | Tocaste el techo. |

Dado el tema del juego, vale la pena poner una **etiqueta temática** debajo de la
letra, en la jerga de permisos de un sistema operativo: `GUEST` / `USER` /
`POWER USER` / `ADMIN` / `ROOT` / `KERNEL`. La letra se lee al instante; la
etiqueta le da personalidad y conecta directo con la fantasía del lobby-escritorio.

Un nivel fallado (salud agotada o tiempo expirado) **no recibe rango**: recibe el
puntaje parcial y un estado de intento incompleto. El rango es la recompensa por
terminar.

---

## 8. Anti-exploit

Es la pregunta abierta más importante del documento madre. El juego ya tiene tres
defensas estructurales, y sólo hace falta una regla nueva.

**Defensas que ya existen y hay que preservar:**

1. **Nada reaparece.** Las ventanas y las pelotas no respawnean. No existe una
   fuente infinita de puntos, así que no hay farmeo posible.
2. **La munición es finita.** Cualquier estrategia repetitiva se queda sin balas.
3. **El tiempo corre.** El nivel tiene un límite.

Estas tres cosas ya vuelven imposible el exploit clásico. Conviene tratarlas como
**restricciones de diseño no negociables**: el día que se agregue un objetivo que
reaparece o munición infinita, el sistema de puntuación se rompe entero.

**Regla nueva, contra la monotonía dentro de un encuentro:**

4. **Rendimientos decrecientes por repetición.** Golpear el mismo `zone_id` en
   objetivos consecutivos aplica ×0.9 acumulativo, con piso en ×0.5, y se
   reinicia al cambiar de tipo de zona. No prohíbe nada ni rompe nada: sólo hace
   que alternar entre X, botón y comportamientos especiales rinda más que repetir
   el blanco fácil. Empuja variedad sin obligarla.

Y una regla higiénica: **disparar al vacío nunca da puntos ni hits**, y siempre
cuenta como fallo.

---

## 9. Presentación y feedback

El principio: **durante el nivel, sólo lo que alimenta la apuesta; al cerrar,
todo.** Con el modelo de pozo, el HUD tiene un trabajo nuevo e importante: mostrar
lo que hay para ganar y lo que hay para perder.

### 9.1 El contador de combo, arriba y al centro

Referencia directa: **Marvel vs. Capcom.** El contador de hits no es un dato en
una esquina, es un personaje en pantalla. Va en el **centro superior**, grande, y
es lo segundo que el jugador mira después de la mira.

```
              ╭──────────────────────╮
                     24 HITS
                      ×6.0
                  ▓▓▓▓▓▓▓░░░
                  4 100 × 6.0
              ╰──────────────────────╯
```

Cuatro elementos, en orden de importancia visual:

1. **El contador de hits**, tipografía grande y con carácter. Es la estrella.
2. **El multiplicador**, debajo y en el color del escalón actual.
3. **La barra del temporizador**, que se vacía. Comunica urgencia sin números.
4. **La cuenta pendiente**, `pozo × multiplicador`, en cuerpo chico. Ésta es la
   línea que enseña la mecánica: el jugador ve literalmente el trato que está
   haciendo.

Los **números flotantes en el punto de impacto** siguen existiendo en el mundo 3D,
porque nacen donde el jugador ya está mirando, pero ahora dicen lo que suman al
pozo, no puntos finales.

### 9.2 La escalada visual

El contador tiene que crecer con el combo, no quedarse quieto. Cada escalón sube
la apuesta estética:

| Escalón | Tratamiento |
| --- | --- |
| ×1.0 – ×1.5 | Chico, sobrio, casi invisible. |
| ×2.0 – ×3.0 | Crece, toma color, pulsa al subir. |
| ×4.0 | Cambia de color, vibración leve permanente, el sonido sube de tono. |
| ×6.0 | Contorno encendido, sacudida de cámara mínima al sumar hits. |
| ×8.0 | Estado especial: el número domina la pantalla superior, sonido propio, aberración cromática sutil, el HUD entero adopta ese color. |

Cada subida de escalón dispara un golpe: sonido con tono ascendente por escalón,
un destello en el número y un microzoom. Es el refuerzo más barato y el que más
rinde.

Y el reverso: **al fallar, el castigo tiene que verse.** El contador se desploma
con animación de caída —los números bajan contados, no cortados—, se sacude en
rojo y suena un tono descendente. Perder 3 escalones tiene que doler visualmente
tanto como duele en la aritmética.

### 9.3 El cobro: el momento juicy

Cuando la cadena se cierra, se corre esta secuencia. Es el clímax del encuentro y
merece cuadros:

1. El contador se congela y se agranda un instante.
2. La línea pendiente se resuelve en pantalla: `4 100 × 6.0` → `24 600`,
   contado hacia arriba, con un tic por cada tramo.
3. El número vuela hacia el marcador total, que sube contando.
4. Golpe de sonido según el escalón alcanzado. Cerrar en ×8.0 debería sonar como
   un evento, no como una notificación.
5. El contador se desarma y vuelve a cero, listo para la sala siguiente.

Si el cierre fue por daño, la misma secuencia pero **en negativo**: el
multiplicador se tacha visiblemente antes de resolver, y el cobro sale a ×1.0.
El jugador tiene que ver exactamente cuánto le costó el golpe.

Regla de oro: si el jugador tiene que mover los ojos fuera del eje mira–contador
para entender su combo, el HUD está mal.

### 9.4 Al cerrar una sala

Tarjeta breve, **no bloqueante**, de ~1.5 s, junto a la puerta que se abre. Ese
momento ya existe en el flujo y hoy está vacío. Tres líneas: cobro de la cadena,
bonos obtenidos, y el porcentaje del techo de esa sala.

### 9.5 Al terminar el nivel

Pantalla completa con desglose **animado línea por línea**, porque el conteo es
parte de la recompensa:

```
SALAS                     12 400
CADENA MÁXIMA       ×6    (+3 100)
MUNICIÓN SOBRANTE   34    (+170)
TIEMPO RESTANTE     22 s  (+220)
SIN DAÑO                  (+2 000)
────────────────────────────────────
TOTAL                     17 890     RANGO A — ADMIN
TECHO DEL NIVEL           22 400     80 %
RÉCORD ANTERIOR           15 240     ▲ +2 650
```

Debe poder **saltearse con una tecla**, y el reintento tiene que estar a un botón
de distancia.

---

## 10. Eventos en el feed de logs

El HUD ya tiene un feed con categorías de color (`system`, `hit`, `miss`,
`danger`, `info`) y un tope de 5 líneas. Es el canal ideal para narrar el puntaje
sin agregar interfaz nueva.

Propuesta: sumar una categoría **`score`** a `LOG_COLORS`, en ámbar o dorado, para
que los eventos de puntaje se distingan de un vistazo de los de combate.

| Evento | Categoría | Línea propuesta |
| --- | --- | --- |
| Sube de escalón | `score` | `CHAIN ×4.0 // 14 HITS` |
| Nuevo escalón máximo de la partida | `score` | `NEW PEAK ×8.0` |
| Fallo | `miss` | `MISS // ×4.0 -> ×2.0` |
| Fallos consecutivos | `miss` | `SPRAY // ×2.0 -> ×1.0` |
| Zona trampa | `danger` | `TRAP // -150 // CHAIN LOST` |
| Cierre por daño | `danger` | `HIT TAKEN // 3 200 BANKED AT ×1.0` |
| Cierre por abandono | `info` | `CHAIN TIMED OUT // 900 BANKED` |
| Cobro por sala completada | `score` | `ROOM CLEARED // 4 100 ×6.0 = 24 600` |
| Bono de sala | `score` | `BONUS // NO DAMAGE +500` |
| Sala perfecta | `system` | `PERFECT ROOM // 100 %` |
| Récord de sala superado | `system` | `ROOM BEST // +1 240` |
| Cierre de nivel | `system` | `LEVEL COMPLETE // RANK A` |

**Regla de higiene, no negociable:** el feed muestra 5 líneas. Un log por cada
acierto lo convierte en ruido y tapa los eventos de combate, que son los que
avisan al jugador que algo lo va a lastimar. **Sólo hitos, nunca impactos
individuales**: el impacto ya tiene su número flotante y su tic en el contador.

Si al probarlo el feed sigue saturado, la salida es separar el feed de puntaje del
de combate en dos columnas, no bajar la cantidad de líneas.

---

## 11. Récord, persistencia y reintento

### 11.1 Qué se guarda por nivel

Puntaje máximo, rango máximo, porcentaje del techo, mejor tiempo, mejor precisión,
cadena más larga, cobro más grande de una sola cadena, cantidad de intentos, y si
se logró alguna vez sin daño. Persistir por `id` de nivel en `user://` con
`ConfigFile`.

Guardar también la **versión de la fórmula** junto a cada récord. El día que se
recalibre un peso, los récords viejos quedan marcados como de otra versión en
lugar de convertirse en mentiras. Es una línea de código hoy y evita un problema
feo más adelante.

Vale la pena guardar además el **mejor puntaje por sala**. Con la cadena acotada a
la sala, cada sala es una prueba independiente y puede tener su propio récord: es
rejugabilidad extra que sale gratis del cambio de alcance.

### 11.2 Reintento

Innegociable en un modo de puntaje: **reiniciar el nivel tiene que costar menos
de un segundo y ninguna confirmación.** Una tecla dedicada, disponible también
durante la partida y no sólo en la pantalla de resultados. Si reintentar es
incómodo, todo este documento no sirve para nada: nadie repite un nivel dos veces
si volver a empezar cuesta cinco clics.

### 11.3 Comparación

La prioridad 1 es el récord local con delta visible. Un **fantasma del mejor
intento propio** (marcas de tiempo por sala: "vas 3 s adelante") es más motivador
y mucho más barato que un leaderboard, y no depende de infraestructura.

Los rankings globales quedan fuera de alcance por ahora, pero conviene que el
puntaje sea **determinista y reproducible** desde el inicio, para poder sumarlos
después sin rediseñar nada.

---

## 12. Relación con los otros tres ejes

- **Ventanas (eje 2):** cada comportamiento nuevo debería llegar con su propia
  respuesta a "¿qué se premia acá?". Resolver una ventana de la forma difícil
  paga; ignorarla cuesta la cadena. El sistema de puntuación es lo que le da
  consecuencia jugable a cada comportamiento sin tener que inventarle daño. El
  pozo además le da a las ventanas amenazantes un costo enorme y legible: dejar
  activarse una Descarga no te saca vida, te cobra el pozo a ×1.0.
- **Combos (eje 3):** este anexo define el *número*; el eje 3 define el *estilo*,
  o sea el reconocimiento cualitativo. Conviene que el estilo no altere la
  fórmula, sólo la celebre; si el estilo también multiplicara, tendríamos dos
  economías compitiendo por la misma atención.
- **Lobby (eje 4):** **completar** desbloquea el siguiente nivel; **los rangos**
  desbloquean cosméticos. La habilidad nunca debería bloquear el acceso al
  contenido jugable, sólo abrir expresión personal. Así, el jugador que quiere ver
  el juego lo ve, y el que quiere dominarlo tiene por qué volver.

---

## 13. Respuestas propuestas a las preguntas abiertas del documento madre

| Pregunta | Respuesta propuesta |
| --- | --- |
| ¿La campaña se desbloquea completando o por rango? | **Completando.** Los rangos desbloquean cosméticos del lobby, nunca niveles. |
| ¿Premiar velocidad o equilibrar estilos? | **Ninguna de las dos: eficiencia.** La velocidad es un bono de cierre, no la base del puntaje. |
| ¿El daño resta, rompe el combo, o ambos? | **Cierra la cadena y la cobra a ×1.0, y bloquea los bonos de "sin daño". No resta puntos directos.** El costo real es el multiplicador perdido, que es enorme y perfectamente visible. |
| ¿Cómo evitar el juego repetitivo? | Las tres defensas estructurales que ya existen (nada reaparece, munición finita, tiempo) más rendimientos decrecientes por repetición. |
| ¿Puntajes globales, de amigos o locales? | **Locales primero**, con fantasma del mejor intento y récord por sala. Fórmula determinista y versionada para poder sumar globales después. |

---

## 14. Plan de implementación

### 14.1 Lo que el código ya provee

| Dato | Dónde |
| --- | --- |
| Aciertos, disparos, precisión | `RoundController.hits` / `attacks` |
| Salud y daño recibido | `RoundController.apply_damage` |
| Tiempo restante | `RoundController.time_remaining` |
| Munición en cargador y reserva | `RoundController.report_ammo_changed` |
| Zona golpeada e identidad de la ventana | `WindowPanel3D.zone_hit(zone_id, ventana)` |
| Cierre de ventana | `WindowPanel3D.closed` |
| Amenaza ignorada | `report_target_left` / `report_block_crossed` |
| Fin de ronda y su motivo | `round_ended(reason)` |
| Canal de feedback textual | `log_added` más el feed del HUD |

La base está casi entera. Lo que falta es un consumidor.

### 14.2 Lo que hay que agregar

- Un `ScoreController` que escuche al `RoundController` y a las ventanas, y
  mantenga pozo, cadena, escalón y bonos. Que sea un nodo aparte y no una
  ampliación del `RoundController`: la ronda administra reglas de vida y tiempo;
  el puntaje es otra responsabilidad y va a cambiar mucho más seguido.
- **Límites de sala como eventos de primera clase.** Con la cadena acotada a la
  sala, "entré a la sala" y "la sala quedó limpia" dejan de ser un detalle y pasan
  a ser los eventos que abren y cierran cada cadena. Hoy el `RoundController` no
  sabe en qué sala ocurre nada; es el cambio de fondo más importante.
- Marca de tiempo por evento, para el temporizador de cadena y para el par.
- Cálculo del techo (puntaje) y del par (tiempo) al cargar el nivel, recorriendo
  las salas y sus oleadas.
- El contador de combo central, con sus estados de escalada y su animación de cobro.
- Categoría `score` en el feed de logs.
- Persistencia de récords por nivel y por sala.
- Pantalla de resultados y reintento rápido.

### 14.3 Fases sugeridas

**Fase 1 — Que se sienta.** Valor por zona, pozo, cadena con escalones, castigo
por fallo, contador central con su escalada y su animación de cobro al limpiar la
sala. Nada de bonos, nada de rangos, nada de persistencia. El objetivo de esta
fase es contestar una sola pregunta: *¿mantener la cadena y cobrarla es
divertido?* Si la respuesta es no, ninguna fórmula posterior lo arregla.

**Fase 2 — Que cierre.** Bonos de sala y de nivel, techo y par calculados, rangos,
logs de puntaje, pantalla de resultados, récord local, reintento rápido. Acá el
modo ya es jugable de punta a punta.

**Fase 3 — Que profundice.** Modificadores instantáneos, rendimientos
decrecientes, récord por sala, fantasma del mejor intento, desafíos por nivel y
enganche con los cosméticos del lobby.

---

## 15. Constantes de arranque

Todo junto, para tunear desde un solo recurso.

| Constante | Valor inicial |
| --- | --- |
| Valor zona `close` | 100 |
| Valor zona botón | 60 |
| Valor zona cartel | 40 |
| Valor zona `next` | 10 |
| Valor pelota | 50 |
| Penalización zona trampa | −150 |
| Escalones de multiplicador | 1.0 / 1.5 / 2.0 / 3.0 / 4.0 / 6.0 / 8.0 |
| Hits para cada escalón | 3 / 6 / 10 / 14 / 19 / 25 |
| Ventana de gracia de la cadena | 3.0 s |
| Fallo aislado | −2 escalones |
| 2º fallo consecutivo | −3 escalones |
| 3º fallo consecutivo y siguientes | −4 escalones |
| Piso del castigo por fallo | escalón 1 (×1.0), nunca cierra la cadena |
| Vencimiento del temporizador | −1 escalón |
| Efecto del daño | cierra y cobra el pozo a ×1.0 |
| Decaimiento por repetición | ×0.9, piso ×0.5 |
| Bono por bala en reserva | 5 |
| Bono por segundo restante | 10 |
| Bono sala limpia | 500 |
| Bono cadena única | 800 |
| Bono cadena intacta | 300 |
| Bono sin daño (nivel) | 2000 |
| Bono nivel perfecto | 2500 |
| Segundos de par por objetivo | 1.8 |
| Segundos de par por tránsito | 2.5 |
| Umbrales de rango | 0.35 / 0.55 / 0.75 / 0.90 / 1.00 |

---

## 16. Preguntas que quedan abiertas

Decisiones que hacen falta y que no conviene tomar sin probar el juego:

- El pozo se cobra al **multiplicador vigente al cierre**. La alternativa es
  cobrarlo al **máximo alcanzado en la cadena**, que es mucho más indulgente con
  un fallo tardío. Es la perilla más sensible del sistema y hay que probar las dos.
- ¿Cuántos objetivos tiene una sala típica? De eso depende toda la tabla de
  escalones: si las salas rondan los 10 objetivos, el escalón ×8.0 no existe en
  la práctica y hay que comprimir más.
- ¿El puntaje de campaña es la suma de los mejores puntajes por nivel, o cada
  nivel vive por su cuenta? (La recomendación es *cada nivel por su cuenta*, con
  la suma como métrica secundaria del lobby.)
- ¿Morir o quedarse sin tiempo conserva el puntaje parcial como récord, o el
  intento se descarta entero?
- ¿Una sala con varias oleadas debería cerrar la cadena entre oleada y oleada, o
  sostenerla como propone este documento?
- ¿Queremos desafíos por nivel con reglas alteradas (sin recargar, sólo a la X,
  con tiempo reducido), o alcanza con perseguir el rango S?
- ¿La etiqueta temática de rangos (`GUEST` → `KERNEL`) reemplaza a las letras o
  las acompaña?
- ¿El bono por munición sobrante puede volverse perverso, empujando a no disparar
  a objetivos opcionales? Hay que medirlo en cuanto existan objetivos opcionales.
