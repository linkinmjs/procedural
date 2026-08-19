import assert from "node:assert/strict";
import fs from "node:fs";

const html = fs.readFileSync("tools/level-editor/index.html", "utf8");
const script = fs.readFileSync("tools/level-editor/app.js", "utf8");
const schema = JSON.parse(fs.readFileSync("level_designs/schema.json", "utf8"));
const example = JSON.parse(fs.readFileSync("level_designs/three-room-example.json", "utf8"));
const levelOne = JSON.parse(fs.readFileSync("level_designs/levels/nivel-1.json", "utf8"));

for (const id of [
  "level-canvas",
  "rooms-layer",
  "connections-layer",
  "room-inspector",
  "block-editors",
  "level-time-minutes",
  "level-time-seconds",
  "import-file",
  "download-file"
]) {
  assert.match(html, new RegExp(`id=["']${id}["']`), `Falta el control #${id}`);
}

assert.equal(schema.properties.schemaVersion.const, 3);
assert.equal(example.schemaVersion, 3);
assert.equal(example.timeLimitSeconds, 90);
assert.equal(schema.properties.timeLimitSeconds.minimum, 1);
assert.equal(schema.properties.timeLimitSeconds.maximum, 3600);
assert.equal(levelOne.timeLimitSeconds, 90);
assert.equal(levelOne.schemaVersion, 3);
assert.equal(example.rooms.length, 3);
assert.equal(example.connections.length, 2);

const roomIds = new Set(example.rooms.map((room) => room.id));
assert.equal(roomIds.size, example.rooms.length, "Los IDs de sala deben ser únicos");
for (const room of example.rooms) {
  assert.ok(["small", "large", "corridor", "custom"].includes(room.type));
  assert.ok(["north", "east", "south", "west"].includes(room.entry.wall));
  assert.deepEqual(Object.keys(room.blocks).sort(), ["front", "left", "right"]);
  for (const block of Object.values(room.blocks)) {
    assert.equal(typeof block.movementSpeed, "number");
    assert.match(block.color, /^#[0-9a-f]{6}$/i);
    assert.ok(Array.isArray(block.waves));
    assert.equal("targetCount" in block, false);
  }
}
for (const connection of example.connections) {
  assert.ok(roomIds.has(connection.fromRoomId), "La conexión debe partir de una sala existente");
  assert.ok(roomIds.has(connection.toRoomId), "La conexión debe llegar a una sala existente");
}

assert.match(script, /localStorage\.setItem/, "El editor debe guardar el borrador automáticamente");
assert.match(script, /showSaveFilePicker/, "El editor debe poder guardar un archivo JSON");
assert.match(script, /createSVGPoint/, "El editor debe soportar arrastre sobre el plano SVG");
assert.match(script, /refreshConnectionsForRoom\(dragState\.roomId\)/, "Mover una sala debe actualizar las paredes de sus conexiones");
assert.match(script, /data-add-wave/, "El editor debe permitir agregar oleadas por bloque");
assert.deepEqual(example.rooms[1].blocks.front.waves, [3, 6]);
assert.equal(example.rooms[1].blocks.front.movementSpeed, 0.8);

console.log("LEVEL EDITOR SMOKE TEST PASSED");
