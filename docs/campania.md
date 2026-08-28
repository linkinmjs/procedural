# Campaña: treinta niveles

Diseño de la campaña que vive en `level_designs/levels/nivel-01.json` …
`nivel-30.json`, en el orden de `level-sequence.json`. Los niveles se editan
con el Level Workshop (`tools/level-editor/`); este documento explica **por
qué** cada nivel es como es, para que un retoque no rompa la curva sin querer.
La estructura general (ejes, actos, curvas, reglas) está en
[`progresion.md`](progresion.md).

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
| **La dificultad es una montaña rusa**, no una rampa: cada tramo sube hasta su confrontación, respira y vuelve a subir (cap. 6, *Growth/Challenge Curve*). | Tres actos de diez niveles, cada uno con apertura, pico, respiro y examen. Los respiros (6, 16, 25) tienen las menos ventanas de su acto. |
| **Curva de dos jorobas** dentro de cada nivel (cap. 10, *Locked-Position Shooters*). | Sala A establece, B sube, C cambia el eje o afloja, D es el examen. |
| **El clímax usa todo lo aprendido y no introduce trucos nuevos**; después viene el desenlace (cap. 1, *Climax and Denouement*). | Kernel, Núcleo y Root recapitulan las lecciones de su acto en seis u ocho oleadas. Después de cada uno hay una sala más, vacía y bajo el cielo nocturno, para salir caminando y no cortar en seco. |
| **Ubicar al jugador**: que aparezca mirando hacia donde tiene que ir, en un lugar reconocible (cap. 6, *Placing the Player*). | `facing` apunta al primer pasillo. Las salas de inicio son chicas (8×8, 4 m de alto), con madera y radio: un "escritorio" que se distingue del resto. |
| **La arquitectura empuja y atrae**: los espacios abiertos invitan, los cerrados expulsan; alternarlos crea flujo. Viajes de menos de 30 s. Cada sala tiene que ser identificable (cap. 4). | Inicio cerrado y bajo → arenas altas y algunas a cielo abierto → salida abierta. Pasillos de 5–10 m. Cada nivel tiene una paleta de texturas propia y un color de panel propio. Los carteles sobre cada puerta dicen a dónde lleva. |
| **Luz y color como estado de ánimo**: azules fríos, naranjas cálidos; ante la duda, más luz (cap. 5). | El cielo marca el arco de cada acto: día → nublado → atardecer → noche, con la noche reservada para los exámenes y los niveles de amenaza irreversible. |
| **Sonido por zona** sutil, no en todos lados (cap. 5, *Audio*). | Radios sólo en la sala de inicio y en la de salida: marcan "acá no se pelea". El zumbido de los bloques sólo intimida de cerca. |
| **Colocar ítems**: munición a la vista sobre el camino principal; que el jugador no llegue a la última pelea con el último aliento (cap. 6, *Item Placement*). | La burbuja de munición flota en el centro de la sala recién limpiada. Antes de cada examen hay una recompensa grande (20 balas). |
| **Balancear**: primero el poder del jugador, después los "baches" sala por sala; mejor un poco difícil que aburrido (cap. 9). | Munición y tiempo salen de una fórmula (§5); lo que sigue es probar con gente y tocar **una sala**, no las constantes. |
| **Bloodlock aceptable si el jugador sabe qué se espera** (cap. 6, *Bloodlocking*). | El sellado de puertas es el bloodlock del juego; la barrera roja y el HUD lo hacen explícito. |

---

## 2. La campaña de un vistazo

| # | Nivel | Lección (pregunta que hace) | Salas de combate | Ventanas | Impactos | Balas | Límite |
|---:|---|---|---:|---:|---:|---:|---:|
| **I** | **Usuario** | | | | | | |
| 1 | Hola, mundo | ¿Entendés dónde se dispara para cerrar una ventana? | 2 | 10 | 10 | 22 | 80 s |
| 2 | Actualizaciones pendientes | ¿Entendés que limpiar la pantalla no siempre cierra el bloque, y cuándo recargar? | 2 | 16 | 16 | 32 | 95 s |
| 3 | Barrido | ¿Podés releer la sala y girar cuando cambia de pared? | 3 | 30 | 30 | 60 | 145 s |
| 4 | Desfragmentar | ¿Conservás precisión mientras el espacio seguro se achica? | 3 | 31 | 31 | 62 | 160 s |
| 5 | Cortafuegos | ¿Identificás qué objetivo desbloquea al resto? | 3 | 33 | 33 | 68 | 140 s |
| 6 | Error crítico | ¿Podés frenar una fracción de segundo y leer antes de tirar? | 3 | 25 | 25 | 48 | 120 s |
| 7 | Publicidad | ¿Elegís bien qué costo pagar: tiempo, atención o una X más chica? | 4 | 27+ | 27+ | 64 | 190 s |
| 8 | Descargas | ¿Reconocés una amenaza irreversible y replanificás la sala alrededor de ella? | 4 | 31 | 39 | 68 | 160 s |
| 9 | Sobrecarga | Sin reglas nuevas: ¿armás una cola de prioridades con tres problemas a la vez? | 4 | 46 | 50 | 82 | 210 s |
| 10 | Kernel | Examen I: todo lo anterior en seis oleadas. | 4 | 70 | 74 | 110 | 280 s |
| **II** | **Sistema** | | | | | | |
| 11 | Caché | Respiro: ¿sostenés la cadena veinte ventanas seguidas? | 3 | 41 | 41 | 70 | 135 s |
| 12 | Ping de red | ¿Anticipás dónde aparece la próxima oleada cuando trae familias? | 3 | 42 | 44 | 64 | 175 s |
| 13 | Sector dañado | ¿Podés leer un error crítico mientras el panel avanza? | 3 | 29 | 29 | 58 | 130 s |
| 14 | Cola de impresión | ¿Secuenciás descargas en capas y en dos paredes sin perder la roja? | 3 | 31 | 42 | 66 | 140 s |
| 15 | Adware persistente | ¿Cerrás popups a tiempo cuando además se te vienen encima? | 3 | 40+ | 40+ | 72 | 220 s |
| 16 | Modo seguro | Respiro: ¿cada bala cuenta cuando todo es trampa? | 3 | 20 | 25 | 46 | 105 s |
| 17 | Puerto abierto | ¿Resolvés firewall + infectada con dos relojes corriendo? | 3 | 42 | 47 | 72 | 175 s |
| 18 | Registro corrupto | ¿Ordenás tres paredes con familias distintas y después limpiás rápido? | 4 | 50 | 53 | 78 | 200 s |
| 19 | Fuga de memoria | ¿Administrás balas y cadena a lo largo de cinco salas? | 5 | 54 | 56 | 84 | 215 s |
| 20 | Pantalla azul | Examen II: Núcleo, seis oleadas más rápidas que Kernel. | 3 | 61 | 64 | 100 | 235 s |
| **III** | **Root** | | | | | | |
| 21 | Overclock | ¿Ejecutás limpio con paneles que llegan en 18–23 s? | 4 | 50 | 50 | 78 | 185 s |
| 22 | Inyección | ¿Priorizás infectadas protegidas con popups alrededor y paneles móviles? | 3 | 33 | 38 | 70 | 160 s |
| 23 | Bucle infinito | ¿Sabés dónde va a aparecer la oleada ocho? | 3 | 50 | 53 | 76 | 175 s |
| 24 | Desbordamiento | ¿Mantenés el multiplicador con capas de nueve y diez? | 3 | 58 | 58 | 84 | 190 s |
| 25 | Rootkit | Respiro: ¿precisión perfecta con munición corta? | 3 | 24 | 30 | 50 | 120 s |
| 26 | Ataque DDoS | ¿Gestionás una crisis de popups que además se acercan? | 3 | 32+ | 32+ | 76 | 200 s |
| 27 | Cortocircuito | ¿Te posicionás cuando la presión viene de un solo lado? | 3 | 39 | 41 | 70 | 155 s |
| 28 | Ransomware | ¿Ponés lo irreversible primero con el tiempo más corto del acto? | 3 | 30 | 39 | 70 | 125 s |
| 29 | Sistema comprometido | ¿Tres paredes mixtas y dos de ellas avanzando? | 3 | 50 | 54 | 82 | 205 s |
| 30 | Root | Examen III: ocho oleadas en la sala más grande. | 4 | 73 | 79 | 110 | 275 s |

"Balas" es cargador inicial (10) + reserva inicial + recompensas de las salas.
"Impactos" cuenta las confirmaciones de descarga (2 por descarga cancelada).
Los niveles con popups (7, 15, 26) pueden generar publicidades derivadas: se
presupuesta margen.

Familias por acto (primera aparición en negrita):

| Acto | normal | popup | firewall | critical-error | download | infected | móviles | oleadas máx. |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| I (1–10) | **1** | **7** | **5** | **6** | **8** | **8** | **4** | 6 |
| II (11–20) | ● | ● | ● | ● | ● | ● | ● | 6 |
| III (21–30) | ● | ● | ● | ● | ● | ● | ● | 8 |

---

## 3. Acto I · Usuario (1–10)

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

Es el nivel con menos ventanas del acto a propósito: la dificultad es
cognitiva, no de volumen, y funciona como respiro antes del 7.

### 7 · Publicidad (día, madera; panel rosa)

- **Ventana emergente** (12×12): 1 popup + 3 normales. Un solo popup para descubrir X inmediata vs. SKIP con cuenta regresiva.
- **Adware** (16×14): oleada 1 frontal con 3 normales + 2 `custom:oferta`; oleada 2 izquierda con 3 popups.
- **Cola de espera** (16×14): popups estáticos a la izquierda y un panel normal lento (0,45 m/s) a la derecha. Elegir entre atender lo que se multiplica o lo que se acerca.
- **Popocalipsis** (16×16, cielo abierto): 2 + 3 + 2 popups en las tres paredes. Dificultad emergente: quien cierra rápido ve siete ventanas; quien espera, el doble.

El límite de tiempo es el más holgado del acto (190 s) porque cada SKIP cuesta segundos.

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

## 4. Acto II · Sistema (11–20)

Todas las reglas ya se conocen. El acto pregunta si el jugador puede aplicar
**dos a la vez**: leer mientras un panel avanza, cancelar descargas en capas,
cerrar popups que además se mueven. Los diseños de ventana nuevos (`soporte`,
`torrent`, `rescate`, `vpn`, `panico`) le cambian la voz sin cambiar la mecánica.

### 11 · Caché (día, revoque claro; panel turquesa) — apertura / respiro

- **Maratón** (14×14): frontal, cuatro capas de 5 (la última `custom:soporte`). Veinte ventanas sin girar la cabeza: cadena y ritmo después de Kernel.
- **Tridente II** (16×16): 4 + 5 + 4 en las tres paredes, todo normal.
- **Galería larga** (20×10): 8 normales al fondo de una sala larga. Precisión a distancia.

### 12 · Ping de red (nublado, ladrillo; panel celeste)

- **Eco** (16×14): izquierda firewall + 3 → derecha vpn + 3 → frontal 5. El ping-pong del nivel 3, ahora con prioridad en cada pared.
- **Latencia** (18×14): cuatro oleadas que alternan familias (3 popups → 3 + error → 3 + descarga → 4). Anticipar dónde y qué.
- **Paquete perdido** (16×16): frontal 5 → 2 + 2 popups en los laterales → frontal firewall + infectada + 3.

### 13 · Sector dañado (atardecer, ladrillo oscuro; panel lavanda)

- **Lectura lenta** (18×12): frontal móvil muy lento (0,4 m/s, contacto ~42 s) con 2 errores + 4 normales. Primera vez que hay que leer con un panel viniendo.
- **Doble lectura** (16×14): izquierda móvil con 2 `custom:panico` + 3; derecha estática con firewall + 3.
- **Sin frenos** (16×16): frontal 2 errores + 4; después laterales móviles a 0,5 m/s con un error cada uno.

### 14 · Cola de impresión (día, metal; panel verde)

- **Cola** (12×12): capas de descargas: 2 `custom:driver` + 2 | 2 descargas + firewall + 2. Cancelar → confirmar en secuencia, con el firewall en medio.
- **Documento pendiente** (16×14): 2 `custom:torrent` + 2 a la izquierda; infectada + 3 a la derecha. Dos paredes, una con reloj irreversible.
- **Impresora atascada** (18×16): frontal 3 descargas + firewall + 2; después lateral móvil con `custom:factura` + 3 y el otro con 2 errores + 2.

### 15 · Adware persistente (noche, madera; panel rosa) — pico

- **Barra de herramientas** (14×14): capas 3 `custom:oferta` + 3 | 2 popups + 3.
- **Ventanas en cadena** (18×14): frontal 4 → 3 popups izquierda → 3 `oferta` derecha → laterales móviles a 0,55 m/s con popup + 3 cada uno. Los popups del nivel 7 con el movimiento del 4.
- **Popocalipsis II** (18×18, cielo abierto): 3 popups | 3 `oferta` + firewall | 3 popups + error. El popocalipsis del acto I, con dos ventanas de lectura adentro.

### 16 · Modo seguro (nublado, gris claro; panel plomo) — respiro

Veinte ventanas y 46 balas: el nivel más chico del acto y el que menos perdona.

- **Diagnóstico** (16×14): 2 errores + infectada + 2 normales.
- **Cuarentena** (18×16): izquierda firewall + `rescate` + 1; derecha 2 `excepcion` + 2.
- **Restaurar sistema** (18×16): frontal 2 descargas + 2 errores; después izquierda vpn + infectada + 2.

### 17 · Puerto abierto (atardecer, metal; panel naranja)

- **Puerto 80** (14×14): dos capas, cada una con firewall + infectada + normales. El puzzle "firewall infectado" del nivel 8, dos veces seguidas.
- **Túnel** (18×12): laterales móviles a 0,55 m/s con dos capas cada uno (firewall + 3 | infectada + 3 y 3 | vpn + 3). Contacto ~30 s: la Trituradora con prioridad.
- **Cortafuegos caído** (18×16, cielo abierto): tres paredes (vpn + 3 | `rescate` + 3 | 3 popups) y después un frontal móvil con firewall + infectada + 3.

### 18 · Registro corrupto (noche, ladrillo; panel celeste)

- **Clave rota** (16×14): 2 errores + 2 | firewall + 4 | 3 popups. Tres paredes, todo quieto: ordenar la cola sin apuro.
- **Valores basura** (18×16): descarga + infectada + 2 | 2 `panico` + 3 | 3 `oferta`. Lo irreversible, lo que hay que leer y lo que se multiplica, cada cosa en una pared.
- **Colmena** (18×16): tres paredes mixtas y después 6 normales de frente para cobrar la cadena.
- **Reinicio** (14×14): 8 `custom:soporte`. Alivio antes de la salida.

### 19 · Fuga de memoria (nublado, gris; panel plomo) — resistencia

Cinco salas medianas y el factor de tiempo más bajo del acto (1,3).

- **Página 1** (14×14): capas 4 + popup | 4 + firewall.
- **Página 2** (16×14): 3 + error a la izquierda, 3 + `torrent` a la derecha.
- **Página 3** (16×14): frontal móvil a 0,5 m/s con capas 6 | 4 + infectada.
- **Página 4** (16×16): 3 `oferta` → 3 + 2 errores → vpn + 4.
- **Swap** (18×16): laterales móviles a 0,55 m/s con 4 cada uno y 2 `panico` + 2 de frente.

### 20 · Pantalla azul (noche, metal oscuro; panel rojo) — examen II

- **POST** (inicio 10×10).
- **Volcado** (14×14): 6 normales + 2 popups.
- **Interrupción** (18×16): firewall + `rescate` + 2 | 2 errores + 3. Recompensa de 20.
- **Núcleo** (24×20, 9 m, cielo abierto), seis oleadas: 6 normales → 3 popups + 3 `oferta` → firewall + infectada + 4 → 2 + 2 errores y 2 + 2 `panico` → laterales móviles a 0,75 m/s (contacto ~25 s) con 4 cada uno → 2 popups | vpn + factura + 3 | 2 errores + 1.
- **Reinicio forzado** (salida 10×10, cielo abierto).

---

## 5. Acto III · Root (21–30)

Ya no hay nada que enseñar ni que combinar por primera vez. El acto sube
velocidad, densidad y escasez: paneles que llegan en 18–23 s, capas de nueve
y diez, ocho oleadas, munición a 1,4–1,5 balas por impacto y el factor de
tiempo en 1,25–1,3.

### 21 · Overclock (día, metal; panel ámbar) — apertura

Sólo ventanas normales. La regla nueva del acto es la velocidad.

- **Turbo** (20×12): frontal a 0,8 m/s con capas 5 + 5, contacto ~23 s.
- **Ventilador** (16×14): laterales a 0,7 m/s con 5 cada uno, contacto ~21 s.
- **Disipador** (18×12): laterales a 0,6 m/s con capas 4 + 4 cada uno, contacto ~18 s.
- **Frecuencia** (16×16): frontal a 0,8 m/s con 6; después laterales a 0,7 m/s con 4 cada uno.

### 22 · Inyección (atardecer, ladrillo; panel verde)

- **Payload** (14×14): capas firewall + `rescate` + 3 | 2 popups + 3.
- **Vector** (18×14): izquierda móvil con `rescate` + 3; derecha estática con 3 `oferta` + firewall.
- **Exploit** (18×16, cielo abierto): 2 popups | vpn + `rescate` + 3; después laterales móviles a 0,55 m/s con una infectada cada uno.

### 23 · Bucle infinito (noche, revoque; panel lavanda)

- **Iteración** (18×16): ocho oleadas, el máximo del formato: izq 3 → der 3 → frente 4 → izq 2 + popup → der 2 + error → frente firewall + 4 → izq 3 + der 3 `soporte` → frente 3 + 2 `panico`. Treinta y dos ventanas sin salir de la sala.
- **Condición de salida** (16×14): 2 `torrent` + 2 → `rescate` + 3 → vpn + 3.
- **Break** (14×14): 6 normales, para respirar antes de la salida.

### 24 · Desbordamiento (nublado, ladrillo; panel celeste) — pico

- **Búfer** (18×14): capas 9 | 8 + error. Las capas más densas de la campaña.
- **Pila** (20×16): 6 + firewall | 4 `soporte` | 6 + error.
- **Heap** (20×18, cielo abierto): frontal 10; después laterales móviles a 0,6 m/s con 5 + popup cada uno.

### 25 · Rootkit (noche, metal oscuro; panel plomo) — respiro

Veinticuatro ventanas, 50 balas, casi nada fácil.

- **Oculto** (16×14): `rescate` + firewall + 2 errores + 1 normal.
- **Persistencia** (18×16): descarga + 2 `panico` | `rescate` + vpn + 1.
- **Extracción** (18×16): capas 2 infectadas + 2 errores | factura + firewall + excepción; después laterales móviles con un error cada uno.

### 26 · Ataque DDoS (atardecer, madera; panel rosa)

- **Solicitudes** (16×14): 4 popups + 2 normales.
- **Saturación** (18×16): 3 `oferta` | 3 popups + firewall | 3 popups.
- **Colapso** (20×18, cielo abierto): 2 | 4 `oferta` | 2 popups; después laterales móviles a 0,6 m/s con 2 popups + 2 cada uno. Quien cierra por la X ve dieciséis ventanas; quien espera, hasta el doble.

### 27 · Cortocircuito (noche, metal; panel naranja)

- **Chispa** (16×14): izquierda móvil a 0,6 m/s con 6; frente firewall + 4; derecha estática 3. La presión viene de un solo lado.
- **Sobretensión** (18×14): izquierda lenta (0,5) con `rescate` + 4; derecha rápida (0,9, contacto ~19 s) con 2 + 2 errores. Camino corto difícil vs. camino largo fácil.
- **Fusible** (18×16): frente 3 + 2 `panico` y derecha móvil con 4 + 2 popups; después izquierda móvil con firewall + infectada + 3.

### 28 · Ransomware (atardecer, ladrillo oscuro; panel rojo)

Una infectada en cada oleada y el factor de tiempo más bajo (1,25).

- **Cifrado** (14×14): capas 3 + descarga + `rescate` | 2 + `rescate` + firewall.
- **Rescate** (18×14): `rescate` + 3 | `rescate` + 2 errores.
- **Llave** (18×16, cielo abierto): frontal vpn + 2 `rescate` + 3; después laterales móviles con una infectada cada uno.

### 29 · Sistema comprometido (noche, metal; panel celeste)

- **Proceso desconocido** (18×16): 3 popups | firewall + `rescate` + 3 | 2 errores + 3.
- **Privilegios** (18×16): laterales móviles a 0,5 m/s (vpn + 4 y 2 `panico` + 2) con 2 `torrent` + 2 de frente.
- **Puerta trasera** (20×18, cielo abierto): tres paredes mixtas y después laterales móviles a 0,6 m/s con 4 + popup cada uno. Veinticuatro ventanas: la antesala de Root.

### 30 · Root (noche, metal oscuro; panel rojo) — examen III

- **Login** (inicio 10×10).
- **Sudo** (14×14): 8 normales.
- **Escalada** (18×16): firewall + `rescate` + 3 → 2 errores + 2 | 2 popups + 2.
- **Panic** (18×18): laterales móviles a 0,6 m/s con 4 cada uno → frontal 2 + `rescate` + vpn + 2 `panico`. Recompensa de 20.
- **Root** (26×22, 10 m, cielo abierto), ocho oleadas: 4 normales → 2 popups + 2 `oferta` → firewall + `rescate` + 3 → 2 errores + 2 `panico` → laterales a 0,75 m/s con 3 cada uno → 2 `torrent` + vpn → 2 popups | `rescate` + vpn + 2 | 2 errores + 1 → frontal a 0,9 m/s con 3.
- **Shutdown** (salida 10×10, cielo abierto, radio).

---

## 6. Cómo se calcularon munición y tiempo

Los números salen de las fórmulas de `analisis_y_curva_de_niveles.md`:

- **Impactos** = ventanas, +1 por cada descarga (cancelar + confirmar).
- **Balas** = ⌈impactos / precisión objetivo⌉, con precisión objetivo 50 % (1–2), 58–60 % (3–4), 63–65 % (5–6), 68–70 % (7–20) y 72 % (21–30). Se comprobó además sala por sala que, entrando sin sobrante del tramo anterior, la munición acumulada alcanza para resolverla a esa precisión. El tope real del arma es 10 + 60: ninguna sala pide más de 70 balas.
- **Par ajustado** = par del juego (1,8 s × ventana + 2,5 s × sala) + 0,5 s por firewall o error crítico + 1,2 s por descarga + 2,5 s por popup + 0,75 s por oleada extra + 4 s por sala con bloques móviles.
- **Viaje** = metros de pasillo y de cruce de sala a 6,4 m/s + 1,5 s por puerta.
- **Límite** = (par ajustado + viaje) × factor, redondeado a 5 s. Factor 2,2 → 1,35 en el acto I, 1,35 → 1,3 en el II, 1,3 → 1,25 en el III.

El par que muestra el HUD sigue siendo el del sistema de puntuación (sin
extras), así que el rango alto sigue premiando a quien lo baja.

Tiempo hasta contacto de los bloques móviles (`recorrido / velocidad`): 34 s
al enseñar (4, Muro), 25–33 s en los actos I y II, 18–23 s en Overclock y
19–31 s en el resto del acto III.

---

## 7. Diseños de ventana (Window Workshop)

En `level_designs/window-designs.json`, todos con la mecánica de su familia
base; sólo cambian los textos y la skin, para que cada nivel tenga voz propia
y para que la variante retro aparezca de a poco:

| Slug | Familia | Se usa en |
|---|---|---|
| `bienvenida` | normal | 1 |
| `actualizacion` | normal | 2 |
| `estafa-bancaria` (ya existía) | normal | 9 |
| `soporte` | normal | 11, 18, 23, 24 |
| `oferta` | popup (rápido, lento y retro) | 7, 9, 10, 12, 15, 18, 19, 20, 22, 24, 26, 29, 30 |
| `driver` | download | 8, 14 |
| `torrent` | download | 14, 19, 23, 29, 30 |
| `factura` | infected-download | 8, 9, 10, 14, 17, 20, 22, 25, 28 |
| `rescate` | infected-download | 16, 17, 20, 22, 23, 25, 27, 28, 29, 30 |
| `antivirus` | firewall | 5, 10, 17 |
| `vpn` | firewall | 12, 16, 17, 19, 20, 22, 23, 25, 28, 29, 30 |
| `excepcion` | critical-error | 6, 9, 10, 16, 25 |
| `panico` | critical-error | 13, 18, 19, 23, 25, 27, 29, 30 |

Las descargas infectadas custom siguen mostrando el nombre de archivo en rojo:
la regla que enseña el nivel 8 es "rojo = no dejarla terminar", no un nombre
en particular.

---

## 8. Reglas para retocar la campaña

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

Qué mirar al probar con jugadores está en [`progresion.md`](progresion.md) §7.
Si un nivel falla esos rangos, tocar **una sala** (cantidad, velocidad o
recompensa), no las constantes de las ventanas.
