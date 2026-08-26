// Servidor local del Level Workshop. Sirve el repositorio como archivos
// estaticos (igual que `python -m http.server`) y ademas expone la API que el
// editor usa para abrir y guardar niveles directamente en
// level_designs/levels/ y mantener level-sequence.json, sin selectores de
// archivo ni edicion a mano.
//
// Uso, desde la raiz del repositorio:
//   node tools/level-editor/serve.js
//
// Sin dependencias: solo modulos de Node.

const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const WindowFormat = require(path.join(__dirname, "window-format.js"));

const REPO_ROOT = path.resolve(__dirname, "..", "..");
const LEVELS_DIR = path.join(REPO_ROOT, "level_designs", "levels");
const SEQUENCE_PATH = path.join(REPO_ROOT, "level_designs", "level-sequence.json");
// Plantillas de sala compartidas entre niveles, versionadas junto a ellos.
const ROOM_TEMPLATES_PATH = path.join(REPO_ROOT, "level_designs", "room-templates.json");
// Diseños de ventana del Window Workshop, que el juego lee al spawnear.
const WINDOW_DESIGNS_PATH = path.join(REPO_ROOT, "level_designs", "window-designs.json");
// Un nombre de nivel es un archivo suelto: nada de rutas, ni ocultos.
const LEVEL_FILE = /^[A-Za-z0-9][A-Za-z0-9._ -]*\.json$/;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ttf": "font/ttf",
  ".ico": "image/x-icon"
};

function sendJson(response, status, payload) {
  const body = `${JSON.stringify(payload, null, 2)}\n`;
  response.writeHead(status, { "Content-Type": MIME[".json"], "Cache-Control": "no-store" });
  response.end(body);
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on("data", (chunk) => {
      size += chunk.length;
      if (size > 4 * 1024 * 1024) {
        reject(new Error("Cuerpo demasiado grande"));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    request.on("error", reject);
  });
}

/** Reescribe el JSON normalizado: dos espacios y salto final, como el resto del repo. */
function writeJsonFile(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function listLevels() {
  const files = fs.existsSync(LEVELS_DIR)
    ? fs.readdirSync(LEVELS_DIR).filter((file) => LEVEL_FILE.test(file)).sort()
    : [];
  return files.map((file) => {
    try {
      const parsed = JSON.parse(fs.readFileSync(path.join(LEVELS_DIR, file), "utf8"));
      return { file, id: String(parsed.id ?? ""), name: String(parsed.name ?? file), rooms: Array.isArray(parsed.rooms) ? parsed.rooms.length : 0 };
    } catch (error) {
      return { file, id: "", name: file, error: "JSON inválido" };
    }
  });
}

function readSequence() {
  if (!fs.existsSync(SEQUENCE_PATH)) return { schemaVersion: 1, levels: [] };
  return JSON.parse(fs.readFileSync(SEQUENCE_PATH, "utf8"));
}

function readRoomTemplates() {
  if (!fs.existsSync(ROOM_TEMPLATES_PATH)) return { schemaVersion: 1, templates: [] };
  return JSON.parse(fs.readFileSync(ROOM_TEMPLATES_PATH, "utf8"));
}

function validRoomTemplates(value) {
  return value && typeof value === "object" && Array.isArray(value.templates) &&
    value.templates.every((entry) => entry && typeof entry === "object" &&
      typeof entry.id === "string" && entry.id.length > 0 &&
      typeof entry.name === "string" && entry.name.length > 0 &&
      entry.room && typeof entry.room === "object" && !Array.isArray(entry.room));
}

function readWindowDesigns() {
  if (!fs.existsSync(WINDOW_DESIGNS_PATH)) return { schemaVersion: WindowFormat.WINDOW_DESIGNS_VERSION, designs: [] };
  return JSON.parse(fs.readFileSync(WINDOW_DESIGNS_PATH, "utf8"));
}

function validWindowDesigns(value) {
  return value && typeof value === "object" && Array.isArray(value.designs) &&
    value.designs.every((entry) => entry && typeof entry === "object" &&
      typeof entry.id === "string" && entry.id.length > 0 &&
      typeof entry.name === "string" && entry.name.length > 0 &&
      WindowFormat.SLUG_PATTERN.test(entry.slug) &&
      WindowFormat.FAMILIES.includes(entry.family) &&
      Array.isArray(entry.variants) && entry.variants.length > 0 &&
      entry.variants.every((variant) => variant && typeof variant === "object" && !Array.isArray(variant)));
}

function validSequence(value) {
  return value && typeof value === "object" && Array.isArray(value.levels) &&
    value.levels.every((entry) => entry && typeof entry === "object" &&
      typeof entry.id === "string" && entry.id.length > 0 &&
      typeof entry.path === "string" && entry.path.startsWith("res://level_designs/levels/"));
}

async function handleApi(request, response, pathname) {
  if (pathname === "/api/levels" && request.method === "GET") {
    sendJson(response, 200, { levels: listLevels() });
    return true;
  }
  const levelMatch = pathname.match(/^\/api\/levels\/([^/]+)$/);
  if (levelMatch) {
    const file = decodeURIComponent(levelMatch[1]);
    if (!LEVEL_FILE.test(file)) {
      sendJson(response, 400, { error: "Nombre de archivo inválido" });
      return true;
    }
    const filePath = path.join(LEVELS_DIR, file);
    if (request.method === "GET") {
      if (!fs.existsSync(filePath)) {
        sendJson(response, 404, { error: "No existe" });
        return true;
      }
      response.writeHead(200, { "Content-Type": MIME[".json"], "Cache-Control": "no-store" });
      response.end(fs.readFileSync(filePath));
      return true;
    }
    if (request.method === "PUT") {
      let parsed;
      try {
        parsed = JSON.parse(await readBody(request));
      } catch (error) {
        sendJson(response, 400, { error: `JSON inválido: ${error.message}` });
        return true;
      }
      writeJsonFile(filePath, parsed);
      sendJson(response, 200, { saved: file });
      return true;
    }
  }
  if (pathname === "/api/sequence") {
    if (request.method === "GET") {
      try {
        sendJson(response, 200, readSequence());
      } catch (error) {
        sendJson(response, 500, { error: `level-sequence.json inválido: ${error.message}` });
      }
      return true;
    }
    if (request.method === "PUT") {
      let parsed;
      try {
        parsed = JSON.parse(await readBody(request));
      } catch (error) {
        sendJson(response, 400, { error: `JSON inválido: ${error.message}` });
        return true;
      }
      if (!validSequence(parsed)) {
        sendJson(response, 400, { error: "La secuencia necesita entradas {id, path} dentro de level_designs/levels/" });
        return true;
      }
      writeJsonFile(SEQUENCE_PATH, parsed);
      sendJson(response, 200, { saved: "level-sequence.json" });
      return true;
    }
  }
  if (pathname === "/api/room-templates") {
    if (request.method === "GET") {
      try {
        sendJson(response, 200, readRoomTemplates());
      } catch (error) {
        sendJson(response, 500, { error: `room-templates.json inválido: ${error.message}` });
      }
      return true;
    }
    if (request.method === "PUT") {
      let parsed;
      try {
        parsed = JSON.parse(await readBody(request));
      } catch (error) {
        sendJson(response, 400, { error: `JSON inválido: ${error.message}` });
        return true;
      }
      if (!validRoomTemplates(parsed)) {
        sendJson(response, 400, { error: "Las plantillas necesitan entradas {id, name, room}" });
        return true;
      }
      writeJsonFile(ROOM_TEMPLATES_PATH, parsed);
      sendJson(response, 200, { saved: "room-templates.json" });
      return true;
    }
  }
  if (pathname === "/api/window-designs") {
    if (request.method === "GET") {
      try {
        sendJson(response, 200, readWindowDesigns());
      } catch (error) {
        sendJson(response, 500, { error: `window-designs.json inválido: ${error.message}` });
      }
      return true;
    }
    if (request.method === "PUT") {
      let parsed;
      try {
        parsed = JSON.parse(await readBody(request));
      } catch (error) {
        sendJson(response, 400, { error: `JSON inválido: ${error.message}` });
        return true;
      }
      if (!validWindowDesigns(parsed)) {
        sendJson(response, 400, { error: "Los diseños necesitan entradas {id, slug, name, family, variants} con familia conocida" });
        return true;
      }
      writeJsonFile(WINDOW_DESIGNS_PATH, parsed);
      sendJson(response, 200, { saved: "window-designs.json" });
      return true;
    }
  }
  return false;
}

function serveStatic(request, response, pathname) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    sendJson(response, 405, { error: "Método no permitido" });
    return;
  }
  let relative = decodeURIComponent(pathname);
  if (relative.endsWith("/")) relative += "index.html";
  const filePath = path.resolve(REPO_ROOT, `.${relative}`);
  // Contencion: nada fuera del repositorio, pase lo que pase con ../ o %2e.
  if (filePath !== REPO_ROOT && !filePath.startsWith(REPO_ROOT + path.sep)) {
    sendJson(response, 404, { error: "Fuera del repositorio" });
    return;
  }
  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    sendJson(response, 404, { error: "No existe" });
    return;
  }
  const type = MIME[path.extname(filePath).toLowerCase()] || "application/octet-stream";
  response.writeHead(200, { "Content-Type": type, "Cache-Control": "no-store" });
  if (request.method === "HEAD") {
    response.end();
    return;
  }
  fs.createReadStream(filePath).pipe(response);
}

function createLevelServer() {
  return http.createServer(async (request, response) => {
    const pathname = new URL(request.url, "http://localhost").pathname;
    try {
      if (await handleApi(request, response, pathname)) return;
      serveStatic(request, response, pathname);
    } catch (error) {
      sendJson(response, 500, { error: error.message });
    }
  });
}

module.exports = { createLevelServer };

if (require.main === module) {
  const port = Number(process.env.PORT || 8080);
  const server = createLevelServer();
  server.on("error", (error) => {
    if (error.code === "EADDRINUSE") {
      // Doble click repetido en workshop.cmd: el servidor anterior sigue vivo
      // y alcanza con usar esa instancia.
      console.log(`El puerto ${port} ya esta en uso: el Workshop ya corre en http://localhost:${port}/tools/level-editor/`);
      process.exit(0);
    }
    throw error;
  });
  server.listen(port, "127.0.0.1", () => {
    console.log(`Level Workshop: http://localhost:${port}/tools/level-editor/`);
    console.log(`Niveles: ${LEVELS_DIR}`);
    console.log("Cerrar esta ventana (o Ctrl+C) detiene el servidor.");
  });
}
