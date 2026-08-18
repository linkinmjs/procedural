(() => {
  "use strict";

  const STORAGE_KEY = "procedural-map.level-workshop.draft.v1";
  const ROOM_DEFAULTS = {
    small: { label: "Habitación pequeña", width: 14, depth: 14 },
    large: { label: "Habitación grande", width: 24, depth: 18 },
    corridor: { label: "Pasillo", width: 10, depth: 28 },
    custom: { label: "Personalizada", width: 14, depth: 14 }
  };
  const SLOT_LABELS = { left: "Izquierdo", front: "Frontal", right: "Derecho" };
  const WALL_LABELS = { north: "N", east: "E", south: "S", west: "O" };
  const OPPOSITE_WALL = { north: "south", east: "west", south: "north", west: "east" };
  const RELATIVE_WALLS = {
    north: { left: "east", front: "south", right: "west" },
    east: { left: "south", front: "west", right: "north" },
    south: { left: "west", front: "north", right: "east" },
    west: { left: "north", front: "east", right: "south" }
  };

  const $ = (selector) => document.querySelector(selector);
  const svg = $("#level-canvas");
  const roomsLayer = $("#rooms-layer");
  const connectionsLayer = $("#connections-layer");
  let level = loadDraft() || createEmptyLevel();
  let selectedRoomId = level.rooms[0]?.id || null;
  let connectSourceId = null;
  let dragState = null;
  let saveHandle = null;
  let toastTimer = null;

  function blankBlock() {
    return { enabled: false, targetCount: 0, movement: "static" };
  }

  function createEmptyLevel() {
    return {
      schemaVersion: 1,
      id: `level-${Date.now()}`,
      name: "Nivel sin título",
      description: "",
      gridSize: 1,
      rooms: [],
      connections: []
    };
  }

  function createRoom(type, index) {
    const preset = ROOM_DEFAULTS[type];
    return {
      id: crypto.randomUUID(),
      name: `Sala ${index}`,
      type,
      position: { x: (index - 1) * 4, z: (index - 1) * -4 },
      size: { width: preset.width, depth: preset.depth },
      entry: { wall: "south", offset: 0 },
      blocks: { left: blankBlock(), front: blankBlock(), right: blankBlock() }
    };
  }

  function exampleLevel() {
    const result = createEmptyLevel();
    result.id = "f4-three-room-example";
    result.name = "Circuito de tres salas";
    result.description = "Ejemplo editable con sala pequeña, sala grande y pasillo.";
    const a = createRoom("small", 1);
    Object.assign(a, { id: "room-entry", name: "Entrada", position: { x: -18, z: 8 } });
    a.blocks.front = { enabled: true, targetCount: 4, movement: "static" };
    const b = createRoom("large", 2);
    Object.assign(b, { id: "room-arena", name: "Arena", position: { x: 4, z: 5 } });
    b.entry.wall = "west";
    b.blocks.left = { enabled: true, targetCount: 5, movement: "static" };
    b.blocks.front = { enabled: true, targetCount: 3, movement: "opposite" };
    b.blocks.right = { enabled: true, targetCount: 5, movement: "static" };
    const c = createRoom("corridor", 3);
    Object.assign(c, { id: "room-corridor", name: "Pasillo de salida", position: { x: 22, z: -11 } });
    c.entry.wall = "north";
    c.blocks.left = { enabled: true, targetCount: 4, movement: "opposite" };
    c.blocks.right = { enabled: true, targetCount: 4, movement: "opposite" };
    result.rooms = [a, b, c];
    result.connections = [
      { id: "connection-entry-arena", fromRoomId: a.id, toRoomId: b.id, fromWall: "east", toWall: "west" },
      { id: "connection-arena-corridor", fromRoomId: b.id, toRoomId: c.id, fromWall: "south", toWall: "north" }
    ];
    return result;
  }

  function normalizeLevel(candidate) {
    if (!candidate || !Array.isArray(candidate.rooms) || !Array.isArray(candidate.connections)) {
      throw new Error("El archivo no contiene rooms y connections válidos.");
    }
    candidate.schemaVersion = 1;
    candidate.id ||= `level-${Date.now()}`;
    candidate.name ||= "Nivel importado";
    candidate.description ||= "";
    candidate.gridSize ||= 1;
    candidate.rooms.forEach((room, index) => {
      room.id ||= crypto.randomUUID();
      room.name ||= `Sala ${index + 1}`;
      room.type = ROOM_DEFAULTS[room.type] ? room.type : "custom";
      room.position ||= { x: 0, z: 0 };
      room.size ||= { width: 14, depth: 14 };
      room.entry ||= { wall: "south", offset: 0 };
      room.blocks ||= {};
      for (const slot of Object.keys(SLOT_LABELS)) room.blocks[slot] = { ...blankBlock(), ...(room.blocks[slot] || {}) };
    });
    return candidate;
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

  function commit(message = "Borrador actualizado") {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(level));
    $("#level-status").textContent = message;
    render();
  }

  function selectedRoom() {
    return level.rooms.find((room) => room.id === selectedRoomId) || null;
  }

  function svgElement(tag, attributes = {}) {
    const element = document.createElementNS("http://www.w3.org/2000/svg", tag);
    Object.entries(attributes).forEach(([key, value]) => element.setAttribute(key, value));
    return element;
  }

  function wallPoint(room, wall) {
    const halfW = room.size.width / 2;
    const halfD = room.size.depth / 2;
    const points = {
      north: { x: room.position.x, y: room.position.z - halfD },
      east: { x: room.position.x + halfW, y: room.position.z },
      south: { x: room.position.x, y: room.position.z + halfD },
      west: { x: room.position.x - halfW, y: room.position.z }
    };
    return points[wall];
  }

  function renderConnections() {
    connectionsLayer.replaceChildren();
    for (const connection of level.connections) {
      const from = level.rooms.find((room) => room.id === connection.fromRoomId);
      const to = level.rooms.find((room) => room.id === connection.toRoomId);
      if (!from || !to) continue;
      const a = wallPoint(from, connection.fromWall);
      const b = wallPoint(to, connection.toWall);
      const midX = (a.x + b.x) / 2;
      const path = svgElement("path", {
        d: `M ${a.x} ${a.y} L ${midX} ${a.y} L ${midX} ${b.y} L ${b.x} ${b.y}`,
        class: "connection-path"
      });
      const start = svgElement("circle", { cx: a.x, cy: a.y, r: .38, class: "connection-node" });
      const end = svgElement("circle", { cx: b.x, cy: b.y, r: .38, class: "connection-node" });
      connectionsLayer.append(path, start, end);
    }
  }

  function addDoor(group, room) {
    const point = wallPoint(room, room.entry.wall);
    const horizontal = room.entry.wall === "north" || room.entry.wall === "south";
    const door = svgElement("line", {
      x1: point.x - (horizontal ? 1.4 : 0),
      y1: point.y - (horizontal ? 0 : 1.4),
      x2: point.x + (horizontal ? 1.4 : 0),
      y2: point.y + (horizontal ? 0 : 1.4),
      class: "door-mark"
    });
    group.append(door);
  }

  function addBlock(group, room, slot, config) {
    if (!config.enabled) return;
    const wall = RELATIVE_WALLS[room.entry.wall][slot];
    const point = wallPoint(room, wall);
    const horizontal = wall === "north" || wall === "south";
    const maxLength = horizontal ? room.size.width - 2 : room.size.depth - 2;
    const length = Math.max(2, Math.min(maxLength, 3 + config.targetCount * 1.1));
    const rect = svgElement("rect", {
      x: point.x - (horizontal ? length / 2 : .3),
      y: point.y - (horizontal ? .3 : length / 2),
      width: horizontal ? length : .6,
      height: horizontal ? .6 : length,
      rx: .22,
      class: `target-block${config.movement === "opposite" ? " moving" : ""}`
    });
    const count = svgElement("text", { x: point.x, y: point.y, class: "block-count" });
    count.textContent = String(config.targetCount);
    group.append(rect, count);
  }

  function renderRooms() {
    roomsLayer.replaceChildren();
    for (const room of level.rooms) {
      const group = svgElement("g", {
        class: `room-group${room.id === selectedRoomId ? " selected" : ""}${room.id === connectSourceId ? " connect-source" : ""}`,
        "data-room-id": room.id
      });
      const rect = svgElement("rect", {
        x: room.position.x - room.size.width / 2,
        y: room.position.z - room.size.depth / 2,
        width: room.size.width,
        height: room.size.depth,
        rx: .5,
        class: "room-shape"
      });
      const label = svgElement("text", { x: room.position.x, y: room.position.z - .25, class: "room-label" });
      label.textContent = room.name;
      const meta = svgElement("text", { x: room.position.x, y: room.position.z + 1.05, class: "room-meta" });
      meta.textContent = `${ROOM_DEFAULTS[room.type].label} · ${room.size.width}×${room.size.depth} m · entrada ${WALL_LABELS[room.entry.wall]}`;
      group.append(rect);
      addDoor(group, room);
      for (const [slot, config] of Object.entries(room.blocks)) addBlock(group, room, slot, config);
      group.append(label, meta);
      roomsLayer.append(group);
    }
  }

  function renderInspector() {
    const room = selectedRoom();
    $("#empty-inspector").hidden = Boolean(room);
    $("#room-inspector").hidden = !room;
    if (!room) return;
    $("#room-name").value = room.name;
    $("#room-type").value = room.type;
    $("#room-width").value = room.size.width;
    $("#room-depth").value = room.size.depth;
    $("#room-x").value = room.position.x;
    $("#room-z").value = room.position.z;
    $("#entry-wall").value = room.entry.wall;
    for (const slot of Object.keys(SLOT_LABELS)) {
      const config = room.blocks[slot];
      $(`[data-block-enabled="${slot}"]`).checked = config.enabled;
      $(`[data-block-fields="${slot}"]`).hidden = !config.enabled;
      $(`[data-block-targets="${slot}"]`).value = config.targetCount;
      $(`[data-block-movement="${slot}"]`).value = config.movement;
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
      const text = document.createElement("span");
      text.textContent = `${from.name} → ${to.name}`;
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "danger subtle";
      remove.textContent = "Quitar";
      remove.addEventListener("click", () => {
        level.connections = level.connections.filter((item) => item.id !== connection.id);
        commit("Conexión eliminada");
      });
      item.append(text, remove);
      list.append(item);
    }
  }

  function render() {
    $("#level-name").value = level.name;
    $("#level-description").value = level.description;
    const targets = level.rooms.reduce((total, room) => total + Object.values(room.blocks).reduce((sum, block) => sum + (block.enabled ? block.targetCount : 0), 0), 0);
    $("#level-stats").textContent = `${level.rooms.length} salas · ${level.connections.length} conexiones · ${targets} objetivos`;
    renderConnections();
    renderRooms();
    renderInspector();
    renderConnectionList();
  }

  function makeBlockEditors() {
    const container = $("#block-editors");
    for (const [slot, label] of Object.entries(SLOT_LABELS)) {
      const editor = document.createElement("section");
      editor.className = "block-editor";
      editor.innerHTML = `
        <div class="block-title">
          <strong>${label}</strong>
          <label class="switch"><input type="checkbox" data-block-enabled="${slot}"> Activo</label>
        </div>
        <div class="block-fields" data-block-fields="${slot}" hidden>
          <label>Objetivos<input type="number" min="0" max="24" step="1" data-block-targets="${slot}"></label>
          <label>Movimiento
            <select data-block-movement="${slot}">
              <option value="static">Estático</option>
              <option value="opposite">Hacia el lado contrario</option>
            </select>
          </label>
        </div>`;
      container.append(editor);
    }
  }

  function chooseConnectionWalls(from, to) {
    const dx = to.position.x - from.position.x;
    const dz = to.position.z - from.position.z;
    const fromWall = Math.abs(dx) >= Math.abs(dz) ? (dx >= 0 ? "east" : "west") : (dz >= 0 ? "south" : "north");
    return { fromWall, toWall: OPPOSITE_WALL[fromWall] };
  }

  function selectOrConnect(roomId) {
    if (!$("#connect-mode").getAttribute("aria-pressed").includes("true")) {
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
    if (!duplicate) {
      const walls = chooseConnectionWalls(from, to);
      level.connections.push({ id: crypto.randomUUID(), fromRoomId: from.id, toRoomId: to.id, ...walls });
      to.entry.wall = walls.toWall;
    }
    connectSourceId = null;
    selectedRoomId = roomId;
    $("#connect-help").textContent = "Conexión creada. Elegí otra sala de origen.";
    commit(duplicate ? "Las salas ya estaban conectadas" : "Salas conectadas");
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
    const slug = level.name.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
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

  function bindEvents() {
    $("#level-name").addEventListener("input", (event) => { level.name = event.target.value; commit(); });
    $("#level-description").addEventListener("input", (event) => { level.description = event.target.value; commit(); });

    document.querySelectorAll(".room-preset").forEach((button) => button.addEventListener("click", () => {
      const room = createRoom(button.dataset.roomType, level.rooms.length + 1);
      level.rooms.push(room);
      selectedRoomId = room.id;
      commit("Sala agregada");
    }));

    $("#new-level").addEventListener("click", () => {
      if (level.rooms.length && !window.confirm("¿Crear un nivel nuevo? El borrador actual seguirá disponible sólo si ya lo descargaste.")) return;
      level = createEmptyLevel();
      selectedRoomId = null;
      connectSourceId = null;
      saveHandle = null;
      commit("Nivel nuevo");
    });

    $("#load-example").addEventListener("click", () => {
      level = exampleLevel();
      selectedRoomId = level.rooms[0].id;
      connectSourceId = null;
      saveHandle = null;
      commit("Ejemplo cargado");
    });

    $("#import-file").addEventListener("change", async (event) => {
      const file = event.target.files[0];
      if (!file) return;
      try {
        level = normalizeLevel(JSON.parse(await file.text()));
        selectedRoomId = level.rooms[0]?.id || null;
        connectSourceId = null;
        saveHandle = null;
        commit(`Importado: ${file.name}`);
        showToast("Nivel importado");
      } catch (error) {
        showToast(`JSON inválido: ${error.message}`);
      } finally {
        event.target.value = "";
      }
    });

    $("#save-file").addEventListener("click", saveWithPicker);
    $("#download-file").addEventListener("click", () => { downloadJson(); showToast("JSON descargado"); });

    $("#connect-mode").addEventListener("click", (event) => {
      const active = event.currentTarget.getAttribute("aria-pressed") !== "true";
      event.currentTarget.setAttribute("aria-pressed", String(active));
      connectSourceId = null;
      $("#connect-help").textContent = active ? "Seleccioná la sala de origen y luego la de destino." : "Seleccioná una sala para editarla.";
      renderRooms();
    });

    roomsLayer.addEventListener("pointerdown", (event) => {
      const group = event.target.closest(".room-group");
      if (!group) return;
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
      if (!dragState) return;
      const room = level.rooms.find((item) => item.id === dragState.roomId);
      const point = clientToSvg(event);
      room.position.x = Math.round((point.x - dragState.dx) / level.gridSize) * level.gridSize;
      room.position.z = Math.round((point.y - dragState.dz) / level.gridSize) * level.gridSize;
      renderConnections();
      renderRooms();
      renderInspector();
    });

    svg.addEventListener("pointerup", (event) => {
      if (!dragState) return;
      dragState = null;
      if (svg.hasPointerCapture(event.pointerId)) svg.releasePointerCapture(event.pointerId);
      commit("Posición actualizada");
    });

    const roomFields = {
      "#room-name": (room, value) => { room.name = value; },
      "#room-width": (room, value) => { room.size.width = Number(value); room.type = "custom"; },
      "#room-depth": (room, value) => { room.size.depth = Number(value); room.type = "custom"; },
      "#room-x": (room, value) => { room.position.x = Number(value); },
      "#room-z": (room, value) => { room.position.z = Number(value); },
      "#entry-wall": (room, value) => { room.entry.wall = value; }
    };
    for (const [selector, update] of Object.entries(roomFields)) {
      $(selector).addEventListener("input", (event) => {
        const room = selectedRoom();
        if (!room) return;
        update(room, event.target.value);
        commit();
      });
    }

    $("#room-type").addEventListener("change", (event) => {
      const room = selectedRoom();
      const preset = ROOM_DEFAULTS[event.target.value];
      if (!room || !preset) return;
      room.type = event.target.value;
      if (room.type !== "custom") room.size = { width: preset.width, depth: preset.depth };
      commit("Tipo de sala actualizado");
    });

    $("#delete-room").addEventListener("click", () => {
      const room = selectedRoom();
      if (!room || !window.confirm(`¿Eliminar ${room.name}?`)) return;
      level.rooms = level.rooms.filter((item) => item.id !== room.id);
      level.connections = level.connections.filter((connection) => connection.fromRoomId !== room.id && connection.toRoomId !== room.id);
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
      $(`[data-block-targets="${slot}"]`).addEventListener("input", (event) => {
        const room = selectedRoom();
        if (!room) return;
        room.blocks[slot].targetCount = Math.max(0, Math.min(24, Number(event.target.value)));
        commit();
      });
      $(`[data-block-movement="${slot}"]`).addEventListener("change", (event) => {
        const room = selectedRoom();
        if (!room) return;
        room.blocks[slot].movement = event.target.value;
        commit("Movimiento actualizado");
      });
    }
  }

  makeBlockEditors();
  bindEvents();
  if (!level.rooms.length) level = exampleLevel();
  selectedRoomId ||= level.rooms[0]?.id || null;
  commit("Borrador guardado localmente");
})();
