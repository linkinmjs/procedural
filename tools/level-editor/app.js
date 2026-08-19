(() => {
  "use strict";

  const {
    ROOM_PRESETS, ROLE_LABELS, SLOT_LABELS, TEXTURE_SLOTS, WALL_LABELS, RELATIVE_WALLS, LIMITS,
    clamp, clampInt, newId, createEmptyLevel, createRoom, createConnection, chooseConnectionWalls,
    degreesToWall, assignRole, normalizeRoles, resolveEntryWalls, normalizeLevel, corridorPlan, corridorOutline
  } = window.LevelFormat;

  const STORAGE_KEY = "procedural-map.level-workshop.draft.v3";

  const $ = (selector) => document.querySelector(selector);
  const svg = $("#level-canvas");
  const roomsLayer = $("#rooms-layer");
  const corridorsLayer = $("#corridors-layer");

  let level = loadDraft() || createEmptyLevel();
  let selectedRoomId = level.rooms[0]?.id || null;
  let connectSourceId = null;
  let activeTab = "general";
  let dragState = null;
  let panState = null;
  let view = { x: -35, y: -28, width: 70, height: 56 };
  let textureCatalog = [];
  let saveHandle = null;
  let toastTimer = null;

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
    configure(a.blocks.front, [4]);
    const b = createRoom("large", 2);
    Object.assign(b, { id: "room-arena", name: "Arena", position: { x: 4, z: 5 }, wallHeight: 9, hasCeiling: false });
    b.ammoReward = { enabled: true, amount: 40, color: "#f4bc59" };
    configure(b.blocks.left, [5], "static", "#35d4c7");
    configure(b.blocks.front, [3, 6], "opposite", "#f4bc59", 0.8);
    configure(b.blocks.right, [5], "static", "#35d4c7");
    const c = createRoom("corridor", 3);
    Object.assign(c, { id: "room-corridor", name: "Pasillo de salida", role: "exit", position: { x: 22, z: -11 }, wallHeight: 4 });
    configure(c.blocks.left, [4], "opposite");
    configure(c.blocks.right, [4], "opposite");
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

  // El catálogo es opcional: si el editor se abre con file:// el fetch falla y
  // los campos de textura siguen aceptando texto libre.
  async function loadTextureCatalog() {
    try {
      const response = await fetch("../../level_designs/texture-catalog.json", { cache: "no-store" });
      if (!response.ok) throw new Error(String(response.status));
      const catalog = await response.json();
      textureCatalog = Array.isArray(catalog.textures) ? catalog.textures : [];
    } catch (error) {
      textureCatalog = [];
    }
    const options = $("#texture-catalog-options");
    options.replaceChildren();
    for (const entry of textureCatalog) {
      const id = typeof entry === "string" ? entry : String(entry?.id ?? "");
      if (!id) continue;
      const option = document.createElement("option");
      option.value = id;
      if (entry?.label) option.label = String(entry.label);
      options.append(option);
    }
    $("#texture-catalog-status").textContent = textureCatalog.length
      ? `${textureCatalog.length} texturas en el catálogo.`
      : "Catálogo vacío: los packs de assets/_raw/textures todavía no se importaron.";
  }

  /** Toda mutación pasa por acá: reconcilia los datos derivados y redibuja. */
  function commit(message = "Borrador actualizado") {
    normalizeRoles(level.rooms);
    resolveEntryWalls(level);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(level));
    $("#level-status").textContent = message;
    render();
  }

  function selectedRoom() {
    return level.rooms.find((room) => room.id === selectedRoomId) || null;
  }

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
      const from = level.rooms.find((room) => room.id === connection.fromRoomId);
      const to = level.rooms.find((room) => room.id === connection.toRoomId);
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
    count.textContent = config.waves.length ? config.waves.join("›") : "×";
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
      item.append(button);
      list.append(item);
    }
  }

  function renderConnectionList() {
    const list = $("#connection-list");
    list.replaceChildren();
    for (const connection of level.connections) {
      const from = level.rooms.find((room) => room.id === connection.fromRoomId);
      const to = level.rooms.find((room) => room.id === connection.toRoomId);
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
      remove.className = "danger subtle";
      remove.textContent = "×";
      remove.title = "Quitar el pasillo";
      remove.addEventListener("click", () => {
        level.connections = level.connections.filter((item) => item.id !== connection.id);
        commit("Pasillo eliminado");
      });
      item.append(text, width, remove);
      list.append(item);
    }
    if (!level.connections.length) {
      const empty = document.createElement("p");
      empty.className = "hint";
      empty.textContent = "Las salas todavía no están unidas.";
      list.append(empty);
    }
  }

  const WALL_NAMES = { north: "norte", east: "este", south: "sur", west: "oeste" };

  function renderRoleHelp(room) {
    const help = {
      start: "El jugador aparece acá, mirando hacia donde indique la brújula.",
      transition: "Se entra por la pared que la une con la sala anterior.",
      exit: "Llegar a esta sala cierra el nivel."
    };
    $("#role-help").textContent = help[room.role];
    document.querySelectorAll(".segment").forEach((button) =>
      button.setAttribute("aria-checked", String(button.dataset.role === room.role)));
  }

  function renderEntrySummary(room) {
    if (room.role === "start") {
      $("#entry-summary").textContent = `Mira al ${WALL_NAMES[degreesToWall(room.facing)]}, así que entra por el ${WALL_NAMES[room.entry.wall]}.`;
      return;
    }
    $("#entry-summary").textContent = connectionsFor(room.id).length
      ? `Se entra por el ${WALL_NAMES[room.entry.wall]}, viniendo de la sala anterior.`
      : `Sin pasillos: se asume el ${WALL_NAMES[room.entry.wall]}.`;
  }

  function renderInspector() {
    const room = selectedRoom();
    $("#empty-inspector").hidden = Boolean(room);
    $("#room-inspector").hidden = !room;
    if (!room) return;
    $("#room-heading").textContent = room.name || "Sala";
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
    $("#room-ammo-fields").hidden = !room.ammoReward.enabled;
    $("#room-ammo-amount").value = room.ammoReward.amount;
    $("#room-ammo-color").value = room.ammoReward.color;
    renderRoleHelp(room);
    renderEntrySummary(room);
    for (const slot of Object.keys(SLOT_LABELS)) {
      const config = room.blocks[slot];
      $(`[data-block-wall="${slot}"]`).textContent = WALL_LABELS[RELATIVE_WALLS[room.entry.wall][slot]];
      $(`[data-block-enabled="${slot}"]`).checked = config.enabled;
      $(`[data-block-fields="${slot}"]`).hidden = !config.enabled;
      $(`[data-block-movement="${slot}"]`).value = config.movement;
      $(`[data-block-speed="${slot}"]`).value = config.movementSpeed;
      $(`[data-block-speed-field="${slot}"]`).hidden = config.movement !== "opposite";
      $(`[data-block-color="${slot}"]`).value = config.color;
      renderWaveEditor(slot, config);
    }
    for (const slot of Object.keys(TEXTURE_SLOTS)) {
      $(`[data-texture="${slot}"]`).value = room.textures[slot];
      $(`[data-texture-inherit="${slot}"]`).textContent = level.defaults.textures[slot]
        ? `Nivel: ${level.defaults.textures[slot]}`
        : "";
    }
  }

  function renderWaveEditor(slot, config) {
    const list = $(`[data-block-waves="${slot}"]`);
    list.replaceChildren();
    if (!config.waves.length) {
      const empty = document.createElement("p");
      empty.className = "hint wave-empty";
      empty.textContent = "Sin oleadas: el bloque usa el control de cierre.";
      list.append(empty);
      return;
    }
    config.waves.forEach((targetCount, index) => {
      const row = document.createElement("div");
      row.className = "wave-row";
      const label = document.createElement("label");
      label.textContent = `Oleada ${index + 1}`;
      const input = document.createElement("input");
      input.type = "number";
      input.min = String(LIMITS.wave.min);
      input.max = String(LIMITS.wave.max);
      input.step = "1";
      input.value = String(targetCount);
      input.addEventListener("change", () => {
        const room = selectedRoom();
        if (!room) return;
        room.blocks[slot].waves[index] = clampInt(input.value, LIMITS.wave);
        commit("Oleada actualizada");
      });
      label.append(input);
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "danger subtle";
      remove.textContent = "Quitar";
      remove.addEventListener("click", () => {
        const room = selectedRoom();
        if (!room) return;
        room.blocks[slot].waves.splice(index, 1);
        commit("Oleada eliminada");
      });
      row.append(label, remove);
      list.append(row);
    });
  }

  function renderStats() {
    const targets = level.rooms.reduce((total, room) =>
      total + Object.values(room.blocks).reduce((sum, block) =>
        sum + (block.enabled ? block.waves.reduce((waveTotal, count) => waveTotal + count, 0) : 0), 0), 0);
    const rewarded = level.rooms.reduce((total, room) =>
      total + (room.ammoReward.enabled ? room.ammoReward.amount : 0), 0);
    const openRooms = level.rooms.filter((room) => !roomHasCeiling(room)).length;
    const timeLabel = `${Math.floor(level.timeLimitSeconds / 60)}:${String(level.timeLimitSeconds % 60).padStart(2, "0")}`;
    const parts = [
      `${level.rooms.length} salas`,
      `${level.connections.length} pasillos`,
      `${targets} objetivos`,
      timeLabel,
      `${level.startingAmmo.magazine}+${level.startingAmmo.reserve} balas`
    ];
    if (rewarded) parts.push(`+${rewarded} de recompensa`);
    if (openRooms) parts.push(`${openRooms} a cielo abierto`);
    $("#level-stats").textContent = parts.join(" · ");
  }

  function render() {
    $("#level-name").value = level.name;
    $("#level-description").value = level.description;
    $("#level-time-minutes").value = Math.floor(level.timeLimitSeconds / 60);
    $("#level-time-seconds").value = level.timeLimitSeconds % 60;
    $("#level-ammo-magazine").value = level.startingAmmo.magazine;
    $("#level-ammo-reserve").value = level.startingAmmo.reserve;
    $("#level-wall-height").value = level.defaults.wallHeight;
    $("#level-corridor-width").value = level.defaults.corridorWidth;
    $("#level-has-ceiling").checked = level.defaults.hasCeiling;
    renderStats();
    renderCorridors();
    renderRooms();
    renderRoomList();
    renderConnectionList();
    renderInspector();
  }

  function makeBlockEditors() {
    const container = $("#block-editors");
    for (const [slot, label] of Object.entries(SLOT_LABELS)) {
      const editor = document.createElement("section");
      editor.className = "block-editor";
      editor.innerHTML = `
        <div class="block-title">
          <label class="switch"><input type="checkbox" data-block-enabled="${slot}"> <strong>${label}</strong></label>
          <span class="wall-chip" data-block-wall="${slot}"></span>
        </div>
        <div class="block-fields" data-block-fields="${slot}" hidden>
          <div class="field-row">
            <label>Color<input type="color" data-block-color="${slot}"></label>
            <label data-block-speed-field="${slot}">Velocidad<input type="number" min="0.05" max="5" step="0.05" data-block-speed="${slot}"></label>
          </div>
          <label>Movimiento
            <select data-block-movement="${slot}">
              <option value="static">Estático</option>
              <option value="opposite">Hacia el lado contrario</option>
            </select>
          </label>
          <div class="waves-heading"><strong>Oleadas</strong><button type="button" class="subtle" data-add-wave="${slot}">Agregar</button></div>
          <div class="wave-list" data-block-waves="${slot}"></div>
        </div>`;
      container.append(editor);
    }
  }

  function makeTextureEditors() {
    const container = $("#texture-fields");
    for (const [slot, label] of Object.entries(TEXTURE_SLOTS)) {
      const field = document.createElement("label");
      field.innerHTML = `${label}
        <input type="text" list="texture-catalog-options" maxlength="120" placeholder="Sin textura" data-texture="${slot}">
        <span class="hint texture-inherit" data-texture-inherit="${slot}"></span>`;
      container.append(field);
    }
  }

  function selectTab(tab) {
    activeTab = tab;
    document.querySelectorAll(".tab").forEach((button) =>
      button.setAttribute("aria-selected", String(button.dataset.tab === tab)));
    document.querySelectorAll(".tab-panel").forEach((panel) => {
      panel.hidden = panel.dataset.tabPanel !== tab;
    });
  }

  function refreshConnectionsForRoom(roomId) {
    for (const connection of connectionsFor(roomId)) {
      const from = level.rooms.find((room) => room.id === connection.fromRoomId);
      const to = level.rooms.find((room) => room.id === connection.toRoomId);
      if (!from || !to) continue;
      Object.assign(connection, chooseConnectionWalls(from, to));
    }
  }

  function selectOrConnect(roomId) {
    if ($("#connect-mode").getAttribute("aria-pressed") !== "true") {
      selectedRoomId = roomId;
      render();
      return;
    }
    if (!connectSourceId) {
      connectSourceId = roomId;
      $("#connect-help").textContent = "Ahora seleccioná la sala de destino.";
      renderRooms();
      return;
    }
    if (connectSourceId === roomId) return;
    const from = level.rooms.find((room) => room.id === connectSourceId);
    const to = level.rooms.find((room) => room.id === roomId);
    const duplicate = level.connections.some((connection) =>
      (connection.fromRoomId === from.id && connection.toRoomId === to.id) ||
      (connection.fromRoomId === to.id && connection.toRoomId === from.id));
    if (!duplicate) level.connections.push(createConnection(from, to, level.defaults.corridorWidth));
    connectSourceId = null;
    selectedRoomId = roomId;
    $("#connect-help").textContent = "Pasillo creado. Elegí otra sala de origen.";
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
    const slug = level.name.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
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
    connectSourceId = null;
    saveHandle = null;
    fitView();
    commit(message);
  }

  function bindLevelFields() {
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
    $("#level-corridor-width").addEventListener("change", (event) => {
      level.defaults.corridorWidth = clamp(event.target.value, LIMITS.corridorWidth);
      commit("Ancho de pasillo predeterminado actualizado");
    });
    $("#level-has-ceiling").addEventListener("change", (event) => {
      level.defaults.hasCeiling = event.target.checked;
      commit("Techo predeterminado actualizado");
    });
  }

  function bindFileActions() {
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
    $("#connect-mode").addEventListener("click", (event) => {
      const active = event.currentTarget.getAttribute("aria-pressed") !== "true";
      event.currentTarget.setAttribute("aria-pressed", String(active));
      connectSourceId = null;
      $("#connect-help").textContent = active
        ? "Seleccioná la sala de origen y luego la de destino."
        : "Seleccioná una sala para editarla.";
      renderRooms();
    });

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
      if ($("#connect-mode").getAttribute("aria-pressed") === "true") return;
      const room = level.rooms.find((item) => item.id === roomId);
      const point = clientToSvg(event);
      dragState = { roomId, dx: point.x - room.position.x, dz: point.y - room.position.z };
      group.classList.add("dragging");
      svg.setPointerCapture(event.pointerId);
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
      const room = level.rooms.find((item) => item.id === dragState.roomId);
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

  function bindRoomFields() {
    document.querySelectorAll(".tab").forEach((button) =>
      button.addEventListener("click", () => selectTab(button.dataset.tab)));

    document.querySelectorAll(".segment").forEach((button) => button.addEventListener("click", () => {
      const room = selectedRoom();
      if (!room) return;
      const role = button.dataset.role;
      assignRole(level.rooms, room, role);
      commit(`Sala marcada como ${ROLE_LABELS[role].toLowerCase()}`);
    }));

    document.querySelectorAll(".compass-point").forEach((button) => button.addEventListener("click", () => {
      const room = selectedRoom();
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
        const room = selectedRoom();
        if (!room) return;
        update(room, event.target.value);
        refreshConnectionsForRoom(room.id);
        commit();
      });
    }

    $("#room-type").addEventListener("change", (event) => {
      const room = selectedRoom();
      const preset = ROOM_PRESETS[event.target.value];
      if (!room || !preset) return;
      room.type = event.target.value;
      if (room.type !== "custom") room.size = { width: preset.width, depth: preset.depth };
      commit("Tipo de sala actualizado");
    });

    $("#room-wall-height-mode").addEventListener("change", (event) => {
      const room = selectedRoom();
      if (!room) return;
      room.wallHeight = event.target.value === "inherit" ? null : level.defaults.wallHeight;
      commit("Altura de la sala actualizada");
    });

    $("#room-wall-height").addEventListener("change", (event) => {
      const room = selectedRoom();
      if (!room) return;
      room.wallHeight = clamp(event.target.value, LIMITS.wallHeight);
      commit("Altura de la sala actualizada");
    });

    $("#room-ceiling").addEventListener("change", (event) => {
      const room = selectedRoom();
      if (!room) return;
      room.hasCeiling = event.target.value === "inherit" ? null : event.target.value === "closed";
      commit(room.hasCeiling === false ? "Sala a cielo abierto" : "Techo actualizado");
    });

    $("#room-ammo-enabled").addEventListener("change", (event) => {
      const room = selectedRoom();
      if (!room) return;
      room.ammoReward.enabled = event.target.checked;
      commit("Recompensa actualizada");
    });

    $("#room-ammo-amount").addEventListener("change", (event) => {
      const room = selectedRoom();
      if (!room) return;
      room.ammoReward.amount = clampInt(event.target.value, LIMITS.ammoReward);
      commit("Recompensa actualizada");
    });

    $("#room-ammo-color").addEventListener("change", (event) => {
      const room = selectedRoom();
      if (!room) return;
      room.ammoReward.color = event.target.value;
      commit("Recompensa actualizada");
    });

    $("#duplicate-room").addEventListener("click", () => {
      const room = selectedRoom();
      if (!room) return;
      const copy = structuredClone(room);
      copy.id = newId();
      copy.name = `${room.name} (copia)`;
      copy.role = "transition";
      copy.position = { x: room.position.x + room.size.width + 2, z: room.position.z };
      level.rooms.push(copy);
      selectedRoomId = copy.id;
      commit("Sala duplicada");
    });

    $("#delete-room").addEventListener("click", () => {
      const room = selectedRoom();
      if (!room || !window.confirm(`¿Eliminar ${room.name}?`)) return;
      level.rooms = level.rooms.filter((item) => item.id !== room.id);
      level.connections = level.connections.filter((connection) =>
        connection.fromRoomId !== room.id && connection.toRoomId !== room.id);
      selectedRoomId = level.rooms[0]?.id || null;
      commit("Sala eliminada");
    });

    for (const slot of Object.keys(SLOT_LABELS)) {
      $(`[data-block-enabled="${slot}"]`).addEventListener("change", (event) => {
        const room = selectedRoom();
        if (!room) return;
        room.blocks[slot].enabled = event.target.checked;
        commit("Bloque actualizado");
      });
      $(`[data-block-speed="${slot}"]`).addEventListener("change", (event) => {
        const room = selectedRoom();
        if (!room) return;
        room.blocks[slot].movementSpeed = clamp(event.target.value, LIMITS.movementSpeed);
        commit("Velocidad actualizada");
      });
      $(`[data-block-color="${slot}"]`).addEventListener("change", (event) => {
        const room = selectedRoom();
        if (!room) return;
        room.blocks[slot].color = event.target.value;
        commit("Color actualizado");
      });
      $(`[data-block-movement="${slot}"]`).addEventListener("change", (event) => {
        const room = selectedRoom();
        if (!room) return;
        room.blocks[slot].movement = event.target.value;
        commit("Movimiento actualizado");
      });
      $(`[data-add-wave="${slot}"]`).addEventListener("click", () => {
        const room = selectedRoom();
        if (!room) return;
        room.blocks[slot].waves.push(LIMITS.wave.fallback);
        commit("Oleada agregada");
      });
    }

    for (const slot of Object.keys(TEXTURE_SLOTS)) {
      $(`[data-texture="${slot}"]`).addEventListener("change", (event) => {
        const room = selectedRoom();
        if (!room) return;
        room.textures[slot] = event.target.value.trim();
        commit("Textura actualizada");
      });
    }
  }

  function bindShortcuts() {
    window.addEventListener("keydown", (event) => {
      const typing = ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName);
      if (event.ctrlKey && event.key.toLowerCase() === "s") {
        event.preventDefault();
        saveWithPicker();
        return;
      }
      if (typing) return;
      if (event.key === "Delete" && selectedRoom()) {
        event.preventDefault();
        $("#delete-room").click();
        return;
      }
      if (event.key.toLowerCase() === "f") {
        event.preventDefault();
        fitView();
      }
    });
  }

  makeBlockEditors();
  makeTextureEditors();
  bindLevelFields();
  bindFileActions();
  bindCanvas();
  bindRoomFields();
  bindShortcuts();
  selectTab(activeTab);
  loadTextureCatalog();
  if (!level.rooms.length) level = exampleLevel();
  selectedRoomId ||= level.rooms[0]?.id || null;
  syncViewAspect();
  fitView();
  commit("Borrador guardado localmente");
})();
