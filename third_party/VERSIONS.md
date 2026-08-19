# Third-party sources

- FPS Template: `chafmere/Godot4-FPS-Template` commit `71309293911f57b124cf1b4be751df311b20b48c` (MIT).
- SimpleDungeons: `majikayogames/SimpleDungeons` commit `15b32406e2f10c55cdb864e18661137bacfead89` (CC0-1.0).
- Texturas: Screaming Brain Studios — Horror Texture Pack, Tiny Texture Pack y Tiny Texture Pack 2 (CC0-1.0 / dominio publico).
- Cielo: shader de cielo procedural con nubes, sol, luna y estrellas, en `assets/skies/`.

De los packs de texturas solo se versiona la seleccion en uso, bajo
`assets/textures/packs/<pack>/`, en 256x256. Los paquetes completos quedan
comprimidos en `assets/_raw/textures/`, fuera de Git: pesan cientos de MB y no
hace falta arrastrarlos al repositorio para usar quince archivos.

SimpleDungeons stays vendored under `addons/SimpleDungeons/` with its upstream layout.
The FPS Template was dissolved into the project layout: its scenes live under `scenes/player/`, `scenes/weapons/` and `scenes/projectiles/`, its scripts under `scripts/player/`, `scripts/weapons/` and `scripts/projectiles/`, its data under `resources/weapons/` and `resources/animations/`, and its art under `assets/models/weapons/` and `assets/textures/`.
