(() => {
  "use strict";

  const {
    ROOM_PRESETS, ROLE_LABELS, SKY_LABELS, SLOT_LABELS, WINDOW_TYPES, TEXTURE_SLOTS, WALL_LABELS,
    RELATIVE_WALLS, LIMITS, clamp, clampInt, newId, createEmptyLevel, createRoom, createConnection,
    chooseConnectionWalls, degreesToWall, assignRole, normalizeRoles, resolveEntryWalls, normalizeLevel,
    corridorPlan, corridorOutline, doorPoint, blankLayer, blankRoomWave, layerTotal,
    roomTemplateFrom, roomFromTemplate, normalizeRoomTemplates, isCustomType
  } = window.LevelFormat;

  const {
    BASES, FAMILIES, SKINS, SIZE_LIMITS, slugify, customTypeKey, baseMeta, variantSize,
    variantSkin, blankVariant, duplicateVariant, blankDesign, normalizeVariant, normalizeWindowDesigns
  } = window.WindowFormat;

  const STORAGE_KEY = "procedural-map.level-workshop.draft.v3";
  const FILE_KEY = "procedural-map.level-workshop.file.v1";
  // Respaldo de las plantillas cuando no hay servidor del Workshop.
  const TEMPLATES_KEY = "procedural-map.level-workshop.room-templates.v1";
  // Respaldo de los diseños de ventana cuando no hay servidor del Workshop.
  const WINDOW_DESIGNS_KEY = "procedural-map.level-workshop.window-designs.v1";
  // Tono con el que los diseños custom se distinguen de las familias de fábrica.
  const CUSTOM_TONE = "#c9a6ff";
  const SLOT_SHORT = { left: "IZQ", front: "FRENTE", right: "DER" };
  const WALL_NAMES = { north: "norte", east: "este", south: "sur", west: "oeste" };

  const $ = (selector) => document.querySelector(selector);
  const svg = $("#level-canvas");
  const roomsLayer = $("#rooms-layer");
  const corridorsLayer = $("#corridors-layer");
  const levelDialog = $("#level-dialog");
  const roomDialog = $("#room-dialog");

  let level = loadDraft() || createEmptyLevel();
  let selectedRoomId = level.rooms[0]?.id || null;
  let dialogRoomId = null;
  // Que oleada de la sala se esta editando. Los tres slots del dialogo son los
  // de esta oleada, no los de la sala entera.
  let dialogWaveIndex = 0;
  let connectSourceId = null;
  let dragState = null;
  let waypointDrag = null;
  // Doble click sobre un pasillo, detectado a mano: el primer click arranca el
  // paneo con setPointerCapture, y con la captura activa el dblclick nativo se
  // retargetea al svg, ya sin el pasillo como target.
  let corridorClick = null;
  let panState = null;
  let view = { x: -35, y: -28, width: 70, height: 56 };
  let textureCatalog = [];
  let texturePacks = [];
  let saveHandle = null;
  let toastTimer = null;
  let statusTimer = null;
  // Con el servidor del Workshop (tools/level-editor/serve.js) el editor abre y
  // guarda directamente en level_designs/levels/ y mantiene la secuencia.
  // Servido de otra forma, todo eso se esconde y quedan los selectores de antes.
  let workshopApi = false;
  let currentFile = localStorage.getItem(FILE_KEY) || "";
  let dirty = false;
  // Salas guardadas para reutilizar. Con el servidor viven en
  // level_designs/room-templates.json; sin el, en localStorage.
  let roomTemplates = { schemaVersion: 1, templates: [] };
  // Diseños de ventana del Window Workshop. Con el servidor viven en
  // level_designs/window-designs.json, que es lo que lee el juego.
  let windowDesigns = { schemaVersion: 1, designs: [] };
  let selectedDesignId = null;
  let designsDirty = false;

  function exampleLevel() {
    const result = createEmptyLevel();
    result.id = "f4-three-room-example";
    result.name = "Circuito de tres salas";
    result.description = "Ejemplo editable con sala pequeña, sala grande y pasillo.";
    result.startingAmmo = { magazine: 17, reserve: 34 };
    const configure = (block, layers, movement = "static", color = "#2ed5c5", movementSpeed = 0.65) =>
      Object.assign(block, { enabled: true, layers, movement, color, movementSpeed });
    const a = createRoom("small", 1);
    Object.assign(a, { id: "room-entry", name: "Entrada", role: "start", facing: 90, position: { x: -18, z: 8 } });
    configure(a.waves[0].blocks.front, [blankLayer(4)]);
    const b = createRoom("large", 2);
    Object.assign(b, { id: "room-arena", name: "Arena", position: { x: 4, z: 5 }, wallHeight: 9, hasCeiling: false });
    b.ammoReward = { enabled: true, amount: 40, color: "#f4bc59" };
    // La arena se pelea en dos oleadas: primero de frente, despues por los
    // costados. Es el ejemplo de los dos niveles de agrupacion en un solo lugar.
    configure(b.waves[0].blocks.front, [blankLayer(3), { windows: { normal: 4, firewall: 2 } }], "opposite", "#f4bc59", 0.8);
    b.waves.push(blankRoomWave());
    configure(b.waves[1].blocks.left, [blankLayer(5)], "static", "#35d4c7");
    configure(b.waves[1].blocks.right, [blankLayer(5)], "static", "#35d4c7");
    const c = createRoom("corridor", 3);
    Object.assign(c, { id: "room-corridor", name: "Pasillo de salida", role: "exit", position: { x: 22, z: -11 }, wallHeight: 4 });
    configure(c.waves[0].blocks.left, [blankLayer(4)], "opposite");
    configure(c.waves[0].blocks.right, [blankLayer(4)], "opposite");
    result.rooms = [a, b, c];
    result.connections = [createConnection(a, b, 3.5), createConnection(b, c, 2.5)];
    return normalizeLevel(result);
  }

  function loadDraft() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      return raw ? normalizeLevel(JSON.parse(raw)) : null;
    } catch (error) {
      console.warn("No se pudo recuperar el borrador", error);
      return null;
    }
  }

  // El catálogo es opcional: si el editor se abre con file:// el fetch falla,
  // los desplegables quedan sólo con lo que el nivel ya tenía y el aviso lo
  // explica. Sirviendo la carpeta del repo se llenan solos.
  async function loadTextureCatalog() {
    let packs = [];
    try {
      const response = await fetch("../../level_designs/texture-catalog.json", { cache: "no-store" });
      if (!response.ok) throw new Error(String(response.status));
      const catalog = await response.json();
      textureCatalog = Array.isArray(catalog.textures) ? catalog.textures : [];
      packs = Array.isArray(catalog.packs) ? catalog.packs : [];
    } catch (error) {
      textureCatalog = [];
    }
    texturePacks = packs;
    $("#texture-catalog-status").textContent = textureCatalog.length
      ? ""
      : "Sin catálogo: abrí el editor con workshop.cmd (o un servidor local) para elegir texturas.";
    if (roomDialog.open) renderRoomDialog();
  }

  // --- Selector visual de texturas --------------------------------------------
  // Con 345 texturas un desplegable de nombres no dice nada: cada superficie
  // muestra su miniatura y abre una grilla con las imágenes reales, que el
  // servidor sirve desde assets/textures/packs/.

  const textureUrl = (entry) => String(entry?.path ?? "").replace("res://", "/");
  const textureById = (id) => textureCatalog.find((entry) => String(entry?.id) === id) || null;
  let pickerSlot = null;
  // El mismo selector viste una sala o los predeterminados del nivel.
  let pickerScope = "room";
  const pickerTextures = () => pickerScope === "level" ? level.defaults.textures : dialogRoom()?.textures;

  /** El botón de una superficie: miniatura y nombre de la textura elegida. */
  function renderTextureField(button, current) {
    const entry = textureById(current);
    const thumb = button.querySelector("img");
    thumb.hidden = !entry;
    if (entry) thumb.src = textureUrl(entry);
    const label = !current ? "Sin textura" : entry ? String(entry.label) : `${current} (fuera del catálogo)`;
    button.querySelector(".texture-field-name").textContent = label;
    button.title = `${label} — click para cambiar`;
  }

  function openTexturePicker(slot, scope = "room") {
    pickerSlot = slot;
    pickerScope = scope;
    $("#texture-dialog-title").textContent = scope === "level"
      ? `${TEXTURE_SLOTS[slot]} · predeterminada del nivel`
      : `${TEXTURE_SLOTS[slot]}`;
    $("#texture-search").value = "";
    renderTexturePicker();
    $("#texture-dialog").showModal();
  }

  function applyTexture(id) {
    const textures = pickerTextures();
    if (textures && pickerSlot) {
      textures[pickerSlot] = id;
      commit("Textura actualizada");
    }
    $("#texture-dialog").close();
  }

  function textureTile(label, selected, onPick, entry = null) {
    const tile = document.createElement("button");
    tile.type = "button";
    tile.className = "texture-tile" + (selected ? " selected" : "");
    if (entry) {
      const img = document.createElement("img");
      img.loading = "lazy";
      img.alt = "";
      img.src = textureUrl(entry);
      tile.append(img);
    } else {
      const none = document.createElement("span");
      none.className = "texture-tile-none";
      none.textContent = "∅";
      tile.append(none);
    }
    const name = document.createElement("span");
    name.className = "texture-tile-label";
    name.textContent = label;
    tile.title = entry ? String(entry.label) : label;
    tile.append(name);
    tile.addEventListener("click", onPick);
    return tile;
  }

  function renderTexturePicker() {
    const grid = $("#texture-picker-grid");
    grid.replaceChildren();
    const textures = pickerTextures();
    const current = textures && pickerSlot ? String(textures[pickerSlot] ?? "") : "";
    const filter = $("#texture-search").value.trim().toLowerCase();

    // "Sin textura" (el material de color plano) y, si el nivel trae un
    // identificador que ya no está en el catálogo, su tarjeta para conservarlo.
    const head = document.createElement("div");
    head.className = "texture-pack-grid";
    head.append(textureTile("Sin textura", !current, () => applyTexture("")));
    if (current && !textureById(current)) {
      head.append(textureTile(`${current} (fuera del catálogo)`, true, () => applyTexture(current)));
    }
    grid.append(head);

    const grouped = new Map();
    for (const entry of textureCatalog) {
      const id = String(entry?.id ?? "");
      if (!id) continue;
      const pack = String(entry?.pack ?? "otros");
      const meta = texturePacks.find((item) => item.id === pack);
      const packLabel = meta ? String(meta.label) : pack;
      const label = String(entry?.label ?? id);
      if (filter && !`${label} ${id} ${packLabel}`.toLowerCase().includes(filter)) continue;
      if (!grouped.has(packLabel)) grouped.set(packLabel, []);
      grouped.get(packLabel).push(entry);
    }
    let shown = 0;
    for (const [packLabel, entries] of grouped) {
      const title = document.createElement("h3");
      title.className = "texture-pack-title";
      title.textContent = `${packLabel} · ${entries.length}`;
      grid.append(title);
      const packGrid = document.createElement("div");
      packGrid.className = "texture-pack-grid";
      for (const entry of entries) {
        const id = String(entry.id);
        // Dentro de la sección del pack alcanza con la parte propia del nombre.
        const short = String(entry.label ?? id).split("·").pop().trim();
        packGrid.append(textureTile(short, id === current, () => applyTexture(id), entry));
        shown += 1;
      }
      grid.append(packGrid);
    }
    $("#texture-picker-empty").textContent = textureCatalog.length
      ? (shown ? "" : "Ninguna textura coincide con la búsqueda.")
      : "Sin catálogo: abrí el editor con workshop.cmd (o un servidor local) para ver las texturas.";
  }

  /** Toda mutación pasa por acá: reconcilia los datos derivados y redibuja. */
  function commit(message = "") {
    normalizeRoles(level.rooms);
    resolveEntryWalls(level);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(level));
    dirty = true;
    if (message) setStatus(message);
    render();
  }

  function setStatus(message) {
    const status = $("#level-status");
    status.textContent = message;
    status.classList.add("visible");
    clearTimeout(statusTimer);
    statusTimer = setTimeout(() => status.classList.remove("visible"), 2200);
  }

  const roomById = (id) => level.rooms.find((room) => room.id === id) || null;
  const selectedRoom = () => roomById(selectedRoomId);
  const dialogRoom = () => roomById(dialogRoomId);
  const dialogWave = () => {
    const room = dialogRoom();
    if (!room) return null;
    dialogWaveIndex = Math.min(dialogWaveIndex, room.waves.length - 1);
    return room.waves[dialogWaveIndex] || null;
  };
  /** Todos los bloques de la sala, de todas sus oleadas. */
  const roomBlocks = (room) => room.waves.flatMap((wave) => Object.values(wave.blocks));

  function roomWallHeight(room) {
    return room.wallHeight === null ? level.defaults.wallHeight : room.wallHeight;
  }

  function roomHasCeiling(room) {
    return room.hasCeiling === null ? level.defaults.hasCeiling : room.hasCeiling;
  }

  function connectionsFor(roomId) {
    return level.connections.filter((connection) =>
      connection.fromRoomId === roomId || connection.toRoomId === roomId);
  }

  const blockTotal = (block) => block.layers.reduce((total, wave) => total + layerTotal(wave), 0);

  // --- Tipos de ventana de una capa -----------------------------------------
  // Una capa puede nombrar una familia del catalogo o un diseño custom
  // (`custom:<slug>`). Todo lo que dibuja chips o resúmenes pasa por acá, que
  // nunca devuelve undefined: un diseño borrado se marca en vez de romper.

  const designByKey = (type) => windowDesigns.designs.find((design) => customTypeKey(design) === type) || null;
  const designGlyph = (design) => design.name.trim().split(/\s+/).slice(0, 2)
    .map((word) => word[0].toUpperCase()).join("") || "◆";

  function windowTypeMeta(type) {
    if (WINDOW_TYPES[type]) return WINDOW_TYPES[type];
    const design = isCustomType(type) ? designByKey(type) : null;
    if (design) {
      const family = WINDOW_TYPES[design.family];
      return {
        label: design.name,
        glyph: designGlyph(design),
        color: CUSTOM_TONE,
        status: "custom",
        hint: `Diseño propio sobre ${family ? family.label.toLowerCase() : design.family} · ${design.variants.length} variante(s) al azar.`
      };
    }
    return {
      label: `${String(type).replace(/^custom:/, "")} (falta)`,
      glyph: "?",
      color: "#ff6577",
      status: "missing",
      hint: "Este diseño ya no está en la pestaña Ventanas: el juego lo spawnea como una ventana normal."
    };
  }

  function svgElement(tag, attributes = {}) {
    const element = document.createElementNS("http://www.w3.org/2000/svg", tag);
    Object.entries(attributes).forEach(([key, value]) => element.setAttribute(key, value));
    return element;
  }

  function wallPoint(room, wall) {
    const halfW = room.size.width / 2;
    const halfD = room.size.depth / 2;
    return {
      north: { x: room.position.x, y: room.position.z - halfD },
      east: { x: room.position.x + halfW, y: room.position.z },
      south: { x: room.position.x, y: room.position.z + halfD },
      west: { x: room.position.x - halfW, y: room.position.z }
    }[wall];
  }

  function applyView() {
    svg.setAttribute("viewBox", `${view.x} ${view.y} ${view.width} ${view.height}`);
  }

  function zoomBy(factor, focus) {
    const aspect = view.height / view.width;
    const width = Math.min(400, Math.max(12, view.width * factor));
    const height = width * aspect;
    const anchor = focus || { x: view.x + view.width / 2, y: view.y + view.height / 2 };
    view = {
      x: anchor.x - (anchor.x - view.x) * (width / view.width),
      y: anchor.y - (anchor.y - view.y) * (height / view.height),
      width,
      height
    };
    applyView();
  }

  function fitView() {
    const aspect = view.height / view.width;
    if (!level.rooms.length) {
      view = { x: -35, y: -28, width: 70, height: 70 * aspect };
      applyView();
      return;
    }
    const bounds = level.rooms.reduce((box, room) => ({
      minX: Math.min(box.minX, room.position.x - room.size.width / 2),
      maxX: Math.max(box.maxX, room.position.x + room.size.width / 2),
      minY: Math.min(box.minY, room.position.z - room.size.depth / 2),
      maxY: Math.max(box.maxY, room.position.z + room.size.depth / 2)
    }), { minX: Infinity, maxX: -Infinity, minY: Infinity, maxY: -Infinity });
    const padding = 6;
    const width = Math.max(bounds.maxX - bounds.minX + padding * 2, (bounds.maxY - bounds.minY + padding * 2) / aspect);
    const height = width * aspect;
    view = {
      x: (bounds.minX + bounds.maxX) / 2 - width / 2,
      y: (bounds.minY + bounds.maxY) / 2 - height / 2,
      width,
      height
    };
    applyView();
  }

  function syncViewAspect() {
    const box = svg.getBoundingClientRect();
    if (box.width <= 0 || box.height <= 0) return;
    const centerY = view.y + view.height / 2;
    view.height = view.width * (box.height / box.width);
    view.y = centerY - view.height / 2;
    applyView();
  }

  function renderCorridors() {
    corridorsLayer.replaceChildren();
    for (const connection of level.connections) {
      const from = roomById(connection.fromRoomId);
      const to = roomById(connection.toRoomId);
      if (!from || !to) continue;
      // Una sola figura cerrada por pasillo: sin bordes internos donde los
      // tramos se encuentran, y el codo queda con su esquina bien resuelta.
      const plan = corridorPlan(from, to, connection);
      const outline = corridorOutline(plan.points, plan.width);
      const points = outline.map((point) => `${point.x} ${point.y}`).join(" L ");
      corridorsLayer.append(svgElement("path", { d: `M ${points} Z`, class: "corridor-shape", "data-connection-id": connection.id }));
      // Los puntos intermedios se arrastran; doble click sobre el pasillo
      // agrega uno y click derecho sobre el punto lo quita.
      (connection.waypoints || []).forEach((waypoint, index) => {
        corridorsLayer.append(svgElement("circle", {
          cx: waypoint.x,
          cy: waypoint.z,
          r: 0.8,
          class: "corridor-waypoint",
          "data-connection-id": connection.id,
          "data-waypoint-index": index
        }));
      });
    }
  }

  const snapHalf = (value) => Math.round(value * 2) / 2;

  const distanceToSegment = (point, a, b) => {
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const lengthSq = dx * dx + dy * dy;
    const t = lengthSq ? Math.max(0, Math.min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSq)) : 0;
    return Math.hypot(point.x - (a.x + dx * t), point.y - (a.y + dy * t));
  };

  /** Suma un punto intermedio en el tramo del recorrido más cercano al click. */
  function addWaypoint(connectionId, point) {
    const connection = level.connections.find((item) => item.id === connectionId);
    const from = roomById(connection?.fromRoomId);
    const to = roomById(connection?.toRoomId);
    if (!connection || !from || !to) return;
    const anchors = [
      doorPoint(from, connection.fromWall, connection, true),
      ...connection.waypoints.map((waypoint) => ({ x: waypoint.x, y: waypoint.z })),
      doorPoint(to, connection.toWall, connection, false)
    ];
    let best = 0;
    let bestDistance = Infinity;
    for (let index = 0; index < anchors.length - 1; index += 1) {
      const distance = distanceToSegment(point, anchors[index], anchors[index + 1]);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    }
    connection.waypoints.splice(best, 0, { x: snapHalf(point.x), z: snapHalf(point.y) });
    refreshConnectionWalls(connection);
    commit("Punto agregado al pasillo");
  }

  function addEntryMark(group, room) {
    const horizontal = room.entry.wall === "north" || room.entry.wall === "south";
    const opening = connectionsFor(room.id).find((connection) =>
      (connection.fromRoomId === room.id ? connection.fromWall : connection.toWall) === room.entry.wall);
    // Con puntos intermedios la puerta puede estar corrida del centro.
    const point = opening
      ? doorPoint(room, room.entry.wall, opening, opening.fromRoomId === room.id)
      : wallPoint(room, room.entry.wall);
    const half = (opening ? opening.width : level.defaults.corridorWidth) / 2;
    group.append(svgElement("line", {
      x1: point.x - (horizontal ? half : 0),
      y1: point.y - (horizontal ? 0 : half),
      x2: point.x + (horizontal ? half : 0),
      y2: point.y + (horizontal ? 0 : half),
      class: "door-mark"
    }));
  }

  function addFacingArrow(group, room) {
    if (room.role !== "start") return;
    const radians = (room.facing * Math.PI) / 180;
    const length = Math.min(room.size.width, room.size.depth) * 0.32;
    const tip = {
      x: room.position.x + Math.sin(radians) * length,
      y: room.position.z - Math.cos(radians) * length
    };
    group.append(
      svgElement("path", { d: `M ${room.position.x} ${room.position.z} L ${tip.x} ${tip.y}`, class: "facing-arrow" }),
      svgElement("circle", { cx: tip.x, cy: tip.y, r: .45, class: "facing-head" })
    );
  }

  function addBlock(group, room, slot, config) {
    if (!config.enabled) return;
    const wall = RELATIVE_WALLS[room.entry.wall][slot];
    const point = wallPoint(room, wall);
    const horizontal = wall === "north" || wall === "south";
    // El bloque cubre la pared entera menos el margen que deja el runtime.
    const length = (horizontal ? room.size.width : room.size.depth) - 0.4;
    const rect = svgElement("rect", {
      x: point.x - (horizontal ? length / 2 : .35),
      y: point.y - (horizontal ? .35 : length / 2),
      width: horizontal ? length : .7,
      height: horizontal ? .7 : length,
      rx: .18,
      class: `target-block${config.movement === "opposite" ? " moving" : ""}`
    });
    rect.style.fill = config.color;
    const count = svgElement("text", { x: point.x, y: point.y, class: "block-count" });
    count.textContent = config.layers.length ? config.layers.map(layerTotal).join("›") : "×";
    group.append(rect, count);
  }

  function addAmmoReward(group, room) {
    if (!room.ammoReward.enabled) return;
    const size = 1.9;
    const y = room.position.z + room.size.depth / 2 - size - 1.3;
    const rect = svgElement("rect", { x: room.position.x - size / 2, y, width: size, height: size, rx: .3, class: "ammo-mark" });
    rect.style.fill = room.ammoReward.color;
    const label = svgElement("text", { x: room.position.x, y: y + size / 2, class: "ammo-count" });
    label.textContent = `+${room.ammoReward.amount}`;
    group.append(rect, label);
  }

  // La radio se dibuja pegada a su esquina, como queda en el juego.
  function addRadio(group, room) {
    if (!room.radio.enabled) return;
    const size = 1.2;
    const inset = 0.9;
    const signX = room.radio.corner.endsWith("e") ? 1 : -1;
    const signZ = room.radio.corner.startsWith("n") ? -1 : 1;
    const cx = room.position.x + signX * (room.size.width / 2 - inset);
    const cz = room.position.z + signZ * (room.size.depth / 2 - inset);
    const rect = svgElement("rect", { x: cx - size / 2, y: cz - size / 2, width: size, height: size, rx: .2, class: "radio-mark" });
    const label = svgElement("text", { x: cx, y: cz, class: "radio-glyph" });
    label.textContent = "\u266a";
    group.append(rect, label);
  }

  function roomBadges(room) {
    const badges = [`H ${roomWallHeight(room)} m`];
    if (!roomHasCeiling(room)) badges.push("CIELO ABIERTO");
    if (room.ammoReward.enabled) badges.push(`+${room.ammoReward.amount} BALAS`);
    if (room.radio.enabled) badges.push(`RADIO ${room.radio.corner.toUpperCase()}`);
    return badges.join(" · ");
  }

  function renderRooms() {
    roomsLayer.replaceChildren();
    for (const room of level.rooms) {
      const classes = ["room-group", `role-${room.role}`];
      if (room.id === selectedRoomId) classes.push("selected");
      if (room.id === connectSourceId) classes.push("connect-source");
      const group = svgElement("g", { class: classes.join(" "), "data-room-id": room.id });
      const shape = {
        x: room.position.x - room.size.width / 2,
        y: room.position.z - room.size.depth / 2,
        width: room.size.width,
        height: room.size.depth,
        rx: .5
      };
      group.append(svgElement("rect", { ...shape, class: "room-shape" }));
      if (!roomHasCeiling(room)) {
        group.append(svgElement("rect", { ...shape, class: "room-open-sky", fill: "url(#open-sky)" }));
      }
      addEntryMark(group, room);
      addFacingArrow(group, room);
      for (const [slot, config] of Object.entries(room.waves[0].blocks)) addBlock(group, room, slot, config);
      addAmmoReward(group, room);
      addRadio(group, room);
      if (room.role !== "transition") {
        const role = svgElement("text", {
          x: room.position.x,
          y: room.position.z - room.size.depth / 2 + 1.5,
          class: "room-role"
        });
        role.textContent = ROLE_LABELS[room.role].toUpperCase();
        group.append(role);
      }
      const label = svgElement("text", { x: room.position.x, y: room.position.z - .7, class: "room-label" });
      label.textContent = room.name;
      const meta = svgElement("text", { x: room.position.x, y: room.position.z + .6, class: "room-meta" });
      meta.textContent = `${room.size.width}×${room.size.depth} m · entra por ${WALL_LABELS[room.entry.wall]}`;
      const badges = svgElement("text", { x: room.position.x, y: room.position.z + 1.7, class: "room-badges" });
      badges.textContent = roomBadges(room);
      group.append(label, meta, badges);
      roomsLayer.append(group);
    }
  }

  function renderRoomList() {
    const list = $("#room-list");
    list.replaceChildren();
    $("#room-count").textContent = level.rooms.length ? String(level.rooms.length) : "";
    if (!level.rooms.length) {
      const empty = document.createElement("p");
      empty.className = "hint";
      empty.textContent = "Todavía no hay salas.";
      list.append(empty);
      return;
    }
    for (const room of level.rooms) {
      const item = document.createElement("li");
      item.className = `room-item role-${room.role}${room.id === selectedRoomId ? " selected" : ""}`;
      const button = document.createElement("button");
      button.type = "button";
      button.className = "room-item-button";
      const name = document.createElement("span");
      name.className = "room-item-name";
      name.textContent = room.name;
      const role = document.createElement("span");
      role.className = "room-item-role";
      role.textContent = ROLE_LABELS[room.role];
      button.append(name, role);
      button.addEventListener("click", () => {
        selectedRoomId = room.id;
        render();
      });
      button.addEventListener("dblclick", () => openRoomDialog(room.id));
      const configure = document.createElement("button");
      configure.type = "button";
      configure.className = "icon-button room-item-config";
      configure.textContent = "⚙";
      configure.title = `Configurar ${room.name}`;
      configure.addEventListener("click", () => openRoomDialog(room.id));
      item.append(button, configure);
      list.append(item);
    }
  }

  // --- Plantillas de sala ----------------------------------------------------

  const templateSummary = (template) => {
    const room = template.room;
    const windows = room.waves.reduce((total, wave) =>
      total + Object.values(wave.blocks).filter((block) => block.enabled)
        .reduce((sum, block) => sum + blockTotal(block), 0), 0);
    return `${room.size.width}×${room.size.depth} · ${windows} vent.`;
  };

  function renderTemplateList() {
    const list = $("#template-list");
    list.replaceChildren();
    const templates = roomTemplates.templates;
    $("#template-count").textContent = templates.length ? String(templates.length) : "";
    $("#template-help").textContent = templates.length
      ? "Click agrega una sala con ese contenido."
      : "Guardá una sala desde su ventana (“Guardar plantilla”) para reutilizarla acá.";
    for (const template of templates) {
      const item = document.createElement("li");
      item.className = "room-item";
      const button = document.createElement("button");
      button.type = "button";
      button.className = "room-item-button";
      button.title = `Agregar “${template.name}” al nivel`;
      const name = document.createElement("span");
      name.className = "room-item-name";
      name.textContent = template.name;
      const meta = document.createElement("span");
      meta.className = "template-item-meta";
      meta.textContent = templateSummary(template);
      button.append(name, meta);
      button.addEventListener("click", () => insertTemplate(template));
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "icon-button template-item-delete";
      remove.textContent = "×";
      remove.title = `Borrar la plantilla ${template.name}`;
      remove.addEventListener("click", () => deleteTemplate(template.id));
      item.append(button, remove);
      list.append(item);
    }
  }

  function insertTemplate(template) {
    const room = roomFromTemplate(template, level.rooms.length + 1);
    level.rooms.push(room);
    selectedRoomId = room.id;
    commit(`Sala “${template.name}” agregada desde la plantilla`);
  }

  async function saveTemplateFromRoom(room) {
    const answer = window.prompt("Nombre de la plantilla:", room.name);
    if (answer === null) return;
    const template = roomTemplateFrom(room, answer);
    const existing = roomTemplates.templates.findIndex((entry) => entry.name === template.name);
    if (existing >= 0) {
      if (!window.confirm(`Ya hay una plantilla “${template.name}”. ¿Reemplazarla?`)) return;
      template.id = roomTemplates.templates[existing].id;
      roomTemplates.templates[existing] = template;
    } else {
      roomTemplates.templates.push(template);
    }
    await persistTemplates(`Plantilla guardada: ${template.name}`);
  }

  async function deleteTemplate(id) {
    const template = roomTemplates.templates.find((entry) => entry.id === id);
    if (!template || !window.confirm(`¿Borrar la plantilla “${template.name}”?`)) return;
    roomTemplates.templates = roomTemplates.templates.filter((entry) => entry.id !== id);
    await persistTemplates("Plantilla borrada");
  }

  async function persistTemplates(message) {
    try {
      if (workshopApi) {
        await apiJson("/api/room-templates", { method: "PUT", body: JSON.stringify(roomTemplates) });
      } else {
        localStorage.setItem(TEMPLATES_KEY, JSON.stringify(roomTemplates));
      }
      showToast(message);
    } catch (error) {
      showToast(`No se pudieron guardar las plantillas: ${error.message}`);
    }
    renderTemplateList();
  }

  async function loadRoomTemplates() {
    let raw = null;
    try {
      raw = workshopApi
        ? await apiJson("/api/room-templates")
        : JSON.parse(localStorage.getItem(TEMPLATES_KEY) || "null");
    } catch (error) {
      console.warn("No se pudieron leer las plantillas", error);
    }
    roomTemplates = normalizeRoomTemplates(raw);
    renderTemplateList();
  }

  function renderConnectionList() {
    const list = $("#connection-list");
    list.replaceChildren();
    for (const connection of level.connections) {
      const from = roomById(connection.fromRoomId);
      const to = roomById(connection.toRoomId);
      if (!from || !to) continue;
      const item = document.createElement("li");
      item.className = "connection-item";
      const text = document.createElement("span");
      text.className = "connection-name";
      const waypointCount = connection.waypoints?.length || 0;
      text.textContent = `${from.name} → ${to.name}` + (waypointCount ? ` · ${waypointCount} pt${waypointCount > 1 ? "s" : ""}` : "");
      text.title = "Doble click sobre el pasillo en el plano agrega un punto intermedio; arrastralo para moverlo y click derecho lo quita.";
      const width = document.createElement("input");
      width.type = "number";
      width.min = String(LIMITS.corridorWidth.min);
      width.max = String(LIMITS.corridorWidth.max);
      width.step = "0.5";
      width.value = String(connection.width);
      width.title = "Ancho del pasillo en metros";
      width.className = "connection-width";
      width.addEventListener("change", () => {
        connection.width = clamp(width.value, { ...LIMITS.corridorWidth, fallback: level.defaults.corridorWidth });
        commit("Ancho del pasillo actualizado");
      });
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "icon-button danger";
      remove.textContent = "×";
      remove.title = "Quitar el pasillo";
      remove.addEventListener("click", () => {
        level.connections = level.connections.filter((item) => item.id !== connection.id);
        commit("Pasillo eliminado");
      });
      item.append(text, width, remove);
      list.append(item);
    }
    if (!level.connections.length && level.rooms.length > 1) {
      const empty = document.createElement("p");
      empty.className = "hint";
      empty.textContent = "Las salas todavía no están unidas.";
      list.append(empty);
    }
  }

  /**
   * Todo lo que se puede deducir del nivel, en un solo lugar: lo comparten las
   * fichas de la barra, la linea del plano y el detalle del dialogo, asi los
   * tres numeros no pueden discrepar entre si.
   */
  function levelSummary() {
    const byRole = { start: 0, transition: 0, exit: 0 };
    const windows = {};
    let activeBlocks = 0;
    let movingBlocks = 0;
    let emptyBlocks = 0;
    let waves = 0;
    let roomWaves = 0;
    let targets = 0;
    let plannedTargets = 0;
    let missingDesignTargets = 0;
    let rewardAmmo = 0;
    let rewardRooms = 0;
    let openRooms = 0;
    let floorArea = 0;
    for (const room of level.rooms) {
      byRole[room.role] += 1;
      floorArea += room.size.width * room.size.depth;
      if (!roomHasCeiling(room)) openRooms += 1;
      if (room.ammoReward.enabled) {
        rewardAmmo += room.ammoReward.amount;
        rewardRooms += 1;
      }
      roomWaves += room.waves.length;
      for (const block of roomBlocks(room)) {
        if (!block.enabled) continue;
        activeBlocks += 1;
        if (block.movement === "opposite") movingBlocks += 1;
        if (!block.layers.length) emptyBlocks += 1;
        waves += block.layers.length;
        for (const wave of block.layers) {
          for (const [type, count] of Object.entries(wave.windows)) {
            windows[type] = (windows[type] || 0) + count;
            targets += count;
            const meta = windowTypeMeta(type);
            if (meta.status === "planned") plannedTargets += count;
            if (meta.status === "missing") missingDesignTargets += count;
          }
        }
      }
    }
    let corridorLength = 0;
    for (const connection of level.connections) {
      const from = roomById(connection.fromRoomId);
      const to = roomById(connection.toRoomId);
      if (!from || !to) continue;
      const plan = corridorPlan(from, to, connection);
      let length = 0;
      for (let index = 1; index < plan.points.length; index += 1) {
        length += Math.hypot(
          plan.points[index].x - plan.points[index - 1].x,
          plan.points[index].y - plan.points[index - 1].y
        );
      }
      corridorLength += length;
      floorArea += length * plan.width;
    }
    const initialAmmo = level.startingAmmo.magazine + level.startingAmmo.reserve;
    return {
      byRole,
      windows,
      activeBlocks,
      movingBlocks,
      emptyBlocks,
      blockSlots: level.rooms.length * 3,
      waves,
      roomWaves,
      targets,
      plannedTargets,
      missingDesignTargets,
      rewardAmmo,
      rewardRooms,
      openRooms,
      floorArea,
      corridorLength,
      initialAmmo,
      totalAmmo: initialAmmo + rewardAmmo,
      unreachable: unreachableRooms()
    };
  }

  /** Salas a las que no se llega caminando desde la de inicio. */
  function unreachableRooms() {
    if (level.rooms.length < 2) return [];
    const start = level.rooms.find((room) => room.role === "start") || level.rooms[0];
    const neighbours = new Map(level.rooms.map((room) => [room.id, []]));
    for (const connection of level.connections) {
      if (!neighbours.has(connection.fromRoomId) || !neighbours.has(connection.toRoomId)) continue;
      neighbours.get(connection.fromRoomId).push(connection.toRoomId);
      neighbours.get(connection.toRoomId).push(connection.fromRoomId);
    }
    const seen = new Set([start.id]);
    const queue = [start.id];
    while (queue.length) {
      for (const next of neighbours.get(queue.shift()) || []) {
        if (seen.has(next)) continue;
        seen.add(next);
        queue.push(next);
      }
    }
    return level.rooms.filter((room) => !seen.has(room.id));
  }

  const round1 = (value) => value.toLocaleString("es-AR", { maximumFractionDigits: 1 });

  function renderSummary() {
    const summary = levelSummary();
    $("#stat-rooms").textContent = String(level.rooms.length);
    $("#stat-time").textContent = timeLabel();
    $("#stat-ammo").textContent = String(summary.totalAmmo);
    $("#stat-ammo-note").textContent = summary.rewardAmmo
      ? `balas (${summary.initialAmmo} + ${summary.rewardAmmo})`
      : "balas iniciales";
    $("#stat-targets").textContent = String(summary.targets);

    const parts = [
      `${level.rooms.length} salas`,
      `${level.connections.length} pasillos`,
      `${summary.targets} objetivos`
    ];
    if (summary.rewardAmmo) parts.push(`+${summary.rewardAmmo} de recompensa`);
    if (summary.openRooms) parts.push(`${summary.openRooms} a cielo abierto`);
    parts.push(SKY_LABELS[level.sky].toLowerCase());
    $("#level-stats").textContent = parts.join(" · ");

    const alerts = summaryWarnings(summary);
    $("#stat-alert").textContent = alerts.length ? alerts[0] : "";
    renderSummaryDetail(summary, alerts);
  }

  /** Lo que hace que el nivel no se pueda terminar tal como esta. */
  function summaryWarnings(summary) {
    const alerts = [];
    if (level.rooms.length && !summary.byRole.exit) {
      alerts.push("El nivel no tiene sala de salida: no hay dónde terminarlo.");
    }
    if (summary.unreachable.length) {
      alerts.push(`No se llega a ${summary.unreachable.map((room) => room.name).join(", ")}: falta un pasillo.`);
    }
    if (summary.targets && summary.totalAmmo < summary.targets) {
      alerts.push(`${summary.totalAmmo} balas para ${summary.targets} objetivos: no alcanzan ni acertando todos los tiros.`);
    }
    return alerts;
  }

  /** Notas que no bloquean el nivel pero conviene tener a la vista. */
  function summaryNotes(summary) {
    const notes = [];
    if (summary.emptyBlocks) {
      notes.push(`${summary.emptyBlocks} ${summary.emptyBlocks === 1 ? "bloque activo no tiene oleadas" : "bloques activos no tienen oleadas"}: se cierran con su propio control.`);
    }
    if (summary.plannedTargets) {
      notes.push(`${summary.plannedTargets} ventanas son de familias sin comportamiento propio: el juego las spawnea como normales.`);
    }
    if (summary.missingDesignTargets) {
      notes.push(`${summary.missingDesignTargets} ventanas usan diseños que ya no existen: el juego las spawnea como normales.`);
    }
    return notes;
  }

  function renderSummaryDetail(summary, alerts) {
    $("#summary-headline").textContent = summary.targets
      ? `${summary.targets} objetivos en ${summary.activeBlocks} ${summary.activeBlocks === 1 ? "bloque" : "bloques"}`
      : "Todavía sin objetivos";

    const rewardText = summary.rewardAmmo
      ? ` · +${summary.rewardAmmo} en ${summary.rewardRooms} ${summary.rewardRooms === 1 ? "sala" : "salas"}`
      : "";
    const rows = [
      ["Salas", `${level.rooms.length} · ${summary.byRole.start} inicio, ${summary.byRole.transition} tránsito, ${summary.byRole.exit} salida`],
      ["Pasillos", `${level.connections.length} · ${round1(summary.corridorLength)} m de recorrido`],
      ["Superficie", `${Math.round(summary.floorArea)} m² de piso`],
      ["Bloques", `${summary.activeBlocks} activos de ${summary.blockSlots} · ${summary.movingBlocks} móviles · hasta ${level.defaults.maxBlockHeight} m de alto`],
      ["Oleadas de sala", `${summary.roomWaves}`],
      ["Capas", `${summary.waves} · ${summary.targets} objetivos`],
      ["Munición", `${level.startingAmmo.magazine}+${level.startingAmmo.reserve} iniciales${rewardText} · ${summary.totalAmmo} en total`],
      ["Margen", summary.targets
        ? `${round1(summary.totalAmmo / summary.targets)} balas y ${round1(level.timeLimitSeconds / summary.targets)} s por objetivo`
        : "—"],
      ["Entorno", `${SKY_LABELS[level.sky].toLowerCase()} · ${summary.openRooms} a cielo abierto · ${level.defaults.wallHeight} m de altura`]
    ];
    const list = $("#summary-detail");
    list.replaceChildren();
    for (const [label, value] of rows) {
      const term = document.createElement("dt");
      term.textContent = label;
      const definition = document.createElement("dd");
      definition.textContent = value;
      list.append(term, definition);
    }

    const chips = $("#summary-windows");
    chips.replaceChildren();
    const families = Object.entries(summary.windows).sort((a, b) => b[1] - a[1]);
    if (!families.length) {
      const empty = document.createElement("p");
      empty.className = "hint";
      empty.textContent = "Ningún bloque spawnea ventanas todavía.";
      chips.append(empty);
    }
    for (const [type, count] of families) {
      const meta = windowTypeMeta(type);
      const chip = document.createElement("span");
      chip.className = "window-chip";
      chip.title = meta.hint;
      const glyph = document.createElement("span");
      glyph.className = "window-glyph";
      glyph.style.setProperty("--tone", meta.color);
      glyph.textContent = meta.glyph;
      const label = document.createElement("span");
      label.textContent = `${meta.label} · ${count}`;
      chip.append(glyph, label);
      chips.append(chip);
    }

    const notices = $("#summary-warnings");
    notices.replaceChildren();
    for (const alert of alerts) {
      const item = document.createElement("li");
      item.className = "alert";
      item.textContent = alert;
      notices.append(item);
    }
    for (const note of summaryNotes(summary)) {
      const item = document.createElement("li");
      item.textContent = note;
      notices.append(item);
    }
  }

  function timeLabel() {
    return `${Math.floor(level.timeLimitSeconds / 60)}:${String(level.timeLimitSeconds % 60).padStart(2, "0")}`;
  }

  function render() {
    $("#level-chip-name").textContent = level.name;
    $("#level-chip-meta").textContent = `${timeLabel()} · ${level.startingAmmo.magazine}+${level.startingAmmo.reserve} balas`;
    renderSummary();
    renderCorridors();
    renderRooms();
    renderRoomList();
    renderConnectionList();
    if (levelDialog.open) renderLevelDialog();
    if (roomDialog.open) renderRoomDialog();
  }

  // ---------------------------------------------------------------- diálogos

  function openDialog(dialog) {
    if (!dialog.open) dialog.showModal();
  }

  function openLevelDialog() {
    renderLevelDialog();
    openDialog(levelDialog);
  }

  function renderLevelDialog() {
    $("#level-name").value = level.name;
    $("#level-description").value = level.description;
    $("#level-time-minutes").value = Math.floor(level.timeLimitSeconds / 60);
    $("#level-time-seconds").value = level.timeLimitSeconds % 60;
    $("#level-ammo-magazine").value = level.startingAmmo.magazine;
    $("#level-ammo-reserve").value = level.startingAmmo.reserve;
    $("#level-crossing-damage").value = level.crossingDamage ?? "";
    $("#level-crossing-damage").placeholder = String(LIMITS.crossingDamage.fallback);
    $("#level-wall-height").value = level.defaults.wallHeight;
    $("#level-max-block-height").value = level.defaults.maxBlockHeight;
    $("#level-corridor-width").value = level.defaults.corridorWidth;
    $("#level-has-ceiling").checked = level.defaults.hasCeiling;
    $("#level-sky").value = level.sky;
    for (const slot of Object.keys(TEXTURE_SLOTS)) {
      renderTextureField($(`[data-texture-level="${slot}"]`), level.defaults.textures[slot]);
    }
  }

  function openRoomDialog(roomId) {
    if (!roomById(roomId)) return;
    dialogRoomId = roomId;
    dialogWaveIndex = 0;
    selectedRoomId = roomId;
    renderRooms();
    renderRoomList();
    renderRoomDialog();
    openDialog(roomDialog);
  }

  /**
   * Pestanas de oleada. Una pestana por oleada mas el boton de agregar: llegar a
   * cualquiera es un clic, sin recorrerlas de a una.
   */
  function renderWaveBar(room) {
    dialogWaveIndex = Math.min(dialogWaveIndex, room.waves.length - 1);
    const tabs = $("#wave-tabs");
    tabs.replaceChildren();
    room.waves.forEach((wave, index) => {
      const tab = document.createElement("button");
      tab.type = "button";
      tab.className = "wave-tab";
      tab.setAttribute("role", "tab");
      tab.setAttribute("aria-selected", String(index === dialogWaveIndex));
      const blocks = Object.values(wave.blocks).filter((block) => block.enabled);
      const windows = blocks.reduce((total, block) => total + blockTotal(block), 0);
      tab.innerHTML = `<strong>Oleada ${index + 1}</strong><small>${blocks.length ? `${blocks.length}▦ ${windows}▢` : "vacía"}</small>`;
      tab.title = blocks.length
        ? `${blocks.length} bloque(s), ${windows} ventana(s)`
        : "Sin bloques: esta oleada se saltea";
      tab.addEventListener("click", () => {
        dialogWaveIndex = index;
        renderRoomDialog();
      });
      tabs.append(tab);
    });

    const add = document.createElement("button");
    add.type = "button";
    add.className = "wave-tab add";
    add.textContent = "+";
    add.title = "Agregar una oleada";
    add.disabled = room.waves.length >= LIMITS.roomWaves.max;
    add.addEventListener("click", () => {
      room.waves.push(blankRoomWave());
      dialogWaveIndex = room.waves.length - 1;
      commit("Oleada agregada");
    });
    tabs.append(add);

    // Duplicar ahorra rehacer a mano una oleada parecida a la anterior, que es
    // lo mas comun al escalonar dificultad.
    const clone = document.createElement("button");
    clone.type = "button";
    clone.className = "wave-tab add";
    clone.textContent = "⧉";
    clone.title = "Duplicar esta oleada";
    clone.disabled = room.waves.length >= LIMITS.roomWaves.max;
    clone.addEventListener("click", () => {
      room.waves.splice(dialogWaveIndex + 1, 0, structuredClone(room.waves[dialogWaveIndex]));
      dialogWaveIndex += 1;
      commit("Oleada duplicada");
    });
    tabs.append(clone);

    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "wave-tab add danger";
    remove.textContent = "×";
    remove.title = "Quitar esta oleada";
    // Una sala sin oleadas no tendria donde poner bloques: siempre queda una.
    remove.disabled = room.waves.length <= 1;
    remove.addEventListener("click", () => {
      room.waves.splice(dialogWaveIndex, 1);
      dialogWaveIndex = Math.max(dialogWaveIndex - 1, 0);
      commit("Oleada eliminada");
    });
    tabs.append(remove);

    renderSlotGrid(room);
  }


  /**
   * Los tres bloques de la oleada, uno al lado del otro. Antes cada uno vivia en
   * un dialogo aparte: configurar una sala de tres oleadas eran nueve aperturas.
   */
  function renderSlotGrid(room) {
    const wave = room.waves[dialogWaveIndex];
    const grid = $("#slot-grid");
    grid.replaceChildren();
    for (const [slot, label] of Object.entries(SLOT_LABELS)) {
      grid.append(slotCard(room, wave, slot, label));
    }
  }


  function slotCard(room, wave, slot, label) {
    const block = wave.blocks[slot];
    const card = document.createElement("article");
    card.className = `slot-card${block.enabled ? " active" : ""}`;
    card.dataset.slot = slot;

    const header = document.createElement("header");
    const toggle = document.createElement("label");
    toggle.className = "switch strong";
    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = block.enabled;
    checkbox.addEventListener("change", () => {
      block.enabled = checkbox.checked;
      // Un bloque recien encendido sin capas no spawnea nada: se le da la
      // primera para que arranque mostrando algo editable.
      if (block.enabled && !block.layers.length) block.layers.push(blankLayer());
      commit(block.enabled ? `${label} activado` : `${label} apagado`);
    });
    toggle.append(checkbox, document.createTextNode(` ${label}`));
    const wall = document.createElement("span");
    wall.className = "slot-wall";
    wall.textContent = WALL_NAMES[RELATIVE_WALLS[room.entry.wall][slot]];
    header.append(toggle, wall);
    card.append(header);

    if (!block.enabled) {
      const empty = document.createElement("p");
      empty.className = "slot-empty";
      empty.textContent = "Pared libre";
      card.append(empty);
      return card;
    }

    const props = document.createElement("div");
    props.className = "slot-props";
    const movement = document.createElement("select");
    movement.title = "Movimiento del bloque";
    for (const [value, text] of [["static", "Estático"], ["opposite", "Avanza"]]) {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = text;
      movement.append(option);
    }
    movement.value = block.movement;
    movement.addEventListener("change", () => {
      block.movement = movement.value;
      commit("Movimiento actualizado");
    });
    const speed = document.createElement("input");
    speed.type = "number";
    speed.min = "0.05";
    speed.max = "5";
    speed.step = "0.05";
    speed.value = String(block.movementSpeed);
    speed.title = "Velocidad en metros por segundo";
    speed.disabled = block.movement !== "opposite";
    speed.addEventListener("change", () => {
      block.movementSpeed = clamp(speed.value, LIMITS.movementSpeed);
      commit("Velocidad actualizada");
    });
    const color = document.createElement("input");
    color.type = "color";
    color.value = block.color;
    color.title = "Color del panel";
    color.addEventListener("change", () => {
      block.color = color.value;
      commit("Color actualizado");
    });
    props.append(movement, speed, color);
    card.append(props);

    const layers = document.createElement("div");
    layers.className = "layer-stack";
    block.layers.forEach((layer, index) => layers.append(layerRow(block, layer, index)));
    card.append(layers);

    const add = document.createElement("button");
    add.type = "button";
    add.className = "ghost-add wide";
    add.textContent = "+ Capa";
    add.addEventListener("click", () => {
      // La capa nueva copia la anterior: escalonar dificultad suele ser repetir
      // lo mismo con una vuelta de tuerca, no empezar de cero.
      const previous = block.layers[block.layers.length - 1];
      block.layers.push(previous ? structuredClone(previous) : blankLayer());
      commit("Capa agregada");
    });
    card.append(add);
    return card;
  }


  /**
   * Una capa en una sola fila: los chips de las familias que trae y la paleta
   * para sumar otra. Un clic en un chip suma una ventana, clic derecho resta.
   */
  function layerRow(block, layer, index) {
    const row = document.createElement("div");
    row.className = "layer-row";

    const title = document.createElement("span");
    title.className = "layer-index";
    title.textContent = `${index + 1}`;
    title.title = `Capa ${index + 1}`;
    row.append(title);

    const chips = document.createElement("div");
    chips.className = "chip-row";
    for (const type of Object.keys(layer.windows)) {
      chips.append(familyChip(type, layer, Object.keys(layer.windows).length === 1));
    }
    chips.append(paletteToggle(layer));
    row.append(chips);

    const total = document.createElement("span");
    total.className = "layer-total";
    total.textContent = String(layerTotal(layer));
    total.title = "Ventanas de la capa";
    row.append(total);

    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "icon-button danger tiny";
    remove.textContent = "×";
    remove.title = "Quitar la capa";
    remove.disabled = block.layers.length <= 1;
    remove.addEventListener("click", () => {
      block.layers.splice(index, 1);
      commit("Capa eliminada");
    });
    row.append(remove);
    return row;
  }


  /** Chip de una familia o diseño custom: glifo, cantidad y los dos clics que la ajustan. */
  function familyChip(type, layer, onlyOne) {
    const meta = windowTypeMeta(type);
    const chip = document.createElement("button");
    chip.type = "button";
    chip.className = `family-chip${meta.status === "planned" ? " planned" : ""}${meta.status === "missing" ? " missing" : ""}`;
    chip.style.setProperty("--tone", meta.color);
    chip.innerHTML = `<b>${meta.glyph}</b>${layer.windows[type]}`;
    chip.title = `${meta.label}: ${meta.hint}\nClic suma una, clic derecho resta.`;
    chip.addEventListener("click", () => {
      if (layerTotal(layer) >= LIMITS.wave.max) return;
      layer.windows[type] += 1;
      commit(`${meta.label} +1`);
    });
    chip.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      if (layer.windows[type] > 1) {
        layer.windows[type] -= 1;
        commit(`${meta.label} −1`);
        return;
      }
      // La ultima ventana de la ultima familia no se saca: una capa vacia no
      // spawnearia nada y el archivo la descartaria igual.
      if (onlyOne) return;
      delete layer.windows[type];
      commit(`${meta.label} fuera`);
    });
    return chip;
  }


  /** Paleta de familias: un clic agrega la que falte, sin menues intermedios.
   * Los diseños de la pestaña Ventanas aparecen al final, con su propio tono. */
  function paletteToggle(layer) {
    const wrap = document.createElement("span");
    wrap.className = "palette";
    const available = [...Object.keys(WINDOW_TYPES), ...windowDesigns.designs.map(customTypeKey)];
    const missing = available.filter((type) => !(type in layer.windows));
    if (!missing.length || layerTotal(layer) >= LIMITS.wave.max) return wrap;

    const button = document.createElement("button");
    button.type = "button";
    button.className = "family-chip add";
    button.textContent = "+";
    button.title = "Agregar otra familia de ventana o un diseño propio";
    const menu = document.createElement("span");
    menu.className = "palette-menu";
    for (const type of missing) {
      const meta = windowTypeMeta(type);
      const option = document.createElement("button");
      option.type = "button";
      option.className = `family-chip${meta.status === "planned" ? " planned" : ""}`;
      option.style.setProperty("--tone", meta.color);
      option.innerHTML = `<b>${meta.glyph}</b>`;
      option.title = `${meta.label}: ${meta.hint}`;
      option.addEventListener("click", () => {
        layer.windows[type] = 1;
        commit(`${meta.label} agregada`);
      });
      menu.append(option);
    }
    button.addEventListener("click", () => wrap.classList.toggle("open"));
    wrap.append(button, menu);
    return wrap;
  }


  function renderRoomDialog() {
    const room = dialogRoom();
    if (!room) {
      roomDialog.close();
      return;
    }
    renderWaveBar(room);
    $("#room-name").value = room.name;
    $("#room-type").value = room.type;
    $("#room-width").value = room.size.width;
    $("#room-depth").value = room.size.depth;
    $("#room-x").value = room.position.x;
    $("#room-z").value = room.position.z;
    $("#facing-field").hidden = room.role !== "start";
    document.querySelectorAll(".compass-point").forEach((button) =>
      button.setAttribute("aria-checked", String(Number(button.dataset.facing) === room.facing)));
    $("#room-wall-height-mode").value = room.wallHeight === null ? "inherit" : "custom";
    $("#room-wall-height-field").hidden = room.wallHeight === null;
    $("#room-wall-height").value = roomWallHeight(room);
    $("#room-ceiling").value = room.hasCeiling === null ? "inherit" : (room.hasCeiling ? "closed" : "open");
    $("#room-ammo-enabled").checked = room.ammoReward.enabled;
    $("#room-ammo-amount").disabled = !room.ammoReward.enabled;
    $("#room-ammo-color").disabled = !room.ammoReward.enabled;
    $("#room-ammo-amount").value = room.ammoReward.amount;
    $("#room-ammo-color").value = room.ammoReward.color;
    $("#room-radio-enabled").checked = room.radio.enabled;
    $("#room-radio-corner").disabled = !room.radio.enabled;
    $("#room-radio-corner").value = room.radio.corner;
    document.querySelectorAll("#room-dialog .segment").forEach((button) =>
      button.setAttribute("aria-checked", String(button.dataset.role === room.role)));
    renderEntrySummary(room);
    renderRoomMap(room);
    for (const slot of Object.keys(TEXTURE_SLOTS)) {
      renderTextureField($(`[data-texture="${slot}"]`), room.textures[slot]);
    }
  }

  function renderEntrySummary(room) {
    if (room.role === "start") {
      $("#entry-summary").textContent = `Aparece mirando al ${WALL_NAMES[degreesToWall(room.facing)]}: entra por el ${WALL_NAMES[room.entry.wall]}.`;
      return;
    }
    $("#entry-summary").textContent = connectionsFor(room.id).length
      ? `Se entra por el ${WALL_NAMES[room.entry.wall]}, viniendo de la sala anterior.`
      : `Sin pasillos: se asume el ${WALL_NAMES[room.entry.wall]}.`;
  }

  /**
   * Plano de la sala dentro del diálogo. Se dibuja en un lienzo fijo de 100×100
   * para que las etiquetas conserven su tamaño cualquiera sea la sala, y cada
   * pared relativa a la entrada es un botón que abre el bloque que le toca.
   */
  function renderRoomMap(room) {
    const map = $("#room-map");
    map.setAttribute("viewBox", "0 0 125 100");
    map.replaceChildren();
    const scale = Math.min(105 / room.size.width, 84 / room.size.depth);
    const width = room.size.width * scale;
    const depth = room.size.depth * scale;
    const box = { x: 62.5 - width / 2, y: 50 - depth / 2, width, height: depth };
    map.append(svgElement("rect", { ...box, rx: 2, class: "map-room" }));

    const thickness = 6;
    const wallRect = {
      north: { x: box.x, y: box.y, width, height: thickness },
      south: { x: box.x, y: box.y + depth - thickness, width, height: thickness },
      west: { x: box.x, y: box.y, width: thickness, height: depth },
      east: { x: box.x + width - thickness, y: box.y, width: thickness, height: depth }
    };

    const mapWave = room.waves[Math.min(dialogWaveIndex, room.waves.length - 1)];
    for (const [slot, label] of Object.entries(SLOT_LABELS)) {
      const config = mapWave.blocks[slot];
      const wall = RELATIVE_WALLS[room.entry.wall][slot];
      const rect = wallRect[wall];
      const group = svgElement("g", {
        class: `map-slot${config.enabled ? " active" : ""}`,
        "data-slot": slot,
        role: "button",
        tabindex: "0"
      });
      const tooltip = svgElement("title");
      tooltip.textContent = `${label} · pared ${WALL_NAMES[wall]} · ${config.enabled ? `${blockTotal(config)} ventanas` : "sin bloque"}`;
      group.append(tooltip);
      const shape = svgElement("rect", { ...rect, rx: 1.5, class: "map-slot-shape" });
      if (config.enabled) shape.style.fill = config.color;
      group.append(shape);
      const center = { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
      const text = svgElement("text", { x: center.x, y: center.y, class: "map-slot-label" });
      if (wall === "east" || wall === "west") {
        text.setAttribute("transform", `rotate(${wall === "west" ? -90 : 90} ${center.x} ${center.y})`);
      }
      text.textContent = config.enabled
        ? `${SLOT_SHORT[slot]} · ${config.layers.map(layerTotal).join("›")}`
        : `${SLOT_SHORT[slot]} +`;
      group.append(text);
      map.append(group);
    }

    const door = {
      north: { x: 62.5, y: box.y },
      south: { x: 62.5, y: box.y + depth },
      east: { x: box.x + width, y: 50 },
      west: { x: box.x, y: 50 }
    }[room.entry.wall];
    const horizontal = room.entry.wall === "north" || room.entry.wall === "south";
    map.append(svgElement("line", {
      x1: door.x - (horizontal ? 9 : 0),
      y1: door.y - (horizontal ? 0 : 9),
      x2: door.x + (horizontal ? 9 : 0),
      y2: door.y + (horizontal ? 0 : 9),
      class: "map-door"
    }));

    if (room.role === "start") {
      const radians = (room.facing * Math.PI) / 180;
      const tip = { x: 62.5 + Math.sin(radians) * 16, y: 50 - Math.cos(radians) * 16 };
      map.append(
        svgElement("path", { d: `M 62.5 50 L ${tip.x} ${tip.y}`, class: "map-facing" }),
        svgElement("circle", { cx: tip.x, cy: tip.y, r: 2.4, class: "map-facing-head" })
      );
    }
  }

  // ------------------------------------------------------------- construcción

  function makeSkyOptions() {
    const select = $("#level-sky");
    for (const [id, label] of Object.entries(SKY_LABELS)) {
      const option = document.createElement("option");
      option.value = id;
      option.textContent = label;
      select.append(option);
    }
  }

  function makeTextureEditors() {
    // Los mismos cinco campos para la sala y para los predeterminados del
    // nivel; el atributo distingue a quién le escribe el selector.
    for (const [containerId, attribute] of [["#texture-fields", "data-texture"], ["#level-texture-fields", "data-texture-level"]]) {
      const container = $(containerId);
      for (const [slot, label] of Object.entries(TEXTURE_SLOTS)) {
        const field = document.createElement("div");
        field.className = "texture-field";
        field.innerHTML = `${label}<button type="button" class="texture-field-button" ${attribute}="${slot}">` +
          `<img class="texture-field-thumb" alt="" hidden><span class="texture-field-name">Sin textura</span></button>`;
        container.append(field);
      }
    }
  }

  function refreshConnectionsForRoom(roomId) {
    for (const connection of connectionsFor(roomId)) refreshConnectionWalls(connection);
  }

  /**
   * Re-deriva las paredes que perfora el pasillo; con puntos intermedios, la
   * puerta de cada extremo mira al punto vecino. Devuelve si algo cambió, para
   * que el arrastre en vivo sepa cuándo redibujar también las salas.
   */
  function refreshConnectionWalls(connection) {
    const from = roomById(connection.fromRoomId);
    const to = roomById(connection.toRoomId);
    if (!from || !to) return false;
    const walls = chooseConnectionWalls(from, to, connection.waypoints);
    const changed = walls.fromWall !== connection.fromWall || walls.toWall !== connection.toWall;
    Object.assign(connection, walls);
    return changed;
  }

  function connectModeActive() {
    return $("#connect-mode").getAttribute("aria-pressed") === "true";
  }

  function setConnectMode(active) {
    $("#connect-mode").setAttribute("aria-pressed", String(active));
    connectSourceId = null;
    $("#connect-help").textContent = active ? "Elegí la sala de origen y después la de destino." : "";
    renderRooms();
  }

  function selectOrConnect(roomId) {
    if (!connectModeActive()) {
      selectedRoomId = roomId;
      render();
      return;
    }
    if (!connectSourceId) {
      connectSourceId = roomId;
      $("#connect-help").textContent = "Ahora elegí la sala de destino.";
      renderRooms();
      return;
    }
    if (connectSourceId === roomId) return;
    const from = roomById(connectSourceId);
    const to = roomById(roomId);
    const duplicate = level.connections.some((connection) =>
      (connection.fromRoomId === from.id && connection.toRoomId === to.id) ||
      (connection.fromRoomId === to.id && connection.toRoomId === from.id));
    if (!duplicate) level.connections.push(createConnection(from, to, level.defaults.corridorWidth));
    connectSourceId = null;
    selectedRoomId = roomId;
    $("#connect-help").textContent = "Elegí otra sala de origen o apagá el modo.";
    commit(duplicate ? "Las salas ya estaban unidas" : "Salas unidas por un pasillo");
  }

  function clientToSvg(event) {
    const point = svg.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    return point.matrixTransform(svg.getScreenCTM().inverse());
  }

  function showToast(message) {
    const toast = $("#toast");
    toast.textContent = message;
    toast.classList.add("visible");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove("visible"), 1800);
  }

  function jsonText() {
    return `${JSON.stringify(level, null, 2)}\n`;
  }

  function safeFilename() {
    const slug = level.name.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
      .replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
    return `${slug || "nivel"}.json`;
  }

  async function saveWithPicker() {
    if (!("showSaveFilePicker" in window)) {
      downloadJson();
      showToast("El navegador descargó el JSON");
      return;
    }
    try {
      saveHandle ||= await window.showSaveFilePicker({
        suggestedName: safeFilename(),
        types: [{ description: "Nivel JSON", accept: { "application/json": [".json"] } }]
      });
      const writable = await saveHandle.createWritable();
      await writable.write(jsonText());
      await writable.close();
      showToast("Nivel guardado");
    } catch (error) {
      if (error.name !== "AbortError") showToast("No se pudo guardar el archivo");
    }
  }

  function downloadJson() {
    const blob = new Blob([jsonText()], { type: "application/json" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = safeFilename();
    link.click();
    URL.revokeObjectURL(link.href);
  }

  function replaceLevel(next, message, file = "") {
    level = next;
    selectedRoomId = level.rooms[0]?.id || null;
    dialogRoomId = null;
    connectSourceId = null;
    saveHandle = null;
    roomDialog.close();
    fitView();
    commit(message);
    setCurrentFile(file);
    dirty = false;
  }

  // --- Window Workshop ---------------------------------------------------------
  // Pestaña "Ventanas": diseños custom con variantes estéticas sobre una familia
  // existente. La familia decide cómo se juega; la variante, cómo se ve. Todo lo
  // que depende de la familia sale de WindowFormat.BASES: agregar una familia
  // nueva es una entrada de datos ahí y otra en window_catalog.gd, nada acá.

  // Textos de la escena real de cada base, para que el preview muestre lo que el
  // jugador vería si la variante no pisa nada.
  const BASE_PREVIEW = {
    close: { title: "Aviso", buttons: ["Cerrar"] },
    shutdown: { title: "Salir", message: "Presione Finalizar para salir.", buttons: ["Finalizar"] },
    popup: { title: "Oportunidad unica", message: "CONVERTI TU DEUDA EN UNA OPORTUNIDAD", subtitle: "Trabaja mientras dormis. Dormi mientras trabajas.", buttons: ["SKIP"], ad: true },
    "popup-slow": { title: "Felicitaciones", message: "SOS EL VISITANTE UN MILLON", subtitle: "Tu premio ya fue descontado de tu sueldo.", buttons: ["SKIP"], ad: true },
    download: { title: "Descargando", message: "actualizacion.exe", buttons: ["Cancelar"], progress: true },
    "infected-download": { title: "Descargando", message: "factura_impaga.exe", buttons: ["Cancelar"], progress: true },
    firewall: { title: "Firewall activo", message: "Protegiendo las ventanas de este bloque.", buttons: ["Desactivar"] },
    "critical-error": { title: "Error critico", message: "La aplicacion dejo de responder.", buttons: ["Reintentar", "Cerrar", "Depurar"] }
  };

  const currentDesign = () => windowDesigns.designs.find((design) => design.id === selectedDesignId) || null;

  function setWorkshopTab(tab) {
    const windows = tab === "windows";
    document.body.classList.toggle("windows-mode", windows);
    $("#tab-levels").setAttribute("aria-selected", String(!windows));
    $("#tab-windows").setAttribute("aria-selected", String(windows));
    $("#level-workspace").hidden = windows;
    $("#window-workshop").hidden = !windows;
    if (windows) renderWindowWorkshop();
    else render();
  }

  /** Toda mutación de los diseños pasa por acá: respaldo local y redibujo. */
  function commitDesigns() {
    designsDirty = true;
    if (!workshopApi) localStorage.setItem(WINDOW_DESIGNS_KEY, JSON.stringify(windowDesigns));
    renderWindowWorkshop();
  }

  function updateDesignsSaveButton() {
    const button = $("#save-window-designs");
    button.textContent = designsDirty ? "Guardar •" : "Guardar";
    button.title = workshopApi
      ? "Guarda level_designs/window-designs.json, que es lo que lee el juego"
      : "Sin servidor: guarda un borrador en el navegador";
  }

  async function loadWindowDesigns() {
    let raw = null;
    try {
      raw = workshopApi
        ? await apiJson("/api/window-designs")
        : JSON.parse(localStorage.getItem(WINDOW_DESIGNS_KEY) || "null");
    } catch (error) {
      console.warn("No se pudieron leer los diseños de ventana", error);
    }
    windowDesigns = normalizeWindowDesigns(raw);
    if (!currentDesign()) selectedDesignId = windowDesigns.designs[0]?.id || null;
    designsDirty = false;
    renderWindowWorkshop();
    render();
  }

  async function saveWindowDesigns() {
    const before = windowDesigns.designs.length;
    windowDesigns = normalizeWindowDesigns(windowDesigns);
    const dropped = before - windowDesigns.designs.length;
    if (!currentDesign()) selectedDesignId = windowDesigns.designs[0]?.id || null;
    try {
      if (workshopApi) {
        await apiJson("/api/window-designs", { method: "PUT", body: JSON.stringify(windowDesigns) });
      } else {
        localStorage.setItem(WINDOW_DESIGNS_KEY, JSON.stringify(windowDesigns));
      }
      designsDirty = false;
      // Descartar en silencio sería mentirle al usuario: si algo quedó afuera
      // del archivo, el guardado lo dice.
      showToast(dropped
        ? `Guardado, pero ${dropped} diseño(s) inválidos quedaron afuera`
        : (workshopApi ? "Guardado: window-designs.json" : "Diseños guardados como borrador local"));
    } catch (error) {
      showToast(`No se pudieron guardar los diseños: ${error.message}`);
    }
    renderWindowWorkshop();
    render();
  }

  /** Cuántas ventanas del nivel actual usan un tipo, para avisar antes de borrar. */
  function countTypeInLevel(type) {
    let count = 0;
    for (const room of level.rooms) {
      for (const block of roomBlocks(room)) {
        for (const layer of block.layers) count += layer.windows[type] || 0;
      }
    }
    return count;
  }

  function createDesign() {
    const answer = window.prompt("Nombre del diseño de ventana:", "");
    if (answer === null) return;
    const design = blankDesign(answer);
    // El slug nace del nombre y queda congelado: es lo que los niveles
    // referencian, y renombrar el diseño no puede romperlos.
    const base = design.slug;
    let candidate = base;
    let suffix = 2;
    while (windowDesigns.designs.some((entry) => entry.slug === candidate)) candidate = `${base}-${suffix++}`;
    design.slug = candidate;
    windowDesigns.designs.push(design);
    selectedDesignId = design.id;
    commitDesigns();
    showToast(`Diseño creado: ${customTypeKey(design)}`);
  }

  function deleteDesign(design) {
    const used = countTypeInLevel(customTypeKey(design));
    const warning = used ? ` El nivel actual lo usa en ${used} ventana(s), que pasarán a normales.` : "";
    if (!window.confirm(`¿Eliminar el diseño “${design.name}”?${warning}`)) return;
    windowDesigns.designs = windowDesigns.designs.filter((entry) => entry.id !== design.id);
    if (selectedDesignId === design.id) selectedDesignId = windowDesigns.designs[0]?.id || null;
    commitDesigns();
    render();
    showToast("Diseño eliminado");
  }

  function renderWindowWorkshop() {
    renderDesignList();
    renderDesignEditor();
    updateDesignsSaveButton();
  }

  function renderDesignList() {
    const list = $("#design-list");
    list.replaceChildren();
    const designs = windowDesigns.designs;
    $("#design-count").textContent = designs.length ? String(designs.length) : "";
    $("#design-help").textContent = designs.length
      ? "En el editor de capas aparecen con la clave custom:."
      : "Un diseño agrupa variantes estéticas de una misma ventana.";
    for (const design of designs) {
      const item = document.createElement("li");
      item.className = `room-item${design.id === selectedDesignId ? " selected" : ""}`;
      const button = document.createElement("button");
      button.type = "button";
      button.className = "room-item-button";
      const name = document.createElement("span");
      name.className = "room-item-name";
      name.textContent = design.name;
      const meta = document.createElement("span");
      meta.className = "template-item-meta";
      const familyMeta = WINDOW_TYPES[design.family];
      meta.textContent = `${familyMeta ? familyMeta.glyph : "?"} · ${design.variants.length} var.`;
      button.append(name, meta);
      button.title = customTypeKey(design);
      button.addEventListener("click", () => {
        selectedDesignId = design.id;
        renderWindowWorkshop();
      });
      item.append(button);
      list.append(item);
    }
  }

  function renderDesignEditor() {
    const design = currentDesign();
    $("#design-editor").hidden = !design;
    $("#design-empty").textContent = design ? "" : "Creá un diseño o elegí uno de la lista.";
    if (!design) return;
    const nameInput = $("#design-name");
    if (document.activeElement !== nameInput) nameInput.value = design.name;
    $("#design-key").textContent = customTypeKey(design);
    $("#design-family").value = design.family;
    const familyMeta = WINDOW_TYPES[design.family];
    $("#design-family-hint").textContent = familyMeta
      ? `${familyMeta.label}: ${familyMeta.hint} Las variantes sólo cambian cómo se ve.`
      : "";
    const container = $("#variant-list");
    container.replaceChildren();
    design.variants.forEach((variant, index) => container.append(variantCard(design, variant, index)));
    $("#add-variant").disabled = false;
  }

  function variantCard(design, variant, index) {
    const card = document.createElement("article");
    card.className = "variant-card";
    const bases = BASES[design.family] || {};
    const baseIds = Object.keys(bases);
    const meta = baseMeta(design.family, variant.base) || bases[baseIds[0]] || { size: { width: 300, height: 150 }, fields: ["title"] };

    const fields = document.createElement("div");
    fields.className = "variant-fields";

    const head = document.createElement("header");
    head.className = "variant-head";
    const title = document.createElement("strong");
    title.textContent = `Variante ${index + 1}`;
    head.append(title);
    if (baseIds.length > 1) {
      const baseSelect = document.createElement("select");
      baseSelect.className = "variant-base";
      baseSelect.title = "Escena base de esta variante";
      for (const id of baseIds) {
        const option = document.createElement("option");
        option.value = id;
        option.textContent = bases[id].label;
        baseSelect.append(option);
      }
      baseSelect.value = variant.base;
      baseSelect.addEventListener("change", () => {
        design.variants[index] = normalizeVariant({ ...variant, base: baseSelect.value }, design.family);
        commitDesigns();
      });
      head.append(baseSelect);
    }
    // La skin re-viste el chrome de la ventana (tema, marco, barra y X) sin
    // tocar el comportamiento ni el layout de la familia.
    const skinSelect = document.createElement("select");
    skinSelect.className = "variant-base";
    skinSelect.title = "Skin del chrome de la ventana";
    const nativeSkin = document.createElement("option");
    nativeSkin.value = "";
    nativeSkin.textContent = `Skin de la base (${SKINS[meta.skin]?.label || meta.skin})`;
    skinSelect.append(nativeSkin);
    for (const [id, skin] of Object.entries(SKINS)) {
      const option = document.createElement("option");
      option.value = id;
      option.textContent = skin.label;
      skinSelect.append(option);
    }
    skinSelect.value = SKINS[variant.skin] ? variant.skin : "";
    skinSelect.addEventListener("change", () => {
      variant.skin = skinSelect.value;
      designsDirty = true;
      updateDesignsSaveButton();
      refreshPreview();
    });
    head.append(skinSelect);
    const spacer = document.createElement("span");
    spacer.className = "spacer";
    const clone = document.createElement("button");
    clone.type = "button";
    clone.className = "icon-button";
    clone.textContent = "⧉";
    clone.title = "Duplicar esta variante";
    clone.addEventListener("click", () => {
      design.variants.splice(index + 1, 0, duplicateVariant(variant));
      commitDesigns();
    });
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "icon-button danger";
    remove.textContent = "×";
    remove.title = "Quitar esta variante";
    remove.disabled = design.variants.length <= 1;
    remove.addEventListener("click", () => {
      design.variants.splice(index, 1);
      commitDesigns();
    });
    head.append(spacer, clone, remove);
    fields.append(head);

    // El preview se refresca solo mientras se tipea; el resto de la tarjeta no
    // se toca para no perder el foco del campo.
    let preview = variantPreview(design, variant);
    const refreshPreview = () => {
      const next = variantPreview(design, variant);
      preview.replaceWith(next);
      preview = next;
    };

    const textFields = [
      { key: "title", label: "Título" },
      { key: "message", label: meta.messageLabel || "Mensaje" },
      { key: "subtitle", label: meta.subtitleLabel || "Bajada" }
    ].filter((field) => (meta.fields || []).includes(field.key));
    for (const field of textFields) {
      const label = document.createElement("label");
      label.textContent = field.label;
      const input = field.key === "title" ? document.createElement("input") : document.createElement("textarea");
      if (field.key === "title") input.type = "text";
      else input.rows = 2;
      input.maxLength = field.key === "title" ? 60 : 200;
      input.value = variant[field.key] || "";
      input.placeholder = BASE_PREVIEW[variant.base]?.[field.key] || "El de la escena";
      input.addEventListener("input", () => {
        variant[field.key] = input.value;
        designsDirty = true;
        updateDesignsSaveButton();
        refreshPreview();
      });
      label.append(input);
      fields.append(label);
    }

    const sizeRow = document.createElement("div");
    sizeRow.className = "variant-size";
    const sizeLabel = document.createElement("span");
    sizeLabel.className = "variant-size-label";
    sizeLabel.textContent = "Tamaño (px)";
    sizeLabel.title = `Vacío usa el de la base (${meta.size.width}×${meta.size.height}). Se acota a ${SIZE_LIMITS.width.min}–${SIZE_LIMITS.width.max} × ${SIZE_LIMITS.height.min}–${SIZE_LIMITS.height.max}.`;
    const widthInput = document.createElement("input");
    const heightInput = document.createElement("input");
    for (const [input, axis] of [[widthInput, "width"], [heightInput, "height"]]) {
      input.type = "number";
      input.min = String(SIZE_LIMITS[axis].min);
      input.max = String(SIZE_LIMITS[axis].max);
      input.step = "10";
      input.placeholder = String(meta.size[axis]);
      input.value = variant.size ? String(variant.size[axis]) : "";
      input.addEventListener("change", () => {
        const width = Number(widthInput.value);
        const height = Number(heightInput.value);
        const size = (widthInput.value === "" && heightInput.value === "")
          ? null
          : { width: Number.isFinite(width) && widthInput.value !== "" ? width : meta.size.width,
              height: Number.isFinite(height) && heightInput.value !== "" ? height : meta.size.height };
        design.variants[index] = normalizeVariant({ ...variant, size }, design.family);
        commitDesigns();
      });
    }
    sizeRow.append(sizeLabel, widthInput, document.createTextNode("×"), heightInput);
    fields.append(sizeRow);

    card.append(fields, preview);
    return card;
  }

  /** Maqueta CSS de la ventana, a escala. Aproximada a propósito: el preview
   * fiel es el juego (Block Lab, F4); acá alcanza con leer los textos puestos. */
  function variantPreview(design, variant) {
    const meta = baseMeta(design.family, variant.base) || { size: { width: 300, height: 150 }, fields: ["title"] };
    const preset = BASE_PREVIEW[variant.base] || { title: "Ventana", buttons: ["Aceptar"] };
    const size = variantSize(variant, design.family);
    const skin = variantSkin(variant, design.family);
    const scale = 0.8;
    const box = document.createElement("div");
    box.className = `win-preview${skin === "retro" ? " retro" : ""}`;
    box.style.width = `${Math.round(size.width * scale)}px`;
    box.style.height = `${Math.round(size.height * scale)}px`;

    const bar = document.createElement("div");
    bar.className = "win-preview-titlebar";
    const barText = document.createElement("span");
    barText.textContent = variant.title || preset.title;
    const cross = document.createElement("i");
    cross.textContent = "×";
    bar.append(barText, cross);
    box.append(bar);

    const body = document.createElement("div");
    body.className = `win-preview-body${preset.ad ? " ad" : ""}`;
    if ((meta.fields || []).includes("message")) {
      const message = document.createElement("p");
      message.className = "win-preview-message";
      message.textContent = variant.message || preset.message || "";
      body.append(message);
    }
    if ((meta.fields || []).includes("subtitle")) {
      const subtitle = document.createElement("p");
      subtitle.className = "win-preview-subtitle";
      subtitle.textContent = variant.subtitle || preset.subtitle || "";
      body.append(subtitle);
    }
    if (preset.progress) {
      const track = document.createElement("div");
      track.className = "win-preview-progress";
      const fill = document.createElement("i");
      track.append(fill);
      body.append(track);
    }
    const buttonRow = document.createElement("div");
    buttonRow.className = "win-preview-buttons";
    for (const text of preset.buttons) {
      const fake = document.createElement("span");
      fake.textContent = text;
      buttonRow.append(fake);
    }
    body.append(buttonRow);
    box.append(body);
    return box;
  }

  function makeFamilyOptions() {
    const select = $("#design-family");
    for (const family of FAMILIES) {
      const option = document.createElement("option");
      option.value = family;
      option.textContent = WINDOW_TYPES[family] ? WINDOW_TYPES[family].label : family;
      select.append(option);
    }
  }

  function bindWindowWorkshop() {
    $("#tab-levels").addEventListener("click", () => setWorkshopTab("levels"));
    $("#tab-windows").addEventListener("click", () => setWorkshopTab("windows"));
    $("#new-design").addEventListener("click", createDesign);
    $("#save-window-designs").addEventListener("click", saveWindowDesigns);
    $("#design-name").addEventListener("input", (event) => {
      const design = currentDesign();
      if (!design) return;
      design.name = event.target.value;
      designsDirty = true;
      renderDesignList();
      updateDesignsSaveButton();
    });
    $("#design-key").addEventListener("click", async () => {
      const design = currentDesign();
      if (!design) return;
      try {
        await navigator.clipboard.writeText(customTypeKey(design));
        showToast("Clave copiada");
      } catch (error) {
        showToast(customTypeKey(design));
      }
    });
    $("#design-family").addEventListener("change", (event) => {
      const design = currentDesign();
      if (!design || !FAMILIES.includes(event.target.value)) return;
      design.family = event.target.value;
      // Las bases son por familia: cada variante cae en una base válida de la nueva.
      design.variants = design.variants.map((variant) => normalizeVariant(variant, design.family));
      commitDesigns();
      render();
    });
    $("#delete-design").addEventListener("click", () => {
      const design = currentDesign();
      if (design) deleteDesign(design);
    });
    $("#add-variant").addEventListener("click", () => {
      const design = currentDesign();
      if (!design) return;
      // La variante nueva copia la última: crear una variante suele ser cambiar
      // un texto, no arrancar de cero.
      const last = design.variants[design.variants.length - 1];
      design.variants.push(last ? duplicateVariant(last) : blankVariant(design.family));
      commitDesigns();
    });
  }

  // --- Servidor del Workshop --------------------------------------------------

  const levelResPath = (file) => `res://level_designs/levels/${file}`;

  function setCurrentFile(file) {
    currentFile = file;
    localStorage.setItem(FILE_KEY, file);
    renderCurrentFile();
  }

  function renderCurrentFile() {
    $("#current-file").textContent = workshopApi ? currentFile : "";
  }

  async function detectWorkshopApi() {
    try {
      const response = await fetch("/api/levels", { cache: "no-store" });
      workshopApi = response.ok;
    } catch (error) {
      workshopApi = false;
    }
    $("#open-file").hidden = !workshopApi;
    $("#open-sequence").hidden = !workshopApi;
    renderCurrentFile();
    await loadRoomTemplates();
    await loadWindowDesigns();
  }

  async function apiJson(url, options = {}) {
    const response = await fetch(url, { cache: "no-store", ...options });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Error ${response.status}`);
    return payload;
  }

  async function fetchSequence() {
    const payload = await apiJson("/api/sequence");
    return { schemaVersion: 1, ...payload, levels: Array.isArray(payload.levels) ? payload.levels : [] };
  }

  async function putSequence(sequence) {
    await apiJson("/api/sequence", { method: "PUT", body: JSON.stringify(sequence) });
  }

  function confirmDiscard() {
    return !dirty || !level.rooms.length ||
      window.confirm("Hay cambios sin guardar en el nivel actual. ¿Continuar igual?");
  }

  async function saveLevel() {
    if (!workshopApi) {
      saveWithPicker();
      return;
    }
    let file = currentFile;
    const isNew = !file;
    if (isNew) {
      const answer = window.prompt("Guardar en level_designs/levels/ como:", safeFilename());
      if (answer === null) return;
      file = answer.trim() || safeFilename();
      if (!file.toLowerCase().endsWith(".json")) file += ".json";
    }
    try {
      await apiJson(`/api/levels/${encodeURIComponent(file)}`, { method: "PUT", body: jsonText() });
    } catch (error) {
      showToast(`No se pudo guardar: ${error.message}`);
      return;
    }
    setCurrentFile(file);
    dirty = false;
    showToast(`Guardado: ${file}`);
    await syncSequence(file, isNew);
  }

  /** Mantiene level-sequence.json al día: sincroniza el id de un nivel ya
   * registrado (el juego rechaza ids desparejos) y ofrece sumar los nuevos. */
  async function syncSequence(file, offerAdd) {
    try {
      const sequence = await fetchSequence();
      const entry = sequence.levels.find((item) => item.path === levelResPath(file));
      if (entry) {
        if (entry.id !== level.id) {
          entry.id = level.id;
          await putSequence(sequence);
          showToast("Secuencia sincronizada con el nuevo id");
        }
        return;
      }
      if (offerAdd && window.confirm(`¿Agregar “${level.name}” al final de la secuencia del juego?`)) {
        sequence.levels.push({ id: level.id, path: levelResPath(file) });
        await putSequence(sequence);
        showToast("Agregado a la secuencia");
      }
    } catch (error) {
      showToast(error.message);
    }
  }

  async function openWorkshopDialog() {
    const dialog = $("#open-dialog");
    $("#open-list").replaceChildren();
    $("#open-empty").textContent = "Cargando…";
    dialog.showModal();
    let levels = [];
    let sequence = { levels: [] };
    try {
      levels = (await apiJson("/api/levels")).levels || [];
      sequence = await fetchSequence().catch(() => ({ levels: [] }));
    } catch (error) {
      $("#open-empty").textContent = "No se pudo leer level_designs/levels/.";
      return;
    }
    $("#open-empty").textContent = levels.length ? "" : "Todavía no hay niveles guardados.";
    const order = new Map(sequence.levels.map((entry, index) => [entry.path, index + 1]));
    for (const item of levels) {
      const row = document.createElement("li");
      row.className = "file-row";
      const main = document.createElement("button");
      main.type = "button";
      main.className = "file-row-main";
      const name = document.createElement("span");
      name.className = "file-row-name";
      name.textContent = item.name;
      main.append(name);
      const position = order.get(levelResPath(item.file));
      if (position) {
        const badge = document.createElement("span");
        badge.className = "file-row-badge";
        badge.textContent = `#${position} en secuencia`;
        main.append(badge);
      }
      const meta = document.createElement("span");
      meta.className = "file-row-meta";
      meta.textContent = item.error ? `${item.file} · ${item.error}` : `${item.file} · ${item.rooms} salas`;
      main.append(meta);
      main.disabled = Boolean(item.error);
      main.addEventListener("click", () => openWorkshopLevel(item.file, dialog));
      row.append(main);
      $("#open-list").append(row);
    }
  }

  async function openWorkshopLevel(file, dialog) {
    if (!confirmDiscard()) return;
    try {
      const next = normalizeLevel(await apiJson(`/api/levels/${encodeURIComponent(file)}`));
      dialog.close();
      replaceLevel(next, `Abierto: ${file}`, file);
      showToast(`Abierto: ${file}`);
    } catch (error) {
      showToast(`No se pudo abrir: ${error.message}`);
    }
  }

  async function openSequenceDialog() {
    $("#sequence-dialog").showModal();
    await renderSequenceDialog();
  }

  async function renderSequenceDialog() {
    const list = $("#sequence-list");
    list.replaceChildren();
    $("#sequence-empty").textContent = "Cargando…";
    let sequence;
    let levels = [];
    try {
      sequence = await fetchSequence();
      levels = (await apiJson("/api/levels")).levels || [];
    } catch (error) {
      $("#sequence-empty").textContent = `No se pudo leer la secuencia: ${error.message}`;
      return;
    }
    $("#sequence-empty").textContent = sequence.levels.length ? "" : "La secuencia está vacía: el juego no tiene niveles para encadenar.";
    const byPath = new Map(levels.map((item) => [levelResPath(item.file), item]));
    const mutate = async (change) => {
      const next = { ...sequence, levels: [...sequence.levels] };
      change(next.levels);
      try {
        await putSequence(next);
        setStatus("Secuencia guardada");
      } catch (error) {
        showToast(error.message);
      }
      await renderSequenceDialog();
    };
    sequence.levels.forEach((entry, index) => {
      const meta = byPath.get(entry.path);
      const row = document.createElement("li");
      row.className = "file-row";
      const main = document.createElement("button");
      main.type = "button";
      main.className = "file-row-main";
      main.disabled = !meta;
      const name = document.createElement("span");
      name.className = "file-row-name" + (meta ? "" : " file-row-warning");
      name.textContent = meta ? `${index + 1}. ${meta.name}` : `${index + 1}. Archivo faltante`;
      const metaSpan = document.createElement("span");
      metaSpan.className = "file-row-meta";
      metaSpan.textContent = entry.path.split("/").pop();
      main.append(name, metaSpan);
      if (meta) main.addEventListener("click", () => openWorkshopLevel(meta.file, $("#sequence-dialog")));
      row.append(main);
      const makeAction = (label, title, disabled, action) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "icon-button";
        button.textContent = label;
        button.title = title;
        button.disabled = disabled;
        button.addEventListener("click", action);
        row.append(button);
      };
      makeAction("↑", "Subir", index === 0, () => mutate((items) => items.splice(index - 1, 0, items.splice(index, 1)[0])));
      makeAction("↓", "Bajar", index === sequence.levels.length - 1, () => mutate((items) => items.splice(index + 1, 0, items.splice(index, 1)[0])));
      makeAction("×", "Quitar de la secuencia", false, () => mutate((items) => items.splice(index, 1)));
      list.append(row);
    });
    const addButton = $("#sequence-add-current");
    const alreadyListed = Boolean(currentFile) && sequence.levels.some((entry) => entry.path === levelResPath(currentFile));
    addButton.disabled = !currentFile || alreadyListed;
    addButton.title = !currentFile
      ? "Guardá el nivel primero para poder sumarlo"
      : alreadyListed ? "El nivel actual ya está en la secuencia" : "";
  }

  function bindLevelFields() {
    $("#open-level-dialog").addEventListener("click", openLevelDialog);
    $("#open-summary").addEventListener("click", openLevelDialog);
    $("#level-name").addEventListener("input", (event) => { level.name = event.target.value; commit(); });
    $("#level-description").addEventListener("input", (event) => { level.description = event.target.value; commit(); });
    const updateTimeLimit = () => {
      const minutes = clampInt($("#level-time-minutes").value, { min: 0, max: 60, fallback: 1 });
      const seconds = clampInt($("#level-time-seconds").value, { min: 0, max: 59, fallback: 30 });
      level.timeLimitSeconds = clampInt(minutes * 60 + seconds, LIMITS.timeLimit);
      commit("Tiempo del nivel actualizado");
    };
    $("#level-time-minutes").addEventListener("change", updateTimeLimit);
    $("#level-time-seconds").addEventListener("change", updateTimeLimit);
    $("#level-ammo-magazine").addEventListener("change", (event) => {
      level.startingAmmo.magazine = clampInt(event.target.value, LIMITS.magazine);
      commit("Munición inicial actualizada");
    });
    $("#level-ammo-reserve").addEventListener("change", (event) => {
      level.startingAmmo.reserve = clampInt(event.target.value, LIMITS.reserve);
      commit("Munición inicial actualizada");
    });
    $("#level-crossing-damage").addEventListener("change", (event) => {
      if (event.target.value.trim() === "") {
        delete level.crossingDamage;
        commit("Daño por cruce: el del juego");
      } else {
        level.crossingDamage = clampInt(event.target.value, LIMITS.crossingDamage);
        commit("Daño por cruce actualizado");
      }
      event.target.value = level.crossingDamage ?? "";
    });
    $("#level-wall-height").addEventListener("change", (event) => {
      level.defaults.wallHeight = clamp(event.target.value, LIMITS.wallHeight);
      commit("Altura predeterminada actualizada");
    });
    $("#level-max-block-height").addEventListener("change", (event) => {
      level.defaults.maxBlockHeight = clamp(event.target.value, LIMITS.maxBlockHeight);
      commit("Alto máximo de bloque actualizado");
    });
    $("#level-corridor-width").addEventListener("change", (event) => {
      level.defaults.corridorWidth = clamp(event.target.value, LIMITS.corridorWidth);
      commit("Ancho de pasillo predeterminado actualizado");
    });
    $("#level-has-ceiling").addEventListener("change", (event) => {
      level.defaults.hasCeiling = event.target.checked;
      commit("Techo predeterminado actualizado");
    });
    $("#level-sky").addEventListener("change", (event) => {
      level.sky = SKY_LABELS[event.target.value] ? event.target.value : level.sky;
      commit(`Cielo: ${SKY_LABELS[level.sky].toLowerCase()}`);
    });
  }

  function bindFileActions() {
    const menu = $("#file-menu");
    const closeMenu = () => menu.removeAttribute("open");
    document.addEventListener("click", (event) => {
      if (menu.open && !menu.contains(event.target)) closeMenu();
    });
    menu.querySelectorAll("button, label").forEach((item) => item.addEventListener("click", closeMenu));

    document.querySelectorAll(".room-preset").forEach((button) => button.addEventListener("click", () => {
      const room = createRoom(button.dataset.roomType, level.rooms.length + 1);
      level.rooms.push(room);
      selectedRoomId = room.id;
      commit("Sala agregada");
    }));

    $("#new-level").addEventListener("click", () => {
      if (!confirmDiscard()) return;
      replaceLevel(createEmptyLevel(), "Nivel nuevo");
    });

    $("#load-example").addEventListener("click", () => {
      if (!confirmDiscard()) return;
      replaceLevel(exampleLevel(), "Ejemplo cargado");
    });

    $("#import-file").addEventListener("change", async (event) => {
      const file = event.target.files[0];
      if (!file) return;
      try {
        const next = normalizeLevel(JSON.parse(await file.text()));
        if (!confirmDiscard()) return;
        replaceLevel(next, `Importado: ${file.name}`);
        showToast("Nivel importado");
      } catch (error) {
        showToast(`JSON inválido: ${error.message}`);
      } finally {
        event.target.value = "";
      }
    });

    $("#open-file").addEventListener("click", openWorkshopDialog);
    $("#open-sequence").addEventListener("click", openSequenceDialog);
    $("#sequence-add-current").addEventListener("click", async () => {
      if (!currentFile) return;
      try {
        const sequence = await fetchSequence();
        if (!sequence.levels.some((entry) => entry.path === levelResPath(currentFile))) {
          sequence.levels.push({ id: level.id, path: levelResPath(currentFile) });
          await putSequence(sequence);
          showToast("Agregado a la secuencia");
        }
      } catch (error) {
        showToast(error.message);
      }
      await renderSequenceDialog();
    });
    $("#save-file").addEventListener("click", saveLevel);
    $("#save-as-file").addEventListener("click", () => { saveHandle = null; saveWithPicker(); });
    $("#download-file").addEventListener("click", () => { downloadJson(); showToast("JSON descargado"); });
  }

  function bindCanvas() {
    $("#connect-mode").addEventListener("click", () => setConnectMode(!connectModeActive()));
    $("#zoom-in").addEventListener("click", () => zoomBy(0.8));
    $("#zoom-out").addEventListener("click", () => zoomBy(1.25));
    $("#zoom-fit").addEventListener("click", fitView);

    svg.addEventListener("wheel", (event) => {
      event.preventDefault();
      zoomBy(event.deltaY > 0 ? 1.12 : 0.89, clientToSvg(event));
    }, { passive: false });

    svg.addEventListener("pointerdown", (event) => {
      const handle = event.target.closest(".corridor-waypoint");
      if (handle && event.button === 0) {
        waypointDrag = { connectionId: handle.dataset.connectionId, index: Number(handle.dataset.waypointIndex) };
        svg.setPointerCapture(event.pointerId);
        return;
      }
      const shape = event.target.closest(".corridor-shape");
      if (shape && event.button === 0 && !connectModeActive()) {
        const isSecondClick = corridorClick && corridorClick.id === shape.dataset.connectionId &&
          performance.now() - corridorClick.time < 450 &&
          Math.hypot(event.clientX - corridorClick.clientX, event.clientY - corridorClick.clientY) < 8;
        if (isSecondClick) {
          corridorClick = null;
          addWaypoint(shape.dataset.connectionId, clientToSvg(event));
          return;
        }
        corridorClick = { id: shape.dataset.connectionId, time: performance.now(), clientX: event.clientX, clientY: event.clientY };
        // El primer click sigue paneando, como cualquier click en el fondo.
      } else {
        corridorClick = null;
      }
      const group = event.target.closest(".room-group");
      if (!group) {
        const point = clientToSvg(event);
        panState = { x: point.x, y: point.y };
        svg.classList.add("panning");
        svg.setPointerCapture(event.pointerId);
        return;
      }
      const roomId = group.dataset.roomId;
      selectOrConnect(roomId);
      if (connectModeActive()) return;
      const room = roomById(roomId);
      const point = clientToSvg(event);
      dragState = { roomId, dx: point.x - room.position.x, dz: point.y - room.position.z };
      group.classList.add("dragging");
      svg.setPointerCapture(event.pointerId);
    });

    svg.addEventListener("dblclick", (event) => {
      const group = event.target.closest(".room-group");
      if (group && !connectModeActive()) openRoomDialog(group.dataset.roomId);
      // El doble click sobre un pasillo se detecta en pointerdown: acá el
      // target ya viene retargeteado por la captura del paneo.
    });

    // Click derecho sobre un punto intermedio lo quita.
    svg.addEventListener("contextmenu", (event) => {
      const handle = event.target.closest(".corridor-waypoint");
      if (!handle) return;
      event.preventDefault();
      const connection = level.connections.find((item) => item.id === handle.dataset.connectionId);
      if (!connection) return;
      connection.waypoints.splice(Number(handle.dataset.waypointIndex), 1);
      refreshConnectionWalls(connection);
      commit("Punto del pasillo quitado");
    });

    svg.addEventListener("pointermove", (event) => {
      if (waypointDrag) {
        const connection = level.connections.find((item) => item.id === waypointDrag.connectionId);
        const waypoint = connection?.waypoints[waypointDrag.index];
        if (waypoint) {
          const point = clientToSvg(event);
          waypoint.x = snapHalf(point.x);
          waypoint.z = snapHalf(point.y);
          // Arrastrar el punto vecino a una sala puede cambiar de pared la
          // puerta: las salas también se redibujan para mover su marca.
          if (refreshConnectionWalls(connection)) {
            resolveEntryWalls(level);
            renderRooms();
          }
          renderCorridors();
        }
        return;
      }
      if (panState) {
        const point = clientToSvg(event);
        view.x -= point.x - panState.x;
        view.y -= point.y - panState.y;
        applyView();
        return;
      }
      if (!dragState) return;
      const room = roomById(dragState.roomId);
      const point = clientToSvg(event);
      room.position.x = Math.round((point.x - dragState.dx) / level.gridSize) * level.gridSize;
      room.position.z = Math.round((point.y - dragState.dz) / level.gridSize) * level.gridSize;
      refreshConnectionsForRoom(dragState.roomId);
      resolveEntryWalls(level);
      renderCorridors();
      renderRooms();
    });

    const endPointer = (event) => {
      if (svg.hasPointerCapture(event.pointerId)) svg.releasePointerCapture(event.pointerId);
      if (waypointDrag) {
        waypointDrag = null;
        commit("Recorrido del pasillo ajustado");
        return;
      }
      if (panState) {
        panState = null;
        svg.classList.remove("panning");
        return;
      }
      if (!dragState) return;
      refreshConnectionsForRoom(dragState.roomId);
      dragState = null;
      commit("Posición actualizada");
    };
    svg.addEventListener("pointerup", endPointer);
    svg.addEventListener("pointercancel", endPointer);
    window.addEventListener("resize", syncViewAspect);
  }

  function bindDialogs() {
    document.querySelectorAll("[data-close-dialog]").forEach((button) =>
      button.addEventListener("click", () => button.closest("dialog").close()));
    // El fondo de un diálogo modal es el propio elemento: un click ahí lo cierra.
    for (const dialog of [levelDialog, roomDialog, $("#open-dialog"), $("#sequence-dialog"), $("#texture-dialog")]) {
      dialog.addEventListener("pointerdown", (event) => {
        if (event.target === dialog) dialog.close();
      });
    }
    roomDialog.addEventListener("close", () => {
      dialogRoomId = null;
    });
  }

  function bindRoomFields() {
    document.querySelectorAll("#room-dialog .segment").forEach((button) => button.addEventListener("click", () => {
      const room = dialogRoom();
      if (!room) return;
      assignRole(level.rooms, room, button.dataset.role);
      commit(`Sala marcada como ${ROLE_LABELS[button.dataset.role].toLowerCase()}`);
    }));

    document.querySelectorAll(".compass-point").forEach((button) => button.addEventListener("click", () => {
      const room = dialogRoom();
      if (!room) return;
      room.facing = Number(button.dataset.facing);
      commit("Orientación inicial actualizada");
    }));

    const roomFields = {
      "#room-name": (room, value) => { room.name = value; },
      "#room-width": (room, value) => { room.size.width = Number(value); room.type = "custom"; },
      "#room-depth": (room, value) => { room.size.depth = Number(value); room.type = "custom"; },
      "#room-x": (room, value) => { room.position.x = Number(value); },
      "#room-z": (room, value) => { room.position.z = Number(value); }
    };
    for (const [selector, update] of Object.entries(roomFields)) {
      $(selector).addEventListener("input", (event) => {
        const room = dialogRoom();
        if (!room) return;
        update(room, event.target.value);
        refreshConnectionsForRoom(room.id);
        commit();
      });
    }

    $("#room-type").addEventListener("change", (event) => {
      const room = dialogRoom();
      const preset = ROOM_PRESETS[event.target.value];
      if (!room || !preset) return;
      room.type = event.target.value;
      if (room.type !== "custom") room.size = { width: preset.width, depth: preset.depth };
      refreshConnectionsForRoom(room.id);
      commit("Tipo de sala actualizado");
    });

    $("#room-wall-height-mode").addEventListener("change", (event) => {
      const room = dialogRoom();
      if (!room) return;
      room.wallHeight = event.target.value === "inherit" ? null : level.defaults.wallHeight;
      commit("Altura de la sala actualizada");
    });

    $("#room-wall-height").addEventListener("change", (event) => {
      const room = dialogRoom();
      if (!room) return;
      room.wallHeight = clamp(event.target.value, LIMITS.wallHeight);
      commit("Altura de la sala actualizada");
    });

    $("#room-ceiling").addEventListener("change", (event) => {
      const room = dialogRoom();
      if (!room) return;
      room.hasCeiling = event.target.value === "inherit" ? null : event.target.value === "closed";
      commit(room.hasCeiling === false ? "Sala a cielo abierto" : "Techo actualizado");
    });

    $("#room-ammo-enabled").addEventListener("change", (event) => {
      const room = dialogRoom();
      if (!room) return;
      room.ammoReward.enabled = event.target.checked;
      commit("Recompensa actualizada");
    });

    $("#room-ammo-amount").addEventListener("change", (event) => {
      const room = dialogRoom();
      if (!room) return;
      room.ammoReward.amount = clampInt(event.target.value, LIMITS.ammoReward);
      commit("Recompensa actualizada");
    });

    $("#room-ammo-color").addEventListener("change", (event) => {
      const room = dialogRoom();
      if (!room) return;
      room.ammoReward.color = event.target.value;
      commit("Recompensa actualizada");
    });

    const cornerSelect = $("#room-radio-corner");
    for (const corner of LevelFormat.RADIO_CORNERS) {
      const option = document.createElement("option");
      option.value = corner;
      option.textContent = `${LevelFormat.RADIO_CORNER_LABELS[corner]} (${corner.toUpperCase()})`;
      cornerSelect.append(option);
    }

    $("#room-radio-enabled").addEventListener("change", (event) => {
      const room = dialogRoom();
      if (!room) return;
      room.radio.enabled = event.target.checked;
      commit(room.radio.enabled ? "Radio agregada" : "Radio quitada");
    });

    cornerSelect.addEventListener("change", (event) => {
      const room = dialogRoom();
      if (!room) return;
      room.radio.corner = LevelFormat.RADIO_CORNERS.includes(event.target.value)
        ? event.target.value : LevelFormat.DEFAULT_RADIO_CORNER;
      commit("Radio movida de esquina");
    });

    const openSlot = (event) => {
      const group = event.target.closest(".map-slot");
      const wave = dialogWave();
      if (!group || !wave) return;
      const block = wave.blocks[group.dataset.slot];
      block.enabled = !block.enabled;
      if (block.enabled && !block.layers.length) block.layers.push(blankLayer());
      commit(block.enabled ? "Bloque activado" : "Bloque apagado");
    };
    $("#room-map").addEventListener("click", openSlot);
    $("#room-map").addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openSlot(event);
      }
    });

    $("#save-template").addEventListener("click", () => {
      const room = dialogRoom();
      if (room) saveTemplateFromRoom(room);
    });

    $("#duplicate-room").addEventListener("click", () => {
      const room = dialogRoom();
      if (!room) return;
      const copy = structuredClone(room);
      copy.id = newId();
      copy.name = `${room.name} (copia)`;
      copy.role = "transition";
      copy.position = { x: room.position.x + room.size.width + 2, z: room.position.z };
      level.rooms.push(copy);
      selectedRoomId = copy.id;
      dialogRoomId = copy.id;
      commit("Sala duplicada");
    });

    for (const slot of Object.keys(TEXTURE_SLOTS)) {
      $(`[data-texture="${slot}"]`).addEventListener("click", () => openTexturePicker(slot));
      $(`[data-texture-level="${slot}"]`).addEventListener("click", () => openTexturePicker(slot, "level"));
    }
    $("#texture-search").addEventListener("input", renderTexturePicker);

    $("#delete-room").addEventListener("click", () => {
      const room = dialogRoom();
      if (!room || !window.confirm(`¿Eliminar ${room.name}?`)) return;
      deleteRoom(room.id);
    });
  }

  function deleteRoom(roomId) {
    level.rooms = level.rooms.filter((item) => item.id !== roomId);
    level.connections = level.connections.filter((connection) =>
      connection.fromRoomId !== roomId && connection.toRoomId !== roomId);
    if (dialogRoomId === roomId) roomDialog.close();
    if (selectedRoomId === roomId) selectedRoomId = level.rooms[0]?.id || null;
    commit("Sala eliminada");
  }

  function bindBlockFields() {
  }

  function bindShortcuts() {
    window.addEventListener("keydown", (event) => {
      const typing = ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName);
      if (event.ctrlKey && event.key.toLowerCase() === "s") {
        event.preventDefault();
        if (document.body.classList.contains("windows-mode")) saveWindowDesigns();
        else saveLevel();
        return;
      }
      if (typing || document.querySelector("dialog[open]")) return;
      if (event.key === "Enter" && selectedRoom()) {
        event.preventDefault();
        openRoomDialog(selectedRoomId);
        return;
      }
      if (event.key === "Delete" && selectedRoom()) {
        event.preventDefault();
        if (window.confirm(`¿Eliminar ${selectedRoom().name}?`)) deleteRoom(selectedRoomId);
        return;
      }
      if (event.key.toLowerCase() === "f") {
        event.preventDefault();
        fitView();
      }
    });
  }

  makeSkyOptions();
  makeTextureEditors();
  makeFamilyOptions();
  bindWindowWorkshop();
  bindLevelFields();
  bindFileActions();
  bindCanvas();
  bindDialogs();
  bindRoomFields();
  bindBlockFields();
  bindShortcuts();
  loadTextureCatalog();
  detectWorkshopApi();
  if (!level.rooms.length) level = exampleLevel();
  selectedRoomId ||= level.rooms[0]?.id || null;
  commit();
  // El arranque no es una edición: recién ensuciamos cuando el usuario toca algo.
  dirty = false;
  // El plano ocupa el alto que le deja el flex, asi que el primer encuadre
  // espera a que el observador informe el tamaño real: encuadrar antes deja el
  // nivel recortado.
  let fitted = false;
  new ResizeObserver(() => {
    syncViewAspect();
    if (fitted) return;
    fitted = true;
    fitView();
  }).observe(svg);
})();
