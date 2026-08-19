# Level Workshop

Editor web local para diseñar niveles desde arriba. No necesita dependencias ni proceso de compilación.

## Uso

Se puede abrir `index.html` directamente. Para servirlo desde una URL local, desde la raíz del repositorio:

```powershell
python -m http.server 8080 --directory tools/level-editor
```

Abrir `http://localhost:8080` en el navegador.

- Agregar salas pequeñas, grandes o pasillos.
- Arrastrarlas sobre la grilla.
- Activar **Unir dos salas** y seleccionar origen y destino.
- Configurar la entrada y los bloques izquierdo, frontal y derecho de cada sala.
- Elegir color, velocidad y si el bloque es estático o avanza hacia el lado contrario.
- Configurar una o más oleadas de objetivos; la siguiente aparece al destruir la anterior.
- Definir el tiempo límite global del nivel en minutos y segundos.
- Guardar con el selector de archivos del navegador o descargar el JSON.
- Colocar los archivos definitivos en `level_designs/`.

El editor conserva automáticamente un borrador en el almacenamiento local del navegador. Ese borrador es una comodidad y no reemplaza a los JSON versionados en Git.

## Alcance actual

El formato registra la intención de diseño. Todavía no instancia estas definiciones dentro de Godot; esa importación será el siguiente puente entre la herramienta y el runtime.
