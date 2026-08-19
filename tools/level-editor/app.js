(() => {
  "use strict";

  const {
    ROOM_PRESETS, ROLE_LABELS, SKY_LABELS, SLOT_LABELS, WINDOW_TYPES, TEXTURE_SLOTS, WALL_LABELS,
    RELATIVE_WALLS, LIMITS, clamp, clampInt, newId, createEmptyLevel, createRoom, createConnection,
    chooseConnectionWalls, degreesToWall, assignRole, normalizeRoles, resolveEntryWalls, normalizeLevel,
    corridorPlan, corridorOutline, blankWave, waveTotal
  } = window.LevelFormat;

  const STORAGE_KEY = "procedural-map.level-workshop.draft.v3";
  const SLOT_SHORT = { left: "IZQ", front: "FRENTE", right: "DER" };
  const WALL_NAMES = { north: "norte", east: "este", south: "sur", west: "oeste" };

  const $ = (selector) => document.querySelector(selector);
  const svg = $("#level-canvas");
  const roomsLayer = $("#rooms-layer");
  const corridorsLayer = $("#corridors-layer");
  const levelDialog = $("#level-dialog");
  const roomDialog = $("#room-dialog");
  const blockDialog = $("#block-dialog");

  let level = loadDraft() || createEmptyLevel();
  let selectedRoomId = level.rooms[0]?.id || null;
  let dialogRoomId = null;
  let dialogSlot = null;
  let connectSourceId = null;
  let dragState = null;
  let panState = null;
  let view = { x: -35, y: -28, width: 70, height: 56 };
  let textureCatalog = [];
  let texturePacks = [];
  let saveHandle = null;
  let toastTimer = null;
  let statusTimer = null;

  function exampleLevel() {
    const result = createEmptyLevel();
    result.id = "f4-three-room-example";
    result.name = "Circuito de tres salas";
    result.description = "Ejemplo editable con sala pequeña, sala grande y pasillo.";
    result.startingAmmo = { magazine: 17, reserve: 34 };
    const configure = (block, waves, movement = "static", color = "#2ed5c5", movementSpeed = 0.65) =>
      Object.assign(block, { enabled: true, waves, movement, color, movementSpeed });
    const a = createRoom("small", 1);
    Object.assign(a, { id: "room-entry", name: "Entrada", role: "start", facing: 90, position: { x: -18, z: 8 } });
    configure(a.blocks.front, [blankWave(4)]);
    const b = createRoom("large", 2);
    Object.assign(b, { id: "room-arena", name: "Arena", position: { x: 4, z: 5 }, wallHeight: 9, hasCeiling: false });
    b.ammoReward = { enabled: true, amount: 40, color: "#f4bc59" };
    configure(b.blocks.left, [blankWave(5)], "static", "#35d4c7");
    configure(b.blocks.front, [blankWave(3), { windows: { normal: 4, firewall: 2 } }], "opposite", "#f4bc59", 0.8);
    configure(b.blocks.right, [blankWave(5)], "static", "#35d4c7");
    const c = createRoom("corridor", 3);
    Object.assign(c, { id: "room-corridor", name: "Pasillo de salida", role: "exit", position: { x: 22, z: -11 }, wallHeight: 4 });
    configure(c.blocks.left, [blankWave(4)], "opposite");
    configure(c.blocks.right, [blankWave(4)], "opposite");
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
      : "Sin catálogo: serví el repositorio con un servidor local para elegir texturas.";
    if (roomDialog.open) renderRoomDialog();
  }

  /** Agrupa las texturas por pack para que el desplegable se lea de un vistazo. */
  function fillTextureSelect(select, current) {
    select.replaceChildren();
    const none = document.createElement("option");
    none.value = "";
    none.textContent = "Sin textura";
    select.append(none);
    const grouped = new Map();
    for (const entry of textureCatalog) {
      const id = String(entry?.id ?? "");
      if (!id) continue;
      const pack = String(entry?.pack ?? "otros");
      if (!grouped.has(pack)) grouped.set(pack, []);
      grouped.get(pack).push({ id, label: String(entry?.label ?? id) });
    }
    for (const [pack, entries] of grouped) {
      const group = document.createElement("optgroup");
      const meta = texturePacks.find((item) => item.id === pack);
      group.label = meta ? String(meta.label) : pack;
      for (const entry of entries) {
        const option = document.createElement("option");
        option.value = entry.id;
        option.textContent = entry.label;
        group.append(option);
      }
      select.append(group);
    }
    // Un identificador que no está en el catálogo se conserva en vez de
    // borrarse por elegir de una lista incompleta.
    if (current && !textureCatalog.some((entry) => String(entry?.id) === current)) {
      const orphan = document.createElement("option");
      orphan.value = current;
      orphan.textContent = `${current} (fuera del catálogo)`;
      select.append(orphan);
    }
    select.value = current;
  }

  /** Toda mutación pasa por acá: reconcilia los datos derivados y redibuja. */
  function commit(message = "") {
    normalizeRoles(level.rooms);
    resolveEntryWalls(level);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(level));
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
  const dialogBlock = () => dialogRoom()?.blocks[dialogSlot] || null;

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

  const blockTotal = (block) => block.waves.reduce((total, wave) => total + waveTotal(wave), 0);

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
      corridorsLayer.append(svgElement("path", { d: `M ${points} Z`, class: "corridor-shape" }));
    }
  }

  function addEntryMark(group, room) {
    const point = wallPoint(room, room.entry.wall);
    const horizontal = room.entry.wall === "north" || room.entry.wall === "south";
    const opening = connectionsFor(room.id).find((connection) =>
      (connection.fromRoomId === room.id ? connection.fromWall : connection.toWall) === room.entry.wall);
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
    count.textContent = config.waves.length ? config.waves.map(waveTotal).join("›") : "×";
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

  function roomBadges(room) {
    const badges = [`H ${roomWallHeight(room)} m`];
    if (!roomHasCeiling(room)) badges.push("CIELO ABIERTO");
    if (room.ammoReward.enabled) badges.push(`+${room.ammoReward.amount} BALAS`);
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
      for (const [slot, config] of Object.entries(room.blocks)) addBlock(group, room, slot, config);
      addAmmoReward(group, room);
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
      text.textContent = `${from.name} → ${to.name}`;
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
    let targets = 0;
    let plannedTargets = 0;
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
      for (const block of Object.values(room.blocks)) {
        if (!block.enabled) continue;
        activeBlocks += 1;
        if (block.movement === "opposite") movingBlocks += 1;
        if (!block.waves.length) emptyBlocks += 1;
        waves += block.waves.length;
        for (const wave of block.waves) {
          for (const [type, count] of Object.entries(wave.windows)) {
            windows[type] = (windows[type] || 0) + count;
            targets += count;
            if (WINDOW_TYPES[type].status !== "ready") plannedTargets += count;
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
      targets,
      plannedTargets,
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
      ["Oleadas", `${summary.waves} · ${summary.targets} objetivos`],
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
      const meta = WINDOW_TYPES[type];
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
    if (blockDialog.open) renderBlockDialog();
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
    $("#level-wall-height").value = level.defaults.wallHeight;
    $("#level-max-block-height").value = level.defaults.maxBlockHeight;
    $("#level-corridor-width").value = level.defaults.corridorWidth;
    $("#level-has-ceiling").checked = level.defaults.hasCeiling;
    $("#level-sky").value = level.sky;
  }

  function openRoomDialog(roomId) {
    if (!roomById(roomId)) return;
    dialogRoomId = roomId;
    selectedRoomId = roomId;
    renderRooms();
    renderRoomList();
    renderRoomDialog();
    openDialog(roomDialog);
  }

  function renderRoomDialog() {
    const room = dialogRoom();
    if (!room) {
      roomDialog.close();
      return;
    }
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
    document.querySelectorAll("#room-dialog .segment").forEach((button) =>
      button.setAttribute("aria-checked", String(button.dataset.role === room.role)));
    renderEntrySummary(room);
    renderRoomMap(room);
    for (const slot of Object.keys(TEXTURE_SLOTS)) {
      fillTextureSelect($(`[data-texture="${slot}"]`), room.textures[slot]);
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

    for (const [slot, label] of Object.entries(SLOT_LABELS)) {
      const config = room.blocks[slot];
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
        ? `${SLOT_SHORT[slot]} · ${config.waves.map(waveTotal).join("›")}`
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

  function openBlockDialog(slot) {
    if (!dialogRoom() || !SLOT_LABELS[slot]) return;
    dialogSlot = slot;
    renderBlockDialog();
    openDialog(blockDialog);
  }

  function renderBlockDialog() {
    const room = dialogRoom();
    const block = dialogBlock();
    if (!room || !block) {
      blockDialog.close();
      return;
    }
    const wall = RELATIVE_WALLS[room.entry.wall][dialogSlot];
    $("#block-dialog-eyebrow").textContent = `${room.name.toUpperCase()} · PARED ${WALL_NAMES[wall].toUpperCase()}`;
    $("#block-dialog-title").textContent = `Bloque ${SLOT_LABELS[dialogSlot].toLowerCase()}`;
    $("#block-enabled").checked = block.enabled;
    $("#block-dialog-body").classList.toggle("disabled", !block.enabled);
    $("#block-movement").value = block.movement;
    $("#block-speed").value = block.movementSpeed;
    $("#block-speed-field").hidden = block.movement !== "opposite";
    $("#block-color").value = block.color;
    const total = blockTotal(block);
    $("#wave-summary").textContent = block.waves.length
      ? `${block.waves.length} ${block.waves.length === 1 ? "oleada" : "oleadas"} · ${total} ${total === 1 ? "ventana" : "ventanas"}`
      : "";
    $("#block-dialog-hint").textContent = block.enabled
      ? "El bloque cubre la pared entera, de piso a techo."
      : "Bloque apagado: la pared queda libre.";
    renderWaveList(block);
  }

  function renderWaveList(block) {
    const list = $("#wave-list");
    list.replaceChildren();
    if (!block.waves.length) {
      const empty = document.createElement("p");
      empty.className = "hint";
      empty.textContent = "Sin oleadas: el bloque se cierra con su propio control.";
      list.append(empty);
      return;
    }
    block.waves.forEach((wave, index) => list.append(waveCard(wave, index, block)));
  }

  function waveCard(wave, index, block) {
    const card = document.createElement("article");
    card.className = "wave-card";

    const header = document.createElement("header");
    const title = document.createElement("strong");
    title.textContent = `Oleada ${index + 1}`;
    const total = document.createElement("span");
    total.className = "wave-total";
    const count = waveTotal(wave);
    total.textContent = `${count} ${count === 1 ? "ventana" : "ventanas"}`;
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "icon-button danger";
    remove.textContent = "×";
    remove.title = "Quitar la oleada";
    remove.addEventListener("click", () => {
      block.waves.splice(index, 1);
      commit("Oleada eliminada");
    });
    header.append(title, total, remove);
    card.append(header);

    const rows = document.createElement("ul");
    rows.className = "window-rows";
    const present = Object.keys(wave.windows);
    for (const type of present) {
      rows.append(windowRow(type, wave, present.length === 1));
    }
    card.append(rows);

    const missing = Object.keys(WINDOW_TYPES).filter((type) => !(type in wave.windows));
    if (missing.length && count < LIMITS.wave.max) {
      const select = document.createElement("select");
      select.className = "add-window";
      const placeholder = document.createElement("option");
      placeholder.value = "";
      placeholder.textContent = "+ Agregar ventana";
      select.append(placeholder);
      for (const group of ["ready", "planned"]) {
        const types = missing.filter((type) => WINDOW_TYPES[type].status === group);
        if (!types.length) continue;
        const optgroup = document.createElement("optgroup");
        optgroup.label = group === "ready" ? "En el juego" : "Todavía sin comportamiento propio";
        for (const type of types) {
          const option = document.createElement("option");
          option.value = type;
          option.textContent = WINDOW_TYPES[type].label;
          option.title = WINDOW_TYPES[type].hint;
          optgroup.append(option);
        }
        select.append(optgroup);
      }
      select.addEventListener("change", () => {
        if (!select.value) return;
        wave.windows[select.value] = 1;
        commit(`${WINDOW_TYPES[select.value].label} agregada`);
      });
      card.append(select);
    }
    return card;
  }

  function windowRow(type, wave, onlyOne) {
    const meta = WINDOW_TYPES[type];
    const row = document.createElement("li");
    row.className = "window-row";

    const glyph = document.createElement("span");
    glyph.className = "window-glyph";
    glyph.style.setProperty("--tone", meta.color);
    glyph.textContent = meta.glyph;

    const name = document.createElement("span");
    name.className = "window-name";
    name.textContent = meta.label;
    name.title = meta.hint;
    if (meta.status === "planned") {
      const chip = document.createElement("span");
      chip.className = "soon-chip";
      chip.textContent = "pronto";
      chip.title = "Se guarda en el nivel; el juego todavía la spawnea como ventana normal.";
      name.append(" ", chip);
    }

    const stepper = document.createElement("div");
    stepper.className = "stepper";
    const less = document.createElement("button");
    less.type = "button";
    less.textContent = "−";
    less.title = "Una menos";
    const input = document.createElement("input");
    input.type = "number";
    input.min = "1";
    input.max = String(LIMITS.wave.max);
    input.step = "1";
    input.value = String(wave.windows[type]);
    const more = document.createElement("button");
    more.type = "button";
    more.textContent = "+";
    more.title = "Una más";
    less.addEventListener("click", () => setWindowCount(wave, type, wave.windows[type] - 1, onlyOne));
    more.addEventListener("click", () => setWindowCount(wave, type, wave.windows[type] + 1, onlyOne));
    input.addEventListener("change", () => setWindowCount(wave, type, Number(input.value), onlyOne));
    stepper.append(less, input, more);

    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "icon-button";
    remove.textContent = "×";
    remove.title = onlyOne ? "Una oleada necesita al menos un tipo de ventana" : "Quitar este tipo";
    remove.disabled = onlyOne;
    remove.addEventListener("click", () => {
      delete wave.windows[type];
      commit("Ventana quitada de la oleada");
    });

    row.append(glyph, name, stepper, remove);
    return row;
  }

  /** Una oleada nunca queda vacía ni pasa del máximo de ventanas simultáneas. */
  function setWindowCount(wave, type, value, onlyOne) {
    const others = waveTotal(wave) - wave.windows[type];
    const room = Math.max(0, LIMITS.wave.max - others);
    const next = Math.max(onlyOne ? 1 : 0, Math.min(room, Math.round(Number(value) || 0)));
    if (next === wave.windows[type]) {
      renderBlockDialog();
      return;
    }
    if (next === 0) {
      delete wave.windows[type];
      commit("Ventana quitada de la oleada");
      return;
    }
    wave.windows[type] = next;
    commit("Oleada actualizada");
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
    const container = $("#texture-fields");
    for (const [slot, label] of Object.entries(TEXTURE_SLOTS)) {
      const field = document.createElement("label");
      field.innerHTML = `${label}<select data-texture="${slot}"></select>`;
      container.append(field);
    }
  }

  function refreshConnectionsForRoom(roomId) {
    for (const connection of connectionsFor(roomId)) {
      const from = roomById(connection.fromRoomId);
      const to = roomById(connection.toRoomId);
      if (!from || !to) continue;
      Object.assign(connection, chooseConnectionWalls(from, to));
    }
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

  function replaceLevel(next, message) {
    level = next;
    selectedRoomId = level.rooms[0]?.id || null;
    dialogRoomId = null;
    connectSourceId = null;
    saveHandle = null;
    blockDialog.close();
    roomDialog.close();
    fitView();
    commit(message);
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
      if (level.rooms.length && !window.confirm("¿Crear un nivel nuevo? El borrador actual seguirá disponible sólo si ya lo descargaste.")) return;
      replaceLevel(createEmptyLevel(), "Nivel nuevo");
    });

    $("#load-example").addEventListener("click", () => replaceLevel(exampleLevel(), "Ejemplo cargado"));

    $("#import-file").addEventListener("change", async (event) => {
      const file = event.target.files[0];
      if (!file) return;
      try {
        replaceLevel(normalizeLevel(JSON.parse(await file.text())), `Importado: ${file.name}`);
        showToast("Nivel importado");
      } catch (error) {
        showToast(`JSON inválido: ${error.message}`);
      } finally {
        event.target.value = "";
      }
    });

    $("#save-file").addEventListener("click", saveWithPicker);
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
    });

    svg.addEventListener("pointermove", (event) => {
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
    for (const dialog of [levelDialog, roomDialog, blockDialog]) {
      dialog.addEventListener("pointerdown", (event) => {
        if (event.target === dialog) dialog.close();
      });
    }
    roomDialog.addEventListener("close", () => {
      dialogRoomId = null;
      blockDialog.close();
    });
    blockDialog.addEventListener("close", () => { dialogSlot = null; });
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

    const openSlot = (event) => {
      const group = event.target.closest(".map-slot");
      if (group) openBlockDialog(group.dataset.slot);
    };
    $("#room-map").addEventListener("click", openSlot);
    $("#room-map").addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openSlot(event);
      }
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
      $(`[data-texture="${slot}"]`).addEventListener("change", (event) => {
        const room = dialogRoom();
        if (!room) return;
        room.textures[slot] = event.target.value;
        commit("Textura actualizada");
      });
    }

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
    $("#block-enabled").addEventListener("change", (event) => {
      const block = dialogBlock();
      if (!block) return;
      block.enabled = event.target.checked;
      // Un bloque recién encendido sin oleadas no spawnea nada: le damos la
      // primera para que el diálogo arranque mostrando algo editable.
      if (block.enabled && !block.waves.length) block.waves.push(blankWave());
      commit(block.enabled ? "Bloque activado" : "Bloque apagado");
    });

    $("#block-movement").addEventListener("change", (event) => {
      const block = dialogBlock();
      if (!block) return;
      block.movement = event.target.value;
      commit("Movimiento actualizado");
    });

    $("#block-speed").addEventListener("change", (event) => {
      const block = dialogBlock();
      if (!block) return;
      block.movementSpeed = clamp(event.target.value, LIMITS.movementSpeed);
      commit("Velocidad actualizada");
    });

    $("#block-color").addEventListener("change", (event) => {
      const block = dialogBlock();
      if (!block) return;
      block.color = event.target.value;
      commit("Color actualizado");
    });

    $("#add-wave").addEventListener("click", () => {
      const block = dialogBlock();
      if (!block) return;
      block.waves.push(blankWave());
      commit("Oleada agregada");
    });
  }

  function bindShortcuts() {
    window.addEventListener("keydown", (event) => {
      const typing = ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName);
      if (event.ctrlKey && event.key.toLowerCase() === "s") {
        event.preventDefault();
        saveWithPicker();
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
  bindLevelFields();
  bindFileActions();
  bindCanvas();
  bindDialogs();
  bindRoomFields();
  bindBlockFields();
  bindShortcuts();
  loadTextureCatalog();
  if (!level.rooms.length) level = exampleLevel();
  selectedRoomId ||= level.rooms[0]?.id || null;
  commit();
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
