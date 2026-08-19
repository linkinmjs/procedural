# Level Workshop

Editor web local para diseñar niveles desde arriba. No necesita dependencias ni proceso de compilación.

## Uso

Se puede abrir `index.html` directamente, pero conviene servirlo para que el editor pueda leer el catálogo de texturas. Desde la raíz del repositorio:

```powershell
python -m http.server 8080 --directory .
```

Abrir `http://localhost:8080/tools/level-editor/` en el navegador.

La pantalla separa lo que se configura por nivel (columna izquierda) de lo que se configura por sala (columna derecha).

## Configuración del nivel

El panel de **Salas** y el de **Conexiones** quedan arriba de todo, porque son los que más se usan al componer; el resto arranca plegado.

- **Salas**: agregar pequeñas, grandes o pasillos, y seleccionarlas desde la lista.
- **Conexiones**: unir dos salas y ajustar el ancho de cada pasillo.
- **Identidad**: nombre y descripción.
- **Reglas**: tiempo límite en minutos y segundos, y munición inicial. El cargador se recorta a la capacidad del arma: la Glock lleva 10 balas, así que un valor mayor entra igual pero se guarda el resto en la reserva.
- **Entorno**: el cielo del nivel — día despejado, nublado, atardecer o noche. Además de pintar el cielo coloca el sol, así la luz de las salas acompaña. Sin elegir ninguno se usa el día despejado.
- **Predeterminados de sala**: altura de paredes, ancho de pasillos y si las salas llevan techo. Cada sala y cada pasillo puede usar su propio valor.

## Configuración de la sala

Cada sala tiene un **rol**:

- **Inicio**: donde aparece el jugador. Hay exactamente una por nivel.
- **Tránsito**: cualquier sala intermedia.
- **Salida**: llegar a ella cierra el nivel. Hay una como máximo.

Marcar una sala como inicio o salida devuelve a tránsito a la que tenía ese rol.

En la pestaña **Sala**:

- Nombre, tipo, tamaño y posición.
- **Orientación inicial** (sólo en la sala de inicio): una brújula de ocho direcciones decide hacia dónde mira el jugador al aparecer, para que no arranque contra una pared.
- **Entrada**: es un dato calculado, no un campo. Se entra a cada sala por la pared que la une con la anterior, siguiendo el camino desde el inicio; en la sala de inicio, por la pared que le queda a la espalda del jugador. El resumen dice cuál quedó.
- **Volumen**: altura de paredes propia o heredada, y techo heredado / cerrado / a cielo abierto.

En la pestaña **Bloques**:

- Los lados izquierdo, frontal y derecho son relativos a la entrada; el recuadro de cada bloque muestra sobre qué pared cae. Cambiar el recorrido del nivel los reorienta solo.
- Cada bloque cubre su pared completa, de piso a techo, para que no se lo pueda esquivar mientras avanza.
- Color, movimiento estático o hacia el lado contrario, velocidad y oleadas.
- **Recompensa al limpiar**: un bloque de munición con la cantidad de balas indicada, que aparece cuando cae el último bloque y se abren las puertas.

En la pestaña **Texturas**: paredes, suelo, techo, puertas y bloques, con las texturas del catálogo agrupadas por pack. Sin textura, la superficie usa el material de color plano. Hoy el juego aplica `walls`, `floor` y `ceiling`; los pasillos heredan las de la sala de la que salen.

## Plano

- Rueda del mouse para acercar, arrastre del fondo para desplazar, **Encuadrar** para ver todo el nivel.
- Cada pasillo se dibuja como una sola figura cerrada, con su ancho real y sus codos resueltos, igual que la geometría que arma el juego. Si las puertas quedan desalineadas menos que el ancho, el pasillo se ensancha en lugar de quebrarse.
- Las salas muestran su altura, si están a cielo abierto y cuántas balas entregan.
- La sala de inicio muestra una flecha con la orientación del jugador.
- Atajos: `Supr` elimina la sala seleccionada, `F` encuadra, `Ctrl+S` guarda.

## Archivo

- Guardar con el selector de archivos del navegador o descargar el JSON.
- Colocar los archivos definitivos en `level_designs/levels/` y registrarlos en `level_designs/level-sequence.json`.

El editor conserva automáticamente un borrador en el almacenamiento local del navegador. Ese borrador es una comodidad y no reemplaza a los JSON versionados en Git.

## Estructura

- `level-format.js` define el modelo de datos: límites, normalización, roles e inferencia de entradas. Lo comparten el editor, el migrador y los smoke tests, así que la lógica del formato tiene una sola implementación.
- `app.js` es la interfaz: dibujo del plano, inspector y eventos.
- `migrate-level.js` actualiza archivos versionados al formato actual.

## Migrar diseños viejos

Importar un archivo anterior desde el editor lo completa en memoria. Para migrar los archivos versionados en el disco:

```powershell
node tools/level-editor/migrate-level.js level_designs/levels/nivel-1.json
```

## Texturas

Los desplegables se llenan desde `level_designs/texture-catalog.json`, así que **el editor hay que servirlo** (ver *Uso*): abierto con `file://` el navegador no puede leer el catálogo y los campos quedan vacíos.

Hay tres packs cargados —Horror, Tiny 1 y Tiny 2, todos CC0—. Para compararlos, el nivel `nivel-texturas` tiene tres salas idénticas con un pack en cada una.

Para sumar texturas: extraer las que falten de `assets/_raw/textures/`, copiarlas a `assets/textures/packs/<pack>/` y agregar su entrada al catálogo.

## Alcance actual

El runtime construye todo lo que declara el formato: alturas, techos, pasillos con su ancho, roles, orientación inicial, munición, recompensas, cielo y las texturas de paredes, suelo y techo. Los slots `door` y `block` se guardan pero todavía no se aplican.
