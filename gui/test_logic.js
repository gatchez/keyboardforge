// gui/test_logic.js
// Run with: node --test gui/test_logic.js
const test = require("node:test");
const assert = require("node:assert/strict");
const KFLogic = require("./logic.js");

test("padLevels pads short arrays and does not mutate input", () => {
    const input = ["1", "ampersand"];
    const out = KFLogic.padLevels(input, 4);
    assert.deepEqual(out, ["1", "ampersand", "", ""]);
    assert.deepEqual(input, ["1", "ampersand"]); // untouched
});

test("padLevels truncates arrays longer than count", () => {
    const out = KFLogic.padLevels(["a", "b", "c", "d", "e"], 4);
    assert.deepEqual(out, ["a", "b", "c", "d"]);
});

test("setLevel sets a slot and trims trailing empties", () => {
    const out = KFLogic.setLevel(["1"], 1, "ampersand");
    assert.deepEqual(out, ["1", "ampersand"]);
});

test("setLevel keeps at least one slot even if it ends up empty", () => {
    const out = KFLogic.setLevel([], 0, "");
    assert.deepEqual(out, [""]);
});

test("setLevel does not mutate the input array", () => {
    const input = ["1", "ampersand"];
    KFLogic.setLevel(input, 2, "asciitilde");
    assert.deepEqual(input, ["1", "ampersand"]);
});

test("rawSymbolAtLevel returns the raw symbol token at the requested level", () => {
    const key = { levels: ["1", "ampersand"] };
    assert.equal(KFLogic.rawSymbolAtLevel(key, 0), "1");
    assert.equal(KFLogic.rawSymbolAtLevel(key, 1), "ampersand");
    assert.equal(KFLogic.rawSymbolAtLevel(key, 2), ""); // not defined
});

test("rawSymbolAtLevel does not decode/render anything -- that's keysyms.js's job", () => {
    const key = { levels: ["0x10000b2"] };
    assert.equal(KFLogic.rawSymbolAtLevel(key, 0), "0x10000b2");
});

test("rawSymbolAtLevel handles a missing key gracefully", () => {
    assert.equal(KFLogic.rawSymbolAtLevel(null, 0), "");
    assert.equal(KFLogic.rawSymbolAtLevel({ levels: [] }, 0), "");
});

test("matchesSearch matches on keycode", () => {
    assert.equal(KFLogic.matchesSearch("AE01", { levels: ["1"] }, "ae01"), true);
});

test("matchesSearch matches on any level symbol, case-insensitively", () => {
    assert.equal(KFLogic.matchesSearch("AE02", { levels: ["2", "eacute"] }, "EACUTE"), true);
    assert.equal(KFLogic.matchesSearch("AE02", { levels: ["2", "eacute"] }, "zzz"), false);
});

test("matchesSearch: empty query matches everything", () => {
    assert.equal(KFLogic.matchesSearch("AE01", { levels: ["1"] }, ""), true);
});

test("keysArrayToMap and keysMapToArray round-trip", () => {
    const arr = [
        { keycode: "ae01", levels: ["1", "ampersand"] },
        { keycode: "AD01", levels: ["q", "Q"], comment: "note" },
    ];
    const map = KFLogic.keysArrayToMap(arr);
    assert.deepEqual(Object.keys(map).sort(), ["AD01", "AE01"]);
    assert.equal(map["AE01"].levels[1], "ampersand");

    const backToArray = KFLogic.keysMapToArray(map);
    assert.equal(backToArray.length, 2);
    assert.equal(backToArray[0].keycode, "AD01"); // sorted
    assert.equal(backToArray[0].comment, "note");
    assert.equal(backToArray[1].comment, undefined);
});

test("blankLayout produces a valid-shape empty layout", () => {
    const layout = KFLogic.blankLayout("fr_custom", "custom", "French", "fra");
    assert.equal(layout.xkb_name, "fr_custom");
    assert.equal(layout.variant, "custom");
    assert.equal(layout.description, "French");
    assert.equal(layout.language, "fra");
    assert.deepEqual(layout.keys, []);
});

test("blankLayout applies sensible defaults", () => {
    const layout = KFLogic.blankLayout();
    assert.equal(layout.xkb_name, "new_layout");
    assert.equal(layout.variant, "custom");
    assert.equal(layout.language, "eng");
});
