# Diseños de niveles

Esta carpeta contiene las definiciones versionadas creadas con `tools/level-editor/`.

- `level-sequence.json` define el orden de los niveles jugables.
- Cada nivel vive en un archivo JSON independiente.
- `schema.json` documenta y valida el formato actual.
- `three-room-example.json` sirve como referencia editable.
- Las posiciones y dimensiones están expresadas en metros para facilitar su futura conversión a coordenadas de Godot.
- `timeLimitSeconds` define el tiempo límite global del nivel. El editor lo presenta en minutos y segundos.

Los bloques `left`, `front` y `right` son relativos a la pared por la que entra el jugador a cada sala. Por ejemplo, con una entrada `south`, el bloque `front` se dibuja sobre la pared `north`.

El formato actual usa `schemaVersion: 3`. Cada bloque define color, velocidad y una lista ordenada de oleadas. Al importar un archivo anterior, el editor migra `targetCount` a una primera oleada y conserva los valores existentes.
