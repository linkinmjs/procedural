# Level Workshop

Editor web local para diseñar niveles desde arriba. No necesita dependencias ni proceso de compilación.

## Uso

Se puede abrir `index.html` directamente, pero conviene servirlo para que el editor pueda leer el catálogo de texturas. Desde la raíz del repositorio:

```powershell
python -m http.server 8080 --directory .
```

Abrir `http://localhost:8080/tools/level-editor/` en el navegador.

La pantalla es el plano. Todo lo que se configura vive en tres ventanas que se abren sobre él, así ninguna propiedad queda detrás de un scroll:

- **Nivel**: el botón del encabezado con el nombre del nivel.
- **Sala**: doble click sobre la sala en el plano, `Enter` sobre la sala seleccionada, o el engranaje de la lista.
- **Bloque**: click sobre una pared en el plano de la ventana de sala.

A la izquierda quedan el **Resumen** y las dos listas que se usan mientras se compone: **Salas** (agregar pequeña, grande o pasillo, y seleccionar) y **Conexiones** (el botón *Unir* enlaza dos salas; cada fila ajusta el ancho de su pasillo).

## Resumen

Cuatro fichas siempre a la vista con los números que definen el nivel: salas, tiempo de ronda, balas disponibles (iniciales más las que se recogen) y objetivos. Debajo aparece en rojo el primer problema que impide terminar el nivel.

*Detalle* abre la ventana del nivel, que cierra con el desglose completo:

- Salas por rol, pasillos con los metros de recorrido y superficie de piso.
- Bloques activos sobre los disponibles, cuántos se mueven y hasta qué alto llegan.
- Oleadas, objetivos y cuántas ventanas de cada familia.
- Munición inicial, la que entregan las salas y el total.
- Margen: balas y segundos por objetivo, para calibrar la dificultad de un vistazo.
- Entorno: cielo, salas a cielo abierto y altura predeterminada.

Los avisos en rojo marcan lo que rompe el nivel —sin salida, una sala a la que no se llega, o menos balas que objetivos—; los grises son datos a tener en cuenta, como los bloques activos sin oleadas o las ventanas de familias que todavía se spawnean como normales.

## Ventana del nivel

- **Identidad**: nombre y descripción.
- **Reglas**: tiempo límite en minutos y segundos, y munición inicial. El cargador se recorta a la capacidad del arma: la Glock lleva 10 balas, así que un valor mayor entra igual pero se guarda el resto en la reserva.
- **Entorno**: el cielo del nivel — día despejado, nublado, atardecer o noche. Además de pintar el cielo coloca el sol, así la luz de las salas acompaña.
- **Predeterminados de sala**: altura de paredes, ancho de pasillos, alto máximo de los bloques y si las salas llevan techo. La altura y el techo los puede pisar cada sala; el ancho, cada pasillo.

El **alto máximo de bloque** recorta el bloque de ventanas cuando la pared es más alta que él: cubre la pared desde el piso hasta ese valor y deja libre lo que sobra, para que los objetivos no aparezcan donde no se apunta cómodo. Con paredes más bajas el bloque las sigue hasta el techo. Por defecto son 6 m.

## Ventana de la sala

Arriba, el nombre y el **rol**:

- **Inicio**: donde aparece el jugador. Hay exactamente una por nivel.
- **Tránsito**: cualquier sala intermedia.
- **Salida**: llegar a ella cierra el nivel. Hay una como máximo.

Marcar una sala como inicio o salida devuelve a tránsito a la que tenía ese rol.

A la izquierda, el **plano de la sala**: muestra la puerta de entrada, la orientación del jugador si es la sala de inicio, y las tres paredes que pueden llevar bloque. Cada pared dice cuántas ventanas trae cada oleada y se abre con un click; las que están apagadas aparecen punteadas con un `+`. Debajo, el resumen de la entrada y la **recompensa al limpiar**: un bloque de munición con la cantidad indicada, que aparece cuando cae el último bloque y se abren las puertas.

A la derecha:

- **Forma**: tipo, ancho, profundidad y posición.
- **Volumen**: altura de paredes propia o heredada, y techo heredado / cerrado / a cielo abierto.
- **Orientación inicial** (sólo en la sala de inicio): una brújula de ocho direcciones decide hacia dónde mira el jugador al aparecer, para que no arranque contra una pared.
- **Texturas**: paredes, suelo, techo, puertas y bloques, con las texturas del catálogo agrupadas por pack. Sin textura, la superficie usa el material de color plano. Hoy el juego aplica `walls`, `floor` y `ceiling`; los pasillos heredan las de la sala de la que salen.

La **entrada** es un dato calculado, no un campo. Se entra a cada sala por la pared que la une con la anterior, siguiendo el camino desde el inicio; en la sala de inicio, por la pared que le queda a la espalda del jugador. Cambiar el recorrido reorienta los bloques solo, porque los lados izquierdo, frontal y derecho son relativos a la entrada.

## Oleadas, bloques y capas

Todo esto se edita en la ventana de la sala, sin abrir nada más. Los tres bloques de la oleada elegida se ven al mismo tiempo, así que armar una sala de tres oleadas es elegir pestaña y tocar; antes cada bloque abría su propio diálogo.

**Pestañas de oleada.** Una por oleada, con lo que trae cada una (`2▦ 10▢` son dos bloques y diez ventanas). Al lado, tres botones: `+` agrega una vacía, `⧉` duplica la abierta y `×` la quita. Duplicar es lo que más ahorra: escalonar dificultad suele ser repetir la oleada anterior con una vuelta de tuerca.

Una oleada es un grupo de bloques que aparecen juntos; la siguiente no llega hasta que el jugador limpia la anterior. Una sala siempre tiene al menos una y admite hasta ocho. Las que quedan sin bloques se saltean.

**Los tres bloques.** Cada columna es una pared. El interruptor la enciende, y con ella aparecen movimiento, velocidad y color en una sola fila. **También se enciende y apaga haciendo clic en la pared del plano**, que es lo más rápido cuando ya sabés dónde la querés.

**Capas.** Cada fila es una capa: su número, los chips de las familias que trae, el total y la `×` para quitarla. Al romper la última ventana de una capa aparece la siguiente; el bloque se cierra al terminarlas todas.

- **Clic en un chip** suma una ventana de esa familia. **Clic derecho** resta, y saca la familia cuando llega a cero.
- **`+`** abre la paleta con las familias que faltan: un clic y entra.
- **`+ Capa`** agrega una capa copiando la anterior, que casi siempre es lo que se quiere.

Una capa no puede quedar vacía ni pasar de 64 ventanas.

Las familias salen de los comportamientos que enumera `docs/gdd_atractivo_y_progresion.md`. Ya están construidas *Ventana normal*, *Publicidad*, *Firewall*, *Error crítico*, *Descarga* y *Descarga infectada*; el resto aparece con el borde punteado: se guarda en el archivo y el juego la spawnea como ventana normal hasta que exista su comportamiento. Cada bloque cubre su pared completa, de piso a techo, para que no se lo pueda esquivar mientras avanza. Sin ninguna capa, el bloque se cierra con su propio control.

**Forma, volumen y texturas** viven plegados al pie de la ventana: se abren cuando hacen falta y no empujan las oleadas fuera de la pantalla.

## Plano

- Rueda del mouse para acercar, arrastre del fondo para desplazar, **Encuadrar** para ver todo el nivel.
- Cada pasillo se dibuja como una sola figura cerrada, con su ancho real y sus codos resueltos, igual que la geometría que arma el juego. Si las puertas quedan desalineadas menos que el ancho, el pasillo se ensancha en lugar de quebrarse.
- Las salas muestran su altura, si están a cielo abierto y cuántas balas entregan; cada bloque, el total de ventanas de cada oleada.
- La sala de inicio muestra una flecha con la orientación del jugador.
- Atajos: `Enter` abre la sala seleccionada, `Supr` la elimina, `F` encuadra, `Ctrl+S` guarda.

## Archivo

- Guardar con el selector de archivos del navegador o descargar el JSON desde el menú **Archivo**.
- Colocar los archivos definitivos en `level_designs/levels/` y registrarlos en `level_designs/level-sequence.json`.

El editor conserva automáticamente un borrador en el almacenamiento local del navegador. Ese borrador es una comodidad y no reemplaza a los JSON versionados en Git.

## Estructura

- `level-format.js` define el modelo de datos: límites, normalización, roles, familias de ventana e inferencia de entradas. Lo comparten el editor, el migrador y los smoke tests, así que la lógica del formato tiene una sola implementación.
- `app.js` es la interfaz: dibujo del plano, ventanas de configuración y eventos.
- `migrate-level.js` actualiza archivos versionados al formato actual.

## Migrar diseños viejos

Importar un archivo anterior desde el editor lo completa en memoria. Para migrar los archivos versionados en el disco:

```powershell
node tools/level-editor/migrate-level.js level_designs/levels/nivel-1.json
```

Una oleada guardada como número suelto (`"waves": [5]`) pasa a `{ "windows": { "normal": 5 } }`.

## Texturas

Los desplegables se llenan desde `level_designs/texture-catalog.json`, así que **el editor hay que servirlo** (ver *Uso*): abierto con `file://` el navegador no puede leer el catálogo y los campos quedan vacíos.

Hay tres packs cargados —Horror, Tiny 1 y Tiny 2, todos CC0—. Para compararlos, `tests/texture_catalog_smoke_test.gd` arma en memoria un nivel con una sala por pack.

Para sumar texturas: extraer las que falten de `assets/_raw/textures/`, copiarlas a `assets/textures/packs/<pack>/` y agregar su entrada al catálogo.

## Alcance actual

El runtime construye todo lo que declara el formato: alturas, techos, pasillos con su ancho, roles, orientación inicial, munición, recompensas, cielo y las texturas de paredes, suelo y techo. Los slots `door` y `block` se guardan pero todavía no se aplican, y de una oleada sólo usa el total de ventanas: las familias distintas de `normal` esperan su comportamiento.
