# Progresión de la campaña (30 niveles)

Este documento explica **cómo crece la dificultad** a lo largo de los treinta
niveles y qué reglas se siguieron para que crezca sin saltos ni mesetas. El
detalle sala por sala está en [`campania.md`](campania.md); las fórmulas de
presupuesto vienen de [`analisis_y_curva_de_niveles.md`](analisis_y_curva_de_niveles.md)
y los arquetipos de sala del [catálogo de 30 salas](catalogo_30_salas_level_design.md).

---

## 1. Qué es "difícil" en este juego

El juego no tiene enemigos con vida ni armas nuevas: la única fuente de
crecimiento es la **composición** de lo que ya existe. Por eso la dificultad
se mide en cinco ejes independientes, y un nivel sube uno o dos por vez:

| Eje | Qué lo sube | Familia o parámetro |
|---|---|---|
| **Ejecución** | cantidad de impactos, blancos chicos, capas largas | `normal`, capas, densidad por pared |
| **Secuencia** | capas dentro de un bloque, oleadas dentro de una sala | `layers`, `waves` (hasta 8) |
| **Atención espacial** | paredes activas a la vez, cambio de pared entre oleadas | `left` / `front` / `right` |
| **Presión** | bloques que avanzan, tiempo de contacto, límite de tiempo | `movement: opposite`, `movementSpeed`, `timeLimitSeconds` |
| **Comprensión** | reglas que hay que leer antes de disparar | `firewall`, `critical-error`, `popup`, `download`, `infected-download` |

Además hay dos recursos que modulan todo: la **munición** (10 en el cargador,
60 de reserva como máximo) y el **tiempo**. Recortarlos endurece un nivel sin
tocar sus salas.

---

## 2. Tres actos

La campaña es una montaña rusa de tres subidas (cap. 6 del libro: *"think of
difficulty as a roller coaster"*), no una rampa única que terminaría en un
final que nadie puede pasar.

| Acto | Niveles | Nombre | Pregunta del acto | Cómo sube |
|---|---|---|---|---|
| I · Usuario | 1–10 | Aprender | ¿Conocés cada regla? | una regla nueva por nivel, aislada, después combinada |
| II · Sistema | 11–20 | Combinar | ¿Podés aplicar dos reglas a la vez? | las reglas conocidas bajo la presión de otra: leer mientras avanza, cancelar en capas, popups que se mueven |
| III · Root | 21–30 | Dominar | ¿Podés hacerlo rápido, denso y con menos balas? | velocidad de bloques, densidad por pared, munición más corta, tiempo más justo, ocho oleadas |

Cada acto tiene la misma forma interna (curva de dos jorobas):

```
 intensidad
   ^                       examen
   |                    ▲          ▲
   |          pico     / \        / \
   |         ▲        /   \      /   \
   |        / \      /     ▼    /     \
   |  ▲    /   \    /   respiro/       \
   | / \  /     ▼  /                    \
   |/   \/  respiro                      \
   +---------------------------------------> niveles del acto
    1    2   3   4   5   6   7   8   9   10
```

- **Apertura** (1, 11, 21): lo más limpio del acto. En el I es el tutorial; en
  el II es un *score farm* (Caché) para recuperarse de Kernel; en el III es
  velocidad pura sin familias (Overclock).
- **Primer pico** (4–5, 15, 24): un eje empujado a fondo.
- **Respiro** (6, 16, 25): pocas ventanas, dificultad cognitiva o de
  precisión, munición corta. El jugador baja el pulso pero no se aburre.
- **Subida** (7–9, 17–19, 26–29): combinaciones.
- **Examen** (10, 20, 30): sin reglas nuevas, seis u ocho oleadas, sala más
  grande del acto, y una sala vacía después para salir caminando.

---

## 3. Qué sube en cada nivel

La matriz muestra qué ejes toca cada nivel respecto del anterior (● sube,
○ se mantiene, ◌ afloja). La regla es que **no haya más de dos ● por fila**.

| # | Nivel | Ejecución | Secuencia | Espacial | Presión | Comprensión | Novedad |
|---:|---|:---:|:---:|:---:|:---:|:---:|---|
| 1 | Hola, mundo | ● | ○ | ○ | ○ | ○ | cerrar ventanas |
| 2 | Actualizaciones pendientes | ○ | ● | ○ | ○ | ○ | capas, recargar |
| 3 | Barrido | ● | ● | ● | ○ | ○ | oleadas, girar |
| 4 | Desfragmentar | ○ | ◌ | ○ | ● | ○ | bloques móviles |
| 5 | Cortafuegos | ○ | ○ | ○ | ◌ | ● | firewall |
| 6 | Error crítico | ◌ | ○ | ○ | ○ | ● | leer antes de tirar |
| 7 | Publicidad | ○ | ● | ○ | ○ | ● | popups |
| 8 | Descargas | ○ | ○ | ○ | ● | ● | descargas, infectada |
| 9 | Sobrecarga | ● | ○ | ● | ○ | ○ | multitarea |
| 10 | Kernel | ● | ● | ○ | ○ | ○ | examen I |
| 11 | Caché | ○ | ● | ○ | ◌ | ◌ | respiro; cadena larga |
| 12 | Ping de red | ○ | ● | ● | ○ | ○ | anticipar oleadas con familias |
| 13 | Sector dañado | ◌ | ○ | ○ | ● | ● | leer bajo movimiento |
| 14 | Cola de impresión | ○ | ● | ○ | ○ | ● | descargas en capas y dos paredes |
| 15 | Adware persistente | ● | ● | ○ | ● | ○ | popups que se mueven |
| 16 | Modo seguro | ◌ | ○ | ○ | ◌ | ● | respiro; munición corta |
| 17 | Puerto abierto | ● | ● | ○ | ● | ○ | firewall + infectada móviles |
| 18 | Registro corrupto | ● | ○ | ● | ◌ | ● | tres paredes mixtas |
| 19 | Fuga de memoria | ● | ○ | ○ | ● | ○ | resistencia, tiempo justo |
| 20 | Pantalla azul | ● | ● | ● | ● | ○ | examen II |
| 21 | Overclock | ○ | ○ | ○ | ● | ◌ | contacto 18–23 s |
| 22 | Inyección | ○ | ○ | ○ | ○ | ● | prioridad bajo dos relojes |
| 23 | Bucle infinito | ○ | ● | ● | ◌ | ○ | ocho oleadas |
| 24 | Desbordamiento | ● | ○ | ○ | ○ | ○ | capas de 9–10 |
| 25 | Rootkit | ◌ | ○ | ○ | ◌ | ● | respiro; precisión |
| 26 | Ataque DDoS | ○ | ○ | ● | ● | ● | crisis de popups |
| 27 | Cortocircuito | ○ | ○ | ● | ● | ○ | presión asimétrica |
| 28 | Ransomware | ○ | ○ | ○ | ● | ● | infectada en cada oleada, tiempo corto |
| 29 | Sistema comprometido | ● | ○ | ● | ● | ○ | tres paredes móviles |
| 30 | Root | ● | ● | ● | ● | ○ | examen III |

---

## 4. Las curvas en números

| # | Nivel | Ventanas | Impactos | Balas | Balas/impacto | Límite | Contacto mín. |
|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | Hola, mundo | 10 | 10 | 22 | 2,20 | 80 s | — |
| 2 | Actualizaciones pendientes | 16 | 16 | 32 | 2,00 | 95 s | — |
| 3 | Barrido | 30 | 30 | 60 | 2,00 | 145 s | — |
| 4 | Desfragmentar | 31 | 31 | 62 | 2,00 | 160 s | 25 s |
| 5 | Cortafuegos | 33 | 33 | 68 | 2,06 | 140 s | — |
| 6 | Error crítico | 25 | 25 | 48 | 1,92 | 120 s | — |
| 7 | Publicidad | 27+ | 27+ | 64 | 2,37 | 190 s | 28 s |
| 8 | Descargas | 31 | 39 | 68 | 1,74 | 160 s | 33 s |
| 9 | Sobrecarga | 46 | 50 | 82 | 1,64 | 210 s | 21 s |
| 10 | Kernel | 70 | 74 | 110 | 1,49 | 280 s | 27 s |
| 11 | Caché | 41 | 41 | 70 | 1,71 | 135 s | — |
| 12 | Ping de red | 42 | 44 | 64 | 1,45 | 175 s | — |
| 13 | Sector dañado | 29 | 29 | 58 | 2,00 | 130 s | 29 s |
| 14 | Cola de impresión | 31 | 42 | 66 | 1,57 | 140 s | 37 s |
| 15 | Adware persistente | 40+ | 40+ | 72 | 1,80 | 220 s | 30 s |
| 16 | Modo seguro | 20 | 25 | 46 | 1,84 | 105 s | — |
| 17 | Puerto abierto | 42 | 47 | 72 | 1,53 | 175 s | 30 s |
| 18 | Registro corrupto | 50 | 53 | 78 | 1,47 | 200 s | — |
| 19 | Fuga de memoria | 54 | 56 | 84 | 1,50 | 215 s | 27 s |
| 20 | Pantalla azul | 61 | 64 | 100 | 1,56 | 235 s | 25 s |
| 21 | Overclock | 50 | 50 | 78 | 1,56 | 185 s | 18 s |
| 22 | Inyección | 33 | 38 | 70 | 1,84 | 160 s | 25 s |
| 23 | Bucle infinito | 50 | 53 | 76 | 1,43 | 175 s | — |
| 24 | Desbordamiento | 58 | 58 | 84 | 1,45 | 190 s | 31 s |
| 25 | Rootkit | 24 | 30 | 50 | 1,67 | 120 s | 29 s |
| 26 | Ataque DDoS | 32+ | 32+ | 76 | 2,38 | 200 s | 31 s |
| 27 | Cortocircuito | 39 | 41 | 70 | 1,71 | 155 s | 19 s |
| 28 | Ransomware | 30 | 39 | 70 | 1,79 | 125 s | 30 s |
| 29 | Sistema comprometido | 50 | 54 | 82 | 1,52 | 205 s | 28 s |
| 30 | Root | 73 | 79 | 110 | 1,39 | 275 s | 27 s |

Lecturas de la tabla:

- **Ventanas** forma tres dientes de sierra (10→70, 41→61, 50→73), no una
  recta. Los valles (6, 16, 25) son los respiros.
- **Balas por impacto** cae de 2,2 a 1,4: la precisión de supervivencia sube
  de 45 % a 72 %. Los niveles con popups (7, 15, 26) parecen generosos porque
  presupuestan las publicidades derivadas.
- **Límite** = (par ajustado + viaje) × factor; el factor baja de 2,2 a 1,25.
  El par ajustado suma 2,5 s por popup, 1,2 s por descarga y 0,5 s por firewall
  o error crítico, así que un nivel de lectura tiene más aire que uno de
  normales con el mismo número de ventanas.
- **Contacto** (`recorrido / velocidad` del bloque más rápido) baja de 34 s
  cuando se enseña el movimiento (4) a 18 s en Overclock (21). Nunca menos:
  por debajo de 16 s el jugador no llega a leer la pared.

---

## 5. Reglas de composición

Son las que se aplicaron y las que hay que respetar al retocar o agregar:

1. **Una regla nueva se presenta sola**, estática y de frente, en una sala
   chica. Recién en el nivel siguiente se combina, y en el subsiguiente se
   mueve. (5 → 6 → 13 para el firewall y los errores; 7 → 9 → 15 para los popups.)
2. **No más de dos ejes suben** entre niveles consecutivos (§3).
3. **Respiro cada cuatro o cinco niveles**: menos ventanas, no menos
   exigencia. Se cambia el tipo de esfuerzo (lectura, precisión, cadena).
4. **Los exámenes no introducen nada.** Repasan las lecciones del acto en
   oleadas ordenadas de la más vieja a la más nueva.
5. **Tres paredes a la vez** sólo con pocas ventanas por pared (2–5) o sin
   familias que exijan lectura en más de una de ellas.
6. **Toda amenaza con deadline** (infectada, popup) se estrena visible y sin
   competencia; en los actos II y III puede ir tapada, pero nunca la primera
   vez que se combina con movimiento.
7. **La munición se calcula, no se adivina**: `⌈impactos / precisión⌉` por
   nivel y, sala por sala, que se pueda entrar sin sobrante y resolverla. Las
   recompensas van después de dominar una pregunta y la grande antes del
   examen (20 balas antes de Kernel, Núcleo y Root).
8. **Salas de salida vacías y a cielo abierto**, salvo que la salida sea el
   examen (ninguna lo es: los exámenes tienen una sala de desenlace después).
9. **Cada nivel se distingue** por paleta de texturas, color de panel y cielo.
   Las salas de inicio son siempre madera, chicas y con radio; las de salida,
   ladrillo y pasto bajo el cielo. Esa constante es la que hace legible la
   variación de todo lo demás.

---

## 6. Cómo se construyó y cómo extenderla

Los treinta archivos se generaron con un script que escribe el JSON en el
mismo formato que el Level Workshop y lo pasa por `migrate-level.js` para que
la normalización sea idéntica (el smoke test del editor exige que cada
archivo sea igual a su versión normalizada). Un nivel se editó siempre como
**una lista de salas con oleadas**, y el script calculó por cada nivel:
ventanas, impactos, par ajustado, viaje, límite y el chequeo de munición
sala por sala. Cualquier nivel se puede seguir editando en el Workshop; el
script no es necesario para jugar ni para validar.

Para agregar un nivel 31+:

1. Elegir en qué punto de la curva entra (apertura, pico, respiro, examen) y
   qué uno o dos ejes sube respecto del 30.
2. Componer con arquetipos del catálogo de salas, tres o cuatro salas de
   combate, inicio y salida vacías.
3. Calcular impactos y fijar munición con 72–75 % de precisión objetivo; el
   tope real es 70 balas por sala.
4. Fijar el límite en ~1,25 × (par ajustado + viaje).
5. Correr `node tests/level_editor_smoke_test.mjs` y
   `tests/corridor_layout_smoke_test.gd`, que validan formato y pasillos de
   toda la secuencia.

---

## 7. Qué medir para validar la curva

Objetivos por tramo (intentos hasta completar, jugadores nuevos):

| Tramo | Completan en ≤ 3 intentos | Munición sobrante mediana | Tiempo sobrante mediana |
|---|---:|---:|---:|
| 1–2 | 85–95 % | 30–45 % | 40–55 % |
| 3–9 | 70–85 % | 15–30 % | 25–35 % |
| 10, 20, 30 | 55–70 % | 10–20 % | 15–25 % |
| 11–19 | 65–80 % | 15–30 % | 20–35 % |
| 21–29 | 55–75 % | 10–25 % | 15–30 % |

Si un nivel queda fuera de rango, el orden de retoque es: cantidad de
ventanas de **una** sala → velocidad de **un** bloque → recompensa de **una**
sala → límite de tiempo. Las constantes de las ventanas (segundos de
descarga, SKIP) no se tocan por un nivel: cambiarlas mueve los treinta. El
daño por cruzar tampoco, salvo excepción declarada: es una constante del juego
(`crossingDamage`, 40 sobre 100 HP) que un nivel sólo sobreescribe en su JSON
si quiere ser explícitamente más duro que el resto.

### Cómo se pierde

Las tres derrotas son legibles y todas se anuncian antes de cortar:

| Motivo | Cuándo | Qué lo enseña |
|---|---|---|
| `health_depleted` | tres cruces de bloque móvil (40 HP cada uno: 100 → 60 → 20 → 0) | el bloque que atraviesa al jugador **se descarga** —se apaga y desaparece sin pagar puntos— así que el cruce se ve, se paga y no deja un bloque pegado a la pared de atrás |
| `time_expired` | `timeLimitSeconds` en cero | el reloj del HUD marca los últimos diez segundos |
| `ammo_depleted` | sin balas, sin disparos en el aire, sin burbujas con balas al alcance (con una sala sellada, solo las de adentro) y con alguna sala de combate abierta | el HUD parpadea `SIN MUNICION` y la ronda cae 2,5 s después; un nivel ya limpio nunca falla por esto |

Con esos números la vida decide partidas (antes hacían falta siete cruces de
15 HP) sin que un solo error sea fatal: el primer cruce avisa, el segundo pone
el HUD en rojo.
