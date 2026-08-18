# Diseños de niveles

Esta carpeta contiene las definiciones versionadas creadas con `tools/level-editor/`.

- Cada nivel vive en un archivo JSON independiente.
- `schema.json` documenta y valida el formato actual.
- `three-room-example.json` sirve como referencia editable.
- Las posiciones y dimensiones están expresadas en metros para facilitar su futura conversión a coordenadas de Godot.

Los bloques `left`, `front` y `right` son relativos a la pared por la que entra el jugador a cada sala. Por ejemplo, con una entrada `south`, el bloque `front` se dibuja sobre la pared `north`.

El campo `schemaVersion` permitirá migrar diseños cuando se incorporen tipos de objetivos, nuevas formas de bloques o geometrías de sala adicionales.
