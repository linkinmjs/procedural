# Level Workshop

Editor web local para diseñar niveles desde arriba. No necesita dependencias ni proceso de compilación. El encabezado tiene dos pestañas: **Niveles** (el plano de siempre) y **Ventanas** (el Window Workshop, para crear diseños de ventana con variantes).

## Uso

Doble click en `tools/level-editor/workshop.cmd`: levanta el servidor y abre el editor en el navegador. Cerrar esa ventana detiene el servidor.

O a mano, desde la raíz del repositorio:

```powershell
node tools/level-editor/serve.js
```

y abrir `http://localhost:8080/tools/level-editor/` en el navegador. El servidor no tiene dependencias: sirve el repositorio como archivos estáticos y expone la API con la que el editor abre y guarda niveles en `level_designs/levels/` y mantiene `level-sequence.json`, sin selectores de archivo ni edición a mano.

Cualquier otro servidor estático (`python -m http.server 8080 --directory .`) también funciona, pero sin esa API el editor esconde *Abrir…* y *Secuencia…* y vuelve a los selectores de archivo del navegador. Abierto con `file://` tampoco puede leer el catálogo de texturas.

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
- **Texturas predeterminadas**: las cinco superficies con el mismo selector visual que usa la sala. Visten todas las salas y pasillos del nivel; cada sala pisa sólo los slots que quiera.

El **alto máximo de bloque** recorta el bloque de ventanas cuando la pared es más alta que él: cubre la pared desde el piso hasta ese valor y deja libre lo que sobra, para que los objetivos no aparezcan donde no se apunta cómodo. Con paredes más bajas el bloque las sigue hasta el techo. Por defecto son 6 m.

## Ventana de la sala

Arriba, el nombre y el **rol**:

- **Inicio**: donde aparece el jugador. Hay exactamente una por nivel.
- **Tránsito**: cualquier sala intermedia.
- **Salida**: llegar a ella cierra el nivel. Hay una como máximo.

Marcar una sala como inicio o salida devuelve a tránsito a la que tenía ese rol.

A la izquierda, el **plano de la sala**: muestra la puerta de entrada, la orientación del jugador si es la sala de inicio, y las tres paredes que pueden llevar bloque. Cada pared dice cuántas ventanas trae cada oleada y se abre con un click; las que están apagadas aparecen punteadas con un `+`. Debajo, el resumen de la entrada y la **recompensa al limpiar**: un bloque de munición con la cantidad indicada, que aparece cuando cae el último bloque y se abren las puertas. Más abajo, la **radio**: un interruptor y la esquina donde se apoya (NE/NO/SE/SO); en el plano general se dibuja como una marca con una nota musical pegada a esa esquina. En el juego suena en loop mirando al centro, se rompe de un disparo y, si hay varias, solo la más cercana lleva la acústica de sala.

A la derecha:

- **Forma**: tipo, ancho, profundidad y posición.
- **Volumen**: altura de paredes propia o heredada, y techo heredado / cerrado / a cielo abierto.
- **Orientación inicial** (sólo en la sala de inicio): una brújula de ocho direcciones decide hacia dónde mira el jugador al aparecer, para que no arranque contra una pared.
- **Texturas**: paredes, suelo, techo, puertas y bloques. Cada superficie muestra la miniatura de su textura y abre una grilla con las imágenes reales, agrupadas por pack y con buscador. Sin textura, la superficie usa el material de color plano. Hoy el juego aplica `walls`, `floor` y `ceiling`; los pasillos heredan las de la sala de la que salen.

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

Las familias salen de los comportamientos que enumera `docs/gdd_atractivo_y_progresion.md`. Ya están construidas *Ventana normal*, *Publicidad*, *Firewall*, *Error crítico*, *Descarga* y *Descarga infectada*; el resto aparece con el borde punteado: se guarda en el archivo y el juego la spawnea como ventana normal hasta que exista su comportamiento. La paleta también ofrece, en violeta, los **diseños de la pestaña Ventanas**: en el archivo viajan como `custom:<slug>` y al spawnear alternan sus variantes al azar. Un diseño borrado queda marcado en rojo (`(falta)`) y el juego lo spawnea como normal. Cada bloque cubre su pared completa, de piso a techo, para que no se lo pueda esquivar mientras avanza. Sin ninguna capa, el bloque se cierra con su propio control.

**Forma, volumen y texturas** viven plegados al pie de la ventana: se abren cuando hacen falta y no empujan las oleadas fuera de la pantalla.

## Plano

- Rueda del mouse para acercar, arrastre del fondo para desplazar, **Encuadrar** para ver todo el nivel.
- Cada pasillo se dibuja como una sola figura cerrada, con su ancho real y sus codos resueltos, igual que la geometría que arma el juego. Si las puertas quedan desalineadas menos que el ancho, el pasillo se ensancha en lugar de quebrarse.
- **Puntos intermedios**: doble click sobre un pasillo agrega un punto por el que el recorrido tiene que pasar; el punto se arrastra, y con click derecho se quita. El pasillo une los puntos en ángulo recto, saliendo y llegando perpendicular a las puertas. Un desvío que vuelve sobre su propia línea se descarta en vez de degenerar el trazado. Ojo con acercar dos tramos paralelos a menos del ancho del pasillo: las paredes de uno invaden al otro (el smoke test de pasillos lo detecta).
- **Mover la puerta**: el primer punto (o el último, del lado destino) también decide dónde está la puerta. La puerta se pone en la pared que mira hacia ese punto —rodear la sala con el recorrido la cambia de pared, y la entrada de la sala se actualiza sola— y, dentro de esa pared, se desliza hasta quedar enfrentada al punto, con tope antes de la esquina, para que el pasillo salga derecho desde ahí. Un punto fuera del frente de la pared no la desliza: el recorrido la alcanza con codos, como siempre.
- Las salas muestran su altura, si están a cielo abierto y cuántas balas entregan; cada bloque, el total de ventanas de cada oleada.
- La sala de inicio muestra una flecha con la orientación del jugador.
- Atajos: `Enter` abre la sala seleccionada, `Supr` la elimina, `F` encuadra, `Ctrl+S` guarda.

## Ventanas (Window Workshop)

La pestaña **Ventanas** crea diseños de ventana sin abrir Godot. Un diseño elige una **familia base** —que decide cómo se juega: normal se cierra con la X, la descarga tiene su barra, el firewall protege— y agrupa **variantes** puramente estéticas: título, mensaje y tamaño. Al spawnear el diseño en un bloque, cada ventana elige una variante al azar.

- **+ Nuevo diseño** pide el nombre; el slug (`custom:<slug>`, la clave con la que los niveles lo referencian) nace de ese nombre y queda congelado, así renombrar el diseño después no rompe ningún nivel. La clave violeta bajo el nombre se copia con un click.
- Cada **variante** es una tarjeta: la escena base (sólo si la familia tiene más de una), la **skin** del chrome — *Windows XP* o *Retro 97*, con la de la base como valor por defecto; cambia tema, marco, barra y X sin tocar el comportamiento —, los textos que esa escena puede mostrar —la tool no ofrece campos que la ventana no tiene— y el tamaño en píxeles, que vacío usa el nativo de la base y se acota a 200–560 × 110–320. Al lado, una maqueta estilo XP se actualiza mientras se tipea; el preview fiel es el juego (Block Lab, F4, que lista los diseños en su desplegable de familias). Un texto vacío deja el de la escena original.
- **⧉ duplica** la variante (el flujo normal: cambiar un texto sobre la anterior) y **+ Variante** copia la última.
- **Guardar** (o `Ctrl+S` con la pestaña abierta) escribe `level_designs/window-designs.json`, que es lo que lee el juego. El botón marca con `•` los cambios sin guardar, y si alguna entrada inválida queda afuera del archivo, el guardado lo avisa en vez de descartarla en silencio. Sin el servidor, los diseños quedan como borrador en el navegador.
- **Eliminar** avisa cuántas ventanas del nivel abierto usan el diseño; esas pasan a spawnearse como normales.

Los diseños aparecen en la paleta del editor de capas apenas se guardan. Para una familia nueva o un layout distinto el camino sigue siendo una escena en Godot (`docs/ventanas.md`).

## Plantillas de sala

Una sala que costó armar se puede guardar para reutilizarla en cualquier nivel:

- **Guardar plantilla**, al pie de la ventana de la sala, pide un nombre y guarda todo lo que define el contenido: tamaño, altura, techo, recompensa, radio, texturas y las oleadas con sus bloques y capas. No guarda lo que depende del nivel (posición, rol ni pared de entrada). Repetir un nombre ofrece reemplazar la plantilla anterior.
- El bloque **Plantillas** de la barra lateral las lista con su tamaño y total de ventanas: un click agrega al nivel una sala nueva con ese contenido, con rol de transición y el nombre de la plantilla; la × la borra.
- Con el servidor del Workshop viven en `level_designs/room-templates.json`, versionado junto a los niveles, así se comparten entre máquinas. Sin el servidor quedan en el almacenamiento local del navegador.

## Archivo

Con el servidor del Workshop corriendo (ver *Uso*):

- **Abrir…** lista los niveles de `level_designs/levels/` con su nombre, cuántas salas tienen y su posición en la secuencia. Un click y se abre.
- **Guardar** (o `Ctrl+S`) escribe directo al archivo abierto; el nombre se ve junto al menú Archivo. La primera vez pide sólo el nombre del archivo y, si el nivel no está en la secuencia, ofrece sumarlo al final.
- **Secuencia…** muestra los niveles en el orden en que el juego los encadena: se reordenan con ↑ ↓, se quitan con ×, y *Agregar nivel actual* suma el que está abierto. Cada cambio se guarda solo en `level_designs/level-sequence.json`.
- Al guardar un nivel que ya está en la secuencia, su `id` se sincroniza solo: el juego rechaza ids desparejos.

Sin el servidor quedan **Guardar como…** (selector del navegador), **Descargar JSON** e **Importar…**.

El editor conserva automáticamente un borrador en el almacenamiento local del navegador y avisa antes de descartar cambios sin guardar. Ese borrador es una comodidad y no reemplaza a los JSON versionados en Git.

## Estructura

- `level-format.js` define el modelo de datos: límites, normalización, roles, familias de ventana e inferencia de entradas. Lo comparten el editor, el migrador y los smoke tests, así que la lógica del formato tiene una sola implementación.
- `window-format.js` define el modelo de los diseños de ventana: familias, bases con sus tamaños nativos y campos, slugs y normalización. Sus tablas están en paridad con `BASE_SCENES` de `scripts/windows/window_catalog.gd` (el smoke test lo verifica): una familia nueva es una entrada de datos en cada lado y el resto se deriva.
- `app.js` es la interfaz: dibujo del plano, ventanas de configuración, el Window Workshop y eventos.
- `serve.js` es el servidor local: archivos estáticos del repositorio más la API de niveles, secuencia, plantillas de sala y diseños de ventana (`/api/levels`, `/api/sequence`, `/api/room-templates`, `/api/window-designs`).
- `migrate-level.js` actualiza archivos versionados al formato actual.

## Migrar diseños viejos

Importar un archivo anterior desde el editor lo completa en memoria. Para migrar los archivos versionados en el disco:

```powershell
node tools/level-editor/migrate-level.js level_designs/levels/nivel-1.json
```

Una oleada guardada como número suelto (`"waves": [5]`) pasa a `{ "windows": { "normal": 5 } }`.

## Texturas

La grilla se llena desde `level_designs/texture-catalog.json` y las miniaturas son los PNG reales de `assets/textures/packs/`, así que **el editor hay que servirlo** (ver *Uso*): abierto con `file://` el navegador no puede leer ni el catálogo ni las imágenes.

Hay catorce packs cargados, agrupados por material (Ladrillos, Madera, Metal, Piedra, ...), todos CC0 de Screaming Brain Studios. Para compararlos, `tests/texture_catalog_smoke_test.gd` arma en memoria un nivel con una sala por pack.

Para sumar texturas: extraer las que falten de `assets/_raw/textures/`, copiarlas a la carpeta de su material en `assets/textures/packs/` y regenerar el catálogo (una entrada por PNG, con id `material/nombre-en-minusculas`).

## Alcance actual

El runtime construye todo lo que declara el formato: alturas, techos, pasillos con su ancho y sus puntos intermedios, roles, orientación inicial, munición, recompensas, radios por esquina, cielo, las texturas de paredes, suelo y techo, las familias de ventana con comportamiento propio y los diseños custom con sus variantes. Los slots de textura `door` y `block` se guardan pero todavía no se aplican, y las familias `planned` se spawnean como normales hasta que exista su escena.
