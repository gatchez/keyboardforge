#!/usr/bin/env bash
# File: tests/run_all_tests.sh
# Single entry point that runs every component's test suite.
# Each block is skipped gracefully if that phase/component isn't present yet,
# so this script works correctly at every phase snapshot of the project.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FAILED=0
run_suite() {
    local name="$1"
    shift
    echo ""
    echo "=============================================="
    echo " $name"
    echo "=============================================="
    if "$@"; then
        echo "[PASS] $name"
    else
        echo "[FAIL] $name"
        FAILED=1
    fi
}

# --- Phase 2: Core Keyboard Engine ---
if compgen -G "core/tests/test_*.py" > /dev/null 2>&1; then
    run_suite "Core engine tests (pytest)" bash -c "cd core && python3 -m pytest tests/ -q"
fi

# --- Phase 3: Linux installer ---
if [[ -f "linux/test.sh" ]]; then
    run_suite "Linux installer tests" bash -c "cd linux && ./test.sh"
fi

# --- Phase 4: CLI ---
if compgen -G "cli/tests/test_*.py" > /dev/null 2>&1; then
    run_suite "CLI tests (pytest)" bash -c "cd cli && python3 -m pytest tests/ -q"
fi

# --- Phase 5: GUI (static asset sanity + logic/smoke tests) ---
if [[ -f "gui/index.html" ]]; then
    run_suite "GUI static asset checks" bash -c "
        [[ -s gui/index.html ]] &&
        [[ -s gui/app.js ]] &&
        [[ -s gui/style.css ]] &&
        grep -q '<html' gui/index.html
    "
    if command -v node >/dev/null 2>&1; then
        run_suite "GUI logic tests (node --test)" bash -c "cd gui && node --test test_logic.js"
        if [[ -d "gui/node_modules/jsdom" ]]; then
            run_suite "GUI headless DOM smoke test (jsdom)" bash -c "cd gui && node smoke_test.js"
        else
            echo "[SKIP] GUI DOM smoke test -- run 'npm install' in gui/ first."
        fi
    fi
fi

# --- Cross-component integration test ---
if [[ -f "tests/test_end_to_end.sh" && -f "linux/install.sh" ]]; then
    run_suite "End-to-end integration test" bash tests/test_end_to_end.sh
fi

echo ""
if [[ "$FAILED" == "1" ]]; then
    echo "One or more test suites FAILED."
    exit 1
fi
echo "All available test suites passed."
