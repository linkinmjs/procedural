import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const LevelFormat = require("../tools/level-editor/level-format.js");
const WindowFormat = require("../tools/level-editor/window-format.js");

const html = fs.readFileSync("tools/level-editor/index.html", "utf8");
const script = fs.readFileSync("tools/level-editor/app.js", "utf8");
const styles = fs.readFileSync("tools/level-editor/styles.css", "utf8");
const schema = JSON.parse(fs.readFileSync("level_designs/schema.json", "utf8"));
const catalog = JSON.parse(fs.readFileSync("level_designs/texture-catalog.json", "utf8"));
const levelPaths = [
  "level_designs/three-room-example.json",
  ...fs.readdirSync("level_designs/levels").map((file) => `level_designs/levels/${file}`)
];

// --- Controles del documento -------------------------------------------------

for (const id of [
  "level-canvas", "rooms-layer", "corridors-layer", "room-dialog", "room-map",
  "wave-tabs", "slot-grid",
  "texture-fields", "room-list", "connection-list", "level-time-minutes", "level-time-seconds",
  "level-ammo-magazine", "level-ammo-reserve", "level-wall-height", "level-corridor-width",
  "level-has-ceiling", "room-wall-height", "room-wall-height-mode", "room-ceiling",
  "room-ammo-enabled", "room-ammo-amount", "room-radio-enabled", "room-radio-corner", "template-list", "save-template", "facing-compass", "entry-summary",
  "duplicate-room", "zoom-fit", "import-file", "download-file"
]) {
  assert.match(html, new RegExp(`id=["']${id}["']`), `Falta el control #${id}`);
}
for (const role of ["start", "transition", "exit"]) {
  assert.match(html, new RegExp(`data-role=["']${role}["']`), `Falta el rol ${role}`);
}
for (const facing of [0, 45, 90, 135, 180, 225, 270, 315]) {
  assert.match(html, new RegExp(`data-facing=["']${facing}["']`), `Falta la dirección ${facing}`);
}
assert.doesNotMatch(html, /id=["']entry-wall["']/, "La pared de entrada ya no se elige a mano");

// Cada control que el script busca por id tiene que existir en el documento.
const referencedIds = new Set([...script.matchAll(/\$\("#([a-z0-9-]+)"\)/g)].map((match) => match[1]));
const missingIds = [...referencedIds].filter((id) => !html.includes(`id="${id}"`));
assert.deepEqual(missingIds, [], `El editor referencia controles inexistentes: ${missingIds.join(", ")}`);
assert.match(styles, /\.segment\[aria-checked="true"\]/, "El selector de rol necesita estado visual");
assert.match(script, /window\.LevelFormat/, "El editor debe usar el modelo compartido");
assert.match(script, /localStorage\.setItem/, "El editor debe guardar el borrador automáticamente");
assert.match(script, /showSaveFilePicker/, "El editor debe poder guardar un archivo JSON");
assert.match(script, /createSVGPoint/, "El editor debe soportar arrastre sobre el plano SVG");
assert.match(script, /texture-catalog\.json/, "El editor debe leer el catálogo de texturas");

// --- Contrato del formato ----------------------------------------------------

assert.equal(schema.properties.schemaVersion.const, LevelFormat.SCHEMA_VERSION);
assert.deepEqual(schema.$defs.role.enum, ["start", "transition", "exit"]);
assert.equal(schema.$defs.facing.maximum, 359);
assert.ok(schema.$defs.connection.required.includes("width"), "Cada pasillo declara su ancho");
assert.ok(schema.$defs.levelDefaults.required.includes("corridorWidth"));
for (const key of ["role", "facing", "wallHeight", "hasCeiling", "ammoReward", "radio", "textures"]) {
  assert.ok(schema.$defs.room.required.includes(key), `La sala debe declarar ${key}`);
}
assert.deepEqual(schema.$defs.radio.properties.corner.enum, LevelFormat.RADIO_CORNERS, "Las esquinas de la radio del schema y la tool deben coincidir");
{
  const legacy = LevelFormat.createEmptyLevel();
  const room = LevelFormat.createRoom("small", 1);
  delete room.radio;
  legacy.rooms.push(room);
  const normalized = LevelFormat.normalizeLevel(legacy);
  assert.deepEqual(normalized.rooms[0].radio, { enabled: false, corner: LevelFormat.DEFAULT_RADIO_CORNER }, "Una sala sin radio recibe la radio apagada");
  room.radio = { enabled: true, corner: "xx" };
  assert.equal(LevelFormat.normalizeLevel(legacy).rooms[0].radio.corner, LevelFormat.DEFAULT_RADIO_CORNER, "Una esquina inválida cae a la de defecto");
}
assert.ok(Array.isArray(catalog.textures), "El catálogo de texturas debe listar sus entradas");
assert.ok(catalog.textures.length > 0, "El catálogo de texturas ya no puede estar vacío");
assert.ok(Array.isArray(catalog.packs) && catalog.packs.length >= 3, "El catálogo debe declarar sus packs");
const catalogPacks = new Set(catalog.packs.map((pack) => pack.id));
for (const entry of catalog.textures) {
  assert.match(entry.id, /^[a-z0-9]+\/[a-z0-9-]+$/, `Identificador de textura inválido: ${entry.id}`);
  assert.ok(catalogPacks.has(entry.pack), `${entry.id} pertenece a un pack no declarado`);
  assert.match(entry.path, /^res:\/\/assets\/textures\//, `${entry.id} debe apuntar a assets/textures`);
  assert.ok(fs.existsSync(entry.path.replace("res://", "")), `Falta el archivo de ${entry.id}`);
  assert.ok(entry.tile > 0, `${entry.id} necesita un tamaño de mosaico`);
}
// Las texturas se eligen viendo la imagen, no adivinando por el nombre.
assert.match(script, /renderTexturePicker/, "El editor debe dibujar la grilla visual de texturas");
assert.match(script, /openTexturePicker/, "Cada superficie abre el selector visual");
assert.match(script, /loading = "lazy"/, "Con 345 miniaturas la grilla carga las imágenes de a poco");
for (const id of ["texture-dialog", "texture-search", "texture-picker-grid"]) {
  assert.match(html, new RegExp(`id=["']${id}["']`), `Falta el control #${id}`);
}
assert.doesNotMatch(script, /<select data-texture/, "El desplegable de nombres quedó reemplazado por la grilla");

// Los cielos que ofrece la herramienta son los que sabe construir el juego.
const skyCatalogSource = fs.readFileSync("scripts/environment/sky_catalog.gd", "utf8");
const catalogBody = skyCatalogSource.slice(skyCatalogSource.indexOf("const SKIES := {"));
const runtimeSkies = [...catalogBody.matchAll(/^	"([a-z-]+)": \{$/gm)].map((match) => match[1]);
assert.deepEqual(
  Object.keys(LevelFormat.SKY_LABELS).sort(),
  runtimeSkies.sort(),
  "SKY_LABELS y SkyCatalog.SKIES deben ofrecer los mismos cielos"
);
assert.deepEqual(
  [...schema.$defs.sky.enum].sort(),
  runtimeSkies.sort(),
  "El schema debe aceptar exactamente los cielos del catálogo"
);
const runtimeDefault = skyCatalogSource.match(/const DEFAULT_ID := "([a-z-]+)"/)[1];
assert.equal(LevelFormat.DEFAULT_SKY, runtimeDefault, "El cielo por defecto debe coincidir con el del juego");
assert.match(html, /id=["']level-sky["']/, "Falta el selector de cielo");
assert.match(script, /SKY_LABELS/, "El editor debe poblar el selector de cielo");

// --- Oleadas de sala y capas de bloque ---------------------------------------

// El formato tiene dos niveles de agrupacion y no pueden llamarse igual: la
// sala declara oleadas, y cada bloque de una oleada declara sus capas.
assert.ok(schema.$defs.room.required.includes("waves"), "La sala debe declarar sus oleadas");
assert.ok(!("blocks" in schema.$defs.room.properties), "Los bloques ya no cuelgan de la sala");
assert.ok(schema.$defs.roomWave.properties.blocks, "Una oleada de sala agrupa bloques");
assert.ok(schema.$defs.block.required.includes("layers"), "El bloque debe declarar sus capas");
assert.ok(!("waves" in schema.$defs.block.properties), "El bloque ya no llama oleadas a sus capas");
assert.equal(
  schema.$defs.room.properties.waves.maxItems,
  LevelFormat.LIMITS.roomWaves.max,
  "El schema y la herramienta deben topear las oleadas en el mismo numero"
);

// El limite de oleadas tambien lo conoce el juego.
const loaderSource = fs.readFileSync("scripts/levels/level_definition_loader.gd", "utf8");
assert.equal(
  Number(loaderSource.match(/const MAX_ROOM_WAVES := (\d+)/)[1]),
  LevelFormat.LIMITS.roomWaves.max,
  "MAX_ROOM_WAVES y LIMITS.roomWaves deben coincidir"
);

// Un archivo v8 se abre sin perder nada: su grupo unico de bloques es la
// primera oleada, y lo que ahi se llamaba `waves` son las capas.
const legacyLevel = LevelFormat.normalizeLevel({
  schemaVersion: 8,
  rooms: [{
    id: "legacy", name: "Vieja", role: "start", position: { x: 0, z: 0 },
    size: { width: 14, depth: 14 }, entry: { wall: "south", offset: 0 }, facing: 0,
    blocks: {
      left: { enabled: false, waves: [] },
      front: { enabled: true, movement: "static", movementSpeed: 0.65, color: "#2ed5c5", waves: [{ windows: { normal: 4 } }] },
      right: { enabled: false, waves: [] }
    }
  }],
  connections: []
});
assert.equal(legacyLevel.schemaVersion, LevelFormat.SCHEMA_VERSION, "Importar migra a la version actual");
const legacyRoom = legacyLevel.rooms[0];
assert.equal(legacyRoom.blocks, undefined, "La sala migrada no conserva el grupo viejo");
assert.equal(legacyRoom.waves.length, 1, "El grupo unico de v8 es una sola oleada");
assert.deepEqual(
  legacyRoom.waves[0].blocks.front.layers,
  [{ windows: { normal: 4 } }],
  "Las oleadas del bloque pasan a ser sus capas"
);
assert.equal(legacyRoom.waves[0].blocks.front.waves, undefined, "El bloque migrado no conserva el nombre viejo");

// Una sala nueva arranca con una oleada, y la herramienta no deja quedarse sin
// ninguna: sin oleada no hay donde poner bloques.
const freshRoom = LevelFormat.createRoom("small", 1);
assert.equal(freshRoom.waves.length, 1, "Una sala nueva arranca con una oleada");
assert.deepEqual(Object.keys(freshRoom.waves[0].blocks).sort(), ["front", "left", "right"]);
assert.match(script, /room\.waves\.length <= 1/, "La ultima oleada de una sala no se puede borrar");

// Los tres bloques de una oleada se editan a la vez: antes cada uno abria su
// propio dialogo y armar una sala eran nueve aperturas.
assert.doesNotMatch(html, /id=["']block-dialog["']/, "Los bloques ya no viven en un dialogo aparte");
assert.match(script, /function renderSlotGrid/, "El editor debe dibujar los tres bloques juntos");
assert.match(script, /function familyChip/, "Las familias se ajustan con chips, sin menues");
assert.match(script, /structuredClone/, "Duplicar oleada y capa evita rehacerlas a mano");
assert.match(styles, /\.slot-grid/, "La grilla de bloques necesita estilos");
assert.match(styles, /\.family-chip/, "Los chips de familia necesitan estilos");

// --- Inferencia de la entrada ------------------------------------------------

/** Arma una cadena de salas en línea: A al oeste, B al centro, C al este. */
function chainLevel() {
  const level = LevelFormat.createEmptyLevel();
  const a = LevelFormat.createRoom("small", 1);
  const b = LevelFormat.createRoom("small", 2);
  const c = LevelFormat.createRoom("small", 3);
  Object.assign(a, { id: "a", name: "A", role: "start", facing: 90, position: { x: -20, z: 0 } });
  Object.assign(b, { id: "b", name: "B", position: { x: 0, z: 0 } });
  Object.assign(c, { id: "c", name: "C", role: "exit", position: { x: 20, z: 0 } });
  level.rooms = [a, b, c];
  level.connections = [LevelFormat.createConnection(a, b, 3.5), LevelFormat.createConnection(b, c, 2)];
  return LevelFormat.normalizeLevel(level);
}

const chain = chainLevel();
const [a, b, c] = chain.rooms;
assert.equal(a.entry.wall, "west", "La sala de inicio entra por la pared a espaldas del jugador");
assert.equal(b.entry.wall, "west", "Se entra a B desde A, que está al oeste");
assert.equal(c.entry.wall, "west", "Se entra a C desde B, que está al oeste");
assert.equal(chain.connections[1].width, 2, "El pasillo conserva el ancho declarado");

// Girar al jugador cambia la entrada de la sala de inicio sin tocar el resto.
a.facing = 180;
LevelFormat.resolveEntryWalls(chain);
assert.equal(a.entry.wall, "north", "Mirando al sur, la entrada queda al norte");
assert.equal(b.entry.wall, "west", "Las demás salas no dependen de la orientación inicial");

// Mover la sala de inicio al otro extremo invierte por dónde llega el jugador.
const moved = chainLevel();
moved.rooms[0].position = { x: 40, z: 0 };
moved.connections[0] = LevelFormat.createConnection(moved.rooms[0], moved.rooms[1], 3.5);
LevelFormat.resolveEntryWalls(moved);
assert.equal(moved.rooms[1].entry.wall, "east", "Ahora se entra a B por el este");

// Una sala suelta no rompe el recorrido.
const orphan = chainLevel();
orphan.rooms.push(Object.assign(LevelFormat.createRoom("small", 4), { id: "d", name: "D", position: { x: 0, z: 40 } }));
LevelFormat.resolveEntryWalls(orphan);
assert.equal(orphan.rooms[3].entry.wall, "south", "Una sala sin pasillos conserva su entrada por defecto");

// --- Trazado de los pasillos -------------------------------------------------

/** Un pasillo entre paredes este/oeste avanza primero a lo ancho. */
const sideways = chainLevel();
const sidewaysPlan = LevelFormat.corridorPlan(sideways.rooms[0], sideways.rooms[1], sideways.connections[0]);
const sidewaysPath = sidewaysPlan.points;
assert.equal(sidewaysPath.length, 2, "Con las salas alineadas el pasillo es recto");
assert.equal(sidewaysPath[0].y, sidewaysPath[1].y);
assert.equal(sidewaysPlan.width, sideways.connections[0].width, "Sin desfase conserva el ancho declarado");

/** Uno entre paredes norte/sur tiene que salir en profundidad, no de costado. */
const elbow = LevelFormat.createEmptyLevel();
const below = Object.assign(LevelFormat.createRoom("small", 1), { id: "below", name: "Abajo", role: "start", position: { x: 7, z: -2 } });
const above = Object.assign(LevelFormat.createRoom("large", 2), { id: "above", name: "Arriba", role: "exit", position: { x: -11, z: -22 } });
elbow.rooms = [below, above];
elbow.connections = [{ id: "e1", fromRoomId: "below", toRoomId: "above", fromWall: "north", toWall: "south", width: 3.5 }];
const elbowPlan = LevelFormat.corridorPlan(below, above, elbow.connections[0]);
const elbowPath = elbowPlan.points;
assert.equal(elbowPath.length, 4, "Sin alineación el pasillo describe un codo");
assert.equal(elbowPlan.width, 3.5, "Un codo con lugar conserva el ancho declarado");
assert.equal(elbowPath[0].x, elbowPath[1].x, "El primer tramo sale perpendicular a la pared norte");
assert.ok(elbowPath[1].y < elbowPath[0].y, "y avanza hacia el norte al salir");
assert.equal(elbowPath[3].x, elbowPath[2].x, "El último tramo entra perpendicular a la pared sur");
assert.deepEqual(elbowPath[0], LevelFormat.wallPoint(below, "north"));
assert.deepEqual(elbowPath[3], LevelFormat.wallPoint(above, "south"));
assert.match(script, /corridorPlan/, "El plano debe dibujar el trazado compartido");

/**
 * Con las puertas desalineadas menos que el ancho no entra un codo: los dos
 * giros se solaparían, así que el pasillo va recto y se ensancha.
 */
const tight = LevelFormat.createEmptyLevel();
const west = Object.assign(LevelFormat.createRoom("large", 1), { id: "w", name: "Oeste", role: "start", position: { x: -11, z: -22 } });
const east = Object.assign(LevelFormat.createRoom("small", 2), { id: "e", name: "Este", role: "exit", position: { x: 19, z: -20 } });
tight.rooms = [west, east];
tight.connections = [{ id: "t1", fromRoomId: "w", toRoomId: "e", fromWall: "east", toWall: "west", width: 3.5 }];
const tightPlan = LevelFormat.corridorPlan(west, east, tight.connections[0]);
assert.equal(tightPlan.points.length, 2, "Sin lugar para el codo el pasillo va recto");
assert.equal(tightPlan.width, 5.5, "El pasillo se ensancha lo justo para cubrir las dos puertas");
const tightMinY = Math.min(...tightPlan.points.map((point) => point.y)) - tightPlan.width / 2;
const tightMaxY = Math.max(...tightPlan.points.map((point) => point.y)) + tightPlan.width / 2;
for (const [room, wall] of [[west, "east"], [east, "west"]]) {
  const door = LevelFormat.wallPoint(room, wall);
  assert.ok(door.y - 3.5 / 2 >= tightMinY - 0.001 && door.y + 3.5 / 2 <= tightMaxY + 0.001,
    `El pasillo ensanchado debe cubrir la puerta de ${room.name}`);
}

// El contorno cierra la banda del pasillo sin bordes internos entre tramos.
const outline = LevelFormat.corridorOutline(elbowPath, 3.5);
assert.equal(outline.length, elbowPath.length * 2, "El contorno recorre ida y vuelta el trazado");
const outlineXs = outline.map((point) => point.x);
const outlineYs = outline.map((point) => point.y);
assert.ok(Math.max(...outlineXs) - Math.min(...outlineXs) >= 3.5, "El contorno tiene el ancho del pasillo");
assert.ok(Math.max(...outlineYs) - Math.min(...outlineYs) >= 3.5);
for (const point of outline) {
  assert.ok(Number.isFinite(point.x) && Number.isFinite(point.y), "El contorno no puede tener puntos degenerados");
}
const straightOutline = LevelFormat.corridorOutline(sidewaysPath, 2);
assert.equal(straightOutline.length, 4, "Un pasillo recto es un rectángulo de cuatro vértices");
assert.match(script, /corridorOutline/, "El plano debe dibujar el pasillo como una sola figura");
assert.doesNotMatch(script, /class: "corridor-shape corner"/, "Ya no se dibujan parches de esquina sueltos");

// --- Puntos intermedios del pasillo -------------------------------------------
// Espejan los casos de tests/corridor_waypoints_smoke_test.gd: las dos
// implementaciones del trazado tienen que coincidir.

/** Dos salas enfrentadas: puertas en (-13, 0) y (-7, 0). */
function waypointLevel(waypoints) {
  const level = LevelFormat.createEmptyLevel();
  const a = Object.assign(LevelFormat.createRoom("small", 1), { id: "wa", role: "start", position: { x: -20, z: 0 } });
  const b = Object.assign(LevelFormat.createRoom("small", 2), { id: "wb", role: "exit", position: { x: 0, z: 0 } });
  level.rooms = [a, b];
  level.connections = [{ id: "wc", fromRoomId: "wa", toRoomId: "wb", fromWall: "east", toWall: "west", width: 3.5, waypoints }];
  return LevelFormat.normalizeLevel(level);
}

// Un desvío en U: pasa por los dos puntos, sale y entra perpendicular, y cada
// tramo es horizontal o vertical.
const detour = waypointLevel([{ x: -11, z: -8 }, { x: -9, z: -8 }]);
const detourPlan = LevelFormat.corridorPlan(detour.rooms[0], detour.rooms[1], detour.connections[0]);
assert.equal(detourPlan.points.length, 6, "El desvío en U describe seis puntos");
assert.deepEqual(detourPlan.points[0], { x: -13, y: 0 }, "El pasillo arranca en la puerta de origen");
assert.deepEqual(detourPlan.points.at(-1), { x: -7, y: 0 }, "El pasillo termina en la puerta de destino");
assert.equal(detourPlan.points[0].y, detourPlan.points[1].y, "Sale perpendicular a la pared este");
assert.equal(detourPlan.points.at(-2).y, detourPlan.points.at(-1).y, "Llega perpendicular a la pared oeste");
for (const waypoint of [{ x: -11, y: -8 }, { x: -9, y: -8 }]) {
  assert.ok(detourPlan.points.some((point) => point.x === waypoint.x && point.y === waypoint.y),
    `El recorrido debe pasar por (${waypoint.x}, ${waypoint.y})`);
}
for (let index = 0; index < detourPlan.points.length - 1; index += 1) {
  const [p, q] = [detourPlan.points[index], detourPlan.points[index + 1]];
  assert.ok(Math.abs(p.x - q.x) < 0.01 || Math.abs(p.y - q.y) < 0.01, "Cada tramo es horizontal o vertical");
}

// Un punto sobre la línea recta no agrega codos.
const alignedLevel = waypointLevel([{ x: -10, z: 0 }]);
const alignedPlan = LevelFormat.corridorPlan(alignedLevel.rooms[0], alignedLevel.rooms[1], alignedLevel.connections[0]);
assert.equal(alignedPlan.points.length, 2, "Un punto alineado deja el pasillo recto");

// Un punto enfrentado a la pared desliza la puerta hasta ese lugar: el pasillo
// sale derecho desde ahí en vez de acodarse desde el centro.
const slide = waypointLevel([{ x: -11, z: -4 }]);
const slidePlan = LevelFormat.corridorPlan(slide.rooms[0], slide.rooms[1], slide.connections[0]);
assert.deepEqual(slidePlan.points, [{ x: -13, y: -4 }, { x: -7, y: -4 }],
  "El punto corre las dos puertas y el pasillo queda recto");

// El tope: un punto casi en la esquina deja la puerta entera dentro de la pared.
const corner = waypointLevel([{ x: -11, z: -6.9 }]);
const cornerPlan = LevelFormat.corridorPlan(corner.rooms[0], corner.rooms[1], corner.connections[0]);
assert.ok(Math.abs(cornerPlan.points[0].y) <= 7 - 3.5 / 2 - 0.35 + 1e-9, "La puerta no se mete en la esquina");

// La puerta sigue al recorrido: con el punto vecino rodeando la sala, la
// conexión cambia de pared en vez de atravesar la sala hasta la puerta vieja.
const rerouted = waypointLevel([{ x: -6, z: 10 }]);
Object.assign(rerouted.connections[0],
  LevelFormat.chooseConnectionWalls(rerouted.rooms[0], rerouted.rooms[1], rerouted.connections[0].waypoints));
assert.equal(rerouted.connections[0].fromWall, "east", "El origen sigue mirando al punto por el este");
assert.equal(rerouted.connections[0].toWall, "south", "El destino pasa a entrar por el sur, que es lo que mira al punto");
const reroutedPlan = LevelFormat.corridorPlan(rerouted.rooms[0], rerouted.rooms[1], rerouted.connections[0]);
const reroutedEnd = reroutedPlan.points.at(-1);
const reroutedPrevious = reroutedPlan.points.at(-2);
assert.equal(reroutedEnd.y, 7, "La puerta queda sobre la pared sur");
assert.equal(reroutedPrevious.x, reroutedEnd.x, "El último tramo entra perpendicular a la pared sur");
assert.ok(reroutedPrevious.y > reroutedEnd.y, "El pasillo llega desde afuera de la sala, no por adentro");
assert.deepEqual(
  LevelFormat.chooseConnectionWalls(rerouted.rooms[0], rerouted.rooms[1], []),
  { fromWall: "east", toWall: "west" },
  "Sin puntos las paredes salen de la posición relativa de las salas, como siempre"
);
assert.match(script, /refreshConnectionWalls/, "El editor re-deriva las paredes al editar los puntos");

// Una ida y vuelta sobre la misma línea se descarta en lugar de degenerar el
// contorno del pasillo.
const spur = waypointLevel([{ x: -10, z: -9 }, { x: -10, z: 0 }]);
const spurPlan = LevelFormat.corridorPlan(spur.rooms[0], spur.rooms[1], spur.connections[0]);
assert.equal(spurPlan.points.length, 2, "El desvío que vuelve sobre sí mismo se colapsa");

// Sin puntos, el trazado de siempre: el desfase chico ensancha en vez de acodar.
const widenLevel = waypointLevel([]);
widenLevel.rooms[1].position.z = 2;
const widenPlan = LevelFormat.corridorPlan(widenLevel.rooms[0], widenLevel.rooms[1], widenLevel.connections[0]);
assert.equal(widenPlan.width, 5.5, "Sin puntos el desfase chico sigue ensanchando el pasillo");
assert.equal(widenPlan.points.length, 2, "Sin puntos el desfase chico sigue yendo recto");

// La normalización completa y limpia los puntos.
const rawWaypoints = waypointLevel([{ x: "no", z: 1 }, { x: 3, z: -2 }]);
assert.deepEqual(rawWaypoints.connections[0].waypoints, [{ x: 3, z: -2 }], "Un punto sin coordenadas numéricas se descarta");
const legacyNoWaypoints = LevelFormat.normalizeLevel({
  rooms: [
    Object.assign(LevelFormat.createRoom("small", 1), { id: "l1" }),
    Object.assign(LevelFormat.createRoom("small", 2), { id: "l2", position: { x: 20, z: 0 } })
  ],
  connections: [{ fromRoomId: "l1", toRoomId: "l2" }]
});
assert.equal(legacyNoWaypoints.connections.length, 1, "La conexión vieja sobrevive a la normalización");
assert.deepEqual(legacyNoWaypoints.connections[0].waypoints, [], "Una conexión sin waypoints los gana vacíos");
assert.ok(schema.$defs.connection.properties.waypoints, "El schema debe aceptar los puntos intermedios");

// La herramienta los edita sobre el plano.
assert.match(script, /corridor-waypoint/, "El plano debe dibujar los puntos intermedios");
assert.match(script, /function addWaypoint/, "Doble click sobre el pasillo agrega un punto");
assert.match(styles, /\.corridor-waypoint/, "Los puntos intermedios necesitan estilos");

// --- Texturas predeterminadas del nivel ---------------------------------------

assert.match(html, /id=["']level-texture-fields["']/, "El diálogo del nivel debe exponer las texturas predeterminadas");
assert.match(script, /data-texture-level/, "Los predeterminados del nivel usan el mismo selector visual");

// --- Roles -------------------------------------------------------------------

const roles = chainLevel();
LevelFormat.assignRole(roles.rooms, roles.rooms[1], "start");
assert.equal(roles.rooms.filter((room) => room.role === "start").length, 1, "Sólo puede haber una sala de inicio");
assert.equal(roles.rooms[1].role, "start");
assert.equal(roles.rooms[0].role, "transition", "La sala de inicio anterior pasa a tránsito");

const singleRoom = LevelFormat.normalizeLevel({
  rooms: [LevelFormat.createRoom("small", 1)],
  connections: []
});
assert.equal(singleRoom.rooms[0].role, "start", "Un nivel de una sala arranca en ella");
assert.equal(singleRoom.sky, LevelFormat.DEFAULT_SKY, "Sin cielo declarado se usa el de por defecto");
assert.equal(singleRoom.rooms.filter((room) => room.role === "exit").length, 0, "Sin salida separada no se inventa una");

// --- Migración de archivos anteriores ----------------------------------------

const legacy = LevelFormat.normalizeLevel({
  schemaVersion: 3,
  rooms: [
    { id: "one", name: "Entrada", type: "small", position: { x: 0, z: 0 }, size: { width: 14, depth: 14 }, entry: { wall: "south", offset: 0 }, blocks: { front: { enabled: true, targetCount: 6 } } },
    { id: "two", name: "Salida", type: "small", position: { x: 20, z: 0 }, size: { width: 14, depth: 14 }, entry: { wall: "west", offset: 0 }, blocks: {} }
  ],
  connections: [{ id: "c1", fromRoomId: "one", toRoomId: "two", fromWall: "east", toWall: "west" }]
});
assert.equal(legacy.schemaVersion, LevelFormat.SCHEMA_VERSION);
const legacyFront = legacy.rooms[0].waves[0].blocks.front;
assert.deepEqual(legacyFront.layers, [{ windows: { normal: 6 } }], "targetCount se migra a la primera capa");
assert.equal("targetCount" in legacyFront, false);
assert.equal(legacy.rooms[0].role, "start");
assert.equal(legacy.rooms[1].role, "exit");
assert.equal(legacy.rooms[0].facing, 90, "Sin orientación declarada, la sala de inicio mira hacia su pasillo");
assert.equal(legacy.connections[0].width, legacy.defaults.corridorWidth, "Los pasillos viejos toman el ancho por defecto");

// --- Archivos versionados ----------------------------------------------------

const TEXTURE_SLOTS = ["walls", "floor", "ceiling", "door", "block"];
for (const path of levelPaths) {
  const level = JSON.parse(fs.readFileSync(path, "utf8"));
  assert.equal(level.schemaVersion, LevelFormat.SCHEMA_VERSION, `${path} debe estar migrado`);
  assert.equal(level.rooms.filter((room) => room.role === "start").length, 1, `${path} necesita una sala de inicio`);
  assert.ok(level.rooms.filter((room) => room.role === "exit").length <= 1, `${path} no puede tener dos salidas`);
  assert.ok(level.defaults.corridorWidth >= 1.5, `${path} necesita un ancho de pasillo válido`);
  assert.ok(LevelFormat.SKY_LABELS[level.sky], `${path} declara un cielo desconocido: ${level.sky}`);
  const roomIds = new Set(level.rooms.map((room) => room.id));
  assert.equal(roomIds.size, level.rooms.length, `${path}: los IDs de sala deben ser únicos`);
  for (const room of level.rooms) {
    assert.ok(["north", "east", "south", "west"].includes(room.entry.wall));
    assert.ok(room.facing >= 0 && room.facing <= 359, `${path}: orientación inválida`);
    assert.ok(room.wallHeight === null || (room.wallHeight >= 2 && room.wallHeight <= 20));
    assert.ok(room.hasCeiling === null || typeof room.hasCeiling === "boolean");
    assert.deepEqual(Object.keys(room.textures).sort(), [...TEXTURE_SLOTS].sort());
    assert.ok(room.waves.length >= 1, `${path}: cada sala declara al menos una oleada`);
    assert.ok(room.waves.length <= LevelFormat.LIMITS.roomWaves.max, `${path}: demasiadas oleadas`);
    for (const wave of room.waves) {
      assert.deepEqual(Object.keys(wave.blocks).sort(), ["front", "left", "right"]);
      for (const block of Object.values(wave.blocks)) {
        assert.ok(Array.isArray(block.layers), `${path}: cada bloque declara sus capas`);
      }
    }
  }
  for (const connection of level.connections) {
    assert.ok(roomIds.has(connection.fromRoomId) && roomIds.has(connection.toRoomId), `${path}: pasillo huérfano`);
    assert.ok(connection.width >= 1.5 && connection.width <= 12, `${path}: ancho de pasillo inválido`);
    assert.ok(Array.isArray(connection.waypoints), `${path}: cada pasillo declara sus waypoints`);
  }
  // Los archivos versionados ya deben tener la entrada resuelta.
  const resolved = LevelFormat.resolveEntryWalls(structuredClone(level));
  for (const [index, room] of resolved.rooms.entries()) {
    assert.equal(room.entry.wall, level.rooms[index].entry.wall, `${path}: ${room.name} tiene una entrada desactualizada`);
  }
}

// --- Secuencia versionada ----------------------------------------------------

// El juego rechaza entradas con id despareja o archivo faltante, así que el
// archivo versionado tiene que estar siempre consistente.
const sequenceRaw = fs.readFileSync("level_designs/level-sequence.json", "utf8");
const sequenceFile = JSON.parse(sequenceRaw);
assert.ok(Array.isArray(sequenceFile.levels) && sequenceFile.levels.length > 0, "La secuencia debe listar niveles");
for (const entry of sequenceFile.levels) {
  assert.match(entry.path, /^res:\/\/level_designs\/levels\//, `La secuencia sólo apunta a levels/: ${entry.path}`);
  const local = entry.path.replace("res://", "");
  assert.ok(fs.existsSync(local), `La secuencia apunta a un archivo faltante: ${entry.path}`);
  const target = JSON.parse(fs.readFileSync(local, "utf8"));
  assert.equal(target.id, entry.id, `${entry.path}: el id de la secuencia no coincide con el del nivel`);
}

// --- Servidor del Workshop ---------------------------------------------------

// El editor abre y guarda niveles por la API del servidor, y mantiene la
// secuencia sin editar el JSON a mano; servido de otra forma, cae en los
// selectores de archivo de siempre.
assert.match(script, /\/api\/levels/, "El editor debe hablar con la API del Workshop");
assert.match(script, /\/api\/sequence/, "El editor debe poder mantener la secuencia");
assert.match(script, /\/api\/room-templates/, "El editor debe poder guardar plantillas de sala");

// --- Plantillas de sala ------------------------------------------------------

{
  const source = LevelFormat.createRoom("large", 1);
  source.name = "Arena";
  source.role = "exit";
  source.radio = { enabled: true, corner: "sw" };
  source.waves[0].blocks.front.enabled = true;
  source.waves[0].blocks.front.layers = [LevelFormat.blankLayer(6)];
  const template = LevelFormat.roomTemplateFrom(source, "Arena doble");
  assert.equal(template.name, "Arena doble");
  for (const key of ["id", "position", "role", "entry"]) {
    assert.ok(!(key in template.room), `La plantilla no guarda ${key}`);
  }
  assert.deepEqual(template.room.radio, { enabled: true, corner: "sw" }, "La plantilla conserva la radio");
  assert.equal(template.room.waves[0].blocks.front.layers[0].windows.normal, 6, "La plantilla conserva las oleadas");

  const inserted = LevelFormat.roomFromTemplate(template, 3);
  assert.notEqual(inserted.id, source.id, "La sala insertada recibe un id nuevo");
  assert.equal(inserted.role, "transition", "La sala insertada nunca trae rol");
  assert.equal(inserted.name, "Arena doble");
  assert.deepEqual(inserted.size, source.size);
  assert.equal(inserted.waves[0].blocks.front.layers[0].windows.normal, 6);

  const normalized = LevelFormat.normalizeRoomTemplates({ templates: [template, { name: "rota" }, null] });
  assert.equal(normalized.templates.length, 1, "Las entradas sin sala se descartan");
  assert.equal(normalized.schemaVersion, LevelFormat.ROOM_TEMPLATES_VERSION);
  const templatesFile = JSON.parse(fs.readFileSync("level_designs/room-templates.json", "utf8"));
  assert.equal(templatesFile.schemaVersion, LevelFormat.ROOM_TEMPLATES_VERSION, "room-templates.json debe estar en la versión actual");
  assert.ok(Array.isArray(templatesFile.templates));
}
for (const id of ["open-file", "open-sequence", "sequence-add-current", "open-dialog", "sequence-dialog", "save-as-file", "current-file"]) {
  assert.match(html, new RegExp(`id=["']${id}["']`), `Falta el control #${id}`);
}

// --- Window Workshop ---------------------------------------------------------

// La pestaña Ventanas edita los diseños custom: nombre, familia base y una
// tarjeta por variante con su preview.
for (const id of [
  "tab-levels", "tab-windows", "level-workspace", "window-workshop", "design-list", "new-design",
  "design-name", "design-key", "design-family", "design-family-hint", "variant-list", "add-variant",
  "delete-design", "save-window-designs"
]) {
  assert.match(html, new RegExp(`id=["']${id}["']`), `Falta el control #${id}`);
}
assert.match(html, /window-format\.js/, "El editor debe cargar el modelo de diseños de ventana");
assert.match(script, /window\.WindowFormat/, "El editor debe usar el modelo compartido de diseños");
assert.match(script, /\/api\/window-designs/, "El editor debe hablar con la API de diseños");
assert.match(script, /function windowTypeMeta/, "Los chips de capa deben tolerar tipos custom y diseños borrados");
assert.doesNotMatch(script, /WINDOW_TYPES\[type\]\./, "Ningún acceso directo a WINDOW_TYPES[type]: un tipo custom lo rompería");
assert.match(styles, /\.win-preview/, "El preview de la variante necesita estilos");
assert.match(styles, /\.workspace\[hidden\]/, "El display de .workspace pisa al [hidden] del navegador: sin esta regla las pestañas no cambian nada");
assert.match(styles, /\.family-chip\.missing/, "Un diseño borrado se marca en los chips");

// El formato de diseños: slugs congelados, familias conocidas y variantes
// siempre usables.
{
  assert.equal(WindowFormat.slugify("Estafa Bancaria Ñoña"), "estafa-bancaria-nona");
  assert.ok(WindowFormat.isCustomType("custom:estafa-bancaria"));
  assert.ok(!WindowFormat.isCustomType("custom:"), "Un custom sin slug no es válido");
  assert.ok(!WindowFormat.isCustomType("custom:-x"), "Un slug no puede arrancar con guión");
  assert.ok(!WindowFormat.isCustomType("normal"), "Una familia de fábrica no es un custom");

  const design = WindowFormat.blankDesign("  Estafa Bancaria  ");
  assert.equal(design.slug, "estafa-bancaria", "El slug nace del nombre");
  assert.equal(design.family, "normal");
  assert.equal(design.variants.length, 1, "Un diseño nuevo arranca con una variante lista");

  const normalized = WindowFormat.normalizeWindowDesigns({
    designs: [
      {
        id: "d1", slug: "estafa", name: "Estafa", family: "normal",
        variants: [
          { base: "no-existe", title: `  ${"x".repeat(80)}  `, message: "Su cuenta fue bloqueada.", size: { width: 9999, height: 10 }, futuro: "se conserva" },
          "rota"
        ]
      },
      { id: "d2", slug: "estafa", name: "Slug repetido", family: "normal", variants: [] },
      { id: "d3", slug: "x", name: "Familia desconocida", family: "nope", variants: [] },
      { id: "d4", slug: "SIN slug válido!!", name: "", family: "normal", variants: [] },
      null
    ]
  });
  assert.equal(normalized.schemaVersion, WindowFormat.WINDOW_DESIGNS_VERSION);
  assert.equal(normalized.designs.length, 1, "Las entradas rotas, sin nombre o repetidas se descartan");
  const variant = normalized.designs[0].variants[0];
  assert.equal(normalized.designs[0].variants.length, 1, "Una variante rota se descarta");
  assert.equal(variant.base, WindowFormat.defaultBase("normal"), "Una base inválida cae en la primera de la familia");
  assert.equal(variant.title.length, WindowFormat.TEXT_LIMITS.title, "El título se recorta");
  assert.deepEqual(variant.size, { width: WindowFormat.SIZE_LIMITS.width.max, height: WindowFormat.SIZE_LIMITS.height.min }, "El tamaño se acota");
  assert.equal(variant.futuro, "se conserva", "Los campos que este formato no conoce sobreviven");

  const empty = WindowFormat.normalizeWindowDesigns({
    designs: [{ id: "d5", slug: "vacio", name: "Vacío", family: "download", variants: [] }]
  });
  assert.equal(empty.designs[0].variants.length, 1, "Un diseño sin variantes recibe una en blanco");
  assert.equal(empty.designs[0].variants[0].base, "download");

  // La skin es un campo de la variante: vacía usa la de la base, y una
  // desconocida cae en vacía en vez de viajar al juego.
  assert.equal(WindowFormat.normalizeVariant({ skin: "retro" }, "normal").skin, "retro");
  assert.equal(WindowFormat.normalizeVariant({ skin: "vista" }, "normal").skin, "");
  assert.equal(WindowFormat.variantSkin({ base: "close", skin: "" }, "normal"), "xp", "Sin skin pedida, manda la nativa de la base");
  assert.equal(WindowFormat.variantSkin({ base: "download", skin: "xp" }, "download"), "xp", "La skin pedida pisa a la nativa");
  assert.equal(WindowFormat.BASES.download.download.skin, "retro", "La descarga es nativamente retro");
}

// El archivo versionado está normalizado y en la versión actual.
{
  const designsFile = JSON.parse(fs.readFileSync("level_designs/window-designs.json", "utf8"));
  assert.equal(designsFile.schemaVersion, WindowFormat.WINDOW_DESIGNS_VERSION, "window-designs.json debe estar en la versión actual");
  assert.ok(Array.isArray(designsFile.designs) && designsFile.designs.length > 0, "El catálogo arranca con al menos un diseño de ejemplo");
  assert.deepEqual(WindowFormat.normalizeWindowDesigns(structuredClone(designsFile)).designs, designsFile.designs,
    "window-designs.json debe estar normalizado");
  for (const entry of designsFile.designs) {
    assert.ok(WindowFormat.FAMILIES.includes(entry.family), `${entry.slug} usa una familia desconocida`);
  }
}

// Las capas conservan los tipos custom (antes normalizeLayer los borraba en
// silencio al guardar) y siguen descartando la basura.
{
  const layer = LevelFormat.normalizeLayer({ windows: { "custom:estafa-bancaria": 3, basura: 2, "custom:NoVale": 1, normal: 1 } });
  assert.deepEqual(layer.windows, { normal: 1, "custom:estafa-bancaria": 3 });
  const capped = LevelFormat.normalizeLayer({ windows: { normal: 60, "custom:extra": 60 } });
  assert.equal(LevelFormat.layerTotal(capped), LevelFormat.LIMITS.wave.max, "El tope por capa también cuenta a los custom");
  assert.ok(LevelFormat.isCustomType("custom:estafa-bancaria"));
  const windowsSchema = schema.$defs.layer.properties.windows.propertyNames;
  assert.ok(Array.isArray(windowsSchema.anyOf), "El schema acepta familias o customs");
  const schemaPattern = windowsSchema.anyOf.find((option) => option.pattern)?.pattern;
  assert.equal(schemaPattern, LevelFormat.CUSTOM_TYPE_PATTERN.source, "El schema y la tool aceptan el mismo patrón custom");
  assert.ok(new RegExp(schemaPattern).test(`custom:${WindowFormat.blankDesign("Prueba").slug}`),
    "Un slug generado por la tool siempre pasa el schema");
}

// Paridad con el juego: las familias y bases de la tool son exactamente las
// escenas de WindowCatalog, y los tamaños nativos son los de las escenas.
{
  const catalogSource = fs.readFileSync("scripts/windows/window_catalog.gd", "utf8");
  const baseStart = catalogSource.indexOf("const BASE_SCENES := {");
  const baseBlock = catalogSource.slice(baseStart, catalogSource.indexOf("\n}", baseStart));
  const runtimeFamilies = [...baseBlock.matchAll(/^\t"([a-z-]+)": \{/gm)].map((match) => match[1]);
  assert.deepEqual(runtimeFamilies.sort(), [...WindowFormat.FAMILIES].sort(),
    "BASES y BASE_SCENES deben declarar las mismas familias");
  const runtimeBases = [...baseBlock.matchAll(/"([a-z-]+)": preload\("(res:\/\/scenes\/windows\/[a-z_]+\.tscn)"\)/g)]
    .map((match) => ({ base: match[1], path: match[2] }));
  const toolBases = WindowFormat.FAMILIES.flatMap((family) => Object.keys(WindowFormat.BASES[family]));
  assert.deepEqual(runtimeBases.map((entry) => entry.base).sort(), toolBases.sort(),
    "Cada base de la tool tiene su escena en el catálogo del juego, y viceversa");
  for (const { base, path } of runtimeBases) {
    const family = WindowFormat.FAMILIES.find((id) => WindowFormat.BASES[id][base]);
    const sceneSource = fs.readFileSync(path.replace("res://", ""), "utf8");
    const viewportSize = sceneSource.match(/size = Vector2i\((\d+), (\d+)\)/);
    assert.ok(viewportSize, `${path} debe declarar el tamaño de su SubViewport`);
    assert.deepEqual(
      WindowFormat.BASES[family][base].size,
      { width: Number(viewportSize[1]), height: Number(viewportSize[2]) },
      `El tamaño nativo de ${base} en la tool debe ser el de su escena`
    );
    // La skin nativa que declara la tool es el theme real de la escena.
    const nativeSkin = sceneSource.includes("retro_theme.tres") ? "retro" : "xp";
    assert.equal(WindowFormat.BASES[family][base].skin, nativeSkin,
      `La skin nativa de ${base} en la tool debe ser la de su escena`);
  }
  // Las skins que ofrece la tool son las que el juego sabe aplicar.
  const skinSource = fs.readFileSync("scripts/windows/window_skin.gd", "utf8");
  const skinStart = skinSource.indexOf("const SKINS := {");
  const skinBlock = skinSource.slice(skinStart, skinSource.indexOf("\n}", skinStart));
  const runtimeSkins = [...skinBlock.matchAll(/^\t"([a-z-]+)": \{$/gm)].map((match) => match[1]);
  assert.deepEqual(runtimeSkins.sort(), Object.keys(WindowFormat.SKINS).sort(),
    "SKINS de la tool y de window_skin.gd deben coincidir");
  // Y el cargador del juego acepta los tipos custom que la tool escribe.
  assert.match(loaderSource, /begins_with\("custom:"\)/, "El loader debe aceptar los tipos custom");
  // El bloque spawnea por plan: escena + configuración de variante por ventana.
  const blockSource = fs.readFileSync("scripts/targets/target_block_3d.gd", "utf8");
  assert.match(blockSource, /spawn_plan_for/, "El bloque debe pedir el plan de spawn con variantes");
  const volumeSource = fs.readFileSync("scripts/targets/target_spawn_volume_3d.gd", "utf8");
  assert.match(volumeSource, /scripted_configs/, "El volumen debe aplicar la configuración por objetivo");
  assert.match(fs.readFileSync("scripts/windows/window_panel_3d.gd", "utf8"), /variant_config/,
    "La ventana debe aplicar su variante al nacer");
}

const { createLevelServer } = require("../tools/level-editor/serve.js");
const server = createLevelServer();
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const base = `http://127.0.0.1:${server.address().port}`;
try {
  const listed = (await (await fetch(`${base}/api/levels`)).json()).levels;
  const firstEntry = listed.find((item) => item.file === "nivel-01.json");
  assert.ok(firstEntry, "La API debe listar nivel-01.json");
  const levelOne = await (await fetch(`${base}/api/levels/nivel-01.json`)).json();
  assert.equal(levelOne.id, firstEntry.id, "El listado y el archivo deben coincidir");

  const evil = await fetch(`${base}/api/levels/..%2F..%2Fpwned.json`, { method: "PUT", body: "{}" });
  assert.equal(evil.status, 400, "La API debe rechazar nombres con rutas");

  // Guardar y releer un nivel de prueba, y limpiarlo del disco.
  const tmpName = "smoke-test-workshop.json";
  const putLevel = await fetch(`${base}/api/levels/${tmpName}`, { method: "PUT", body: JSON.stringify(levelOne) });
  assert.equal(putLevel.status, 200, "La API debe aceptar el guardado");
  const reread = await (await fetch(`${base}/api/levels/${tmpName}`)).json();
  assert.equal(reread.id, levelOne.id, "El nivel guardado debe releerse igual");
  fs.rmSync(`level_designs/levels/${tmpName}`);

  // La secuencia va y vuelve sin cambiar de contenido.
  const sequenceOverWire = await (await fetch(`${base}/api/sequence`)).json();
  assert.deepEqual(sequenceOverWire, sequenceFile, "GET /api/sequence devuelve el archivo versionado");
  const putSequence = await fetch(`${base}/api/sequence`, { method: "PUT", body: JSON.stringify(sequenceOverWire) });
  assert.equal(putSequence.status, 200);
  assert.deepEqual(JSON.parse(fs.readFileSync("level_designs/level-sequence.json", "utf8")), sequenceFile,
    "El PUT de la secuencia conserva el contenido");
  fs.writeFileSync("level_designs/level-sequence.json", sequenceRaw);

  // Las plantillas van y vuelven, y el servidor rechaza entradas rotas.
  const templatesRaw = fs.readFileSync("level_designs/room-templates.json", "utf8");
  const templatesOverWire = await (await fetch(`${base}/api/room-templates`)).json();
  assert.deepEqual(templatesOverWire, JSON.parse(templatesRaw), "GET /api/room-templates devuelve el archivo versionado");
  const putTemplates = await fetch(`${base}/api/room-templates`, { method: "PUT", body: JSON.stringify(templatesOverWire) });
  assert.equal(putTemplates.status, 200);
  fs.writeFileSync("level_designs/room-templates.json", templatesRaw);
  const badTemplates = await fetch(`${base}/api/room-templates`, {
    method: "PUT",
    body: JSON.stringify({ schemaVersion: 1, templates: [{ id: "x", name: "" }] })
  });
  assert.equal(badTemplates.status, 400, "Las plantillas necesitan id, nombre y sala");

  // Los diseños de ventana van y vuelven, y el servidor rechaza entradas rotas.
  const designsRaw = fs.readFileSync("level_designs/window-designs.json", "utf8");
  const designsOverWire = await (await fetch(`${base}/api/window-designs`)).json();
  assert.deepEqual(designsOverWire, JSON.parse(designsRaw), "GET /api/window-designs devuelve el archivo versionado");
  const putDesigns = await fetch(`${base}/api/window-designs`, { method: "PUT", body: JSON.stringify(designsOverWire) });
  assert.equal(putDesigns.status, 200);
  assert.deepEqual(JSON.parse(fs.readFileSync("level_designs/window-designs.json", "utf8")), JSON.parse(designsRaw),
    "El PUT de los diseños conserva el contenido");
  fs.writeFileSync("level_designs/window-designs.json", designsRaw);
  const badDesigns = await fetch(`${base}/api/window-designs`, {
    method: "PUT",
    body: JSON.stringify({ schemaVersion: 1, designs: [{ id: "x", slug: "NO VALE", name: "Rota", family: "normal", variants: [{}] }] })
  });
  assert.equal(badDesigns.status, 400, "Los diseños necesitan slug válido y familia conocida");

  const badSequence = await fetch(`${base}/api/sequence`, {
    method: "PUT",
    body: JSON.stringify({ schemaVersion: 1, levels: [{ id: "x", path: "res://otro/lado.json" }] })
  });
  assert.equal(badSequence.status, 400, "La secuencia sólo acepta niveles de level_designs/levels/");

  const page = await (await fetch(`${base}/tools/level-editor/`)).text();
  assert.match(page, /Level Workshop/, "El servidor debe servir el editor");
  const outside = await fetch(`${base}/..%2F..%2Fsecret.txt`);
  assert.equal(outside.status, 404, "El servidor no sirve nada fuera del repositorio");
} finally {
  server.close();
}

console.log("LEVEL EDITOR SMOKE TEST PASSED");
