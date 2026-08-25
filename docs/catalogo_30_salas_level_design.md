# Catálogo de 30 salas --- Level Design

## Contexto de diseño

Este catálogo está pensado para un juego de disparos con estética y
mecánicas inspiradas en ventanas de Windows XP. La unidad de diseño
sigue esta jerarquía:

**Sala → Oleada → Bloque → Capa → Ventana**

-   **Sala:** encuentro completo.
-   **Oleada:** conjunto de bloques que aparecen simultáneamente.
-   **Bloque:** panel ubicado en `left`, `front` o `right`.
-   **Capa:** tanda de ventanas dentro de un bloque; al limpiarla
    aparece la siguiente.
-   **Ventana:** objetivo individual y su mecánica.

Las salas siguientes utilizan las familias actualmente funcionales:
`normal`, `download`, `infected-download`, `popup`, `firewall` y
`critical-error`, además del movimiento de bloque `opposite`.

------------------------------------------------------------------------

# 1. Galería

**Intención:** precisión básica y entrada en flow.

**Configuración** - Sala larga y relativamente angosta. - 1 oleada. -
`Front`. - Capa 1: 8--12 `normal`.

**Qué pone a prueba:** adquisición rápida de blancos y precisión básica.

Es una sala deliberadamente simple. Sirve como calentamiento,
recuperación entre encuentros complejos y oportunidad de construir
cadena.

------------------------------------------------------------------------

# 2. Barrido horizontal

**Intención:** entrenar flicks amplios y reorientación.

**Configuración** - Sala ancha. - Oleada 1: `Left` → 7 `normal`. -
Oleada 2: `Right` → 7 `normal`. - Oleada 3: `Front` → 7 `normal`.

**Patrón espacial:** izquierda → derecha → frente.

**Qué pone a prueba:** movimiento angular de la mira sin introducir
complejidad cognitiva adicional.

------------------------------------------------------------------------

# 3. Ping Pong

**Intención:** convertir reacción en anticipación.

**Configuración** - O1: `Left` → 5 `normal`. - O2: `Right` → 5
`normal`. - O3: `Left` → 5 `normal`. - O4: `Right` → 5 `normal`. - O5:
`Front` → 8 `normal`.

**Qué pone a prueba:** reorientación y reconocimiento de patrones.

El jugador puede empezar reaccionando, pero gradualmente aprende la
secuencia y anticipa dónde aparecerá la siguiente oleada.

------------------------------------------------------------------------

# 4. Tridente

**Intención:** introducir decisiones espaciales.

**Configuración** - Sala cuadrada. - 1 oleada. - `Left`: 5 `normal`. -
`Front`: 5 `normal`. - `Right`: 5 `normal`.

**Qué pone a prueba:** awareness de aproximadamente 180° y elección del
orden de limpieza.

Aunque todas las ventanas sean normales, la aparición simultánea en tres
paredes obliga al jugador a decidir dónde empezar.

------------------------------------------------------------------------

# 5. Capas de cebolla

**Intención:** sostener cadencia sobre una misma dirección.

**Configuración** - Un bloque `Front`. - Capa 1: 4 `normal`. - Capa 2: 6
`normal`. - Capa 3: 8 `normal`. - Capa 4: 10 `normal`.

**Qué pone a prueba:** ritmo sostenido y mantenimiento de cadena.

Cada capa limpia revela otra tanda, generando progresión temporal sin
cambiar de pared.

------------------------------------------------------------------------

# 6. Embudo

**Intención:** introducir presión espacial y elección de una vía de
escape.

**Configuración** - `Left`: 10 `normal`, movimiento `opposite`. -
`Right`: 10 `normal`, movimiento `opposite`.

**Qué pone a prueba:** velocidad, supervivencia y toma de decisiones.

Los dos laterales avanzan hacia el jugador. La pregunta principal no es
simplemente cuántos objetivos puede destruir, sino qué lateral conviene
limpiar primero para ganar espacio.

------------------------------------------------------------------------

# 7. Trituradora

**Intención:** evolucionar la lógica del Embudo.

**Configuración** - Sala relativamente angosta. - `Left`, movimiento
`opposite`: - C1: 6 `normal`. - C2: 6 `normal`. - `Right`, movimiento
`opposite`: - C1: 6 `normal`. - C2: 6 `normal`.

**Qué pone a prueba:** presión espacial sostenida.

Destruir la primera tanda de una pared ya no elimina el peligro: aparece
una segunda capa mientras el bloque continúa avanzando.

------------------------------------------------------------------------

# 8. Muro frontal

**Intención:** convertir el espacio en un temporizador físico.

**Configuración** - Sala larga. - `Front`, movimiento `opposite`. -
12--16 `normal`.

**Qué pone a prueba:** velocidad de ejecución y precisión bajo presión.

No existe una elección lateral: el jugador debe destruir el muro frontal
antes de que llegue hasta su posición.

------------------------------------------------------------------------

# 9. Firewall 101

**Intención:** enseñar la regla de prioridad del firewall.

**Configuración** - `Front`. - 1 `firewall`. - 5--6 `normal`. - Una sola
capa.

**Qué pone a prueba:** identificación de prioridad.

Secuencia esperada:

**Identificar → destruir firewall → limpiar normales.**

------------------------------------------------------------------------

# 10. Doble Firewall

**Intención:** hacer que el jugador gestione dos grupos protegidos.

**Configuración** - Una oleada. - `Left`: 1 `firewall` + 6 `normal`. -
`Right`: 1 `firewall` + 6 `normal`.

**Qué pone a prueba:** cambio de prioridades y planificación del orden
de limpieza.

------------------------------------------------------------------------

# 11. Firewall en profundidad

**Intención:** consolidar una regla mediante repetición escalonada.

**Configuración** - `Front`. - Capa 1: `firewall` + 5 `normal`. - Capa
2: `firewall` + 7 `normal`. - Capa 3: `firewall` + 9 `normal`.

**Qué pone a prueba:** reconocimiento inmediato de prioridad.

El patrón interno es:

**prioridad → ejecución → prioridad → ejecución → prioridad →
ejecución.**

------------------------------------------------------------------------

# 12. Publicidad molesta

**Intención:** enseñar el comportamiento correcto frente a los popup.

**Configuración** - Sala pequeña. - `Front`. - 4--6 `popup`.

**Qué pone a prueba:** precisión sobre blancos pequeños y lectura de la
mecánica.

El jugador aprende que buscar la X inmediatamente es preferible a
esperar el botón SKIP.

------------------------------------------------------------------------

# 13. Adware

**Intención:** introducir proliferación distribuida espacialmente.

**Configuración** - `Left`: 3 `popup`. - `Right`: 3 `popup`.

**Qué pone a prueba:** control de amenazas y reorientación.

Un jugador rápido ve pocos objetivos. Uno lento permite que las
publicidades generen nuevas ventanas y transforma la sala en un problema
mayor.

------------------------------------------------------------------------

# 14. Popocalypse

**Intención:** generar dificultad emergente.

**Configuración** - `Left`: 2 `popup`. - `Front`: 3 `popup`. - `Right`:
2 `popup`.

**Qué pone a prueba:** gestión de crisis.

No hace falta comenzar con una enorme cantidad de objetivos. El propio
sistema de proliferación genera el caos si el jugador no controla
rápidamente los popup.

------------------------------------------------------------------------

# 15. Centro de descargas

**Intención:** entrenar objetivos de dos pasos.

**Configuración** - `Front`. - 3 `download`.

**Qué pone a prueba:** secuenciación de disparos.

Cadencia:

**Cancelar → confirmar → siguiente descarga.**

La adquisición de blanco deja de ser simplemente apuntar, disparar y
pasar al siguiente objetivo.

------------------------------------------------------------------------

# 16. Factura impaga

**Intención:** enseñar una prioridad temporal real.

**Configuración** - `Front`. - 1 `infected-download`. - 6 `normal`.

**Qué pone a prueba:** priorización frente a objetivos fáciles.

Las normales son tentadoras, pero la descarga infectada tiene
consecuencias permanentes para el bloque si llega al 100 %.

------------------------------------------------------------------------

# 17. ¿Cuál era?

**Intención:** introducir lectura visual dentro de objetivos similares.

**Configuración** - `Front`. - 2 `download`. - 1 `infected-download`. -
4 `normal`.

**Qué pone a prueba:** observar → interpretar → priorizar → ejecutar.

La dificultad no proviene de apuntar mejor, sino de reconocer cuál de
las descargas representa la amenaza crítica.

------------------------------------------------------------------------

# 18. Firewall infectado

**Intención:** crear un pequeño puzzle de combate.

**Configuración** - `Front`. - 1 `firewall`. - 1 `infected-download`. -
5 `normal`.

**Secuencia lógica** 1. Detectar la descarga infectada. 2. Descubrir que
está protegida. 3. Localizar el firewall. 4. Desactivar el firewall. 5.
Cancelar la descarga. 6. Confirmar. 7. Limpiar los objetivos restantes.

**Qué pone a prueba:** orden de operaciones bajo presión temporal.

------------------------------------------------------------------------

# 19. Error crítico

**Intención:** enseñar inhibición del reflejo aprendido.

**Configuración** - Sala pequeña y relativamente tranquila. - `Front`. -
4 `critical-error`.

**Qué pone a prueba:** lectura antes del disparo.

La mecánica contradice deliberadamente la lógica del popup: frente a un
popup conviene buscar la X; frente a un critical-error, disparar a la X
es una trampa.

------------------------------------------------------------------------

# 20. No dispares todavía

**Intención:** alternar ejecución rápida con lectura consciente.

**Configuración** - Una capa. - 6 `normal`. - 3 `critical-error`.

**Qué pone a prueba:** inhibición.

Cadencia mental:

**shoot → shoot → shoot → STOP → leer → shoot.**

------------------------------------------------------------------------

# 21. Izquierda o derecha

**Intención:** presentar dos amenazas diferentes simultáneamente.

**Configuración** - Una oleada. - `Left`: 1 `infected-download` + 4
`normal`. - `Right`: 3 `popup`.

**Qué pone a prueba:** decisión de prioridades.

No es necesario que exista una única solución correcta; diferentes
jugadores pueden desarrollar diferentes órdenes de ejecución.

------------------------------------------------------------------------

# 22. Reloj cruzado

**Intención:** superponer distintos tipos de presión temporal.

**Configuración** - `Left`: 1 `infected-download` + 1 `download`. -
`Right`: 4 `popup`. - `Front`: 4 `normal`.

**Qué pone a prueba:** multitarea y priorización.

Conviven: - una amenaza irreversible; - una amenaza proliferante; -
blancos fáciles útiles para construir o mantener combo.

------------------------------------------------------------------------

# 23. Compresión asimétrica

**Intención:** obligar al jugador a utilizar físicamente la sala.

**Configuración** - `Left`: movimiento `opposite`, 8 `normal`. -
`Front`: 5 `normal`. - `Right`: estático, 4 `normal`.

**Qué pone a prueba:** posicionamiento.

La presión espacial proviene solamente de un lateral, permitiendo que el
jugador identifique y utilice una zona relativamente segura.

------------------------------------------------------------------------

# 24. Salida de emergencia

**Intención:** ofrecer dos rutas de resolución con costes diferentes.

**Configuración** - `Left`: movimiento `opposite`, 12 `normal`. -
`Right`: movimiento `opposite`, 4 `normal`.

**Qué pone a prueba:** elección rápida.

Puede diseñarse para que el lado con menos objetivos tenga blancos más
incómodos, creando una decisión entre:

**camino corto difícil vs. camino largo fácil.**

------------------------------------------------------------------------

# 25. Falsa calma

**Intención:** trabajar el ritmo emocional.

**Configuración** - O1: `Front` → 5 `normal`. - O2: `Left` → 4
`normal`. - O3: `Right` → 4 `normal`. - O4: - `Left`, `opposite`:
`popup` + 3 `normal`. - `Right`, `opposite`: `popup` + 3 `normal`.

**Qué pone a prueba:** adaptación ante un cambio repentino de
intensidad.

Arco:

**calma → confianza → sorpresa.**

------------------------------------------------------------------------

# 26. Escalada

**Intención:** construir una pequeña historia mecánica dentro de una
sala.

**Configuración** - O1: `normal`. - O2: `normal` + `popup`. - O3:
`firewall` + `normal`. - O4: `download` + `normal`. - O5:
`infected-download` + `normal`. - O6: `critical-error` + `popup` +
`firewall`.

**Qué pone a prueba:** adaptación progresiva.

Es especialmente útil como encuentro de cierre de nivel.

------------------------------------------------------------------------

# 27. Maratón de combo

**Intención:** construir y conservar el multiplicador máximo.

**Configuración** - `Front`. - C1: 5 `normal`. - C2: 5 `normal`. - C3: 5
`normal`. - C4: 5 `normal`. - C5: 5 `normal`. - C6: 5 `normal`.

**Total:** 30 objetivos.

**Qué pone a prueba:** consistencia, velocidad y mantenimiento de
cadena.

La complejidad cognitiva es baja. El desafío consiste en ejecutar
limpiamente una gran cantidad de blancos y aprovechar el sistema de
puntuación.

------------------------------------------------------------------------

# 28. Cirugía

**Intención:** hacer que cada disparo importe.

**Configuración** - Sala grande. - 2 `critical-error`. - 2
`infected-download`. - 2 `normal`.

**Qué pone a prueba:** precisión perfecta y lectura.

Hay pocos objetivos, pero equivocarse es costoso. Puede funcionar como
una sala de precisión cognitiva en contraste con encuentros frenéticos.

------------------------------------------------------------------------

# 29. Sobrecarga

**Intención:** presentar tres problemas distintos alrededor del jugador.

**Configuración**

### Left

-   3 `popup`.

### Front

-   1 `firewall`.
-   1 `infected-download`.
-   3 `normal`.

### Right

-   2 `critical-error`.
-   3 `normal`.

**Qué pone a prueba:** multitarea y construcción mental de una cola de
prioridades.

Una posible resolución:

**Firewall → infected → popup urgente → critical-error → objetivos
restantes.**

------------------------------------------------------------------------

# 30. Kernel

**Intención:** encuentro de clímax que examine el dominio integral de
las mecánicas.

No introduce reglas nuevas. Combina reglas conocidas en varias fases.

## Oleada 1 --- Calentamiento

-   `Front`: 10 `normal`.

## Oleada 2 --- Atención

-   `Left`: 3 `popup`.
-   `Right`: 3 `popup`.

## Oleada 3 --- Prioridad

-   `Front`:
    -   1 `firewall`.
    -   1 `infected-download`.
    -   5 `normal`.

## Oleada 4 --- Lectura

-   `Left`: 2 `critical-error`.
-   `Right`: 2 `critical-error`.

## Oleada 5 --- Presión espacial

-   `Left`, `opposite`: 6 `normal`.
-   `Right`, `opposite`: 6 `normal`.

## Oleada 6 --- Examen

-   `Left`: 2 `popup`.
-   `Front`: 1 `firewall` + 1 `infected-download` + 4 `normal`.
-   `Right`: 1 `critical-error` + 1 `download` + 3 `normal`.

**Qué pone a prueba:** dominio integral, priorización, precisión,
lectura, velocidad, posicionamiento y mantenimiento de cadena.

------------------------------------------------------------------------

# Familias de diseño

Conviene clasificar las salas por la habilidad dominante que exigen, no
solamente por las ventanas utilizadas.

  Familia             Verbo mental          Ejemplos
  ------------------- --------------------- ------------------------------
  Precisión           Apuntar               Galería, Cirugía
  Tracking espacial   Buscar                Barrido horizontal, Tridente
  Velocidad           Limpiar               Maratón de combo
  Priorización        Elegir                Firewall infectado
  Lectura             Interpretar           Error crítico, ¿Cuál era?
  Inhibición          No disparar todavía   No dispares todavía
  Gestión             Controlar             Popocalypse
  Supervivencia       Escapar               Trituradora
  Posicionamiento     Moverse               Compresión asimétrica
  Multitarea          Ordenar               Sobrecarga, Kernel

------------------------------------------------------------------------

# Dimensiones de dificultad

La dificultad no debería escalar únicamente aumentando la cantidad de
ventanas. Puede componerse a partir de dimensiones independientes.

## Dificultad mecánica

-   Blancos pequeños.
-   Mayor cantidad de objetivos.
-   Distancias mayores.
-   Ángulos más amplios entre objetivos.

## Dificultad temporal

-   `infected-download`.
-   `popup`.
-   Bloques con movimiento `opposite`.

## Dificultad cognitiva

-   Diferenciar `download` de `infected-download`.
-   Leer correctamente `critical-error`.
-   Recordar reglas contradictorias entre familias.

## Dificultad de prioridad

-   `firewall` + `infected-download`.
-   `popup` + amenazas temporales.
-   Varias familias simultáneas.

## Dificultad espacial

-   Uso simultáneo de `Left`, `Front` y `Right`.
-   Bloques móviles.
-   Presión asimétrica.
-   Elección de zonas seguras.

## Dificultad de ejecución

-   Secuencias de dos impactos de las descargas.
-   Cambios rápidos entre tipos de objetivo.
-   Flicks de gran amplitud.

## Dificultad de puntuación

-   Mantener la cadena.
-   Evitar fallos.
-   Conservar multiplicadores altos.
-   Mantener precisión.
-   Terminar bajo el par de la sala.

------------------------------------------------------------------------

# Tres niveles de dominio de una sala

Una misma sala puede funcionar para jugadores de diferentes niveles si
existen distintas metas implícitas.

### Novato

**¿Puedo sobrevivir y completar la sala?**

### Intermedio

**¿Puedo limpiarla rápidamente y sin cometer demasiados errores?**

### Experto

**¿Cuál es el orden óptimo para conservar el multiplicador, mantener una
precisión perfecta y terminar por debajo del par?**

Esto permite que una misma geometría tenga profundidad sin necesitar
variantes artificiales de dificultad.

------------------------------------------------------------------------

# Hacia una gramática procedural

Estas 30 salas funcionan mejor como **arquetipos de encuentros** que
como una secuencia fija de nivel 1 a nivel 30.

Una siguiente capa de diseño puede clasificar los encuentros
proceduralmente en categorías como:

-   `Warmup`
-   `Precision`
-   `Priority`
-   `Spatial Pressure`
-   `Cognitive`
-   `Score Farm`
-   `Recovery`
-   `Climax`

Cada arquetipo puede recibir además una dificultad aproximada de 1 a 5
en varias dimensiones.

Ejemplo:

  Sala                   Mecánica   Cognitiva   Temporal   Espacial   Intensidad
  -------------------- ---------- ----------- ---------- ---------- ------------
  Galería                       1           1          1          1            1
  Embudo                        3           2          4          4            4
  Firewall infectado            2           4          4          1            4
  Cirugía                       4           5          3          2            3
  Sobrecarga                    4           5          5          5            5
  Kernel                        5           5          5          5            5

Esto permite establecer reglas de composición procedural, por ejemplo:

-   No colocar dos encuentros `Cognitive 5` consecutivos.
-   Alternar presión alta con recuperación.
-   No introducir dos mecánicas nuevas en la misma sala.
-   Introducir una mecánica de forma aislada antes de combinarla.
-   Reservar encuentros `Climax` para cierres de nivel.
-   Utilizar encuentros `Score Farm` después de desafíos cognitivos
    exigentes.
-   Evitar secuencias largas de salas con la misma presión espacial.
-   Incrementar dificultad combinando dimensiones en lugar de
    simplemente sumar objetivos.

El objetivo final es que el generador no produzca únicamente
**habitaciones aleatorias**, sino **niveles proceduralmente compuestos
con ritmo, intención y progresión**.
