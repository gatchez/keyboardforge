// gui/smoke_test.js
// Loads the real index.html/logic.js/app.js into a jsdom environment and
// drives the actual UI (not just the pure logic) to catch DOM wiring bugs.
// Run with: node smoke_test.js
const fs = require("fs");
const path = require("path");
const { JSDOM } = require("jsdom");

const html = fs.readFileSync(path.join(__dirname, "index.html"), "utf8");
const logicSrc = fs.readFileSync(path.join(__dirname, "logic.js"), "utf8");
const keysymsSrc = fs.readFileSync(path.join(__dirname, "keysyms.js"), "utf8");
const appSrc = fs.readFileSync(path.join(__dirname, "app.js"), "utf8");

const dom = new JSDOM(html, { runScripts: "outside-only", url: "http://localhost/" });
const { window } = dom;

// jsdom doesn't implement URL.createObjectURL / drag events fully; stub the
// bits app.js touches so the smoke test can exercise real code paths.
window.URL.createObjectURL = () => "blob:stub";
window.Blob = function (parts, opts) { this.parts = parts; this.type = opts && opts.type; };

let failures = 0;
function check(label, cond) {
    if (cond) {
        console.log("[PASS] " + label);
    } else {
        console.log("[FAIL] " + label);
        failures++;
    }
}

// Run logic.js, then keysyms.js, then app.js in the jsdom window context.
dom.window.eval(logicSrc);
check("KFLogic is defined after loading logic.js", typeof window.KFLogic !== "undefined");
dom.window.eval(keysymsSrc);
check("KFKeysyms is defined after loading keysyms.js", typeof window.KFKeysyms !== "undefined");
dom.window.eval(appSrc);

const doc = window.document;

// 1. Initial state: no layout loaded yet.
check("keyboard is empty before any layout is loaded", doc.getElementById("keyboard").children.length === 0);

// 2. Click "New Layout" and verify the keyboard renders.
doc.getElementById("btn-new").dispatchEvent(new window.Event("click"));
const rows = doc.getElementById("keyboard").children;
check("keyboard has 4 rows after New Layout", rows.length === 4);
check("row 1 (TLDE + AE01..12) has 13 keys", rows[0].children.length === 13);
check("row 4 (LSGT + AB01..10 + Shift spacer) has 12 keys", rows[3].children.length === 12);

function findKey(code) {
    const rows = doc.getElementById("keyboard").children;
    for (const row of rows) {
        const found = Array.prototype.find.call(row.children, el => el.dataset && el.dataset.keycode === code);
        if (found) return found;
    }
    return null;
}

// 3. Click a key (AE01) and verify the property editor renders inputs.
let ae01 = findKey("AE01");
check("found the AE01 key element", !!ae01);
ae01.dispatchEvent(new window.Event("click"));
const levelInputs = doc.querySelectorAll('input[data-level]');
check("property editor shows 4 level inputs after selecting a key", levelInputs.length === 4);

// 4. Type into Level 1 and Level 2 and confirm the keycap label updates.
// (re-query after each change: applyLevel() fully re-renders the keyboard,
//  so any previously-held element reference is stale, exactly as it would
//  be for any code reacting to the DOM after a re-render.)
levelInputs[0].value = "1";
levelInputs[0].dispatchEvent(new window.Event("change"));
check("AE01 keycap shows the actual character '1' after editing", findKey("AE01").textContent === "1");

levelInputs[1].value = "ampersand";
levelInputs[1].dispatchEvent(new window.Event("change"));

// 5. Switch the displayed level to Level 2 and confirm the keycap shows
// the actual rendered character ('&'), not the technical symbol name
// ('ampersand') -- this is the specific behavior this test suite exists
// to guard: the keycap must always show what you'd actually type, not
// XKB's internal name for it.
const levelSelect = doc.getElementById("level-select");
levelSelect.value = "1";
levelSelect.dispatchEvent(new window.Event("change"));
check("AE01 keycap shows '&' (not 'ampersand') after switching level", findKey("AE01").textContent === "&");

// 5b. Dead keys get a distinguishing 'dead-key' class and still render a glyph.
levelInputs[1].value = "dead_circumflex";
levelInputs[1].dispatchEvent(new window.Event("change"));
check("dead_circumflex renders as '^', not the raw name", findKey("AE01").textContent === "^");
check("dead_circumflex gets the 'dead-key' CSS class", findKey("AE01").classList.contains("dead-key"));
// Revert to 'ampersand' for the remaining checks below.
levelInputs[1].value = "ampersand";
levelInputs[1].dispatchEvent(new window.Event("change"));

// 6. Search box filters/highlights matching keys -- searching still
// matches on the raw symbol *name* ('ampersand'), which is friendlier for
// search than requiring the person to type the literal '&' character.
const searchBox = doc.getElementById("search-box");
searchBox.value = "ampersand";
searchBox.dispatchEvent(new window.Event("input"));
check("AE01 gets the 'match' class when searching for its symbol name", findKey("AE01").classList.contains("match"));

// 7. Delete the key and confirm it's gone from the property editor.
searchBox.value = "";
searchBox.dispatchEvent(new window.Event("input"));
doc.getElementById("btn-delete-key").dispatchEvent(new window.Event("click"));
check("property editor resets to placeholder after deleting the selected key",
    doc.querySelector(".property-editor .placeholder") !== null);

// 8. Undo should bring the key back with its levels intact. (Switch the
// display back to Level 1 first -- it's still on Level 2 from step 5, and
// undo correctly doesn't change *which level is displayed*, only the data.)
doc.getElementById("btn-undo").dispatchEvent(new window.Event("click"));
levelSelect.value = "0";
levelSelect.dispatchEvent(new window.Event("change"));
check("undo restores AE01's Level 1 label", findKey("AE01").textContent === "1");

// 9. Theme toggle actually flips the body class.
check("body starts in theme-light", doc.body.classList.contains("theme-light"));
doc.getElementById("btn-theme").dispatchEvent(new window.Event("click"));
check("theme toggle switches to theme-dark", doc.body.classList.contains("theme-dark"));

console.log("");
if (failures > 0) {
    console.log(failures + " smoke test(s) FAILED.");
    process.exit(1);
}
console.log("All GUI smoke tests passed.");
