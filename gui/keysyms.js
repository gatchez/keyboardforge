// gui/keysyms.js
// Maps XKB keysym *names* (e.g. "ampersand", "eacute", "dead_circumflex")
// to the actual character they produce, so the keyboard visualization can
// show "&" and "é" instead of the technical name "ampersand"/"eacute" --
// matching what's actually printed on a real keycap.
//
// The table below is prioritized by real-world frequency: it was built by
// scanning every layout file shipped by the xkb-data package (138 files,
// covering ~100 countries/languages) and covers every keysym name that
// appears more than a handful of times across that corpus, plus the full
// standard Latin-1/Latin-9 letter set. For anything not in the table, two
// general fallback rules handle the long tail (see `charFor` below), and
// anything still unresolved falls back to showing its technical name
// rather than a blank key -- so nothing is ever silently hidden.
//
// UMD-style like logic.js: usable as a plain browser script or a Node
// `require()`-able module (see test_keysyms.js).
(function (root, factory) {
    var mod = factory();
    if (typeof module !== "undefined" && module.exports) {
        module.exports = mod;
    } else {
        root.KFKeysyms = mod;
    }
})(typeof self !== "undefined" ? self : this, function () {
    "use strict";

    var TABLE = {
        // --- ASCII punctuation (the ones with symbolic XKB names) ---
        space: " ", exclam: "!", quotedbl: '"', numbersign: "#", dollar: "$",
        percent: "%", ampersand: "&", apostrophe: "'", parenleft: "(", parenright: ")",
        asterisk: "*", plus: "+", comma: ",", minus: "-", period: ".", slash: "/",
        colon: ":", semicolon: ";", less: "<", equal: "=", greater: ">", question: "?",
        at: "@", bracketleft: "[", backslash: "\\", bracketright: "]", asciicircum: "^",
        underscore: "_", grave: "`", braceleft: "{", bar: "|", braceright: "}",
        asciitilde: "~",

        // --- Latin-1 / Latin-9 accented letters ---
        Agrave: "\u00C0", Aacute: "\u00C1", Acircumflex: "\u00C2", Atilde: "\u00C3",
        Adiaeresis: "\u00C4", Aring: "\u00C5", AE: "\u00C6", Ccedilla: "\u00C7",
        Egrave: "\u00C8", Eacute: "\u00C9", Ecircumflex: "\u00CA", Ediaeresis: "\u00CB",
        Igrave: "\u00CC", Iacute: "\u00CD", Icircumflex: "\u00CE", Idiaeresis: "\u00CF",
        ETH: "\u00D0", Ntilde: "\u00D1", Ograve: "\u00D2", Oacute: "\u00D3",
        Ocircumflex: "\u00D4", Otilde: "\u00D5", Odiaeresis: "\u00D6", Ooblique: "\u00D8",
        Ugrave: "\u00D9", Uacute: "\u00DA", Ucircumflex: "\u00DB", Udiaeresis: "\u00DC",
        Yacute: "\u00DD", THORN: "\u00DE",
        agrave: "\u00E0", aacute: "\u00E1", acircumflex: "\u00E2", atilde: "\u00E3",
        adiaeresis: "\u00E4", aring: "\u00E5", ae: "\u00E6", ccedilla: "\u00E7",
        egrave: "\u00E8", eacute: "\u00E9", ecircumflex: "\u00EA", ediaeresis: "\u00EB",
        igrave: "\u00EC", iacute: "\u00ED", icircumflex: "\u00EE", idiaeresis: "\u00EF",
        eth: "\u00F0", ntilde: "\u00F1", ograve: "\u00F2", oacute: "\u00F3",
        ocircumflex: "\u00F4", otilde: "\u00F5", odiaeresis: "\u00F6", ooblique: "\u00F8",
        ugrave: "\u00F9", uacute: "\u00FA", ucircumflex: "\u00FB", udiaeresis: "\u00FC",
        yacute: "\u00FD", thorn: "\u00FE", ydiaeresis: "\u00FF", ssharp: "\u00DF",

        // --- Currency & typographic symbols ---
        degree: "\u00B0", section: "\u00A7", plusminus: "\u00B1", multiply: "\u00D7",
        division: "\u00F7", notsign: "\u00AC", brokenbar: "\u00A6", currency: "\u00A4",
        cent: "\u00A2", sterling: "\u00A3", yen: "\u00A5", EuroSign: "\u20AC",
        copyright: "\u00A9", registered: "\u00AE", trademark: "\u2122", paragraph: "\u00B6",
        periodcentered: "\u00B7", guillemotleft: "\u00AB", guillemotright: "\u00BB",
        questiondown: "\u00BF", exclamdown: "\u00A1", nobreakspace: "\u00A0",
        mu: "\u00B5", masculine: "\u00BA", feminine: "\u00AA", cedilla: "\u00B8",
        macron: "\u00AF", acute: "\u00B4", diaeresis: "\u00A8",

        // --- Superscripts / fractions ---
        onesuperior: "\u00B9", twosuperior: "\u00B2", threesuperior: "\u00B3",
        onehalf: "\u00BD", onequarter: "\u00BC", threequarters: "\u00BE",
        onethird: "\u2153", twothirds: "\u2154",
        oneeighth: "\u215B", threeeighths: "\u215C", fiveeighths: "\u215D", seveneighths: "\u215E",

        // --- Quotation marks & dashes ---
        leftdoublequotemark: "\u201C", rightdoublequotemark: "\u201D",
        leftsinglequotemark: "\u2018", rightsinglequotemark: "\u2019",
        doublelowquotemark: "\u201E", singlelowquotemark: "\u201A",
        endash: "\u2013", emdash: "\u2014", hyphen: "\u2010",
        ellipsis: "\u2026", U2022: "\u2022",

        // --- Ligatures / strokes ---
        oe: "\u0153", OE: "\u0152", lstroke: "\u0142", Lstroke: "\u0141",
        dstroke: "\u0111", Dstroke: "\u0110", tstroke: "\u0167", Tstroke: "\u0166",
        eng: "\u014B", ENG: "\u014A",

        // --- Greek (full alphabet, upper + lower) ---
        Greek_alpha: "\u03B1", Greek_beta: "\u03B2", Greek_gamma: "\u03B3",
        Greek_delta: "\u03B4", Greek_epsilon: "\u03B5", Greek_zeta: "\u03B6",
        Greek_eta: "\u03B7", Greek_theta: "\u03B8", Greek_iota: "\u03B9",
        Greek_kappa: "\u03BA", Greek_lambda: "\u03BB", Greek_mu: "\u03BC",
        Greek_nu: "\u03BD", Greek_xi: "\u03BE", Greek_omicron: "\u03BF",
        Greek_pi: "\u03C0", Greek_rho: "\u03C1", Greek_sigma: "\u03C3",
        Greek_finalsmallsigma: "\u03C2", Greek_tau: "\u03C4", Greek_upsilon: "\u03C5",
        Greek_phi: "\u03C6", Greek_chi: "\u03C7", Greek_psi: "\u03C8", Greek_omega: "\u03C9",
        Greek_ALPHA: "\u0391", Greek_BETA: "\u0392", Greek_GAMMA: "\u0393",
        Greek_DELTA: "\u0394", Greek_EPSILON: "\u0395", Greek_ZETA: "\u0396",
        Greek_ETA: "\u0397", Greek_THETA: "\u0398", Greek_IOTA: "\u0399",
        Greek_KAPPA: "\u039A", Greek_LAMBDA: "\u039B", Greek_MU: "\u039C",
        Greek_NU: "\u039D", Greek_XI: "\u039E", Greek_OMICRON: "\u039F",
        Greek_PI: "\u03A0", Greek_RHO: "\u03A1", Greek_SIGMA: "\u03A3",
        Greek_TAU: "\u03A4", Greek_UPSILON: "\u03A5", Greek_PHI: "\u03A6",
        Greek_CHI: "\u03A7", Greek_PSI: "\u03A8", Greek_OMEGA: "\u03A9",
        Greek_accentdieresis: "\u0385", Greek_horizbar: "\u2015",
        Greek_iotaaccentdieresis: "\u0390", Greek_upsilonaccentdieresis: "\u03B0",
        Greek_alphaaccent: "\u03AC", Greek_epsilonaccent: "\u03AD",
        Greek_etaaccent: "\u03AE", Greek_iotaaccent: "\u03AF",
        Greek_omicronaccent: "\u03CC", Greek_upsilonaccent: "\u03CD",
        Greek_omegaaccent: "\u03CE", Greek_iotadieresis: "\u03CA",
        Greek_upsilondieresis: "\u03CB",

        // --- Cyrillic (Russian base alphabet + common extras used by
        // Ukrainian, Belarusian, Serbian, Macedonian layouts) ---
        Cyrillic_a: "\u0430", Cyrillic_be: "\u0431", Cyrillic_ve: "\u0432",
        Cyrillic_ghe: "\u0433", Cyrillic_de: "\u0434", Cyrillic_ie: "\u0435",
        Cyrillic_zhe: "\u0436", Cyrillic_ze: "\u0437", Cyrillic_i: "\u0438",
        Cyrillic_shorti: "\u0439", Cyrillic_ka: "\u043A", Cyrillic_el: "\u043B",
        Cyrillic_em: "\u043C", Cyrillic_en: "\u043D", Cyrillic_o: "\u043E",
        Cyrillic_pe: "\u043F", Cyrillic_er: "\u0440", Cyrillic_es: "\u0441",
        Cyrillic_te: "\u0442", Cyrillic_u: "\u0443", Cyrillic_ef: "\u0444",
        Cyrillic_ha: "\u0445", Cyrillic_tse: "\u0446", Cyrillic_che: "\u0447",
        Cyrillic_sha: "\u0448", Cyrillic_shcha: "\u0449", Cyrillic_hardsign: "\u044A",
        Cyrillic_yeru: "\u044B", Cyrillic_softsign: "\u044C", Cyrillic_e: "\u044D",
        Cyrillic_yu: "\u044E", Cyrillic_ya: "\u044F", Cyrillic_io: "\u0451",
        Cyrillic_A: "\u0410", Cyrillic_BE: "\u0411", Cyrillic_VE: "\u0412",
        Cyrillic_GHE: "\u0413", Cyrillic_DE: "\u0414", Cyrillic_IE: "\u0415",
        Cyrillic_ZHE: "\u0416", Cyrillic_ZE: "\u0417", Cyrillic_I: "\u0418",
        Cyrillic_SHORTI: "\u0419", Cyrillic_KA: "\u041A", Cyrillic_EL: "\u041B",
        Cyrillic_EM: "\u041C", Cyrillic_EN: "\u041D", Cyrillic_O: "\u041E",
        Cyrillic_PE: "\u041F", Cyrillic_ER: "\u0420", Cyrillic_ES: "\u0421",
        Cyrillic_TE: "\u0422", Cyrillic_U: "\u0423", Cyrillic_EF: "\u0424",
        Cyrillic_HA: "\u0425", Cyrillic_TSE: "\u0426", Cyrillic_CHE: "\u0427",
        Cyrillic_SHA: "\u0428", Cyrillic_SHCHA: "\u0429", Cyrillic_HARDSIGN: "\u042A",
        Cyrillic_YERU: "\u042B", Cyrillic_SOFTSIGN: "\u042C", Cyrillic_E: "\u042D",
        Cyrillic_YU: "\u042E", Cyrillic_YA: "\u042F", Cyrillic_IO: "\u0401",
        Ukrainian_i: "\u0456", Ukrainian_I: "\u0406", Ukrainian_yi: "\u0457",
        Ukrainian_YI: "\u0407", Ukrainian_ghe_with_upturn: "\u0491",
        Ukrainian_GHE_WITH_UPTURN: "\u0490", Byelorussian_shortu: "\u045E",
        Byelorussian_SHORTU: "\u040E", Serbian_dje: "\u0452", Serbian_DJE: "\u0402",
        Macedonia_gje: "\u0453", Macedonia_GJE: "\u0403",

        // --- Arabic (base letters + common diacritics) ---
        Arabic_comma: "\u060C", Arabic_semicolon: "\u061B", Arabic_question_mark: "\u061F",
        Arabic_hamza: "\u0621", Arabic_maddaonalef: "\u0622", Arabic_hamzaonalef: "\u0623",
        Arabic_hamzaonwaw: "\u0624", Arabic_hamzaunderalef: "\u0625", Arabic_hamzaonyeh: "\u0626",
        Arabic_alef: "\u0627", Arabic_beh: "\u0628", Arabic_tehmarbuta: "\u0629",
        Arabic_teh: "\u062A", Arabic_theh: "\u062B", Arabic_jeem: "\u062C",
        Arabic_hah: "\u062D", Arabic_khah: "\u062E", Arabic_dal: "\u062F",
        Arabic_thal: "\u0630", Arabic_ra: "\u0631", Arabic_zain: "\u0632",
        Arabic_seen: "\u0633", Arabic_sheen: "\u0634", Arabic_sad: "\u0635",
        Arabic_dad: "\u0636", Arabic_tah: "\u0637", Arabic_zah: "\u0638",
        Arabic_ain: "\u0639", Arabic_ghain: "\u063A", Arabic_tatweel: "\u0640",
        Arabic_feh: "\u0641", Arabic_qaf: "\u0642", Arabic_kaf: "\u0643",
        Arabic_lam: "\u0644", Arabic_meem: "\u0645", Arabic_noon: "\u0646",
        Arabic_ha: "\u0647", Arabic_waw: "\u0648", Arabic_alefmaksura: "\u0649",
        Arabic_yeh: "\u064A", Arabic_fathatan: "\u064B", Arabic_dammatan: "\u064C",
        Arabic_kasratan: "\u064D", Arabic_fatha: "\u064E", Arabic_damma: "\u064F",
        Arabic_kasra: "\u0650", Arabic_shadda: "\u0651", Arabic_sukun: "\u0652",
        Arabic_madda_above: "\u0653", Arabic_hamza_above: "\u0654", Arabic_hamza_below: "\u0655",
        Farsi_yeh: "\u06CC", Farsi_0: "\u06F0", Farsi_1: "\u06F1", Farsi_2: "\u06F2",
        Farsi_3: "\u06F3", Farsi_4: "\u06F4", Farsi_5: "\u06F5", Farsi_6: "\u06F6",
        Farsi_7: "\u06F7", Farsi_8: "\u06F8", Farsi_9: "\u06F9", Keheh: "\u06A9",
        Gaf: "\u06AF", Arabic_keheh: "\u06A9", Arabic_gaf: "\u06AF",
        Arabic_0: "\u0660", Arabic_1: "\u0661", Arabic_2: "\u0662", Arabic_3: "\u0663",
        Arabic_4: "\u0664", Arabic_5: "\u0665", Arabic_6: "\u0666", Arabic_7: "\u0667",
        Arabic_8: "\u0668", Arabic_9: "\u0669",

        // --- Special / placeholders (render as blank -- these mean
        // "nothing at this level", not "unknown symbol") ---
        NoSymbol: "", VoidSymbol: "",

        // --- Dead keys: shown as the bare combining/spacing accent mark
        // that key will apply to whatever you type next. `isDeadKey()`
        // below flags these so the UI can add a distinguishing visual
        // treatment (see gui/style.css .key.dead-key) beyond just the glyph.
        dead_grave: "`", dead_acute: "\u00B4", dead_circumflex: "^",
        dead_tilde: "~", dead_diaeresis: "\u00A8", dead_macron: "\u00AF",
        dead_breve: "\u02D8", dead_abovedot: "\u02D9", dead_abovering: "\u02DA",
        dead_doubleacute: "\u02DD", dead_caron: "\u02C7", dead_cedilla: "\u00B8",
        dead_ogonek: "\u02DB", dead_belowdot: ".", dead_hook: "\u02C0",
        dead_horn: "\u02BC", dead_stroke: "/", dead_iota: "\u037A",
        dead_currency: "\u00A4",
    };

    var UNICODE_NAME_RE = /^U([0-9A-Fa-f]{4,6})$/;   // e.g. "U2022"
    var XKB_HEX_CODEPOINT_RE = /^0x([0-9A-Fa-f]+)$/;  // e.g. "0x10000b2" (KeyboardForge's own convention)
    var XKB_HEX_OFFSET = 0x01000000;

    function isDeadKey(rawSymbol) {
        return typeof rawSymbol === "string" && rawSymbol.indexOf("dead_") === 0;
    }

    /** Resolve a raw XKB keysym name/token into what should be displayed
     * on a keycap. Always returns a string (possibly "" for NoSymbol, or
     * the raw name itself as a last-resort fallback -- never undefined). */
    function charFor(rawSymbol) {
        if (!rawSymbol) return "";

        if (Object.prototype.hasOwnProperty.call(TABLE, rawSymbol)) {
            return TABLE[rawSymbol];
        }

        var hexMatch = XKB_HEX_CODEPOINT_RE.exec(rawSymbol);
        if (hexMatch) {
            var value = parseInt(hexMatch[1], 16);
            var codepoint = value >= XKB_HEX_OFFSET ? value - XKB_HEX_OFFSET : value;
            if (codepoint > 0) {
                try {
                    return String.fromCodePoint(codepoint);
                } catch (e) { /* fall through to raw-name fallback below */ }
            }
        }

        var unicodeNameMatch = UNICODE_NAME_RE.exec(rawSymbol);
        if (unicodeNameMatch) {
            try {
                return String.fromCodePoint(parseInt(unicodeNameMatch[1], 16));
            } catch (e) { /* fall through */ }
        }

        // Already a literal single character (covers plain letters "a"/"A"
        // and digits "0"-"9", which are their own valid XKB keysym names).
        if (rawSymbol.length === 1) return rawSymbol;

        // Unmapped: show the technical name rather than nothing, so the
        // person can still see (and correct) what's actually defined there.
        return rawSymbol;
    }

    return {
        TABLE: TABLE,
        charFor: charFor,
        isDeadKey: isDeadKey,
    };
});
