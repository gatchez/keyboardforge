// gui/test_keysyms.js
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");
const KFKeysyms = require("./keysyms.js");

test("charFor resolves known named symbols to their character", () => {
    assert.equal(KFKeysyms.charFor("ampersand"), "&");
    assert.equal(KFKeysyms.charFor("at"), "@");
    assert.equal(KFKeysyms.charFor("eacute"), "\u00e9");
    assert.equal(KFKeysyms.charFor("EuroSign"), "\u20ac");
    assert.equal(KFKeysyms.charFor("degree"), "\u00b0");
});

test("charFor passes through single-character keysyms unchanged", () => {
    assert.equal(KFKeysyms.charFor("a"), "a");
    assert.equal(KFKeysyms.charFor("A"), "A");
    assert.equal(KFKeysyms.charFor("5"), "5");
});

test("charFor decodes KeyboardForge's own 0x-prefixed Unicode codepoints", () => {
    // 0x10000b2 -> 0x01000000 offset + 0xb2 -> U+00B2 SUPERSCRIPT TWO
    assert.equal(KFKeysyms.charFor("0x10000b2"), "\u00b2");
});

test("charFor decodes U-prefixed Unicode keysym names", () => {
    assert.equal(KFKeysyms.charFor("U2022"), "\u2022"); // bullet
});

test("charFor renders NoSymbol/VoidSymbol as blank, not the literal name", () => {
    assert.equal(KFKeysyms.charFor("NoSymbol"), "");
    assert.equal(KFKeysyms.charFor("VoidSymbol"), "");
});

test("charFor falls back to the raw name for something genuinely unmapped", () => {
    assert.equal(KFKeysyms.charFor("SomeExoticKeysymNobodyMapped"), "SomeExoticKeysymNobodyMapped");
});

test("charFor handles empty/falsy input without throwing", () => {
    assert.equal(KFKeysyms.charFor(""), "");
    assert.equal(KFKeysyms.charFor(null), "");
    assert.equal(KFKeysyms.charFor(undefined), "");
});

test("isDeadKey correctly identifies dead_* tokens", () => {
    assert.equal(KFKeysyms.isDeadKey("dead_circumflex"), true);
    assert.equal(KFKeysyms.isDeadKey("dead_diaeresis"), true);
    assert.equal(KFKeysyms.isDeadKey("ampersand"), false);
    assert.equal(KFKeysyms.isDeadKey(""), false);
});

test("every dead_* entry in the table resolves to a non-empty display glyph", () => {
    Object.keys(KFKeysyms.TABLE)
        .filter((name) => name.indexOf("dead_") === 0)
        .forEach((name) => {
            assert.notEqual(KFKeysyms.charFor(name), "", `${name} should not render blank`);
        });
});

// --- Real-world coverage check --------------------------------------------
// Rather than trusting the table in isolation, scan every layout file the
// OS actually ships (same corpus the table was built from) and assert a
// concrete coverage bar. This will only run where xkb-data is installed;
// it skips (not fails) elsewhere, exactly like the equivalent Python tests
// in core/tests/.

const XKB_SYMBOLS_DIR = "/usr/share/X11/xkb/symbols";

test("keysym table covers the large majority of real-world usage", (t) => {
    if (!fs.existsSync(XKB_SYMBOLS_DIR)) {
        t.skip("xkb-data not installed on this system");
        return;
    }

    const counts = new Map();
    const keyRe = /key\s*<[A-Za-z0-9_]+>\s*\{([^{}]*)\}\s*;/g;
    const bracketRe = /\[([^\]]*)\]/;
    for (const fname of fs.readdirSync(XKB_SYMBOLS_DIR)) {
        const full = path.join(XKB_SYMBOLS_DIR, fname);
        let text;
        try {
            if (!fs.statSync(full).isFile()) continue;
            text = fs.readFileSync(full, "utf8");
        } catch (e) {
            continue;
        }
        let keyMatch;
        while ((keyMatch = keyRe.exec(text)) !== null) {
            const bracketMatch = bracketRe.exec(keyMatch[1]);
            if (!bracketMatch) continue;
            for (const raw of bracketMatch[1].split(",")) {
                const sym = raw.trim();
                if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(sym)) {
                    counts.set(sym, (counts.get(sym) || 0) + 1);
                }
            }
        }
    }

    let totalOccurrences = 0;
    let unmappedOccurrences = 0;
    const unmappedNames = new Set();
    for (const [sym, count] of counts.entries()) {
        totalOccurrences += count;
        const resolved = KFKeysyms.charFor(sym);
        // "Unmapped" = charFor had nothing better to do than echo the name
        // back (and it isn't a trivially-already-a-character name, and
        // isn't the deliberately-blank NoSymbol/VoidSymbol pair).
        if (resolved === sym && sym.length > 1 && sym !== "NoSymbol" && sym !== "VoidSymbol") {
            unmappedOccurrences += count;
            unmappedNames.add(sym);
        }
    }

    const coverage = 1 - unmappedOccurrences / totalOccurrences;
    console.log(`  keysym coverage: ${(coverage * 100).toFixed(1)}% of ${totalOccurrences} ` +
        `real occurrences across ${counts.size} distinct names ` +
        `(${unmappedNames.size} distinct names unmapped)`);

    assert.ok(
        coverage > 0.85,
        `Expected >85% real-world keysym coverage, got ${(coverage * 100).toFixed(1)}%. ` +
        `Most common unmapped: ${[...unmappedNames].slice(0, 20).join(", ")}`
    );
    // Note: 100% is not the goal here. A meaningful chunk of the remaining
    // ~15% is *functional* keysyms with no printable glyph at all by
    // design -- modifier switches (ISO_Level3_Shift, Mode_switch), media
    // keys (XF86AudioMute, etc.), keypad functions (KP_Enter), and
    // modifier names themselves (Control_L, Alt_R, Super_L...). Falling
    // back to showing their technical name for those is correct behavior,
    // not a gap to close.
});
