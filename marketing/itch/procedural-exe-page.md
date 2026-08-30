# Procedural.exe — página de itch.io

Textos para el dashboard del proyecto. El bloque HTML de la descripción se pega
en modo fuente (botón `<>`); itch conserva encabezados, párrafos, negrita,
listas, tablas simples e imágenes subidas desde el editor.

## Short description / tagline

Una sola línea; itch la muestra debajo del título y en los links.

> Un FPS arcade dentro de una PC vieja. Los enemigos son pop-ups: disparale a la X.

Inglés, para el bloque en inglés de la descripción (itch no tiene tagline por idioma):

> An arcade FPS inside an old PC. The enemies are pop-ups: shoot the X.

## Tags

Diez como máximo. Los primeros pesan más en las búsquedas.

`fps` · `arcade` · `first-person` · `shooter` · `retro` · `singleplayer` · `procedural-generation` · `windows-xp` · `crt` · `godot`

Género: **Shooter**. Kind of project: **HTML** (jugable en el navegador). Estado: **In development**.

## Description

```html
<p><strong>Abrís procedural.exe en una PC vieja y caés adentro.</strong> Salas generadas al azar, un cronómetro, una Glock con diez balas por cargador y paredes llenas de ventanas emergentes. No se le dispara al medio: se le dispara a la X, al botón o al cartel. Con puntería y velocidad se encadenan cierres, sube el multiplicador y suben los puntos.</p>

<h2>Las ventanas no son todas iguales</h2>
<ul>
<li><strong>Publicidad.</strong> Un botón de SKIP que cuenta hacia atrás. Errarle abre otra. Y otra.</li>
<li><strong>Firewall.</strong> Mientras esté en pie, protege a todas las ventanas de su bloque: los tiros rebotan y no puntúan.</li>
<li><strong>Error crítico.</strong> Tres botones, uno cierra y dos castigan. Se barajan cada vez que fallás.</li>
<li><strong>Descarga.</strong> Dejarla terminar vale poco. Cancelarla vale más, pero pide una confirmación.</li>
<li><strong>Descarga infectada.</strong> Se distingue solo por el nombre del archivo en rojo. Si termina, cuelga el bloque entero.</li>
</ul>

<h2>Cómo se juega</h2>
<table>
<tr><td>Moverse</td><td>WASD</td></tr>
<tr><td>Saltar</td><td>Espacio</td></tr>
<tr><td>Disparar / apuntar</td><td>Clic izquierdo / clic derecho</td></tr>
<tr><td>Recargar</td><td>R</td></tr>
<tr><td>Agacharse · caminar</td><td>C · Shift</td></tr>
<tr><td>Asomarse</td><td>Q / E</td></tr>
<tr><td>Reiniciar nivel · pausa</td><td>Retroceso · Esc</td></tr>
</table>
<p>Mouse y teclado. Se juega en el navegador, sin instalar nada; el juego captura el mouse al entrar a una sala y lo suelta con Esc.</p>

<h2>Estado</h2>
<p><strong>Acceso anticipado.</strong> Campaña de 30 niveles en 3 actos, rangos por nivel, sistema de XP y 24 logros que se consultan desde <em>Mi PC</em>. Los niveles y las familias de ventanas se siguen sumando. Los récords se guardan en el navegador. Textos en español, inglés y portugués.</p>

<h2>Créditos</h2>
<p>Un juego de <a href="https://linkinmjs.itch.io">Ominoso</a>. Hecho con Godot 4.</p>

<hr>

<h2>English</h2>
<p><strong>You open procedural.exe on an old PC and fall in.</strong> Randomly generated rooms, a timer, a Glock with ten rounds per magazine and walls covered in pop-up windows. You don't shoot the middle of a window: you shoot the X, the button or the banner. Aim fast, chain closes, raise the multiplier, raise the score.</p>
<ul>
<li><strong>Ads.</strong> A SKIP button that counts down. Miss the window and it spawns another one.</li>
<li><strong>Firewall.</strong> While it stands, every other window in its block is shielded: shots bounce off and score nothing.</li>
<li><strong>Critical error.</strong> Three buttons: one closes, two punish. They reshuffle every time you miss.</li>
<li><strong>Download.</strong> Letting it finish is worth little. Cancelling is worth more, but asks you to confirm.</li>
<li><strong>Infected download.</strong> Only the red file name gives it away. If it completes, it crashes the whole block.</li>
</ul>
<p>WASD to move, Space to jump, left click to shoot, right click to aim, R to reload, C to crouch, Shift to walk, Q/E to lean, Backspace to restart, Esc to pause. Mouse and keyboard, runs in the browser.</p>
<p><strong>Early access.</strong> A 30-level campaign in 3 acts, per-level ranks, XP and 24 achievements. Progress is saved in your browser. Available in Spanish, English and Portuguese.</p>
```

## Imágenes de esta carpeta

| Uso | Archivo |
|---|---|
| Cover image (630x500) | `game-cover-630x500.png` (Cybercrime 2004); alternativas `game-cover-alt-*.png` |
| Banner (Edit theme) | `game-banner-desktop-960x540.png` |
| Screenshots, en orden | `shot-01-gameplay.png`, `shot-02-window-families.png`, `shot-03-desktop-crt.png`, `shot-04-combo.png`, `shot-05-mi-pc.png`, `shot-06-system-down.png` |

Para regenerar la portada con otra fuente o texto: `game-cover-source.html` se
captura con Chrome headless a 630x500 (`--allow-file-access-from-files` para
que cargue las fuentes del repo). El banner sale del test visual
`tests/desktop_visual_smoke_test.tscn`, que deja `.godot/desktop-crt.png`.
