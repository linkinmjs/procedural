// Modelo de datos de los niveles. Lo comparten el editor (como script clasico,
// para que index.html siga abriendo con file://), el migrador de archivos y los
// smoke tests, de modo que la inferencia de entradas tenga una sola version.
(() => {
  "use strict";

  const SCHEMA_VERSION = 5;

  const ROOM_PRESETS = {
    small: { label: "Habitación pequeña", width: 14, depth: 14 },
    large: { label: "Habitación grande", width: 24, depth: 18 },
    corridor: { label: "Pasillo", width: 10, depth: 28 },
    custom: { label: "Personalizada", width: 14, depth: 14 }
  };
  const ROLE_LABELS = { start: "Inicio", transition: "Tránsito", exit: "Salida" };
  const SLOT_LABELS = { left: "Izquierdo", front: "Frontal", right: "Derecho" };
  const TEXTURE_SLOTS = { walls: "Paredes", floor: "Suelo", ceiling: "Techo", door: "Puertas", block: "Bloques" };
  const WALLS = ["north", "east", "south", "west"];
  const WALL_LABELS = { north: "N", east: "E", south: "S", west: "O" };
  const OPPOSITE_WALL = { north: "south", east: "west", south: "north", west: "east" };
  const RELATIVE_WALLS = {
    north: { left: "east", front: "south", right: "west" },
    east: { left: "south", front: "west", right: "north" },
    south: { left: "west", front: "north", right: "east" },
    west: { left: "north", front: "east", right: "south" }
  };
  // 0 grados mira al norte y los grados crecen hacia el este, igual que una brújula.
  const WALL_DEGREES = { north: 0, east: 90, south: 180, west: 270 };

  const LEVEL_KEYS = ["schemaVersion", "id", "name", "description", "timeLimitSeconds", "gridSize", "startingAmmo", "defaults", "rooms", "connections"];
  const ROOM_KEYS = ["id", "name", "type", "role", "position", "size", "entry", "facing", "wallHeight", "hasCeiling", "ammoReward", "textures", "blocks"];
  const CONNECTION_KEYS = ["id", "fromRoomId", "toRoomId", "fromWall", "toWall", "width"];

  const LIMITS = {
    timeLimit: { min: 1, max: 3600, fallback: 90 },
    wallHeight: { min: 2, max: 20, fallback: 6 },
    corridorWidth: { min: 1.5, max: 12, fallback: 3.5 },
    magazine: { min: 0, max: 200, fallback: 17 },
    reserve: { min: 0, max: 999, fallback: 51 },
    ammoReward: { min: 1, max: 999, fallback: 30 },
    movementSpeed: { min: 0.05, max: 5, fallback: 0.65 },
    wave: { min: 1, max: 64, fallback: 5 },
    facing: { min: 0, max: 359, fallback: 0 }
  };

  const clamp = (value, { min, max, fallback }) => {
    const numeric = Number(value);
    return Number.isFinite(numeric) ? Math.min(max, Math.max(min, numeric)) : fallback;
  };
  const clampInt = (value, limits) => Math.round(clamp(value, limits));
  const isHexColor = (value) => /^#[0-9a-f]{6}$/i.test(String(value));
  const newId = () => (typeof crypto !== "undefined" && crypto.randomUUID
    ? crypto.randomUUID()
    : `id-${Math.floor(Math.random() * 1e12).toString(36)}`);

  // Reordena las claves para que los JSON versionados se lean siempre igual.
  const ordered = (source, keys) => Object.fromEntries([
    ...keys.filter((key) => key in source).map((key) => [key, source[key]]),
    ...Object.entries(source).filter(([key]) => !keys.includes(key))
  ]);

  const blankTextures = (source = {}) => Object.fromEntries(Object.keys(TEXTURE_SLOTS)
    .map((slot) => [slot, typeof source[slot] === "string" ? source[slot] : ""]));

  const blankBlock = () => ({ enabled: false, movement: "static", movementSpeed: 0.65, color: "#2ed5c5", waves: [] });

  const blankAmmoReward = () => ({ enabled: false, amount: LIMITS.ammoReward.fallback, color: "#f4bc59" });

  function createEmptyLevel() {
    return {
      schemaVersion: SCHEMA_VERSION,
      id: `level-${Date.now()}`,
      name: "Nivel sin título",
      description: "",
      timeLimitSeconds: 90,
      gridSize: 1,
      startingAmmo: { magazine: LIMITS.magazine.fallback, reserve: LIMITS.reserve.fallback },
      defaults: {
        wallHeight: LIMITS.wallHeight.fallback,
        hasCeiling: true,
        corridorWidth: LIMITS.corridorWidth.fallback,
        textures: blankTextures()
      },
      rooms: [],
      connections: []
    };
  }

  function createRoom(type, index) {
    const preset = ROOM_PRESETS[type] || ROOM_PRESETS.custom;
    return {
      id: newId(),
      name: `Sala ${index}`,
      type,
      role: "transition",
      position: { x: (index - 1) * 4, z: (index - 1) * -4 },
      size: { width: preset.width, depth: preset.depth },
      entry: { wall: "south", offset: 0 },
      facing: 0,
      wallHeight: null,
      hasCeiling: null,
      ammoReward: blankAmmoReward(),
      textures: blankTextures(),
      blocks: { left: blankBlock(), front: blankBlock(), right: blankBlock() }
    };
  }

  function createConnection(from, to, corridorWidth) {
    return {
      id: newId(),
      fromRoomId: from.id,
      toRoomId: to.id,
      ...chooseConnectionWalls(from, to),
      width: clamp(corridorWidth, LIMITS.corridorWidth)
    };
  }

  /** La pared de cada extremo sale de la posición relativa de las dos salas. */
  function chooseConnectionWalls(from, to) {
    const dx = to.position.x - from.position.x;
    const dz = to.position.z - from.position.z;
    const fromWall = Math.abs(dx) >= Math.abs(dz)
      ? (dx >= 0 ? "east" : "west")
      : (dz >= 0 ? "south" : "north");
    return { fromWall, toWall: OPPOSITE_WALL[fromWall] };
  }

  /** Punto medio de una pared, en el plano visto desde arriba. */
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

  /**
   * Traza el pasillo entre dos salas y decide su ancho efectivo.
   *
   * El primer tramo sale perpendicular a la pared que perfora, o el pasillo
   * arrancaría de costado y dejaría la puerta contra una pared: por eso una
   * conexión norte / sur avanza primero en profundidad y una este / oeste,
   * primero a lo ancho.
   *
   * Cuando las dos puertas están desalineadas menos que el ancho del pasillo no
   * hay lugar para un codo — los dos giros se solaparían y se taparían entre
   * sí —, así que el pasillo va recto y se ensancha lo justo para cubrir ambas
   * bocas. Con más desfase describe un codo de cuatro puntos.
   */
  function corridorPlan(from, to, connection) {
    const start = wallPoint(from, connection.fromWall);
    const end = wallPoint(to, connection.toWall);
    const width = connection.width;
    const exitsAlongDepth = connection.fromWall === "north" || connection.fromWall === "south";
    const offset = exitsAlongDepth ? Math.abs(start.x - end.x) : Math.abs(start.y - end.y);
    if (offset < 0.01) return { points: [start, end], width };
    if (offset <= width) {
      const widened = width + offset;
      if (exitsAlongDepth) {
        const midX = (start.x + end.x) / 2;
        return { points: [{ x: midX, y: start.y }, { x: midX, y: end.y }], width: widened };
      }
      const midY = (start.y + end.y) / 2;
      return { points: [{ x: start.x, y: midY }, { x: end.x, y: midY }], width: widened };
    }
    if (exitsAlongDepth) {
      const midY = (start.y + end.y) / 2;
      return { points: [start, { x: start.x, y: midY }, { x: end.x, y: midY }, end], width };
    }
    const midX = (start.x + end.x) / 2;
    return { points: [start, { x: midX, y: start.y }, { x: midX, y: end.y }, end], width };
  }

  /**
   * Contorno cerrado del pasillo: recorre el trazado por su lado izquierdo y
   * vuelve por el derecho. Dibujarlo como una sola figura evita las costuras
   * que dejaban los rectángulos superpuestos, uno por tramo.
   *
   * En un recorrido ortogonal la esquina del contorno es la intersección de las
   * dos paralelas, y como los tramos son perpendiculares entre sí, esa
   * intersección es la suma de ambos desplazamientos.
   */
  function corridorOutline(points, width) {
    const half = width / 2;
    const direction = (from, to) => {
      const dx = to.x - from.x;
      const dy = to.y - from.y;
      const length = Math.hypot(dx, dy) || 1;
      return { x: dx / length, y: dy / length };
    };
    const leftOf = (d) => ({ x: d.y * half, y: -d.x * half });
    const left = [];
    const right = [];
    for (let index = 0; index < points.length; index += 1) {
      const incoming = index > 0 ? direction(points[index - 1], points[index]) : null;
      const outgoing = index < points.length - 1 ? direction(points[index], points[index + 1]) : null;
      let offset;
      if (!incoming) offset = leftOf(outgoing);
      else if (!outgoing) offset = leftOf(incoming);
      else {
        const a = leftOf(incoming);
        const b = leftOf(outgoing);
        offset = { x: a.x + b.x, y: a.y + b.y };
      }
      left.push({ x: points[index].x + offset.x, y: points[index].y + offset.y });
      right.push({ x: points[index].x - offset.x, y: points[index].y - offset.y });
    }
    return [...left, ...right.reverse()];
  }

  /** Las salas de inicio y de salida son únicas; el resto son de tránsito. */
  function normalizeRoles(rooms) {
    if (!rooms.length) return;
    let start = rooms.find((room) => room.role === "start");
    if (!start) start = rooms.find((room) => room.name.trim().toLowerCase() === "entrada") || rooms[0];
    let exit = rooms.find((room) => room.role === "exit" && room !== start);
    if (!exit) exit = rooms.find((room) => room.name.trim().toLowerCase() === "salida" && room !== start);
    if (!exit && rooms.length > 1) exit = rooms[rooms.length - 1] === start ? rooms[0] : rooms[rooms.length - 1];
    for (const room of rooms) room.role = "transition";
    start.role = "start";
    if (exit && exit !== start) exit.role = "exit";
  }

  /**
   * Asigna un rol a una sala respetando que inicio y salida son unicos: la sala
   * que tenia ese rol vuelve a ser de transito.
   */
  function assignRole(rooms, room, role) {
    if (role !== "transition") {
      for (const other of rooms) {
        if (other !== room && other.role === role) other.role = "transition";
      }
    }
    room.role = role;
    normalizeRoles(rooms);
    return rooms;
  }

  const wallToDegrees = (wall) => WALL_DEGREES[wall] ?? 0;

  /** Devuelve la pared de la sala más cercana a una dirección en grados. */
  function degreesToWall(degrees) {
    const normalized = ((Math.round(Number(degrees) || 0) % 360) + 360) % 360;
    let closest = "north";
    let best = Infinity;
    for (const wall of WALLS) {
      const raw = Math.abs(WALL_DEGREES[wall] - normalized);
      const distance = Math.min(raw, 360 - raw);
      if (distance < best) {
        best = distance;
        closest = wall;
      }
    }
    return closest;
  }

  /**
   * Recalcula la pared de entrada de cada sala recorriendo el nivel desde la de
   * inicio: se entra por la pared de la conexión que trajo al jugador hasta
   * ahí. En la sala de inicio el jugador aparece mirando `facing`, así que su
   * entrada es la pared que le queda a la espalda. Las salas sueltas conservan
   * la pared de su primera conexión.
   */
  function resolveEntryWalls(level) {
    const roomsById = new Map(level.rooms.map((room) => [room.id, room]));
    const neighbours = new Map(level.rooms.map((room) => [room.id, []]));
    for (const connection of level.connections) {
      if (!roomsById.has(connection.fromRoomId) || !roomsById.has(connection.toRoomId)) continue;
      neighbours.get(connection.fromRoomId).push({ id: connection.toRoomId, wall: connection.toWall });
      neighbours.get(connection.toRoomId).push({ id: connection.fromRoomId, wall: connection.fromWall });
    }
    const start = level.rooms.find((room) => room.role === "start") || level.rooms[0];
    const visited = new Set();
    if (start) {
      start.entry.wall = OPPOSITE_WALL[degreesToWall(start.facing)];
      visited.add(start.id);
      const queue = [start.id];
      while (queue.length) {
        const currentId = queue.shift();
        for (const step of neighbours.get(currentId) || []) {
          if (visited.has(step.id)) continue;
          visited.add(step.id);
          roomsById.get(step.id).entry.wall = step.wall;
          queue.push(step.id);
        }
      }
    }
    for (const room of level.rooms) {
      if (visited.has(room.id)) continue;
      const fallback = (neighbours.get(room.id) || [])[0];
      if (fallback) room.entry.wall = fallback.wall;
    }
    return level;
  }

  /**
   * Una sala sin orientación declarada mira hacia su primera conexión, que es
   * como orientaba al jugador el runtime antes de que fuera configurable.
   */
  function applyDefaultFacing(level) {
    for (const room of level.rooms) {
      if (room.facing !== null && room.facing !== undefined) continue;
      const connection = level.connections.find((item) => item.fromRoomId === room.id || item.toRoomId === room.id);
      const wall = connection
        ? (connection.fromRoomId === room.id ? connection.fromWall : connection.toWall)
        : "north";
      room.facing = wallToDegrees(wall);
    }
  }


  /** Acepta archivos de versiones anteriores y completa lo que falte. */
  function normalizeLevel(candidate) {
    if (!candidate || !Array.isArray(candidate.rooms) || !Array.isArray(candidate.connections)) {
      throw new Error("El archivo no contiene rooms y connections válidos.");
    }
    const level = candidate;
    level.schemaVersion = SCHEMA_VERSION;
    level.id ||= `level-${Date.now()}`;
    level.name ||= "Nivel importado";
    level.description ||= "";
    level.timeLimitSeconds = clampInt(level.timeLimitSeconds, LIMITS.timeLimit);
    level.gridSize ||= 1;
    level.startingAmmo = {
      magazine: clampInt(level.startingAmmo?.magazine, LIMITS.magazine),
      reserve: clampInt(level.startingAmmo?.reserve, LIMITS.reserve)
    };
    level.defaults = {
      wallHeight: clamp(level.defaults?.wallHeight, LIMITS.wallHeight),
      hasCeiling: level.defaults?.hasCeiling !== false,
      corridorWidth: clamp(level.defaults?.corridorWidth, LIMITS.corridorWidth),
      textures: blankTextures(level.defaults?.textures)
    };
    level.rooms.forEach((room, index) => {
      room.id ||= newId();
      room.name ||= `Sala ${index + 1}`;
      room.type = ROOM_PRESETS[room.type] ? room.type : "custom";
      room.role = ROLE_LABELS[room.role] ? room.role : "transition";
      room.position ||= { x: 0, z: 0 };
      room.size ||= { width: 14, depth: 14 };
      room.entry = { wall: WALLS.includes(room.entry?.wall) ? room.entry.wall : "south", offset: 0 };
      // Un archivo anterior a la orientación explícita hereda la que aplicaba
      // el runtime: mirar hacia la sala con la que conecta.
      room.facing = room.facing === undefined || room.facing === null
        ? null
        : clampInt(room.facing, LIMITS.facing);
      room.wallHeight = room.wallHeight === null || room.wallHeight === undefined
        ? null
        : clamp(room.wallHeight, LIMITS.wallHeight);
      room.hasCeiling = typeof room.hasCeiling === "boolean" ? room.hasCeiling : null;
      room.ammoReward = {
        enabled: Boolean(room.ammoReward?.enabled),
        amount: clampInt(room.ammoReward?.amount, LIMITS.ammoReward),
        color: isHexColor(room.ammoReward?.color) ? room.ammoReward.color : "#f4bc59"
      };
      room.textures = blankTextures(room.textures);
      room.blocks ||= {};
      for (const slot of Object.keys(SLOT_LABELS)) {
        const source = room.blocks[slot] || {};
        const legacyTargetCount = Math.max(0, Math.round(Number(source.targetCount) || 0));
        const waves = Array.isArray(source.waves)
          ? source.waves.map((count) => clampInt(count, LIMITS.wave))
          : (legacyTargetCount > 0 ? [legacyTargetCount] : []);
        const block = { ...blankBlock(), ...source, waves };
        block.movementSpeed = clamp(block.movementSpeed, LIMITS.movementSpeed);
        block.color = isHexColor(block.color) ? block.color : "#2ed5c5";
        block.movement = block.movement === "opposite" ? "opposite" : "static";
        delete block.targetCount;
        room.blocks[slot] = block;
      }
    });
    const roomIds = new Set(level.rooms.map((room) => room.id));
    level.connections = level.connections
      .filter((connection) => roomIds.has(connection.fromRoomId) && roomIds.has(connection.toRoomId))
      .map((connection) => ({
        ...connection,
        id: connection.id || newId(),
        fromWall: WALLS.includes(connection.fromWall) ? connection.fromWall : "east",
        toWall: WALLS.includes(connection.toWall) ? connection.toWall : "west",
        width: clamp(connection.width, { ...LIMITS.corridorWidth, fallback: level.defaults.corridorWidth })
      }));
    normalizeRoles(level.rooms);
    applyDefaultFacing(level);
    resolveEntryWalls(level);
    level.rooms = level.rooms.map((room) => ordered(room, ROOM_KEYS));
    level.connections = level.connections.map((connection) => ordered(connection, CONNECTION_KEYS));
    return ordered(level, LEVEL_KEYS);
  }

  const LevelFormat = {
    SCHEMA_VERSION,
    ROOM_PRESETS,
    ROLE_LABELS,
    SLOT_LABELS,
    TEXTURE_SLOTS,
    WALLS,
    WALL_LABELS,
    OPPOSITE_WALL,
    RELATIVE_WALLS,
    WALL_DEGREES,
    LEVEL_KEYS,
    ROOM_KEYS,
    CONNECTION_KEYS,
    LIMITS,
    clamp,
    clampInt,
    isHexColor,
    newId,
    ordered,
    blankTextures,
    blankBlock,
    blankAmmoReward,
    createEmptyLevel,
    createRoom,
    createConnection,
    chooseConnectionWalls,
    wallPoint,
    corridorPlan,
    corridorOutline,
    normalizeRoles,
    assignRole,
    applyDefaultFacing,
    wallToDegrees,
    degreesToWall,
    resolveEntryWalls,
    normalizeLevel
  };

  if (typeof module !== "undefined" && module.exports) module.exports = LevelFormat;
  if (typeof window !== "undefined") window.LevelFormat = LevelFormat;
})();
