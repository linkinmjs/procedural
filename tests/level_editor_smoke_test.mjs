import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const LevelFormat = require("../tools/level-editor/level-format.js");

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
  "room-ammo-enabled", "room-ammo-amount", "facing-compass", "entry-summary",
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
for (const key of ["role", "facing", "wallHeight", "hasCeiling", "ammoReward", "textures"]) {
  assert.ok(schema.$defs.room.required.includes(key), `La sala debe declarar ${key}`);
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
assert.match(script, /fillTextureSelect/, "El editor debe poblar los desplegables de textura");

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
  }
  // Los archivos versionados ya deben tener la entrada resuelta.
  const resolved = LevelFormat.resolveEntryWalls(structuredClone(level));
  for (const [index, room] of resolved.rooms.entries()) {
    assert.equal(room.entry.wall, level.rooms[index].entry.wall, `${path}: ${room.name} tiene una entrada desactualizada`);
  }
}

console.log("LEVEL EDITOR SMOKE TEST PASSED");
