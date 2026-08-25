# Encuentros: salas, oleadas, bloques, capas y ventanas

Referencia de diseño de todo lo que pasa dentro de una sala: cómo se
encadenan las oleadas, qué es un bloque y una capa, qué hace cada familia de
ventana, cuántos disparos cuesta cada una, cuántos puntos paga y cómo se
arma el puntaje de la sala y del nivel. Los valores salen del código y de
`resources/gameplay/score_settings.tres`; si se tunean, actualizar acá (el
índice de tuning general está en [`configuraciones.md`](configuraciones.md)).

Vocabulario rápido:

```
Sala
└── Oleadas (waves, 1–8)           grupos de bloques que aparecen juntos
    └── Bloques (left / front / right)   un panel por pared, relativo a la entrada
        └── Capas (layers, sin tope)     tandas de ventanas; limpiar una descubre la siguiente
            └── Ventanas (1–64 por capa)  los objetivos; cada familia tiene su mecánica
```

---

## 1. Flujo de una sala

1. **Entrar.** El jugador pisa el `Area3D` de la sala. Si ninguna oleada tiene
   bloques habilitados, la sala se da por limpia al instante (y no paga
   recompensa ni bonos). Si los tiene, las **puertas se sellan** detrás del
   jugador (esperan a que se aleje 2 m y cierren del lado de adentro) y
   arranca la oleada 1. Entrar a una sala con bloques también arranca el
   cronómetro de la ronda si todavía no corría.
2. **Oleada.** Aparecen a la vez los bloques habilitados de esa oleada. Cada
   bloque trae su primera capa de ventanas.
3. **Capas.** Al caer la última ventana de una capa, el bloque muestra la
   siguiente. Al terminar la última capa el bloque **se cierra** y
   desaparece.
4. **Siguiente oleada.** Recién cuando se cerró **el último bloque** de la
   oleada arranca la siguiente. Las oleadas que quedaron sin bloques
   disponibles (por ejemplo, porque un slot se colgó) se saltean.
5. **Limpiar.** Sin oleadas pendientes, la sala queda limpia: se abren las
   puertas, se cobra la cadena de puntaje con el multiplicador vigente, se
   pagan los bonos de sala, aparece la recompensa de munición (`ammoReward`)
   en el centro y la luz de la sala baja al 30 % como invitación a seguir.

La cadena de puntaje **vive dentro de la sala**: se reinicia al entrar a cada
una (ver §4).

---

## 2. Bloques

Un bloque es un panel vertical translúcido pegado a una pared, que contiene
las ventanas. Es un `Area3D`, no un muro: se puede atravesar, y eso duele.

| Dato | Valor |
|---|---|
| Slots por oleada | 3: `left`, `front`, `right`, **relativos a la pared de entrada** (con entrada sur, `front` es la pared norte) |
| Tamaño | ancho = lado de la sala − 0,4 m; alto = mín(altura de pared − 0,4, `maxBlockHeight`), nunca menos de 2 m |
| Separación de la pared | 0,65 m |
| Ventanas | se reparten al azar dentro del panel con separación mínima 2×1 m (menor que una ventana: **se superponen a propósito**, escalonadas 8 cm en profundidad) |
| Cruzar el bloque | **15 de daño** por cada entrada al panel |

### Movimiento `opposite`

Un bloque con `movement: "opposite"` avanza desde su pared hacia la de
enfrente a `movementSpeed` m/s (0,05–5; por defecto 0,65) y recorre
`lado de la sala − 1,3 m`. Se detiene al llegar y mientras se está cerrando.
Tiempo hasta que toca la pared opuesta: `recorrido / movementSpeed` — en una
sala de 14 m a 0,65 m/s son ~19,5 s. Un bloque colgado (ver abajo) **sigue
moviéndose y sigue lastimando**.

### Crash del bloque (pantalla azul)

Lo provoca una `infected-download` que llega al 100 %:

- Lo que quedaba de la capa **desaparece** y el panel se reemplaza por una
  pantalla azul sin zonas disparables.
- Para la sala el bloque cuenta como resuelto (no traba las puertas), pero
  **ese slot queda anulado en todas las oleadas siguientes**. Si eso deja
  una oleada vacía, se saltea.
- Conviene pensarlo como "perdés el contenido futuro de esa pared": las
  ventanas que iban a venir ahí no se juegan ni puntúan, así que el techo de
  puntaje de la sala se vuelve inalcanzable.

---

## 3. Ventanas

### Reglas comunes a todas

- **No hay vida.** Cada zona (botón, X, barra de título) se resuelve con **un
  solo impacto**; el daño del arma se ignora. "Disparos necesarios" = cantidad
  de zonas correctas que hay que acertar.
- Una ventana se cierra al acertar una zona marcada como *cierra*.
- Solo las zonas frenan la bala: un tiro al **cuerpo** de la ventana (donde no
  hay botón) la atraviesa y cuenta como **fallo** para la cadena y la precisión.
- La **barra de título** (`raise`) no cierra ni puntúa, nunca se gasta y
  adelanta la ventana 2 cm: sirve para traer al frente una ventana tapada.
- Ninguna ventana hace daño al jugador. El único daño en combate es cruzar un
  bloque.
- Todo objetivo cerrado suma **1 hit** a la cadena por cada zona acertada y
  **1 objetivo** resuelto (una `download` de dos disparos suma 2 hits pero 1
  objetivo).

### Tabla por familia

| Familia | Variantes | Zonas | Disparos para cerrar | Puntos | Mecánica |
|---|---|---|---|---|---|
| **normal** | *Aviso* (X o botón "Cerrar") | X → cierra · botón → cierra | **1** | **100** | Ninguna. Dos zonas equivalentes. |
| | *Salir* (X o botón "Finalizar") | X → cierra · botón → cierra | **1** | X **100** · botón **60** | Dos precios por el mismo objetivo: blanco chico caro, blanco grande barato. |
| **download** | una | X / "Cancelar" → no cierra · diálogo "Sí" → cierra · "Finalizar" → cierra (aparece al 100 %) | **2** (cancelar + confirmar) o **1** (esperar y finalizar) | Cancelar: 60 + 100 = **160** · Finalizar: **60** | Barra de **12 s**. Acertar cancelar abre un diálogo de confirmación y **congela la barra**. Esperar es más barato en balas pero paga menos y cuesta tiempo. |
| **infected-download** | una (`factura_impaga.exe`) | idénticas a download; *no* ofrece "Finalizar" | **2**, antes de 12 s | **160** | Al llegar al 100 % **cuelga el bloque** (pantalla azul, §2). Se ve igual que una download sana salvo por el nombre del archivo. Es la prioridad de la capa. |
| **popup** | *rápida* (SKIP 5 s) · *lenta* (SKIP 10 s) | X → cierra · SKIP → cierra solo cuando el contador llegó a 0 · cuerpo (anuncio) → no cierra | **1** por la X en cualquier momento | X **100** · SKIP **60** (0 si se dispara antes de tiempo) | Al llegar a 0 el SKIP parpadea y **abre una publicidad nueva**; acertar el cuerpo también abre una. Cada popup deriva **como máximo una**; tope de **7 publicidades vivas por bloque**. La X es la jugada correcta: cierra antes de que se multiplique y paga más. |
| **firewall** | una | X → cierra · "Desactivar" → cierra | **1** | **100** | Apenas aparece **protege a todas sus hermanas de la capa** (tinte azul). Disparar a una ventana protegida no gasta la zona, no puntúa ni rompe la cadena: suena `shield_blocked` y la bala se pierde. Hay que bajar el firewall primero. |
| **critical-error** | una | "Cerrar" → cierra · "Reintentar" / "Depurar" / **X** → trampa | **1** si se acierta "Cerrar" | "Cerrar" **100** · trampa **−150 y cierra la cadena** | Los tres botones del cuerpo nacen **barajados y se rebarajan a cada trampa** (destello rojo + `window_error`). La X de la barra de título es trampa fija: la única posición memorizable, y siempre mala. Hay que leer el texto del botón. |

Familias declaradas pero sin escena propia todavía (`confirm`, `ad`,
`fake-close`, `task-manager`, `corrupt-file`, `installer`): se juegan como
`normal`. El nivel las puede declarar igual y empezarán a portarse distinto el
día que exista su escena.

### Resumen "costo y valor" por ventana

| Familia | Balas mínimas | Puntos máximos | Puntos por bala | Riesgo |
|---|---|---|---|---|
| normal | 1 | 100 | 100 | — |
| popup | 1 | 100 | 100 | se multiplica si se la deja |
| firewall | 1 | 100 | 100 | bloquea al resto hasta caer |
| critical-error | 1 | 100 | 100 | −150 y cadena cerrada por trampa |
| download | 2 | 160 | 80 | tiempo (12 s) |
| infected-download | 2 | 160 | 80 | cuelga el bloque a los 12 s |
| pelota (`TargetBall`) | 1 | 50 | 50 | — |

### Detalles que conviene saber al diseñar

- **download** tiene dos zonas de cancelar (la X y el botón). Si se acierta a
  las dos antes de confirmar, la segunda también paga 60: 220 puntos en 3
  balas en vez de 160 en 2. Es una rareza del código, no una mecánica.
- **popup** paga más por la X (100) que por el SKIP (60): el SKIP es solo un
  blanco más grande para quien no llega a la X, no un premio por esperar.
- El tope de 7 publicidades se cuenta **por bloque** (sobre los objetivos
  vivos del panel), no por capa.
- Una capa se limpia cuando caen **todas** sus ventanas, incluidas las
  publicidades derivadas.

---

## 4. Puntaje

Constantes en `resources/gameplay/score_settings.tres`
(`scripts/gameplay/score_settings.gd`).

### Valor de cada zona

| Zona | Puntos |
|---|---|
| `close` (X, "Cerrar", "Desactivar", "Sí") | 100 |
| `accept` / `cancel` / `finish` | 60 |
| `sign` | 40 |
| `next` | 10 |
| `trap` | **−150** |
| zona no tabulada | 60 |
| pelota | 50 |

### Pozo, cadena y multiplicador

Los puntos **no se cobran al impactar**: se acumulan en un pozo y se
multiplican enteros cuando la cadena se cierra.

| Hits en la cadena | 0–2 | 3–5 | 6–9 | 10–13 | 14–18 | 19–24 | 25+ |
|---|---|---|---|---|---|---|---|
| Multiplicador | ×1 | ×1,5 | ×2 | ×3 | ×4 | ×6 | ×8 |

- Cada acierto: `pozo += valor`, hits + 1, y reinicia la **gracia de 3 s**.
- **Fallo** (bala sin objetivo, cuerpo de una ventana): no toca el pozo ni
  cierra la cadena, pero baja **2 / 3 / 4 escalones** según sea el 1.º, 2.º o
  3.º+ fallo consecutivo (con piso en ×1).
- **Gracia vencida** (3 s sin acertar): si ya está en ×1, la cadena se cobra a
  ×1; si no, baja 1 escalón y la gracia se reinicia.
- **Cierres de la cadena** y a qué multiplicador cobran:

| Motivo | Multiplicador | Cuenta como… |
|---|---|---|
| Sala limpiada | **el vigente** | el único cierre "bueno" |
| Trampa (`critical-error`) | ×1 | cierre forzado |
| Daño recibido (cruzar un bloque) | ×1 | cierre forzado |
| Gracia vencida en ×1 | ×1 | cierre forzado **y** quiebre |
| Fin de ronda | ×1 | — |

El total nunca baja de 0. La cadena se reinicia al entrar a cada sala.

### Bonos de sala (al limpiarla; una sala sin objetivos no paga ninguno)

| Bono | Condición | Puntos |
|---|---|---|
| Sala limpia | sin daño recibido en la sala | 500 |
| Cadena única | ningún cierre forzado | 800 |
| Cadena intacta | ningún quiebre (fallo consecutivo o gracia) | 300 |
| Precisión | aciertos / disparos ≥ 60 % · 80 % · 100 % | 100 · 300 · 600 |
| Bajo par | por cada segundo por debajo del par | 10 |

**Par de la sala** = `objetivos × 1,8 s + 2,5 s`. Una sala es *perfecta* si
cumple cadena única e intacta.

### Bonos de nivel (solo si se llega a la salida)

| Bono | Valor |
|---|---|
| Munición restante | (cargador + reserva) × 5 |
| Tiempo restante | segundos enteros × 10 |
| Sin daño en todo el nivel | 2000 |
| Todas las salas limpias | 1000 |
| Todas las salas perfectas | 2500 |

Morir (`health_depleted`) o quedarse sin tiempo cierra la ronda sin bonos de
nivel y sin rango.

### Techo y rango

El techo del nivel es lo que pagaría una corrida perfecta:

- `techo_sala = objetivos × 100 × multiplicador(objetivos) + 500 + 800 + 300 + 600`
- `techo_nivel = Σ techo_sala + (munición − objetivos) × 5 + (duración − Σ par) × 10 + 2000 + 1000 + 2500`

El bono por bajar del par queda fuera a propósito: es la única forma de
superar el techo. El rango sale de `total / techo`:

| Ratio | < 0,35 | ≥ 0,35 | ≥ 0,55 | ≥ 0,75 | ≥ 0,90 | = 1,00 |
|---|---|---|---|---|---|---|
| Rango | D · GUEST | C · USER | B · POWER USER | A · ADMIN | S · ROOT | S+ · KERNEL |

Ejemplo (sala de 12 objetivos): multiplicador ×3 → techo de sala
12 × 100 × 3 + 2200 = **5800**; par 12 × 1,8 + 2,5 = **24,1 s**.

> Incoherencia conocida: el techo usa `startingAmmo.magazine` del JSON (17),
> pero el juego lo recorta al cargador real de la Glock (10). El techo queda
> inflado en 35 puntos. Ver `analisis_y_curva_de_niveles.md`.

---

## 5. Jugador y arma

| Dato | Valor |
|---|---|
| Vida | 100 |
| Daño por cruzar un bloque | 15 (6 cruces lo matan) |
| Daño por ventanas | ninguno |
| Glock: cargador / reserva máxima | 10 / 60 |
| Glock: daño | 25 (irrelevante contra objetivos: todo cae de un tiro) |
| Munición inicial | la del JSON, recortada al cargador (10) y a la reserva (60) |
| Tiempo de ronda | `timeLimitSeconds` del nivel (1–3600 s) |

Las pelotas de penalización (8 s de vida, 15 de daño si se van) **no aparecen
en bloques con capas**; solo existen en los sandboxes.

---

## 6. Límites del formato

| Límite | Valor |
|---|---|
| Oleadas por sala | 1–8 |
| Bloques por oleada | 3 slots fijos, cada uno habilitado o no |
| Capas por bloque | sin tope |
| Ventanas por capa | 1–64 (en total y por familia) |
| Tamaño de sala | 4–40 m por lado |
| Altura de pared / de bloque | 2–20 m / 2–12 m |
| Velocidad de bloque | 0,05–5 m/s |
| Recompensa de munición | 1–999 balas |

Los límites viven duplicados a propósito en `tools/level-editor/level-format.js`
y `scripts/levels/level_definition_loader.gd`; el smoke test del editor avisa
si divergen. Cómo se escriben en el JSON está en
[`niveles_json.md`](niveles_json.md); el comportamiento detallado de cada
ventana, en [`ventanas.md`](ventanas.md).
