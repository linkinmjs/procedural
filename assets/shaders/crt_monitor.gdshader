// Monitor de tubo sobre el escritorio del menu principal.
//
// Lo aplica CrtOverlay desde un ColorRect a pantalla completa en una capa por
// encima de todos los menus, leyendo lo ya dibujado con hint_screen_texture.
// Cada efecto va apenas insinuado a proposito: la pantalla es un menu que hay
// que leer, no un filtro que lucir. Los valores por defecto son los del juego;
// docs/configuraciones.md los lista. No hay curvatura: distorsionar la imagen
// corre el dibujo respecto de donde el mouse hace clic.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;

// Encendido del tubo: 0 es apagado, 1 es la imagen completa. Entre medio la
// imagen es una linea brillante que primero se abre a lo ancho y despues se
// despliega a lo alto, como un monitor viejo al prenderlo.
uniform float power_on : hint_range(0.0, 1.0) = 1.0;
// Fraccion de brillo que se llevan las lineas de barrido y cada cuantos
// pixeles reales de pantalla se repiten.
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.10;
uniform float scanline_period_px : hint_range(1.0, 8.0) = 3.0;
// Separacion del rojo y el azul en pixeles, en el borde de la pantalla; en el
// centro es cero, para que el texto siga nitido.
uniform float aberration_px : hint_range(0.0, 3.0) = 0.7;
// Oscurecimiento de los bordes y desde que distancia al centro empieza.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_start : hint_range(0.0, 1.0) = 0.45;
// Esquinas redondeadas del tubo, en fraccion de la pantalla.
uniform float corner_radius : hint_range(0.0, 0.2) = 0.03;
// Parpadeo aleatorio del brillo (fraccion) y una banda algo mas clara que
// baja despacio, como el arrastre de una cinta.
uniform float flicker_strength : hint_range(0.0, 0.2) = 0.012;
uniform float band_strength : hint_range(0.0, 0.2) = 0.03;
uniform float band_speed : hint_range(0.0, 1.0) = 0.05;
uniform float band_height : hint_range(0.0, 1.0) = 0.25;
// Grano por pixel, fraccion.
uniform float noise_strength : hint_range(0.0, 0.2) = 0.015;
// Compensa lo que se llevan las lineas y la viñeta.
uniform float brightness : hint_range(0.5, 1.5) = 1.04;
uniform vec4 bezel_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;

	// --- Encendido -------------------------------------------------------
	float width = mix(0.02, 1.0, smoothstep(0.0, 0.4, power_on));
	float height = mix(0.004, 1.0, pow(smoothstep(0.4, 1.0, power_on), 1.7));
	vec2 source = centered / vec2(width, height) + 0.5;
	bool outside = source.x < 0.0 || source.x > 1.0 || source.y < 0.0 || source.y > 1.0;
	// La linea es mas brillante cuanto mas angosta: el haz concentrado. Con la
	// imagen ya casi desplegada el sobrebrillo tiene que ser leve, o el
	// escritorio aparece quemado.
	float glow = pow(1.0 - height, 3.0) * 2.0 + (1.0 - power_on) * 0.25;

	// --- Aberracion cromatica ----------------------------------------------
	vec2 offset = centered * 2.0 * aberration_px * SCREEN_PIXEL_SIZE;
	vec3 color;
	color.r = texture(screen_texture, source - offset).r;
	color.g = texture(screen_texture, source).g;
	color.b = texture(screen_texture, source + offset).b;

	// --- Lineas de barrido ---------------------------------------------------
	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * TAU / scanline_period_px);
	color *= 1.0 - scanline_strength * scan;

	// --- Banda que baja y parpadeo -------------------------------------------
	float band_pos = fract(uv.y + TIME * band_speed);
	float band = smoothstep(0.0, band_height, band_pos) * (1.0 - smoothstep(band_height, band_height * 2.0, band_pos));
	color *= 1.0 + band_strength * band;
	float flicker = (hash(vec2(floor(TIME * 24.0), 1.0)) - 0.5) * 2.0 * flicker_strength;
	color *= 1.0 + flicker;
	color += (hash(uv * 1000.0 + fract(TIME) * 100.0) - 0.5) * noise_strength;

	// --- Viñeta y esquinas ---------------------------------------------------
	float radial = length(centered * vec2(1.0, 0.85)) * 2.0;
	color *= 1.0 - vignette_strength * smoothstep(vignette_start, 1.3, radial);
	// Distancia con signo a un rectangulo redondeado: negativa adentro. Sin el
	// "- corner_radius" la mascara oscurecia todo el borde recto (se comia una
	// franja abajo y a los costados), no solo las esquinas.
	vec2 corner = max(abs(centered) - (0.5 - corner_radius), 0.0);
	float corner_distance = length(corner) - corner_radius;
	color *= 1.0 - smoothstep(-0.004, 0.0, corner_distance);

	color *= brightness * (1.0 + glow);
	COLOR = outside ? bezel_color : vec4(color, 1.0);
}
