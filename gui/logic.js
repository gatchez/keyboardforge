// gui/logic.js
// Pure, DOM-free helper functions used by app.js. Kept separate so they can
// be unit-tested directly under Node (see gui/test_logic.js) without
// needing a browser or DOM shim.
(function (root, factory) {
    var mod = factory();
    if (typeof module !== "undefined" && module.exports) {
        module.exports = mod;
    } else {
        root.KFLogic = mod;
    }
})(typeof self !== "undefined" ? self : this, function () {
    "use strict";

    var LEVEL_COUNT = 4;

    /** Pad (or trim a copy of) a levels array out to exactly `count` slots,
     * filling missing trailing slots with "". Never mutates the input. */
    function padLevels(levels, count) {
        count = count || LEVEL_COUNT;
        var out = (levels || []).slice(0, count);
        while (out.length < count) out.push("");
        return out;
    }

    /** Set a single level slot on a levels array, padding as needed.
     * Returns a new array; does not mutate the input. */
    function setLevel(levels, index, value) {
        var out = padLevels(levels, Math.max(LEVEL_COUNT, index + 1));
        out[index] = value;
        // Trim trailing empty levels beyond the highest non-empty one,
        // but always keep at least 1 slot.
        var lastNonEmpty = -1;
        for (var i = 0; i < out.length; i++) {
            if (out[i] !== "") lastNonEmpty = i;
        }
        return out.slice(0, Math.max(1, lastNonEmpty + 1));
    }

    /** The raw XKB symbol token defined at the given level (e.g.
     * "ampersand", "0x10000b2", "1"), or "" if that level isn't defined.
     * This is a pure data lookup -- turning that token into something
     * human-displayable (an actual character, a dead-key glyph, etc.) is
     * keysyms.js's job (see charFor() there), deliberately kept separate
     * so this stays trivially unit-testable without needing the keysym
     * table loaded. */
    function rawSymbolAtLevel(key, levelIndex) {
        if (!key || !key.levels) return "";
        return key.levels[levelIndex] || "";
    }

    /** Case-insensitive match: does this key's code or any of its levels
     * contain the query substring? Empty query matches everything. */
    function matchesSearch(keycode, key, query) {
        if (!query) return true;
        var q = query.toLowerCase();
        if (keycode.toLowerCase().indexOf(q) !== -1) return true;
        var levels = (key && key.levels) || [];
        for (var i = 0; i < levels.length; i++) {
            if ((levels[i] || "").toLowerCase().indexOf(q) !== -1) return true;
        }
        return false;
    }

    /** Convert the JSON layout dict's `keys` array into a {CODE: key} map. */
    function keysArrayToMap(keysArray) {
        var map = {};
        (keysArray || []).forEach(function (k) {
            map[k.keycode.toUpperCase()] = { keycode: k.keycode.toUpperCase(), levels: k.levels || [], comment: k.comment || null };
        });
        return map;
    }

    /** Convert a {CODE: key} map back into the JSON layout dict's `keys`
     * array, sorted by keycode for stable/diffable output. */
    function keysMapToArray(keysMap) {
        return Object.keys(keysMap).sort().map(function (code) {
            var k = keysMap[code];
            var out = { keycode: code, levels: k.levels || [] };
            if (k.comment) out.comment = k.comment;
            return out;
        });
    }

    /** Build a blank layout dict with the given metadata and no keys. */
    function blankLayout(xkbName, variant, description, language) {
        return {
            xkb_name: xkbName || "new_layout",
            variant: variant || "custom",
            description: description || "",
            language: language || "eng",
            base_layout: null,
            includes: [],
            author: "",
            version: "1.0.0",
            keys: [],
        };
    }

    return {
        LEVEL_COUNT: LEVEL_COUNT,
        padLevels: padLevels,
        setLevel: setLevel,
        rawSymbolAtLevel: rawSymbolAtLevel,
        matchesSearch: matchesSearch,
        keysArrayToMap: keysArrayToMap,
        keysMapToArray: keysMapToArray,
        blankLayout: blankLayout,
    };
});
