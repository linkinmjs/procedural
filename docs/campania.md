# Campaña: diez niveles

Diseño de la campaña que vive en `level_designs/levels/nivel-01.json` …
`nivel-10.json`, en el orden de `level-sequence.json`. Reemplaza a los tres
niveles de prueba anteriores. Los niveles se editan con el Level Workshop
(`tools/level-editor/`); este documento explica **por qué** cada nivel es como
es, para que un retoque no rompa la curva sin querer.

La base teórica sale de *Beginning Game Level Design* (Feil & Scattergood,
2005, en `docs/pdfs/`) cruzada con lo que ya estaba escrito en
[`analisis_y_curva_de_niveles.md`](analisis_y_curva_de_niveles.md) (los cinco
ejes de dificultad y los presupuestos) y con los arquetipos de
[`catalogo_30_salas_level_design.md`](catalogo_30_salas_level_design.md), que
son las plantillas de `room-templates.json`.

---

## 1. Qué tomamos del libro

| Principio (capítulo) | Cómo se aplica en la campaña |
|---|---|
| **Los primeros diez minutos** deciden si el jugador sigue. La solución es una "sesión de entrenamiento velada": una lección por vez, jugarla, recién después la siguiente (cap. 1, *First Impressions*). | Los niveles 1 y 2 enseñan una cosa cada uno (cerrar; capas y recarga), con munición sobrada y tiempo al doble del par. No aparece ninguna familia especial hasta el nivel 5. |
| **El desafío tiene que verse y entenderse antes de lastimar.** Aprender muriendo es mala señal; el jugador tiene que poder ligar el problema con su solución (cap. 1, *Designing Challenges*). | Cada familia nueva se presenta **sola, estática y de frente** (Firewall 101, Lectura, Ventana emergente, Centro de descargas). La descarga infectada aparece por primera vez en una sala limpia, con cinco normales que la hacen visible por contraste, no tapada. |
| **Consistencia y crecimiento**: dificultad incremental, sin saltos ni mesetas; nunca cambiar las reglas por debajo del jugador (cap. 1, *In the Middle*). | Dientes de sierra: cada nivel sube **uno o dos ejes** (ejecución, secuencia, atención espacial, presión, comprensión) y el siguiente los combina. Las constantes de las ventanas no se tocan. |
| **Ritmo y flujo**: tensión y descanso se alternan; en un FPS el descanso es la zona ya limpiada (cap. 1, *Pacing and Flow*). | Sala de inicio vacía y sin cronómetro, pasillos cortos como respiro, la recompensa de munición **después** de dominar una pregunta y antes de la siguiente, salida vacía y a cielo abierto como cierre. |
| **Curva de dos jorobas**: un pico menor a mitad de nivel, un respiro y el clímax (cap. 10, *Locked-Position Shooters*). | Dentro de cada nivel: sala A establece, B sube, C cambia el eje o afloja, D es el examen. En la campaña entera: el nivel 6 (lectura, pocas ventanas) es el respiro entre 5 y 7; 9 y 10 son la subida final. |
| **El clímax usa todo lo aprendido y no introduce trucos nuevos**; después viene el desenlace (cap. 1, *Climax and Denouement*). | Nivel 10: seis oleadas que recapitulan las seis lecciones. Después de Kernel hay una sala más, **Apagar equipo**, vacía y bajo el cielo nocturno, para salir caminando y no cortar en seco. |
| **Ubicar al jugador**: que aparezca mirando hacia donde tiene que ir, en un lugar reconocible (cap. 6, *Placing the Player*). | `facing` apunta al primer pasillo. Las salas de inicio son chicas (8×8, 4 m de alto), con madera y radio: un "escritorio" que se distingue del resto. |
| **La arquitectura empuja y atrae**: los espacios abiertos invitan, los cerrados expulsan; alternarlos crea flujo. Viajes de menos de 30 s. Cada sala tiene que ser identificable (cap. 4). | Inicio cerrado y bajo → arenas altas y algunas a cielo abierto → salida abierta. Pasillos de 5–7 m. Cada nivel tiene una paleta de texturas propia y un color de panel propio; las arenas grandes son las únicas a cielo abierto. |
| **Luz y color como estado de ánimo**: azules fríos, naranjas cálidos; ante la duda, más luz (cap. 5). | El cielo marca el arco: día (1–2) → nublado (3) → día (4) → atardecer (5) → nublado (6) → día (7) → atardecer (8) → noche (9–10). |
| **Sonido por zona** sutil, no en todos lados (cap. 5, *Audio*). | Radios sólo en la sala de inicio y en la de salida: marcan "acá no se pelea". |
| **Colocar ítems**: el 75 % de la munición a la vista sobre el camino principal; que el jugador no llegue a la última pelea con el último aliento (cap. 6, *Item Placement*). | Las recompensas de munición aparecen en el centro de la sala recién limpiada. Antes de cada examen hay una recompensa grande (10–20 balas). |
| **Balancear**: primero el poder del jugador, después los "baches" sala por sala; mejor un poco difícil que aburrido (cap. 9). | Munición y tiempo salen de una fórmula (§4); lo que sigue es probar con gente y tocar **una sala**, no las constantes. |
| **Bloodlock aceptable si el jugador sabe qué se espera** (cap. 6, *Bloodlocking*). | El sellado de puertas es el bloodlock del juego; la barrera roja y el HUD lo hacen explícito. |

---

## 2. La campaña de un vistazo

| # | Nivel | Lección (pregunta que hace) | Salas de combate | Ventanas | Impactos | Balas | Límite |
|---:|---|---|---:|---:|---:|---:|---:|
| 1 | Hola, mundo | ¿Entendés dónde se dispara para cerrar una ventana? | 2 | 10 | 10 | 22 | 80 s |
| 2 | Actualizaciones pendientes | ¿Entendés que limpiar la pantalla no siempre cierra el bloque, y cuándo recargar? | 2 | 16 | 16 | 32 | 95 s |
| 3 | Barrido | ¿Podés releer la sala y girar cuando cambia de pared? | 3 | 30 | 30 | 60 | 145 s |
| 4 | Desfragmentar | ¿Conservás precisión mientras el espacio seguro se achica? | 3 | 31 | 31 | 62 | 160 s |
| 5 | Cortafuegos | ¿Identificás qué objetivo desbloquea al resto? | 3 | 33 | 33 | 68 | 140 s |
| 6 | Error crítico | ¿Podés frenar una fracción de segundo y leer antes de tirar? | 3 | 25 | 25 | 48 | 120 s |
| 7 | Publicidad | ¿Elegís bien qué costo pagar: tiempo, atención o una X más chica? | 4 | 27 (+derivadas) | 27+ | 64 | 190 s |
| 8 | Descargas | ¿Reconocés una amenaza irreversible y replanificás la sala alrededor de ella? | 4 | 31 | 39 | 68 | 160 s |
| 9 | Sobrecarga | Sin reglas nuevas: ¿armás una cola de prioridades con tres problemas a la vez? | 4 | 46 | 50 | 82 | 210 s |
| 10 | Kernel | Examen final: todo lo anterior en seis oleadas. | 4 | 70 | 74 | 110 | 280 s |

"Balas" es cargador inicial (10) + reserva inicial + recompensas de las salas.
"Impactos" cuenta las confirmaciones de descarga (2 por descarga cancelada).
El nivel 7 puede generar publicidades derivadas: se presupuesta margen.

Familias por nivel (primera aparición en negrita):

| # | normal | popup | firewall | critical-error | download | infected | móviles | oleadas por sala |
|---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | **●** | | | | | | | 1 |
| 2 | ● | | | | | | | 1 (capas) |
| 3 | ● | | | | | | | **3** |
| 4 | ● | | | | | | **●** | 1 |
| 5 | ● | | **●** | | | | | 2 |
| 6 | ● | | ● | **●** | | | | 1 |
| 7 | ● | **●** | | | | | ● | 2 |
| 8 | ● | | ● | ● | **●** | **●** | ● | 2 |
| 9 | ● | ● | ● | ● | ● | ● | ● | 1 |
| 10 | ● | ● | ● | ● | ● | ● | ● | 6 |

---

## 3. Nivel por nivel

Cada sala tiene cuatro *beats*: lectura (desde la puerta se ve dónde va a
aparecer el peligro), establecimiento, escalada y liberación (puerta abierta,
munición si corresponde, pasillo corto). Abajo, qué cambia en cada sala.

### 1 · Hola, mundo (día, revoque y baldosas)

- **Escritorio** (inicio, 8×8, madera, radio): mirar, moverse y disparar sin cronómetro.
- **Bandeja de entrada** (12×12): frontal, 4 ventanas `custom:bienvenida` (familia normal). Una sola pared, una sola capa.
- **Galería** (18×10): sala larga y angosta, 6 normales al fondo. Precisión básica y entrada en flow.
- **Salida**: vacía, a cielo abierto, radio.

Nada se mueve, nada se multiplica, nada castiga. Dos balas por objetivo.

### 2 · Actualizaciones pendientes

- **Parches** (12×12): frontal, capas 3 + 4. La primera capa cae y aparece otra: la pared no terminó. Recompensa de 8 balas en un momento seguro.
- **Cebolla** (14×14): frontal, capas 4 + 5. Examina si el jugador administró el cargador (10 balas: la segunda capa obliga a recargar).
- Primer giro del recorrido (norte y después este): el jugador aprende a buscar la puerta abierta.

### 3 · Barrido (nublado, ladrillo)

- **Barrido** (18×14): frontal 4 → izquierda 4 → derecha 4, en tres oleadas. Flicks amplios sin carga cognitiva.
- **Ping-pong** (16×14): izquierda 3 → derecha 3 → frontal 4. De reaccionar a anticipar.
- **Tridente** (16×16): las tres paredes a la vez con 2 + 4 + 2. Primera decisión espacial: por dónde empezar.

Todo estático y normal. Es el nivel que más ventanas suma respecto del
anterior (16 → 30), así que compensa con dos recompensas de 10.

### 4 · Desfragmentar (día, metal; panel ámbar)

- **Muro** (12×20): frontal móvil a 0,55 m/s, capas 5 + 5. Contacto a ~34 s: tiempo de sobra para entender que el panel avanza y que cruzarlo duele.
- **Embudo** (16×14, 8 m de alto, cielo abierto): laterales móviles a 0,5 m/s con 5 cada uno, contacto ~25 s. Elegir qué lado limpiar primero para ganar espacio.
- **Compresión** (16×14): izquierda móvil (6) y derecha estática (5). La presión viene de un solo lado: hay una zona segura que descubrir y usar.

Sin familias especiales: el movimiento es la única regla nueva.

### 5 · Cortafuegos (atardecer, ladrillo y madera; panel naranja)

- **Firewall 101** (14×14): 1 `custom:antivirus` + 5 normales. Identificar → bajar el firewall → limpiar.
- **Doble guardia** (18×14): izquierda con firewall + 4, derecha 4 sin firewall. Sólo un bloque está protegido: hay que darse cuenta cuál.
- **En profundidad** (14×14): oleada 1 frontal con capas (firewall + 4, firewall + 5); oleada 2 izquierda (firewall + 3) y derecha (3). Prioridad → ejecución → prioridad → ejecución, y después el cambio de pared del nivel 3.

### 6 · Error crítico (nublado, gris; panel lavanda)

- **Lectura** (12×12): 2 `custom:excepcion` + 3 normales. Sala chica y tranquila para descubrir que la X es trampa.
- **Falsa alarma** (14×14): capa 1 firewall + 4; capa 2 con 2 errores + 3. El reflejo del nivel 5 ("bajá el firewall rápido") choca con "leé antes de tirar".
- **No dispares todavía** (16×14): dos paredes con 2 errores + 3 normales cada una. Cadencia mental *shoot, shoot, STOP, leer, shoot*.

Es el nivel con menos ventanas del tramo medio a propósito: la dificultad es
cognitiva, no de volumen, y funciona como respiro antes del 7.

### 7 · Publicidad (día, madera; panel rosa)

- **Ventana emergente** (12×12): 1 popup + 3 normales. Un solo popup para descubrir X inmediata vs. SKIP con cuenta regresiva.
- **Adware** (16×14): oleada 1 frontal con 3 normales + 2 `custom:oferta`; oleada 2 izquierda con 3 popups.
- **Cola de espera** (16×14): popups estáticos a la izquierda y un panel normal lento (0,45 m/s) a la derecha. Elegir entre atender lo que se multiplica o lo que se acerca.
- **Popocalipsis** (16×16, cielo abierto): 2 + 3 + 2 popups en las tres paredes. Dificultad emergente: quien cierra rápido ve siete ventanas; quien espera, el doble.

El límite de tiempo es el más holgado del tramo (190 s) porque cada SKIP cuesta segundos.

### 8 · Descargas (atardecer, metal; panel verde)

- **Centro de descargas** (12×12): 2 `custom:driver` + 2 normales. Objetivo de dos pasos: cancelar → confirmar. Descubrir también la ruta barata de esperar "Finalizar".
- **Factura impaga** (14×14): 1 infectada + 5 normales, todo estático y despejado. Las normales tientan; la roja tiene consecuencias permanentes.
- **¿Cuál era?** (16×14): 2 descargas sanas + 1 `custom:factura` + 4 normales. La dificultad es reconocer cuál de las tres barras es la roja.
- **Firewall infectado** (18×16, cielo abierto): oleada 1 frontal con firewall + infectada + 4 normales (el pequeño puzzle: la infectada está protegida); oleada 2 laterales móviles lentos (0,45 m/s, contacto ~33 s), uno con infectada y otro con un error crítico.

### 9 · Sobrecarga (noche, ladrillo oscuro; panel celeste)

No introduce nada. Combina.

- **Izquierda o derecha** (16×14): infectada + 4 a un lado, 3 `custom:oferta` al otro. Dos amenazas de naturaleza distinta, sin una única respuesta correcta.
- **Reloj cruzado** (18×16): descarga + infectada a la izquierda, 4 `custom:estafa-bancaria` de frente, 3 popups a la derecha. Conviven lo irreversible, lo proliferante y lo fácil para sostener la cadena.
- **Trituradora** (18×12): laterales móviles a 0,5 m/s con capas 4 + 4 cada uno, contacto ~21 s. Limpiar la primera tanda no elimina el peligro. Recompensa de 12 al salir.
- **Sobrecarga** (18×16, cielo abierto): 3 popups | firewall + infectada + 3 | 2 errores + 3. Una resolución posible: firewall → infectada → popups → errores → resto.

### 10 · Kernel (noche, metal oscuro; panel rojo)

- **BIOS** (inicio 10×10).
- **Calentamiento** (14×14): 8 normales. Construir confianza y cadena.
- **Cirugía** (18×16): 2 errores + infectada + 3 normales. Pocas ventanas, cada tiro importa.
- **Falsa calma** (18×18): frontal 5 → izquierda 4 → derecha 4 → laterales móviles a 0,6 m/s con popup + 3 cada uno. Arco calma → confianza → sorpresa. Recompensa de 20 antes del examen.
- **Kernel** (24×20, 9 m de alto, cielo abierto), seis oleadas: calentamiento (5 normales) → atención (2 + 2 popups) → prioridad (firewall + infectada + 3) → lectura (2 + 2 errores) → presión espacial (laterales móviles a 0,7 m/s, 3 + 3) → examen (2 popups | antivirus + factura + 3 | 2 normales + descarga + error).
- **Apagar equipo** (salida 10×10, cielo abierto, radio): el desenlace.

---

## 4. Cómo se calcularon munición y tiempo

Los números salen de las fórmulas de `analisis_y_curva_de_niveles.md`:

- **Impactos** = ventanas, +1 por cada descarga (cancelar + confirmar).
- **Balas** = ⌈impactos / precisión objetivo⌉, con precisión objetivo 50 % (1–2), 58–60 % (3–4), 63–65 % (5–6), 68–70 % (7–10). Se comprobó además sala por sala que, entrando sin sobrante del tramo anterior, la munición acumulada alcanza para resolverla a esa precisión. El tope real del arma es 10 + 60: ninguna sala pide más de 60 balas ni a 70 %.
- **Par ajustado** = par del juego (1,8 s × ventana + 2,5 s × sala) + 0,5 s por firewall o error crítico + 1,2 s por descarga + 2,5 s por popup + 0,75 s por oleada extra + 4 s por sala con bloques móviles.
- **Viaje** = metros de pasillo y de cruce de sala a 6,4 m/s + 1,5 s por puerta.
- **Límite** = (par ajustado + viaje) × factor, redondeado a 5 s. Factor 2,2 → 2,0 → 1,7 → 1,55 → 1,5 → 1,4 → 1,35 del nivel 1 al 10.

El par que muestra el HUD sigue siendo el del sistema de puntuación (sin
extras), así que el rango alto sigue premiando a quien lo baja.

Tiempo hasta contacto de los bloques móviles (`recorrido / velocidad`):
34 s al enseñar (nivel 4, Muro), 25–28 s en el medio, 21 s en Trituradora y
27 s en Kernel, que ya viene con cinco oleadas de desgaste.

---

## 5. Diseños de ventana agregados (Window Workshop)

En `level_designs/window-designs.json`, todos con la mecánica de su familia
base; sólo cambian los textos y la skin, para que cada nivel tenga voz propia
y para que la variante retro aparezca de a poco:

| Slug | Familia | Se usa en |
|---|---|---|
| `bienvenida` | normal | 1 |
| `actualizacion` | normal | 2 |
| `estafa-bancaria` (ya existía) | normal | 9 |
| `oferta` | popup (rápido, lento y retro) | 7, 9, 10 |
| `driver` | download | 8 |
| `factura` | infected-download | 8, 9, 10 |
| `antivirus` | firewall | 5, 10 |
| `excepcion` | critical-error | 6, 9, 10 |

Las descargas infectadas custom siguen mostrando el nombre de archivo en rojo:
la regla que enseña el nivel 8 es "rojo = no dejarla terminar", no un nombre
en particular.

---

## 6. Reglas para retocar la campaña

1. Introducir una familia nueva sola; después combinarla; recién entonces
   someterla a movimiento. Nunca las tres cosas en el mismo nivel.
2. Entre niveles consecutivos, no subir más de dos ejes.
3. Con tres paredes activas, bajar cantidad o complejidad por pared.
4. Una amenaza con deadline (infectada, popup) no se estrena tapada ni fuera
   del campo visual.
5. Recompensar después de dominar una pregunta, antes de plantear la
   siguiente. Que la recompensa grande llegue antes del examen.
6. Salida con combate sólo como examen final; el resto vacías y abiertas.
7. Lo que sólo funciona con conocimiento previo pertenece a un desafío de
   rango, no al camino obligatorio.

Qué mirar al probar con jugadores (objetivos de `analisis_y_curva_de_niveles.md`):
85–95 % completa 1 y 2 en tres intentos; 70–85 % cada nivel medio; 55–70 % el
10. La mediana de munición sobrante debería quedar en 15–30 % del presupuesto
y la de tiempo entre 20 y 35 % por debajo del límite. Si un nivel falla esos
rangos, tocar **una sala** (cantidad, velocidad o recompensa), no las
constantes de las ventanas.
