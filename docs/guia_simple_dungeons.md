# Guía de SimpleDungeons para el proyecto

Esta guía describe cómo funciona la versión de SimpleDungeons incluida en el proyecto, qué tipos de nivel permite construir y qué conviene usar en cada caso.

## Resumen: procedural, predefinido o mixto

SimpleDungeons está orientado principalmente a generar la distribución de un nivel a partir de habitaciones prefabricadas. No genera la geometría de una habitación desde cero: selecciona, rota y conecta escenas que nosotros diseñamos previamente.

Podemos usarlo de tres maneras:

| Modalidad | Qué queda fijo | Qué resuelve el generador | Uso recomendado |
| --- | --- | --- | --- |
| Procedural | El catálogo de habitaciones y las reglas | Cantidad, posición, rotación y corredores | Runs rejugables |
| Mixta | Habitaciones importantes y su posición | Habitaciones secundarias y conexiones | Campaña con variación; modalidad recomendada para el proyecto |
| Predefinida | Todo el layout | Nada, o solamente una fase controlada de conexión | Tutoriales, niveles de prueba y secuencias muy diseñadas |

Una **semilla fija** no convierte el mapa en un nivel diseñado a mano. Sigue siendo procedural, pero permite volver a obtener la misma distribución mientras no cambien el catálogo, sus propiedades ni el algoritmo.

## Conceptos principales

### `DungeonGenerator3D`

Es el nodo que organiza la generación. Sus propiedades principales son:

- `room_scenes`: catálogo de escenas de habitación que puede colocar.
- `corridor_room_scene`: celda especial que utiliza para construir los caminos entre habitaciones.
- `dungeon_size`: tamaño máximo de la grilla, medido en vóxeles.
- `voxel_scale`: tamaño de cada vóxel en unidades del mundo.
- `generate_seed`: semilla opcional para repetir una generación.
- `generate_on_ready`: inicia la generación automáticamente al cargar la escena.
- `max_retries`: cantidad de reintentos si no consigue un layout válido.
- `done_generating`: señal que indica que el nivel ya puede poblarse y recorrerse.

En el prototipo actual la grilla mide `8 × 1 × 8` y cada vóxel mide `10 × 10 × 10` unidades. Por lo tanto, el nivel es horizontal y tiene un área lógica máxima de `80 × 80` unidades.

### `DungeonRoom3D`

Cada habitación es una escena cuyo nodo raíz hereda de `DungeonRoom3D`. La escena puede contener mallas, CSG, colisiones, luces, decoración, scripts y marcadores de gameplay.

Sus propiedades más importantes son:

- `size_in_voxels`: caja rectangular que la habitación ocupa en la grilla.
- `voxel_scale`: debe coincidir con la métrica del generador.
- `min_count` y `max_count`: rango permitido de copias durante la generación.
- `is_stair_room`: identifica piezas que conectan pisos diferentes.

El generador puede rotar una habitación alrededor del eje vertical en incrementos de 90 grados. No realiza espejado automático.

La geometría visual puede ser irregular, pero el espacio reservado para detectar solapamientos siempre es la caja completa definida por `size_in_voxels`.

### Puertas y puntos de conexión

Las puertas se representan mediante nodos `Node3D` —los ejemplos usan CSG— cuyo nombre comienza con:

- `DOOR`: conexión obligatoria. El generador debe llevar un corredor hasta ella.
- `DOOR?`: conexión opcional. Puede utilizarse o quedar cerrada.

La orientación y la celda de la puerta se calculan a partir de su posición dentro de la habitación. Una habitación `1 × 1` admite una posición lógica por pared. Para tener posiciones izquierda, central y derecha sobre una misma pared, esa pared debe ocupar varios vóxeles.

Una puerta opcional no se cierra visualmente por sí sola. La escena debe reaccionar a `dungeon_done_generating`, consultar `door.get_room_leads_to()` y retirar el hueco o colocar una pared cuando no exista conexión. Las habitaciones de ejemplo ya contienen esta lógica.

## Etapas de una generación

El flujo interno puede entenderse así:

1. Instancia las escenas declaradas en `room_scenes`.
2. Selecciona habitaciones hasta satisfacer sus valores `min_count`, sin superar `max_count`.
3. Asigna posiciones y rotaciones de 90 grados dentro de la grilla.
4. Separa habitaciones que se solapan.
5. Coloca escaleras cuando existen varios pisos.
6. Usa A* para conectar todas las habitaciones alcanzables.
7. Construye los caminos con copias de `corridor_room_scene`.
8. Garantiza las conexiones marcadas como obligatorias.
9. Instancia las habitaciones definitivas y emite `dungeon_done_generating` y `done_generating`.

Los sistemas de gameplay deben esperar la señal final. Antes de ese momento todavía pueden cambiar las conexiones o no existir las instancias definitivas.

## Formas de construir un nivel

### 1. Nivel completamente procedural

Se configura un catálogo de habitaciones, sus frecuencias y el tamaño del dungeon. En cada ejecución el generador decide qué copias colocar, su orientación, su posición y los corredores necesarios.

Ejemplo conceptual:

```text
room_scenes:
  - habitación pequeña: min 2, max 5
  - habitación grande:  min 1, max 3
  - pasillo diseñado:   min 1, max 2

corridor_room_scene:
  - celda con cuatro conexiones opcionales
```

Si `generate_seed` queda vacío, se utiliza una semilla aleatoria. Si guardamos la semilla utilizada podemos reproducir una run o un bug.

### 2. Procedural reproducible con semilla

Podemos llamar:

```gdscript
generator.generate(123456)
```

Esto permite tener, por ejemplo:

- desafíos diarios;
- una lista curada de semillas;
- repetición de una run;
- casos de prueba reproducibles.

La distribución puede cambiar si después modificamos habitaciones, puertas, tamaños, cantidades o la versión del algoritmo.

### 3. Nivel mixto con habitaciones precolocadas

Una instancia de `DungeonRoom3D` colocada como hija directa del generador se considera **precolocada**. Conserva su posición y rotación; las habitaciones procedurales se acomodan alrededor de ella y el sistema intenta conectarla.

Esto permite fijar elementos como:

- habitación inicial;
- sala de objetivo principal;
- arena de jefe;
- salida;
- un punto narrativo;
- una sala que deba coincidir con geometría exterior.

El resto del nivel puede seguir variando. Esta es la modalidad más apropiada si queremos controlar el ritmo general sin perder rejugabilidad.

Debemos respetar la grilla y evitar que las habitaciones precolocadas se solapen. El inspector ofrece `force_align_with_grid_button` para ajustar una habitación a la métrica del generador.

### 4. Distribución controlada mediante código

`DungeonGenerator3D` permite asignar `custom_get_rooms_function`. Esta función recibe las habitaciones disponibles y el generador aleatorio, y devuelve clones con cantidades, posiciones y rotaciones decididas por nuestro código.

Sirve para imponer reglas como:

- habitaciones rojas en una mitad y azules en otra;
- distancia mínima entre inicio y salida;
- una secuencia de roles concreta;
- cantidad exacta de una familia;
- reservar regiones para cierto contenido.

Después de esa selección controlada, SimpleDungeons todavía separa y conecta las piezas. Por eso no equivale necesariamente a un mapa completamente congelado.

### 5. Nivel totalmente predefinido

Para un tutorial, un polígono de armas o una secuencia que requiera control absoluto, la solución más clara es construir una escena normal de Godot con las habitaciones y pasillos ya colocados y no ejecutar la generación.

Podemos reutilizar los mismos prefabs, marcadores de objetivos y sistemas de iluminación. No es obligatorio que todos los niveles del juego pasen por `DungeonGenerator3D`.

Aunque el addon admite habitaciones precolocadas, su flujo de validación sigue esperando un catálogo y al menos una colocación generada. Forzarlo a representar un mapa 100 % manual agrega complejidad sin aportar una ventaja real.

## Tipos de habitación que podemos crear

SimpleDungeons no impone categorías de gameplay. Para el plugin casi todas son simplemente `DungeonRoom3D`. Las categorías las definimos nosotros mediante escenas y metadatos.

El sistema permite crear:

- habitaciones pequeñas, grandes o alargadas;
- callejones sin salida;
- habitaciones con múltiples accesos;
- corredores rectos diseñados como una habitación regular;
- celdas de corredor que formen rectas, esquinas, T o cruces;
- puentes y pasarelas;
- escaleras entre pisos;
- salas de inicio, recompensa, objetivo o jefe;
- habitaciones precolocadas;
- geometría interior irregular dentro de una ocupación rectangular.

### Catálogo inicial recomendado

Para este proyecto convendría comenzar con un kit pequeño y explícito:

1. Pequeña `1 × 1`, cuatro posiciones opcionales de puerta.
2. Pequeña `1 × 1`, callejón sin salida.
3. Pequeña `1 × 1`, dos puertas enfrentadas.
4. Grande `3 × 2`, una puerta central.
5. Grande `3 × 2`, una puerta lateral.
6. Grande `3 × 2`, dos accesos.
7. Pasillo diseñado `1 × 2` o `1 × 3`.
8. Celda especial de corredor `1 × 1`, con cuatro puertas opcionales.
9. Inicio y salida como piezas especiales o precolocadas.

Tener variantes separadas ofrece mayor control que una sola habitación con muchos conectores opcionales. El addon no proporciona una regla directa de “usar exactamente una o dos de estas cinco puertas”.

## Corredor automático frente a habitación-pasillo

Es importante distinguirlos:

- La **celda de corredor** es una pieza técnica `1 × 1 × 1` que el generador repite para conectar habitaciones. Una cadena de diez celdas sigue siendo diez instancias diferentes.
- La **habitación-pasillo** es un prefab alargado regular, por ejemplo `1 × 3`, que aparece como una sola unidad de gameplay.

Para encuentros de objetivos laterales es preferible una habitación-pasillo diseñada o un sistema propio que agrupe celdas contiguas. Añadir un encuentro independiente a cada celda automática provoca bloques repetidos y demasiado pequeños.

## Qué no resuelve SimpleDungeons

El addon resuelve principalmente colocación espacial y conectividad. No incluye por sí mismo:

- roles de habitación;
- progresión inicio–combate–recompensa–jefe;
- llaves, puertas bloqueadas o backtracking;
- dificultad de encuentros;
- ubicación semántica de enemigos u objetivos;
- agrupación de celdas en un único tramo de corredor;
- navegación, iluminación o decoración automática;
- garantía de usar exactamente cierta cantidad de puertas opcionales.

Estas reglas deben vivir en una capa propia del proyecto, ejecutada después de `done_generating`.

## Arquitectura recomendada para el proyecto

Conviene separar cuatro responsabilidades:

```text
Catálogo de habitaciones
        ↓
SimpleDungeons: posición y conectividad
        ↓
Clasificación: pequeña, grande, pasillo, inicio, salida…
        ↓
Pobladores: objetivos, luces, enemigos, loot y decoración
```

Cada prefab debería declarar explícitamente:

- su categoría o rol;
- sus puertas posibles;
- superficies o volúmenes válidos para objetivos;
- puntos de luz;
- puntos de aparición de jugador, enemigos y recompensas;
- si admite encuentros al entrar y desde qué accesos.

Así el sistema de objetivos no necesita deducir paredes útiles a partir de una caja genérica y puede respetar la geometría real de cada habitación.

## Limitaciones y precauciones

- Todas las piezas deben utilizar la misma métrica de vóxeles.
- Las puertas deben caer en una celda de borde y apuntar hacia fuera.
- El corredor técnico debe medir exactamente `1 × 1 × 1` y tener cuatro puertas opcionales.
- Un dungeon muy pequeño o un catálogo incompatible puede hacer fallar la conexión; `max_retries` permite probar otra distribución.
- Las habitaciones CSG incluidas son útiles para prototipar, pero conviene reemplazarlas por un kit propio optimizado.
- La generación puede ejecutarse en otro hilo, pero cualquier acceso al árbol de Godot debe respetar las restricciones de threading.
- El contenido dependiente del layout debe añadirse después de `done_generating`.

## Decisión sugerida

Usar una combinación de modalidades:

- **Nivel de pruebas y tutoriales:** escenas completamente predefinidas.
- **Runs normales:** generación procedural con semilla guardada.
- **Niveles con objetivo o narrativa:** estructura mixta, fijando inicio, objetivo y salida, y dejando que el generador complete el recorrido.

Esto mantiene control de diseño donde importa y variación donde aporta valor.
