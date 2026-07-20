# Git & GitHub Workflow Guide

A complete, structured, copy-pasteable guide for committing KeyboardForge
to your GitHub account phase by phase, testing each phase before you
commit and push it. Written for any level of Git familiarity -- if you
already know Git well, skip to the [Cheat sheet](#cheat-sheet) at the end.

## Table of contents

1. [Prerequisites & one-time setup](#1-prerequisites--one-time-setup)
2. [Create the GitHub repository](#2-create-the-github-repository)
3. [Initialize your local repository](#3-initialize-your-local-repository)
4. [Add the GitHub tooling first (recommended)](#4-add-the-github-tooling-first-recommended)
5. [Phase-by-phase workflow](#5-phase-by-phase-workflow)
6. [After Phase 7: tag a release](#6-after-phase-7-tag-a-release)
7. [Troubleshooting common Git problems](#7-troubleshooting-common-git-problems)
8. [Cheat sheet](#cheat-sheet)

---

## 1. Prerequisites & one-time setup

**Install Git**, if you don't already have it:
```bash
git --version
# If missing:
sudo apt-get install -y git      # Debian/Ubuntu
sudo dnf install -y git          # Fedora
sudo pacman -Sy --needed git     # Arch Linux
```

**Tell Git who you are** (once per machine -- these appear on every commit
you make):
```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

**Set up authentication with GitHub.** Two common options:

- **GitHub CLI (`gh`) -- recommended, simplest:**
  ```bash
  # Install: see https://github.com/cli/cli#installation for your distro,
  # or on most distros:
  sudo apt-get install -y gh      # Debian/Ubuntu (may need the GitHub apt repo -- see link above)
  sudo dnf install -y gh          # Fedora
  sudo pacman -Sy --needed github-cli   # Arch Linux

  gh auth login
  # Follow the interactive prompts: choose GitHub.com, HTTPS, and
  # "Login with a web browser" is the easiest option.
  ```
- **SSH key (traditional alternative):** follow GitHub's own guide at
  <https://docs.github.com/en/authentication/connecting-to-github-with-ssh>
  if you'd rather not install `gh`.

The rest of this guide shows `gh` commands where relevant, with the plain
`git`-only equivalent alongside.

---

## 2. Create the GitHub repository

**Using `gh` (creates it and sets up the remote in one step):**
```bash
cd keyboardforge      # the project folder from wherever you extracted/cloned it
gh repo create keyboardforge --public --source=. --remote=origin
# Use --private instead of --public if you don't want it visible yet
# while you're still testing phase by phase.
```

**Or via the GitHub website:**
1. Go to <https://github.com/new>.
2. Repository name: `keyboardforge` (or any name you prefer).
3. Do **not** check "Add a README file", "Add .gitignore", or "Choose a
   license" -- this project already has all three, and letting GitHub
   create its own would conflict with them.
4. Click **Create repository**, then note the URL it gives you (something
   like `https://github.com/<your-username>/keyboardforge.git`) for the
   next section.

---

## 3. Initialize your local repository

If you used `gh repo create --source=. --remote=origin` above, this step
is already done for you -- skip to section 4.

Otherwise:
```bash
cd keyboardforge
git init
git branch -M main
git remote add origin https://github.com/<your-username>/keyboardforge.git
```
Replace `<your-username>` with your actual GitHub username, and the URL
with the one GitHub showed you in section 2.

Confirm the remote is set correctly:
```bash
git remote -v
# origin  https://github.com/<your-username>/keyboardforge.git (fetch)
# origin  https://github.com/<your-username>/keyboardforge.git (push)
```

---

## 4. Add the GitHub tooling first (recommended)

Before committing any phase content, commit the repository-level tooling
this guide's companion deliverable added: `.github/workflows/ci.yml` (runs
the test suite automatically on every push), `.github/ISSUE_TEMPLATE/`,
`.github/PULL_REQUEST_TEMPLATE.md`, `.gitignore`, and this file itself.
Doing this first means CI is already active by the time you push your
very first phase.

```bash
git add .github .gitignore GIT_WORKFLOW.md
git status   # review what's about to be committed
git commit -m "chore: add GitHub Actions CI and contribution templates" -m "- .github/workflows/ci.yml runs tests/run_all_tests.sh on every push/PR
- .github/ISSUE_TEMPLATE/ (bug report, feature request)
- .github/PULL_REQUEST_TEMPLATE.md
- .gitignore covers Python/Node build artifacts and installer logs
- GIT_WORKFLOW.md: this guide"
git push -u origin main
```

**Important:** `linux/install.sh` intentionally requires root privileges
even when run with `--dry-run` (see `docs/architecture.md`), so the CI
workflow runs the whole test suite under `sudo`. This is expected and
already configured in `ci.yml` -- you don't need to do anything extra for
it to work on GitHub's hosted runners.

---

## 5. Phase-by-phase workflow

For each phase below: extract that phase's zip **on top of** your existing
working directory (each phase zip is cumulative and additive -- it never
removes files, so anything from section 4 above, or from an earlier
phase, is preserved), run that phase's test command, review what changed,
commit with the suggested message, then push.

**Extracting a phase zip on top of your existing checkout** (do this
before every phase, including Phase 1):
```bash
# Replace N with the phase number and adjust the filename to match.
unzip -o ~/Downloads/keyboardforge_phaseN_*.zip -d /tmp/kf_extract
rsync -a /tmp/kf_extract/keyboardforge/ ./
rm -rf /tmp/kf_extract
```
`rsync -a` (archive mode, **no** `--delete`) copies every file from the
extracted phase into your repository, overwriting anything that changed
and adding anything new, while leaving alone anything already in your
repository that isn't part of the phase zip (like the `.github/` tooling
and this guide, from section 4). If `rsync` isn't installed
(`sudo apt-get install -y rsync` / `sudo dnf install -y rsync` /
`sudo pacman -Sy --needed rsync`), a `cp -a` equivalent that also handles
dotfiles is:
```bash
shopt -s dotglob
cp -a /tmp/kf_extract/keyboardforge/. ./
shopt -u dotglob
```

### Phase 1 -- Foundation

```bash
# (extract phase 1 zip as shown above)
./tests/run_all_tests.sh
# Expect: "All available test suites passed." -- nothing to test yet at
# this phase besides the skeleton itself.

git add -A
git status   # review: should be README.md, LICENSE, VERSION, docs/architecture.md,
             # tests/run_all_tests.sh, .gitignore (if not already committed)
git commit -m "feat(foundation): establish KeyboardForge project structure" -m "- Renamed project to KeyboardForge; documented the rename and its scope
- Added docs/architecture.md (component map, data flow, coding standards)
- Added tests/run_all_tests.sh as the top-level test-runner skeleton
- Added LICENSE (MIT), VERSION, .gitignore"
git push
```

### Phase 2 -- Core Keyboard Engine

```bash
# (extract phase 2 zip)
cd core && python3 -m pytest tests/ -q && cd ..
# Expect all tests to pass, including real-system-data tests in
# test_xkb_parser_real_files.py / test_system_layouts.py if this machine
# has xkb-data installed (they skip cleanly, not fail, if it doesn't).

git add -A
git commit -m "feat(core): add keyboard layout engine" -m "- core/keyboardforge_core: Layout/Key model, validator, XKB generator
- xkb_parser.py: multi-variant-aware parser (brace-depth block extraction,
  comment stripping), tested against real xkb-data files, not just our
  own generated output
- system_layouts.py: detects and imports real OS-installed layouts,
  including recursive include resolution
- layouts/fr_custom.json: bundled example/seed layout"
git push
```

### Phase 3 -- Linux Integration

```bash
# (extract phase 3 zip)
chmod +x linux/*.sh linux/modules/*.sh tools/generate_layout.py
cd linux && ./test.sh && cd ..
python3 tools/generate_layout.py layouts/fr_custom.json linux/
sudo ./linux/install.sh --dry-run --yes   # requires root; makes zero real changes

git add -A
git commit -m "feat(linux): integrate core engine with the Linux installer" -m "- linux/: Debian, Fedora, and Arch installer/uninstaller, wired to
  consume XKB files generated from layouts/*.json by tools/generate_layout.py
- 3 real bugs found and fixed by actually running the installer:
  dry-run writing to disk, missing /etc/default/keyboard crashing the
  Debian branch, uninstall.sh tripping the global error trap on missing
  tools -- see docs/changelog.md"
git push
```

### Phase 4 -- CLI

```bash
# (extract phase 4 zip)
cd cli && python3 -m pytest tests/ -q && cd ..
# Includes a real (but safe) --dry-run install test against a throwaway
# copy of linux/ -- see cli/tests/test_cli.py.

git add -A
git commit -m "feat(cli): add keyboardforge command-line interface" -m "- new, set-key, remove-key, validate, export, import, list, install, uninstall
- system-layouts, import-system: detect and import real OS layouts
- Verified as a real installed pip package (built wheel, clean venv,
  console entry point), not just as a repo-relative script"
git push
```

### Phase 5 -- GUI

```bash
# (extract phase 5 zip)
cd gui && npm install && npm test && cd ..
# npm install is a dev-only dependency (jsdom) for the smoke test; the
# GUI itself needs no install step to use in a browser.

git add -A
git commit -m "feat(gui): add static visual layout editor" -m "- Zero-dependency, zero-build-step browser-based keyboard visualizer
- keysyms.js renders actual characters (not XKB symbol names) on keycaps,
  covering >85% of real-world usage across every xkb-data layout
  (Latin, Cyrillic, Greek, Arabic scripts), continuously re-verified by
  test_keysyms.js against whatever xkb-data is actually installed
- Dead keys shown with their accent glyph and a distinguishing style
- logic.js (pure) + keysyms.js (pure) + app.js (DOM) + a jsdom-based
  smoke test that drives the real UI, not just the pure logic"
git push
```

### Phase 6 -- Packaging

```bash
# (extract phase 6 zip)
python3 -m pip install --upgrade build
python3 -m build core/ && python3 -m build cli/
# Optionally also verify the built wheels install and the console script
# works, in a throwaway venv:
python3 -m venv /tmp/kf_check && /tmp/kf_check/bin/pip install core/dist/*.whl cli/dist/*.whl -q
/tmp/kf_check/bin/keyboardforge --help
rm -rf /tmp/kf_check core/dist core/build cli/dist cli/build core/*.egg-info cli/*.egg-info

git add -A
git commit -m "feat(packaging): add distribution packaging" -m "- pyproject.toml for keyboardforge-core (zero deps) and keyboardforge-cli
  (depends only on keyboardforge-core), with a 'keyboardforge' console entry point
- .deb / .rpm / Arch PKGBUILD metadata templates for the linux/ installer
- Makefile tying together test/generate/build-wheels/clean targets"
git push
```

### Phase 7 -- Documentation & QA

```bash
# (extract phase 7 zip)
./tests/run_all_tests.sh
# Full suite: core, linux, cli, gui, and the cross-component end-to-end
# integration test (tests/test_end_to_end.sh) all in one run. Run with
# sudo for full coverage of the real install/uninstall round trip:
sudo bash tests/run_all_tests.sh

git add -A
git commit -m "docs: add full documentation set and end-to-end integration tests" -m "- installation guide, user guide, developer guide, architecture,
  CLI manual, GUI manual, troubleshooting, FAQ, contributing, changelog,
  release notes -- written for readers with no assumed prior knowledge
- tests/test_end_to_end.sh: real install -> real uninstall round trip,
  asserting the system ends up byte-identical to its starting state"
git push
```

---

## 6. After Phase 7: tag a release

Once everything above is pushed and green on GitHub Actions (check the
"Actions" tab of your repository):

```bash
git tag -a v0.1.0 -m "KeyboardForge 0.1.0 -- see docs/release-notes.md"
git push origin v0.1.0
```

**Optionally, create a GitHub Release from that tag** (makes it easy for
others to find/download a specific version):
```bash
gh release create v0.1.0 --title "KeyboardForge 0.1.0" --notes-file docs/release-notes.md
```
or via the website: your repository -> "Releases" (right sidebar) ->
"Draft a new release" -> choose the `v0.1.0` tag -> paste in the contents
of `docs/release-notes.md` -> **Publish release**.

---

## 7. Troubleshooting common Git problems

**`error: failed to push some refs` / "Updates were rejected because the
remote contains work that you do not have locally"**
Someone (or something, e.g. GitHub's web UI) changed the remote
repository since your last push. Run `git pull --rebase origin main`,
resolve any conflicts it reports, then push again. If you're certain the
remote has nothing you need (e.g. you accidentally initialized the GitHub
repo with its own README despite section 2's instructions not to), you
can force-overwrite it instead -- **only do this if you're sure**:
```bash
git push --force-with-lease origin main
```

**I committed something I shouldn't have (e.g. `node_modules/`, a
`.venv/`, build artifacts)**
Check `.gitignore` already covers it (it covers `__pycache__/`,
`.pytest_cache/`, `node_modules/`, Python `dist/`/`build/`/`*.egg-info/`,
and installer logs). If you already committed it before it was ignored:
```bash
git rm -r --cached node_modules      # removes it from Git's tracking, keeps the local files
git commit -m "chore: stop tracking node_modules (already in .gitignore)"
git push
```

**I want to change my last commit message before pushing**
```bash
git commit --amend -m "the corrected message"
```
(Only do this if you haven't already pushed that commit -- if you have,
use `git push --force-with-lease` afterward, and only on a branch you're
sure nobody else has already pulled from.)

**`fatal: not a git repository`**
You're not inside the folder you ran `git init` in. `cd` into your
`keyboardforge` folder first.

**I want to see what's about to be committed before I commit it**
```bash
git status         # which files are staged/modified/untracked
git diff            # exact line-by-line changes, unstaged
git diff --staged     # exact line-by-line changes, staged (about to be committed)
```

**I want to undo `git add` for a file I staged by mistake**
```bash
git restore --staged <file>
```

---

## Cheat sheet

```bash
# One-time setup
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
gh auth login
gh repo create keyboardforge --public --source=. --remote=origin

# Per phase
unzip -o ~/Downloads/keyboardforge_phaseN_*.zip -d /tmp/kf_extract
rsync -a /tmp/kf_extract/keyboardforge/ ./ && rm -rf /tmp/kf_extract
# ... run that phase's test command (see section 5) ...
git add -A
git status
git commit -m "<subject>" -m "<body>"
git push

# After phase 7
git tag -a v0.1.0 -m "KeyboardForge 0.1.0"
git push origin v0.1.0
gh release create v0.1.0 --title "KeyboardForge 0.1.0" --notes-file docs/release-notes.md
```
