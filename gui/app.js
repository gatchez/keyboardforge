// gui/app.js
// DOM wiring for the KeyboardForge visual layout editor. Pure/testable
// logic lives in logic.js (loaded before this file); this file only deals
// with rendering and event handling.
(function () {
    "use strict";

    // Physical key geometry. Groupings mirror the original fr_custom
    // hand-authored layout: BKSL is grouped with the AC (home) row, LSGT
    // starts the AB (bottom) row -- see docs/architecture.md for why.
    var ROWS = [
        [{ code: "TLDE" }].concat(range(1, 12).map(function (n) { return { code: "AE" + pad(n) }; })),
        [{ spacer: true, label: "Tab", width: 64 }].concat(range(1, 12).map(function (n) { return { code: "AD" + pad(n) }; })),
        [{ spacer: true, label: "Caps", width: 72 }].concat(range(1, 11).map(function (n) { return { code: "AC" + pad(n) }; })).concat([{ code: "BKSL" }]),
        [{ code: "LSGT" }].concat(range(1, 10).map(function (n) { return { code: "AB" + pad(n) }; })).concat([{ spacer: true, label: "Shift", width: 72 }]),
    ];

    var PALETTE_SYMBOLS = [
        "a", "A", "1", "ampersand", "at", "eacute", "egrave", "ccedilla", "agrave", "ugrave",
        "dead_circumflex", "dead_diaeresis", "section", "degree", "sterling", "dollar", "EuroSign",
        "mu", "semicolon", "colon", "exclam", "question", "comma", "period", "slash", "asterisk",
        "plus", "minus", "equal", "underscore", "bracketleft", "bracketright", "braceleft",
        "braceright", "parenleft", "parenright", "less", "greater", "bar", "backslash",
        "asciitilde", "asciicircum", "quotedbl", "apostrophe", "grave",
    ];

    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    function range(a, b) { var out = []; for (var i = a; i <= b; i++) out.push(i); return out; }

    // --- state -----------------------------------------------------------
    var state = {
        meta: null,           // {xkb_name, variant, description, language, base_layout, includes, author, version}
        keysMap: {},           // {CODE: {keycode, levels, comment}}
        selected: null,
        currentLevel: 0,
        searchQuery: "",
        history: [],
        future: [],
    };

    var el = {
        keyboard: document.getElementById("keyboard"),
        meta: document.getElementById("layout-meta"),
        editor: document.getElementById("property-editor"),
        palette: document.getElementById("symbol-palette"),
        status: document.getElementById("status-text"),
        levelSelect: document.getElementById("level-select"),
        search: document.getElementById("search-box"),
        zoom: document.getElementById("zoom"),
    };

    // --- history -----------------------------------------------------------
    function snapshot() {
        return JSON.stringify({ meta: state.meta, keys: KFLogic.keysMapToArray(state.keysMap) });
    }

    function pushHistory() {
        state.history.push(snapshot());
        if (state.history.length > 50) state.history.shift();
        state.future = [];
    }

    function restoreSnapshot(text) {
        var data = JSON.parse(text);
        state.meta = data.meta;
        state.keysMap = KFLogic.keysArrayToMap(data.keys);
    }

    function undo() {
        if (state.history.length < 2) return; // nothing before current state
        state.future.push(state.history.pop());
        restoreSnapshot(state.history[state.history.length - 1]);
        renderAll();
        setStatus("Undid last change.");
    }

    function redo() {
        if (!state.future.length) return;
        var next = state.future.pop();
        state.history.push(next);
        restoreSnapshot(next);
        renderAll();
        setStatus("Redid change.");
    }

    // --- layout lifecycle ----------------------------------------------------
    function loadLayout(dict) {
        state.meta = {
            xkb_name: dict.xkb_name, variant: dict.variant, description: dict.description || "",
            language: dict.language || "eng", base_layout: dict.base_layout || null,
            includes: dict.includes || [], author: dict.author || "", version: dict.version || "1.0.0",
        };
        state.keysMap = KFLogic.keysArrayToMap(dict.keys || []);
        state.selected = null;
        state.history = [];
        state.future = [];
        pushHistory();
        renderAll();
        setStatus("Loaded '" + state.meta.xkb_name + "' (" + Object.keys(state.keysMap).length + " keys).");
    }

    function newLayout() {
        loadLayout(KFLogic.blankLayout("new_layout", "custom", "New Layout", "eng"));
    }

    function exportDict() {
        return {
            xkb_name: state.meta.xkb_name, variant: state.meta.variant, description: state.meta.description,
            language: state.meta.language, base_layout: state.meta.base_layout, includes: state.meta.includes,
            author: state.meta.author, version: state.meta.version,
            keys: KFLogic.keysMapToArray(state.keysMap),
        };
    }

    function saveLayout() {
        if (!state.meta) return;
        var blob = new Blob([JSON.stringify(exportDict(), null, 2) + "\n"], { type: "application/json" });
        var a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = (state.meta.xkb_name || "layout") + ".json";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setStatus("Saved " + a.download + ".");
    }

    // --- rendering -----------------------------------------------------------
    function renderAll() {
        renderMeta();
        renderKeyboard();
        renderPalette();
        renderPropertyEditor();
    }

    function renderMeta() {
        if (!state.meta) { el.meta.innerHTML = ""; return; }
        var m = state.meta;
        el.meta.innerHTML =
            '<strong>' + escapeHtml(m.xkb_name) + '</strong> (' + escapeHtml(m.variant) + ') &mdash; ' +
            escapeHtml(m.description || "(no description)") + ' &middot; ' + Object.keys(state.keysMap).length + ' keys';
    }

    function renderKeyboard() {
        el.keyboard.innerHTML = "";
        if (!state.meta) return;
        ROWS.forEach(function (row) {
            var rowEl = document.createElement("div");
            rowEl.className = "kb-row";
            row.forEach(function (slot) {
                var keyEl = document.createElement("div");
                if (slot.spacer) {
                    keyEl.className = "key spacer";
                    keyEl.style.minWidth = (slot.width || 44) + "px";
                    keyEl.textContent = slot.label || "";
                } else {
                    var code = slot.code;
                    var key = state.keysMap[code];
                    keyEl.className = "key";
                    if (state.selected === code) keyEl.className += " selected";
                    if (KFLogic.matchesSearch(code, key, state.searchQuery)) {
                        if (state.searchQuery) keyEl.className += " match";
                    } else {
                        keyEl.style.opacity = "0.35";
                    }
                    keyEl.dataset.keycode = code;
                    keyEl.textContent = key ? KFKeysyms.charFor(KFLogic.rawSymbolAtLevel(key, state.currentLevel)) : "";
                    var rawSym = key ? KFLogic.rawSymbolAtLevel(key, state.currentLevel) : "";
                    if (KFKeysyms.isDeadKey(rawSym)) keyEl.className += " dead-key";
                    keyEl.title = code + (rawSym ? " (" + rawSym + ")" : "");
                    keyEl.addEventListener("click", function () { selectKey(code); });
                    keyEl.addEventListener("dragover", function (e) { e.preventDefault(); keyEl.classList.add("drag-over"); });
                    keyEl.addEventListener("dragleave", function () { keyEl.classList.remove("drag-over"); });
                    keyEl.addEventListener("drop", function (e) {
                        e.preventDefault();
                        keyEl.classList.remove("drag-over");
                        var symbol = e.dataTransfer.getData("text/plain");
                        if (symbol) applyLevel(code, state.currentLevel, symbol, true);
                    });
                }
                rowEl.appendChild(keyEl);
            });
            el.keyboard.appendChild(rowEl);
        });
    }

    function renderPalette() {
        el.palette.innerHTML = "";
        PALETTE_SYMBOLS.forEach(function (sym) {
            var span = document.createElement("span");
            span.className = "palette-symbol";
            span.draggable = true;
            span.textContent = sym;
            span.addEventListener("dragstart", function (e) { e.dataTransfer.setData("text/plain", sym); });
            el.palette.appendChild(span);
        });
    }

    function renderPropertyEditor() {
        if (!state.selected) {
            el.editor.innerHTML = '<h2>Key Editor</h2><p class="placeholder">Select a key on the keyboard to edit it.</p>';
            return;
        }
        var code = state.selected;
        var key = state.keysMap[code] || { keycode: code, levels: [] };
        var levels = KFLogic.padLevels(key.levels, 4);
        var labels = ["Level 1 (base)", "Level 2 (Shift)", "Level 3 (AltGr)", "Level 4 (Shift+AltGr)"];

        var html = '<h2>Key: ' + escapeHtml(code) + '</h2>';
        for (var i = 0; i < 4; i++) {
            html += '<label>' + labels[i] + '</label>' +
                '<input type="text" data-level="' + i + '" value="' + escapeHtml(levels[i]) + '">';
        }
        html += '<label>Comment</label><input type="text" id="key-comment" value="' + escapeHtml(key.comment || "") + '">';
        html += '<div class="row-actions"><button id="btn-delete-key" class="danger">Delete key</button></div>';
        el.editor.innerHTML = html;

        Array.prototype.forEach.call(el.editor.querySelectorAll("input[data-level]"), function (input) {
            input.addEventListener("change", function () {
                applyLevel(code, parseInt(input.getAttribute("data-level"), 10), input.value, true);
            });
        });
        document.getElementById("key-comment").addEventListener("change", function (e) {
            var k = state.keysMap[code] || { keycode: code, levels: [] };
            k.comment = e.target.value || null;
            state.keysMap[code] = k;
            pushHistory();
        });
        document.getElementById("btn-delete-key").addEventListener("click", function () {
            delete state.keysMap[code];
            state.selected = null;
            pushHistory();
            renderAll();
            setStatus("Deleted key " + code + ".");
        });
    }

    function selectKey(code) {
        state.selected = code;
        renderKeyboard();
        renderPropertyEditor();
    }

    function applyLevel(code, levelIndex, value, recordHistory) {
        var key = state.keysMap[code] || { keycode: code, levels: [] };
        key.levels = KFLogic.setLevel(key.levels, levelIndex, value);
        state.keysMap[code] = key;
        renderKeyboard();
        if (state.selected === code) renderPropertyEditor();
        renderMeta();
        if (recordHistory) pushHistory();
    }

    function escapeHtml(s) {
        return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
            return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
        });
    }

    function setStatus(text) { el.status.textContent = text; }

    // --- toolbar wiring --------------------------------------------------------
    document.getElementById("btn-new").addEventListener("click", newLayout);
    document.getElementById("btn-save").addEventListener("click", saveLayout);
    document.getElementById("btn-undo").addEventListener("click", undo);
    document.getElementById("btn-redo").addEventListener("click", redo);
    document.getElementById("btn-theme").addEventListener("click", function () {
        document.body.classList.toggle("theme-dark");
        document.body.classList.toggle("theme-light");
    });

    document.getElementById("file-load").addEventListener("change", function (e) {
        var file = e.target.files[0];
        if (!file) return;
        var reader = new FileReader();
        reader.onload = function () {
            try {
                loadLayout(JSON.parse(reader.result));
            } catch (err) {
                setStatus("Could not parse " + file.name + ": " + err.message);
            }
        };
        reader.readAsText(file);
        e.target.value = "";
    });

    el.levelSelect.addEventListener("change", function () {
        state.currentLevel = parseInt(el.levelSelect.value, 10);
        renderKeyboard();
    });

    el.search.addEventListener("input", function () {
        state.searchQuery = el.search.value;
        renderKeyboard();
    });

    el.zoom.addEventListener("input", function () {
        el.keyboard.style.transform = "scale(" + (el.zoom.value / 100) + ")";
    });

    document.addEventListener("keydown", function (e) {
        if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "z") { e.preventDefault(); undo(); }
        if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "y") { e.preventDefault(); redo(); }
    });

    // Start with an empty state; user picks "New Layout" or "Load JSON".
    renderAll();
})();
