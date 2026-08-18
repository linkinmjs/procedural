import fs from "node:fs";

const paths = process.argv.slice(2);
if (!paths.length) {
  console.error("Uso: node migrate-level-v3.mjs <nivel.json> [...]");
  process.exit(1);
}

for (const path of paths) {
  const level = JSON.parse(fs.readFileSync(path, "utf8"));
  level.schemaVersion = 3;
  for (const room of level.rooms || []) {
    for (const block of Object.values(room.blocks || {})) {
      const legacyCount = Math.max(0, Math.round(Number(block.targetCount) || 0));
      block.movementSpeed = Math.max(0.05, Math.min(5, Number(block.movementSpeed) || 0.65));
      block.color = /^#[0-9a-f]{6}$/i.test(block.color) ? block.color : "#2ed5c5";
      block.waves = Array.isArray(block.waves)
        ? block.waves.map((count) => Math.max(1, Math.min(64, Math.round(Number(count) || 1))))
        : (legacyCount > 0 ? [legacyCount] : []);
      delete block.targetCount;
    }
  }
  fs.writeFileSync(path, `${JSON.stringify(level, null, 2)}\n`);
  console.log(`Migrado: ${path}`);
}
