// Migra archivos de nivel versionados al formato actual, reusando la misma
// normalizacion que aplica el editor al importar.
const fs = require("node:fs");
const path = require("node:path");
const LevelFormat = require("./level-format.js");

const paths = process.argv.slice(2);
if (!paths.length) {
  console.error(`Uso: node ${path.basename(__filename)} <nivel.json> [...]`);
  process.exit(1);
}

for (const target of paths) {
  const level = LevelFormat.normalizeLevel(JSON.parse(fs.readFileSync(target, "utf8")));
  fs.writeFileSync(target, `${JSON.stringify(level, null, 2)}\n`);
  const start = level.rooms.find((room) => room.role === "start");
  const exit = level.rooms.find((room) => room.role === "exit");
  console.log(`Migrado a v${LevelFormat.SCHEMA_VERSION}: ${target} (inicio: ${start?.name ?? "-"}, salida: ${exit?.name ?? "-"})`);
}
