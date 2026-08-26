// Modelo de los diseños de ventana del Window Workshop. Igual que
// level-format.js, es la única implementación: la comparten el editor, el
// servidor y los tests. Un diseño agrupa variantes estéticas sobre una familia
// existente — la familia decide cómo se juega; la variante, cómo se ve — y los
// niveles lo referencian como `custom:<slug>` en las capas de sus bloques.
(() => {
  "use strict";

  const WINDOW_DESIGNS_VERSION = 1;

  // Un slug identifica al diseño dentro de los niveles, así que se congela al
  // crearlo: renombrar el diseño no puede romper los archivos que lo usan.
  const SLUG_PATTERN = /^[a-z0-9][a-z0-9-]*$/;
  const CUSTOM_PREFIX = "custom:";

  // Skins de chrome disponibles. Tienen que coincidir con SKINS en
  // scripts/windows/window_skin.gd (hay un test de paridad). Una variante puede
  // pedir cualquiera; vacío usa la de la escena base.
  const SKINS = {
    xp: { label: "Windows XP" },
    retro: { label: "Retro 97" }
  };

  // Escenas base por familia. Tienen que coincidir con BASE_SCENES en
  // scripts/windows/window_catalog.gd (hay un test de paridad). `size` es el
  // tamaño nativo del SubViewport de la escena, `skin` la skin con la que la
  // escena está construida y `fields` dice qué textos existen en ella: la tool
  // no ofrece campos que la escena no puede mostrar.
  const BASES = {
    normal: {
      close: { label: "Aviso (X y Cerrar)", size: { width: 240, height: 110 }, skin: "xp", fields: ["title"] },
      shutdown: { label: "Salir (Finalizar)", size: { width: 320, height: 150 }, skin: "xp", fields: ["title", "message"] }
    },
    popup: {
      popup: { label: "Popup rápido (SKIP 5 s)", size: { width: 300, height: 150 }, skin: "xp", fields: ["title", "message", "subtitle"], messageLabel: "Titular", subtitleLabel: "Bajada" },
      "popup-slow": { label: "Popup lento (SKIP 10 s)", size: { width: 300, height: 150 }, skin: "xp", fields: ["title", "message", "subtitle"], messageLabel: "Titular", subtitleLabel: "Bajada" }
    },
    download: {
      download: { label: "Descarga", size: { width: 260, height: 130 }, skin: "retro", fields: ["title", "message"], messageLabel: "Archivo" }
    },
    "infected-download": {
      "infected-download": { label: "Descarga infectada", size: { width: 260, height: 130 }, skin: "retro", fields: ["title", "message"], messageLabel: "Archivo" }
    },
    firewall: {
      firewall: { label: "Firewall", size: { width: 260, height: 130 }, skin: "xp", fields: ["title", "message"] }
    },
    "critical-error": {
      "critical-error": { label: "Error crítico", size: { width: 300, height: 140 }, skin: "xp", fields: ["title", "message"] }
    }
  };

  // Sólo las familias con comportamiento propio pueden apadrinar diseños: una
  // familia `planned` todavía no tiene escena a la que vestirle variantes.
  const FAMILIES = Object.keys(BASES);

  // Tope del tamaño del SubViewport, en píxeles. Conservador a propósito: más
  // chico deja de ser disparable y más grande deforma los layouts de las
  // familias con offsets absolutos (descarga, error crítico).
  const SIZE_LIMITS = {
    width: { min: 200, max: 560 },
    height: { min: 110, max: 320 }
  };

  const TEXT_LIMITS = { title: 60, message: 200, subtitle: 200 };

  const DESIGN_KEYS = ["id", "slug", "name", "family", "variants"];
  const VARIANT_KEYS = ["base", "skin", "title", "message", "subtitle", "size"];

  const newId = () => (typeof crypto !== "undefined" && crypto.randomUUID
    ? crypto.randomUUID()
    : `id-${Math.floor(Math.random() * 1e12).toString(36)}`);

  const ordered = (source, keys) => Object.fromEntries([
    ...keys.filter((key) => key in source).map((key) => [key, source[key]]),
    ...Object.entries(source).filter(([key]) => !keys.includes(key))
  ]);

  function slugify(name) {
    return String(name ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
      .replace(/[^a-z0-9]+/g, "-").replace(/(^-+|-+$)/g, "");
  }

  const isCustomType = (type) => typeof type === "string" &&
    type.startsWith(CUSTOM_PREFIX) && SLUG_PATTERN.test(type.slice(CUSTOM_PREFIX.length));

  const customTypeKey = (design) => `${CUSTOM_PREFIX}${design.slug}`;

  const baseMeta = (family, base) => (BASES[family] || {})[base] || null;
  const defaultBase = (family) => Object.keys(BASES[family] || {})[0] || null;

  /** Tamaño efectivo de una variante: el propio o el nativo de su escena base. */
  function variantSize(variant, family) {
    if (variant.size && Number.isFinite(variant.size.width)) return variant.size;
    const meta = baseMeta(family, variant.base) || baseMeta(family, defaultBase(family));
    return meta ? meta.size : { width: 300, height: 150 };
  }

  const clampSize = (value, limits) => Math.round(Math.min(limits.max, Math.max(limits.min, value)));

  /** null = usar el tamaño nativo de la escena base. */
  function normalizeSizeValue(candidate) {
    const width = Number(candidate?.width);
    const height = Number(candidate?.height);
    if (!Number.isFinite(width) || !Number.isFinite(height)) return null;
    return {
      width: clampSize(width, SIZE_LIMITS.width),
      height: clampSize(height, SIZE_LIMITS.height)
    };
  }

  const cleanText = (value, limit) => typeof value === "string" ? value.trim().slice(0, limit) : "";

  function blankVariant(family) {
    return { base: defaultBase(family), skin: "", title: "", message: "", subtitle: "", size: null };
  }

  /** Skin con la que se ve una variante: la pedida o la nativa de su base. */
  function variantSkin(variant, family) {
    if (SKINS[variant.skin]) return variant.skin;
    const meta = baseMeta(family, variant.base) || baseMeta(family, defaultBase(family));
    return meta ? meta.skin : "xp";
  }

  function duplicateVariant(variant) {
    return JSON.parse(JSON.stringify(variant));
  }

  function blankDesign(name) {
    const clean = String(name ?? "").trim() || "Ventana";
    return {
      id: newId(),
      slug: slugify(clean) || "ventana",
      name: clean,
      family: "normal",
      variants: [blankVariant("normal")]
    };
  }

  /**
   * Una variante siempre queda usable: base desconocida cae en la primera de la
   * familia, los textos se recortan y el tamaño se acota o vuelve al nativo. Un
   * texto vacío significa "dejar el de la escena", así que no se inventa nada.
   * Los campos que este formato no conoce se conservan: una versión futura de
   * la tool puede haberlos escrito.
   */
  function normalizeVariant(candidate, family) {
    const source = candidate && typeof candidate === "object" ? candidate : {};
    const base = baseMeta(family, source.base) ? source.base : defaultBase(family);
    const variant = {
      ...source,
      base,
      skin: SKINS[source.skin] ? source.skin : "",
      title: cleanText(source.title, TEXT_LIMITS.title),
      message: cleanText(source.message, TEXT_LIMITS.message),
      subtitle: cleanText(source.subtitle, TEXT_LIMITS.subtitle),
      size: normalizeSizeValue(source.size)
    };
    return ordered(variant, VARIANT_KEYS);
  }

  /**
   * Acepta el archivo entero y devuelve sólo diseños sanos: sin nombre, sin
   * slug válido, con familia desconocida o con slug repetido se descartan (el
   * editor avisa cuántos quedaron afuera; acá no hay dónde avisar). No consulta
   * nada externo: es pura, como normalizeLevel.
   */
  function normalizeWindowDesigns(candidate) {
    const entries = Array.isArray(candidate?.designs) ? candidate.designs : [];
    const designs = [];
    const seen = new Set();
    for (const entry of entries) {
      if (!entry || typeof entry !== "object") continue;
      const name = String(entry.name ?? "").trim();
      const family = String(entry.family ?? "");
      const slug = SLUG_PATTERN.test(String(entry.slug ?? "")) ? String(entry.slug) : slugify(entry.slug || name);
      if (!name || !slug || !FAMILIES.includes(family) || seen.has(slug)) continue;
      seen.add(slug);
      const rawVariants = Array.isArray(entry.variants) ? entry.variants : [];
      const variants = rawVariants
        .filter((variant) => variant && typeof variant === "object")
        .map((variant) => normalizeVariant(variant, family));
      if (!variants.length) variants.push(normalizeVariant(blankVariant(family), family));
      designs.push(ordered({
        ...entry,
        id: typeof entry.id === "string" && entry.id ? entry.id : newId(),
        slug,
        name,
        family,
        variants
      }, DESIGN_KEYS));
    }
    return { schemaVersion: WINDOW_DESIGNS_VERSION, designs };
  }

  const WindowFormat = {
    WINDOW_DESIGNS_VERSION,
    SLUG_PATTERN,
    CUSTOM_PREFIX,
    SKINS,
    BASES,
    FAMILIES,
    SIZE_LIMITS,
    TEXT_LIMITS,
    slugify,
    isCustomType,
    customTypeKey,
    baseMeta,
    defaultBase,
    variantSize,
    variantSkin,
    blankVariant,
    duplicateVariant,
    blankDesign,
    normalizeVariant,
    normalizeWindowDesigns
  };

  if (typeof module !== "undefined" && module.exports) module.exports = WindowFormat;
  if (typeof window !== "undefined") window.WindowFormat = WindowFormat;
})();
