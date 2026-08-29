// Escribe el exclude_filter del preset Web en export_presets.cfg a partir de lo
// que la campaña realmente usa.
//
// El catalogo de texturas ofrece 345 texturas al Level Workshop, pero cada
// nivel usa unas diez. Como TextureCatalog las carga por codigo, el export
// ("all_resources") las empaqueta todas: ~30 MB de descarga que el jugador
// nunca ve. Este script recorre la secuencia de niveles, junta los ids que
// declaran (los cinco slots, del nivel y de cada sala), y excluye del export
// el complemento del catalogo, mas las carpetas que no son del juego (tests,
// docs). El Workshop sigue viendo el catalogo entero: si un nivel adopta una
// textura nueva, tests/export_filter_parity_smoke_test.gd avisa que hay que
// volver a correr esto.
//
// Uso (desde la raiz del proyecto): node tools/generate_export_filters.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PRESETS = path.join(ROOT, "export_presets.cfg");
const SEQUENCE = path.join(ROOT, "level_designs", "level-sequence.json");
const CATALOG = path.join(ROOT, "level_designs", "texture-catalog.json");
// Lo que no es del juego. Los patrones se comparan contra la ruta sin "res://".
export const FIXED_EXCLUDES = ["tests/*", "docs/*"];
const SLOTS = ["walls", "floor", "ceiling", "door", "block"];

const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const resToRelative = (resPath) => resPath.replace(/^res:\/\//, "");

/** Ids de textura que la campaña declara, en cualquier slot de cualquier sala. */
export function usedTextureIds(sequence, readLevel) {
  const used = new Set();
  for (const entry of sequence.levels) {
    const level = readLevel(entry.path);
    const collect = (textures) => {
      for (const slot of SLOTS) {
        const id = textures?.[slot];
        if (typeof id === "string" && id) used.add(id);
      }
    };
    collect(level.defaults?.textures);
    for (const room of level.rooms ?? []) collect(room.textures);
  }
  return used;
}

/** Rutas (sin res://) de las texturas del catalogo que ningun nivel usa. */
export function unusedTexturePaths(catalog, used) {
  return catalog.textures
    .filter((texture) => !used.has(texture.id))
    .map((texture) => resToRelative(texture.path))
    .sort();
}

export function buildExcludeFilter(catalog, used) {
  return [...FIXED_EXCLUDES, ...unusedTexturePaths(catalog, used)].join(", ");
}

function main() {
  const sequence = readJson(SEQUENCE);
  const catalog = readJson(CATALOG);
  const used = usedTextureIds(sequence, (resPath) => readJson(path.join(ROOT, resToRelative(resPath))));
  const filter = buildExcludeFilter(catalog, used);
  const source = fs.readFileSync(PRESETS, "utf8");
  const line = /^exclude_filter=".*"$/m;
  if (!line.test(source)) throw new Error("export_presets.cfg no tiene una linea exclude_filter en el preset Web");
  fs.writeFileSync(PRESETS, source.replace(line, `exclude_filter=${JSON.stringify(filter)}`));
  const excluded = catalog.textures.length - used.size;
  console.log(`texturas usadas por la campaña: ${used.size} de ${catalog.textures.length}; excluidas del export: ${excluded}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
