# Third-party sources

- FPS Template: `chafmere/Godot4-FPS-Template` commit `71309293911f57b124cf1b4be751df311b20b48c` (MIT).
- SimpleDungeons: `majikayogames/SimpleDungeons` commit `15b32406e2f10c55cdb864e18661137bacfead89` (CC0-1.0).
- Texturas: Screaming Brain Studios — Horror Texture Pack y la serie Tiny Texture Pack (CC0-1.0 / dominio publico).
- Cielo: shader de cielo procedural con nubes, sol, luna y estrellas, en `assets/skies/`.
- UI de Windows XP: pack de NullTale (`assets/_raw/WinXp.zip`). De ahi salen el theme de ventana, la barra de tareas, el boton de inicio, los iconos del escritorio y el fondo de pantalla.
- UI retro gris: RetroWindowsGUI (`assets/_raw/RetroWindowsGUI.zip`), usado por el theme retro de las ventanas disparables.
- Splash de Godot: pack Godot-SplashScreens de Kenney (`Screen/Pixel logo/original-large-dark.png`, reducido a 1920x1080 en `assets/textures/ui/splash/`). El logo de Godot es de Andrea Calabro, CC-BY-4.0; la composicion y los logos derivados del pack son CC0 de Kenney. Detalle en `assets/textures/ui/splash/LICENSE.txt`.
- Fuente de la terminal del arranque: `Withheld Data` (`assets/fonts/boot/`), copiada del paquete de fuentes de `assets/fonts/` (carpetas con `.gdignore`: solo se importa la que se usa).

De los packs de UI, igual que con las texturas, solo se versiona el recorte en
uso bajo `assets/textures/ui/<estilo>/`. Los packs completos quedan comprimidos
en `assets/_raw/`, fuera de Git.

De los packs de texturas se versiona la seleccion en uso, bajo
`assets/textures/packs/<Material>/`, en 256x256 y agrupada por material
(Bricks, Wood, Metal, ...). `level_designs/texture-catalog.json` se genera
desde esas carpetas y es la unica fuente de la relacion identificador ->
archivo. Los paquetes completos quedan comprimidos en `assets/_raw/textures/`,
fuera de Git: pesan cientos de MB.

SimpleDungeons stays vendored under `addons/SimpleDungeons/` with its upstream layout.
The FPS Template was dissolved into the project layout: its scenes live under `scenes/player/`, `scenes/weapons/` and `scenes/projectiles/`, its scripts under `scripts/player/`, `scripts/weapons/` and `scripts/projectiles/`, its data under `resources/weapons/` and `resources/animations/`, and its art under `assets/models/weapons/` and `assets/textures/`.
