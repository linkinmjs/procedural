# GDD — Atractivo, progresión y rejugabilidad

## Estado del documento

Documento de trabajo para desarrollar los sistemas que darán motivación de corto,
medio y largo plazo. Las ideas aquí registradas todavía no representan decisiones
finales de diseño.

Estados que usaremos durante el desarrollo:

- **Propuesto:** idea pendiente de análisis.
- **En definición:** dirección aceptada, pero con reglas todavía abiertas.
- **Para prototipar:** suficientemente definida como para probarla en el juego.
- **Confirmado:** validada y adoptada como parte del diseño.

## Objetivo

El juego debe ofrecer motivos para avanzar y volver a jugar sin depender
necesariamente de una estructura roguelite ni de mejoras permanentes de poder. Los
cuatro ejes seleccionados son:

1. Campaña arcade basada en puntuación.
2. Ventanas con comportamientos propios.
3. Sistema de combos y estilo.
4. Lobby con escritorio personalizable.

Los tres primeros afectan directamente la experiencia durante los niveles. El
cuarto representa la progresión visible, la expresión personal y el espacio desde
el cual el jugador accede al contenido del juego.

---

## 1. Campaña arcade basada en puntuación

**Estado:** Propuesto.

### Concepto

Cada nivel funciona como una prueba rejugable. Completarlo permite avanzar, pero
el desempeño determina una puntuación y un rango. El objetivo no es solamente
llegar a la salida: también importa cómo se llegó.

### Propósito

- Dar valor a mejorar la ejecución de un nivel conocido.
- Reconocer el dominio de la puntería, el movimiento y la administración de
  recursos.
- Permitir que un jugador avance con una ejecución normal y que otro pueda buscar
  resultados excelentes.
- Generar objetivos claros para repetir niveles sin depender de recompensas de
  poder.

### Aspectos a desarrollar

- Variables que aportan puntuación: tiempo, precisión, daño recibido, munición,
  combos, estilo u objetivos especiales.
- Fórmula de puntuación y peso de cada variable.
- Rangos posibles y requisitos para obtenerlos.
- Presentación del resultado al terminar una habitación y al terminar el nivel.
- Récord personal y comparación con intentos anteriores.
- Relación entre puntuación, desbloqueos y progreso de campaña.
- Reglas para reiniciar rápidamente un intento.
- Posibles desafíos adicionales por nivel.

### Preguntas abiertas

- ¿La campaña se desbloquea completando niveles o consiguiendo determinados
  rangos?
- ¿La puntuación debe premiar principalmente la velocidad o equilibrar varios
  estilos de juego?
- ¿Recibir daño debe reducir puntos, romper el combo o ambas cosas?
- ¿Cómo evitamos que buscar puntuación fomente acciones repetitivas o poco
  divertidas?
- ¿Mostraremos puntuaciones globales, de amigos o solamente récords locales?

---

## 2. Ventanas con comportamientos propios

**Estado:** Propuesto.

### Concepto

Las ventanas dejan de ser únicamente blancos con distintas apariencias. Cada
familia puede introducir una regla, amenaza o prioridad reconocible, convirtiendo
las habitaciones en problemas de acción que el jugador debe leer y resolver con
rapidez.

### Propósito

- Convertir las ventanas en el elemento distintivo del juego.
- Crear variedad de encuentros sin depender de enemigos humanoides tradicionales.
- Generar decisiones de prioridad durante el combate.
- Permitir que la dificultad aumente mediante combinaciones, no sólo aumentando
  cantidades o reduciendo el tiempo.

### Comportamientos iniciales para analizar

- **Popup:** crea nuevas ventanas si permanece abierta demasiado tiempo.
- **Descarga:** produce una consecuencia cuando su barra llega al final.
- **Firewall:** protege otras ventanas hasta ser desactivado.
- **Error crítico:** penaliza al jugador si dispara en una zona incorrecta.
- **Confirmación:** requiere acertar controles en un orden determinado.
- **Publicidad:** tapa parcial o temporalmente otros objetivos.
- **Falsa X:** presenta controles engañosos y exige identificar el correcto.
- **Administrador de tareas:** permite afectar varias ventanas mediante un blanco
  difícil o una secuencia especial.
- **Archivo corrupto:** cambia de posición, forma o comportamiento al ser golpeado.
- **Instalador:** tiene varias etapas antes de poder cerrarse definitivamente.

Esta lista es un banco de ideas, no un catálogo confirmado.

### Aspectos a desarrollar

- Taxonomía de ventanas y función jugable de cada familia.
- Señales visuales y sonoras que permiten reconocerlas rápidamente.
- Reglas de aparición y combinaciones válidas.
- Nivel de complejidad permitido dentro de una sola habitación.
- Consecuencias de ignorar cada comportamiento.
- Interacción con bloques, oleadas, puertas, puntuación y combos.
- Orden de introducción durante la campaña.
- Variantes visuales que no alteran las reglas.

### Preguntas abiertas

- ¿Cuánto tiempo debería necesitar el jugador para entender una ventana nueva?
- ¿Las ventanas explican sus reglas mediante tutorial, iconografía o
  experimentación?
- ¿Cuáles generan decisiones interesantes sin interrumpir el ritmo del FPS?
- ¿Qué comportamientos pueden combinarse y cuáles producirían encuentros
  injustos?
- ¿Destruir una ventana de manera óptima debería dar puntos de estilo adicionales?

---

## 3. Sistema de combos y estilo

**Estado:** Propuesto.

### Concepto

Las acciones ejecutadas con velocidad, precisión y variedad alimentan una cadena
de combo y una valoración de estilo. El sistema debe celebrar el dominio del
jugador y orientar la forma de jugar sin convertir el HUD en una distracción.

### Propósito

- Dar feedback inmediato a una buena ejecución.
- Vincular movimiento, puntería y lectura de ventanas.
- Crear tensión entre jugar de forma segura y mantener una cadena valiosa.
- Aportar profundidad al sistema de puntuación de la campaña.

### Acciones que podrían alimentar el sistema

- Destruir objetivos con poca separación temporal.
- Mantener una secuencia sin disparos fallidos.
- Acertar zonas pequeñas o difíciles.
- Resolver correctamente ventanas con comportamientos especiales.
- Alternar entre objetivos ubicados en paredes diferentes.
- Completar una oleada antes de que avance un bloque.
- Mantener velocidad durante el encuentro.
- Destruir una amenaza justo antes de que se active su penalización.
- Completar una habitación sin recibir daño.

### Aspectos a desarrollar

- Diferencia entre combo, multiplicador y estilo.
- Acciones que aumentan, mantienen, reducen o rompen la cadena.
- Caducidad del combo y tolerancia entre acciones.
- Categorías o mensajes de estilo.
- Relación con la puntuación final.
- Feedback visual, sonoro y háptico.
- Medidas para evitar que el jugador explote el sistema repitiendo una misma
  acción sencilla.
- Tratamiento de recargas, desplazamientos largos y transiciones entre salas.

### Preguntas abiertas

- ¿El combo debe depender solamente de impactos exitosos o también del movimiento?
- ¿Un disparo fallido rompe la cadena o reduce el multiplicador?
- ¿Recibir daño elimina todo el combo?
- ¿Queremos premiar variedad de acciones o ejecución pura?
- ¿La información aparece alrededor de la mira, en un lateral o sólo al cerrar
  cada habitación?

---

## 4. Lobby con escritorio personalizable

**Estado:** En definición.

### Concepto

El jugador dispone de un lobby físico con una pantalla gigante que funciona como
el escritorio de una PC. Desde allí puede acceder a la campaña y configurar el
aspecto del escritorio. Los elementos desbloqueados durante el juego se convierten
en iconos, fondos y opciones de personalización que puede organizar libremente.

El lobby reemplaza la idea de reconstruir una computadora de manera abstracta. La
progresión se vuelve visible dentro de un espacio persistente y manipulable.

### Funciones previstas

- Seleccionar niveles o modos desde iconos del escritorio.
- Desbloquear nuevos iconos a medida que se avanza.
- Acomodar los iconos libremente en la pantalla.
- Elegir y cambiar el fondo de pantalla.
- Cambiar el estilo visual del escritorio.
- Representar el progreso de campaña dentro del propio escritorio.
- Servir como espacio de descanso entre niveles.

### Posibles elementos desbloqueables

- Iconos de niveles, carpetas o aplicaciones.
- Fondos de pantalla.
- Temas inspirados en diferentes épocas o estilos de sistema operativo.
- Cursores y apariencias de selección.
- Sonidos de inicio, cierre y notificación.
- Salvapantallas.
- Widgets decorativos.
- Archivos, mensajes o elementos narrativos.
- Trofeos visuales relacionados con rangos y desafíos.

La personalización será principalmente expresiva. Por ahora no se asume que los
elementos del lobby otorguen mejoras jugables.

### Interacción con la pantalla

Debemos definir si la pantalla se utiliza:

- A distancia mediante una interfaz ampliada.
- Apuntando y disparando sobre iconos y controles.
- Con un cursor controlado por el mouse.
- Acercándose físicamente e interactuando con ella.
- Mediante una combinación de estas opciones según la tarea.

La forma de interacción debería mantener la fantasía de estar dentro del juego y,
al mismo tiempo, hacer cómoda la personalización detallada del escritorio.

### Aspectos a desarrollar

- Distribución física y dirección artística del lobby.
- Flujo entre lobby, selección de nivel, partida y regreso.
- Sistema para mover, ordenar y guardar la posición de iconos.
- Significado de cada categoría de icono.
- Reglas de desbloqueo.
- Catálogo y previsualización de fondos y estilos.
- Persistencia de la configuración elegida.
- Estado inicial del escritorio y evolución visible durante la campaña.
- Relación entre rangos, desafíos y objetos desbloqueables.
- Posibles secretos o interacciones dentro del lobby.

### Preguntas abiertas

- ¿El lobby es una habitación realista, un espacio digital o una mezcla de ambos?
- ¿El jugador puede recorrerlo libremente en primera persona?
- ¿La pantalla gigante es el único elemento interactivo?
- ¿Los iconos representan contenido jugable, objetos decorativos o ambas cosas?
- ¿Cómo accede el jugador a un nivel después de reorganizar los iconos?
- ¿Existe una papelera y qué significa colocar un icono dentro de ella?
- ¿El escritorio comienza vacío, desordenado, corrupto o parcialmente construido?
- ¿Los estilos son puramente visuales o también cambian sonidos y animaciones?
- ¿Qué se obtiene por completar un nivel y qué se reserva para rangos altos?

---

## Relación entre los cuatro sistemas

Flujo provisional:

1. El jugador selecciona un nivel desde el lobby.
2. Durante el nivel interpreta ventanas con diferentes comportamientos.
3. Su ejecución alimenta combos y acciones de estilo.
4. Al finalizar recibe puntuación, rango y récord personal.
5. El resultado puede desbloquear contenido para el lobby.
6. El jugador regresa al escritorio, organiza lo obtenido y elige su próximo
   objetivo.

Esta relación permite que la recompensa no sea solamente numérica: el desempeño
dentro de los niveles modifica progresivamente el espacio personal del jugador.

## Orden sugerido de desarrollo del diseño

1. Definir qué mide la puntuación y qué significa jugar bien.
2. Diseñar un conjunto inicial pequeño de ventanas con funciones claramente
   diferentes.
3. Construir el combo alrededor de las acciones que esas ventanas permiten.
4. Definir qué resultados desbloquean contenido del lobby.
5. Diseñar el flujo y la interacción de la pantalla gigante.

