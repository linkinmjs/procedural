# Análisis y curva de niveles

> **Estado (2026-08-28):** la campaña construida a partir de este análisis está
> documentada en [`campania.md`](campania.md) (diez niveles, `nivel-01` …
> `nivel-10`). El diagnóstico de abajo describe los tres niveles de prueba
> anteriores, que ya no existen; las fórmulas de presupuesto y las reglas de
> composición siguen vigentes y son las que usa la campaña.

## Objetivo del documento

Este documento propone una primera campaña de ocho niveles para enseñar y luego
examinar las mecánicas que ya existen en el proyecto. Los números son una
hipótesis de balance para prototipar: deben ajustarse con telemetría de jugadores,
no tomarse como valores finales.

La fantasía jugable central es leer una pared de ventanas bajo presión, decidir
prioridades y ejecutar tiros precisos con recursos finitos. Por eso la dificultad
no debería crecer sólo agregando blancos. Debe crecer alternando cinco ejes:

1. **Ejecución:** cantidad de impactos y precisión exigida.
2. **Secuencia:** capas dentro de un bloque y oleadas dentro de una sala.
3. **Atención espacial:** cantidad de paredes activas al mismo tiempo.
4. **Presión:** bloques móviles, distancia de contacto y tiempo global.
5. **Comprensión:** reglas de `firewall`, `critical-error`, `popup` y descargas.

## Diagnóstico de los niveles actuales

La Glock tiene un cargador real de 10 balas y una reserva máxima de 60. Aunque
los tres JSON declaran 17 balas en el cargador, el runtime recorta ese valor a
10. Conviene guardar 10 en los diseños para que la herramienta no comunique una
economía falsa.

| Nivel actual | Objetivos declarados | Impactos mínimos aproximados | Balas iniciales reales | Recompensas | Tiempo | Par aproximado actual |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Nivel 1 | 12 | 13 | 61 | 0 | 60 s | 24,1 s |
| Nivel 2 | 39 | 39 | 60 | 10 | 60 s | 80,2 s |
| Nivel 3 | 40 | 40 | 55 | 0 | 80 s | 77,0 s |

El impacto adicional del nivel 1 corresponde a cancelar correctamente la
descarga infectada. La estimación supone un impacto por ventana normal y no
incluye errores.

Problemas detectados:

- El salto de 13 a 39 impactos entre los dos primeros niveles es demasiado
  grande para una introducción.
- El nivel 1 entrega casi cinco balas por impacto obligatorio, por lo que la
  munición todavía no enseña nada. El nivel 3 baja de golpe a 1,38.
- El límite de 60 segundos del nivel 2 está por debajo del par calculado por el
  propio sistema de puntuación. Una corrida de aprendizaje compite contra una
  referencia de dominio.
- El nivel 1 introduce una descarga infectada antes de establecer con claridad
  las ventanas normales, las capas, las oleadas y el movimiento.
- El nivel 2 mezcla capas, dos paredes simultáneas y bloques móviles. Es difícil
  saber qué habilidad causó un fallo.
- Capas de 10 ventanas superpuestas pueden aumentar ruido visual y oclusión, no
  necesariamente decisiones interesantes.

La sala `exit` puede estar vacía o contener el examen final. Si tiene objetivos,
el runtime espera a que se limpien antes de terminar la ronda.

## Gramática recomendada

### Sala, oleada, bloque y capa

Cada nivel debería usar esta jerarquía con una intención distinta:

- **Sala:** una pregunta jugable completa.
- **Oleada de sala:** cambia la dirección o la prioridad después de resolver una
  situación. Sirve para sorpresa y relectura espacial.
- **Bloque:** fuente de presión en una pared. Dos bloques simultáneos dividen la
  atención; tres deben reservarse para exámenes avanzados.
- **Capa:** prolonga el compromiso con la misma pared. Sirve para ritmo,
  resistencia y recarga, no para cambiar la pregunta espacial.

Regla práctica: si se quiere que el jugador siga mirando la misma pared, usar
otra capa. Si se quiere que gire, se reposicione o cambie prioridades, usar otra
oleada.

### Forma de una sala de combate

Una buena sala tiene cuatro beats:

1. **Lectura:** desde la entrada se entiende dónde aparecerá el primer peligro.
2. **Establecimiento:** una versión limpia de la pregunta.
3. **Escalada:** la misma pregunta con una variable adicional.
4. **Liberación:** puerta abierta, munición si corresponde y tránsito corto.

No hace falta que cada sala tenga cuatro oleadas. Los beats pueden repartirse
entre capas y oleadas, pero el jugador debería poder explicar qué cambió.

### Tamaño y densidad

- Sala estándar: 10–14 m de ancho por 10–14 m de profundidad.
- Sala de precisión: 14–18 m de profundidad, una pared frontal y pocos blancos.
- Sala de presión: 8–10 m de profundidad. Usarla sólo cuando el bloque móvil sea
  la lección explícita.
- Corredor de cruce: 8–10 m de ancho por 20–28 m de profundidad, con paredes
  laterales activas.
- Capas iniciales: 3–5 ventanas.
- Capas medias: 5–7 ventanas.
- Capas avanzadas: 6–8 ventanas complejas; hasta 10 sólo si son normales y la
  legibilidad visual está comprobada.
- Un `firewall` por bloque y capa suele ser suficiente. Más de uno repite la
  misma decisión sin profundizarla.

La velocidad de un bloque no debe evaluarse aislada. La métrica útil es:

`tiempo_hasta_contacto = distancia_de_recorrido / movementSpeed`

Como primera referencia, buscar 30–35 s al enseñar movimiento, 22–28 s en el
medio de la campaña y 16–22 s en el examen final.

## Presupuestos de munición y tiempo

### Munición

No balancear munición con la cantidad de ventanas, sino con los **impactos
requeridos**:

- `normal`, `firewall` y `critical-error`: 1 impacto correcto.
- `popup`: 1 si se usa la X inmediatamente; puede crear ventanas adicionales si
  se espera o se dispara al anuncio.
- `download`: 2 por cancelación rápida; 1 si se espera a finalizar.
- `infected-download`: 2 antes de 12 s; dejarla finalizar sacrifica el bloque.

Fórmula de partida:

`balas_disponibles = techo(impactos_nominales / precisión_objetivo)`

Precisión objetivo para completar, no para rango S:

| Tramo | Precisión de supervivencia |
| --- | ---: |
| Niveles 1–2 | 50–55 % |
| Niveles 3–4 | 58–62 % |
| Niveles 5–6 | 63–67 % |
| Niveles 7–8 | 68–72 % |

Las recompensas deben actuar como recuperación después de superar una sala, no
como requisito para poder disparar el último blanco. Antes de una sala, el
jugador debería tener balas suficientes para resolverla con la precisión objetivo
aunque haya llegado sin munición sobrante del tramo anterior.

### Tiempo

El par existente de `1,8 s × objetivo + 2,5 s × sala de combate` funciona para
ventanas simples. Para que siga siendo honesto conviene agregar costes de regla:

- +0,5 s por ventana de lectura (`firewall` o `critical-error`).
- +1,2 s por `download` o `infected-download` resuelta de forma rápida.
- +2,5 s por `popup` si el diseño espera que se interactúe con su temporizador.
- +0,75 s por cambio de oleada posterior a la primera.
- +3–6 s por sala con bloques móviles, según distancia y velocidad.

El límite para completar debería empezar cerca de `1,5 × par` y bajar
gradualmente hasta `1,3 × par`. El rango alto puede seguir premiando llegar al
par o superarlo.

## Campaña base propuesta

La campaña usa una forma de dientes de sierra: cada nivel introduce una regla en
un contexto moderado y el siguiente la combina con lo anterior. Nunca se suben
al mismo tiempo cantidad, velocidad, direcciones y complejidad de ventanas.

| N.º | Nombre de trabajo | Salas (combate) | Ventanas autorales | Impactos nominales | Balas: cargador + reserva + premios | Tiempo | Lección principal |
| ---: | --- | ---: | ---: | ---: | --- | ---: | --- |
| 1 | Cerrar | 4 (2) | 10 | 10 | 10 + 10 + 0 = 20 | 35 s | Apuntar a controles y limpiar una pared estática |
| 2 | Capas | 4 (2) | 16 | 16 | 10 + 13 + 6 = 29 | 50 s | Recargar y entender que una pared revela otra capa |
| 3 | Oleadas | 4 (2) | 20 | 20 | 10 + 19 + 5 = 34 | 60 s | Girar cuando la sala cambia de pared |
| 4 | Avance | 4 (2) | 24 | 24 | 10 + 23 + 6 = 39 | 70 s | Resolver bloques móviles y leer tiempo de contacto |
| 5 | Prioridad | 5 (3) | 28 | 28 | 10 + 28 + 6 = 44 | 80 s | Desactivar `firewall` antes de disparar a sus hermanas |
| 6 | Leer | 5 (3) | 30 | 30 | 10 + 29 + 6 = 45 | 85 s | Distinguir el control correcto de `critical-error` |
| 7 | Demora | 5 (3) | 24 + derivados | 32 de contingencia | 10 + 28 + 8 = 46 | 90 s | Elegir entre cerrar `popup` ya o gestionar su espera |
| 8 | Interrumpir | 5 (3) | 26 | 32 | 10 + 28 + 10 = 48 | 90 s | Cancelar descargas y priorizar la infectada bajo presión |

“Ventanas autorales” cuenta lo escrito en el JSON. “Impactos nominales” incluye
las confirmaciones de descarga y, en el nivel 7, un margen para anuncios
derivados. Los premios pueden dividirse entre varias salas, pero conviene que el
último llegue antes del examen final.

### Nivel 1 — Cerrar

- Inicio vacío para mirar, mover y disparar sin cronómetro.
- Sala A: bloque frontal estático, una capa de 4 `normal`.
- Sala B: bloque frontal estático, una capa de 6 `normal`.
- Salida vacía y visible desde la última puerta.
- No usar movimiento, laterales, familias especiales ni más de una capa.

Pregunta del nivel: “¿Entendés dónde se dispara para cerrar una ventana?”

### Nivel 2 — Capas

- Sala A: bloque frontal, capas de 3 y 4.
- Sala B: bloque frontal, capas de 4 y 5.
- Premio de 6 balas después de la primera sala.
- Diseñar la primera recarga en un momento seguro; la segunda sala examina si el
  jugador administró el cargador.

Pregunta: “¿Entendés que limpiar la pantalla actual no siempre termina el
bloque?”

### Nivel 3 — Oleadas

- Sala A: oleada frontal de 5; después izquierda y derecha con 4 cada una.
- Sala B: frontal de 7, en una única capa.
- Mantener todos los bloques estáticos.
- Dar una señal breve y consistente antes de cada nueva oleada.

Pregunta: “¿Podés releer la sala y cambiar el eje de atención?”

### Nivel 4 — Avance

- Sala A: un frontal móvil lento, 6 + 6 en capas.
- Sala B: laterales móviles, 6 por lado y simultáneos.
- Tiempo de contacto inicial de 30–35 s; segunda sala, 24–28 s.
- No introducir ventanas especiales todavía: el movimiento es la única regla
  nueva.

Pregunta: “¿Podés conservar precisión mientras el espacio seguro se reduce?”

### Nivel 5 — Prioridad

- Sala A: 1 `firewall` + 5 `normal`, frontal y estático.
- Sala B: dos bloques simultáneos; sólo uno tiene `firewall`.
- Sala C: dos oleadas que cambian de pared; cada bloque protegido tiene un solo
  `firewall` claramente visible.
- Reducir algo la cantidad respecto de un nivel puramente normal si las ventanas
  se superponen demasiado.

Pregunta: “¿Identificás qué objetivo desbloquea el resto?”

### Nivel 6 — Leer

- Sala A: 2 `critical-error` aislados con normales alrededor.
- Sala B: `firewall` seguido de 2 `critical-error`; nunca superponer sus controles
  durante la primera exposición.
- Sala C: dos paredes con 2 `critical-error` por pared y bloques estáticos.
- Las trampas castigan puntaje y cadena; la escasez de munición ya castiga el
  disparo apurado sin necesitar daño adicional.

Pregunta: “¿Podés frenar una fracción de segundo y leer antes de tirar?”

### Nivel 7 — Demora

- Sala A: un `popup` aislado para enseñar X inmediata frente a SKIP demorado.
- Sala B: 2 `popup` mezclados con normales, sin movimiento.
- Sala C: `popup` en una pared y presión normal lenta en otra.
- Diseñar para un máximo práctico de 3–4 anuncios vivos; el límite técnico de 7
  es una defensa, no un objetivo de composición.

Pregunta: “¿Elegís correctamente qué costo pagar: tiempo, atención o una X más
pequeña?”

### Nivel 8 — Interrumpir

- Sala A: `download` sana aislada. Permite descubrir la ruta barata de esperar y
  la ruta rápida de dos disparos.
- Sala B: primera `infected-download`, sin movimiento, con espacio visual limpio.
- Sala C/salida: tres oleadas. Primero combinación conocida; después descarga
  sana con `firewall`; por último dos paredes móviles, una con
  `infected-download` y otra con normales/`critical-error`.
- La descarga infectada debe ser visible al aparecer y no quedar totalmente
  tapada por otras ventanas. La dificultad debe venir de priorizarla, no de no
  haber podido verla.

Pregunta: “¿Podés reconocer una amenaza irreversible y reorganizar todo el plan
de la sala alrededor de ella?”

## Reglas para construir encuentros futuros

1. Introducir una familia nueva sola, después combinarla y recién entonces
   someterla a movimiento.
2. No subir más de dos ejes de dificultad entre niveles consecutivos.
3. Si una sala tiene tres paredes activas, bajar cantidad o complejidad por
   pared.
4. Si una capa tiene una amenaza con deadline, evitar otra amenaza irreversible
   fuera del campo visual durante su primera aparición.
5. Recompensar después de dominar una pregunta, antes de plantear la siguiente.
6. Usar una salida con combate sólo como examen final; usarla vacía cuando el
   nivel necesita un cierre y respiración.
7. Una composición que sólo funciona con conocimiento previo pertenece a un
   desafío de rango, no al camino obligatorio de campaña.

## Telemetría mínima para validar la curva

Registrar por intento y por sala:

- tiempo de entrada, limpieza y salida;
- disparos, impactos útiles, rebotes en firewall y zonas trampa;
- munición al entrar, al recibir premio y al salir;
- familia y capa en la que termina un intento;
- daño por cruzar bloques y tiempo restante al contacto;
- cantidad máxima de ventanas simultáneas y anuncios derivados;
- orden real de resolución de las familias;
- reinicios voluntarios y abandonos.

Objetivos de validación iniciales:

- 85–95 % de jugadores nuevos completa los niveles 1 y 2 en hasta tres intentos.
- 70–85 % completa cada nivel medio en hasta tres intentos.
- 55–70 % completa el nivel 8 en hasta tres intentos.
- La mediana de munición restante al completar debe ser 15–30 % del presupuesto;
  menos indica bloqueo por precisión y más indica que la economía no decide nada.
- La mediana de tiempo debe quedar entre 20 y 35 % por debajo del límite. Si queda
  pegada a cero, el límite está funcionando como requisito, no como margen de
  aprendizaje.

## Próximo paso recomendado

Prototipar primero los niveles 1, 4, 5 y 8 como cuatro puntos de control de la
curva. Hacer cinco pruebas nuevas por punto, ajustar velocidad, densidad y
presupuesto, y recién después completar los niveles intermedios. Así se valida el
inicio, el movimiento, la prioridad y el examen final antes de producir toda la
campaña.
