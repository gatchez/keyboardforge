.PHONY: test test-core test-linux test-cli test-gui generate-fr-custom \
        install-dev build-wheels package-linux clean

# Run every component's test suite.
test:
	./tests/run_all_tests.sh

test-core:
	cd core && python3 -m pytest tests/ -q

test-linux:
	cd linux && ./test.sh

test-cli:
	cd cli && python3 -m pytest tests/ -q

test-gui:
	cd gui && node --test test_logic.js
	cd gui && [ -d node_modules/jsdom ] && node smoke_test.js || echo "run 'npm install' in gui/ first"

# Regenerate the bundled fr_custom XKB files from their JSON source of truth.
generate-fr-custom:
	python3 tools/generate_layout.py layouts/fr_custom.json linux/

# Editable-install the core engine and CLI into the current Python environment.
install-dev:
	pip install -e core/
	pip install -e cli/

# Build distributable Python wheels for core/ and cli/.
build-wheels:
	python3 -m pip install --upgrade build
	python3 -m build core/
	python3 -m build cli/

# Placeholder: see packaging/README.md -- wiring this up to actually invoke
# dpkg-deb/rpmbuild/makepkg against the templates in packaging/ is tracked
# as future work, not yet implemented.
package-linux:
	@echo "See packaging/README.md -- .deb/.rpm/.pkg.tar.zst build automation is not yet wired up."
	@exit 1

clean:
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name ".pytest_cache" -type d -exec rm -rf {} + 2>/dev/null || true
	rm -f linux/logs/*.log
	rm -rf core/dist core/build core/*.egg-info
	rm -rf cli/dist cli/build cli/*.egg-info
