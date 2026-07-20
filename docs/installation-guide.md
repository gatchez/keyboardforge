# Installation Guide

This guide explains how to install and use every part of KeyboardForge, from
zero. It assumes no prior experience with the command line, Python, Git,
or keyboard layout internals. If you already know some of this, skip
ahead using the table of contents below.

## Table of contents

1. [What KeyboardForge is, and which parts you actually need](#1-what-keyboardforge-is-and-which-parts-you-actually-need)
2. [Before you start: opening a terminal](#2-before-you-start-opening-a-terminal)
3. [Checking and installing prerequisites](#3-checking-and-installing-prerequisites)
4. [Getting the KeyboardForge files onto your computer](#4-getting-the-keyboardforge-files-onto-your-computer)
5. [Option A: Install the bundled example layout as-is](#5-option-a-install-the-bundled-example-layout-as-is)
6. [Option B: Install the command-line interface (CLI)](#6-option-b-install-the-command-line-interface-cli)
7. [Option C: Use the graphical editor (GUI)](#7-option-c-use-the-graphical-editor-gui)
8. [Verifying your layout was installed correctly](#8-verifying-your-layout-was-installed-correctly)
9. [Uninstalling / reverting](#9-uninstalling--reverting)
10. [Building distributable packages](#10-building-distributable-packages)
11. [Getting help](#11-getting-help)

---

## 1. What KeyboardForge is, and which parts you actually need

KeyboardForge lets you create and install **custom keyboard layouts** on
Linux -- for example, remapping which character each key produces,
changing what Shift or AltGr do on a specific key, or starting from one of
your operating system's own built-in layouts (its real `us`, `fr`, `de`,
etc.) and tweaking it.

The project has four parts. **You do not need all of them** -- pick based
on how you want to work:

| Part | What it's for | Do you need it? |
|---|---|---|
| `linux/` | The installer that actually applies a layout to your system | **Yes, always** -- this is the only part that touches your real system |
| `core/` + `cli/` | A command-line tool (`keyboardforge`) for creating/editing/validating layouts, and importing your OS's real layouts | Optional -- only if you want to script things or don't want to use the graphical editor |
| `gui/` | A point-and-click visual layout editor that runs in your web browser | Optional -- only if you prefer clicking over typing commands |
| `docs/`, `packaging/` | This documentation, and templates for building `.deb`/`.rpm`/Arch packages | Not required to use the software |

If you just want to try the bundled example layout with the least effort,
read section 5 only. If you want to build your own layout starting from
your OS's real keyboard layout, read sections 6 and/or 7 as well.

**A note on "example/seed" data:** this project ships with one working
example layout, `layouts/fr_custom.json` (a customized French layout), so
that every tool in the project has something real to load, edit, and
install right out of the box. It is **not** the point of the project --
it exists purely to demonstrate that the pipeline works end to end. Your
own layouts, and layouts imported from your operating system, work
exactly the same way through exactly the same tools.

---

## 2. Before you start: opening a terminal

Every command in this guide is typed into a **terminal** (also called a
"command line", "console", or "shell"). If you already know how to open
one on your system, skip to section 3.

- **Ubuntu, Debian, Fedora, or Arch Linux with a desktop (GNOME/KDE/XFCE):**
  Press the "Super" key (usually the Windows-logo key) and type `terminal`,
  then press Enter. Or look for an application called "Terminal",
  "Console", or "Konsole" in your applications menu.
- **A Linux server with no desktop (SSH):** You are most likely already
  looking at a terminal if you connected via `ssh`.

Once open, you'll see a prompt, usually ending in `$` (regular user) or `#`
(root user), where you can type commands. Every command shown in this
guide as a gray code block is meant to be typed there, followed by
pressing Enter. Lines starting with `#` inside a code block are comments
explaining what the next line does -- they are not meant to be typed.

**A note on `sudo`:** many commands below start with `sudo`. This runs the
command with administrator ("root") privileges, which are required to
install a system-wide keyboard layout, install system packages, or modify
files outside your home directory. You will normally be prompted to type
your own account password (not a separate "root password") the first time
you use `sudo` in a terminal session. If you are not a member of your
system's administrator group, ask whoever manages the machine to either
run these commands for you or add your account to that group (on Debian/
Ubuntu/Fedora/Arch this is usually the `sudo` or `wheel` group).

---

## 3. Checking and installing prerequisites

Different parts of the project need different tools. Check what you
already have before installing anything -- most of these come
pre-installed on modern Linux desktops.

### 3.1 Required for the Linux installer (`linux/`) -- always needed

**Bash** (the shell itself). Check with:
```bash
bash --version
```
If this prints a version number, you have it (virtually every Linux
system does; if this command isn't found at all, something unusual is
going on with your system and you should consult your distribution's
documentation).

**One of these three Linux distribution families.** Check which one you
have:
```bash
cat /etc/os-release
```
Look at the `ID` and `ID_LIKE` lines in the output.
- If you see `debian` or `ubuntu` (e.g. Ubuntu, Debian, Linux Mint, Pop!_OS,
  Kali) -- you're on the **Debian family**.
- If you see `fedora` (e.g. Fedora, and generally RHEL/CentOS derivatives
  close enough to it) -- you're on the **Fedora family**.
- If you see `arch` (e.g. Arch Linux, EndeavourOS, Manjaro) -- you're on
  the **Arch family**.

If you see something else entirely, the automatic installer does not
support your distribution yet -- see `linux/steps.txt` for a manual,
step-by-step alternative that works on any XKB-based Linux system.

**`xmllint`** (part of the `libxml2` library) is used to validate the
system's keyboard configuration file before and after editing it. You do
not need to install this yourself -- the installer detects if it's
missing and installs it automatically as its very first step, using your
distribution's own package manager (`apt` on Debian/Ubuntu, `dnf` on
Fedora, `pacman` on Arch). If you'd rather install it yourself first (or
just want to confirm it's present), check with:
```bash
xmllint --version
```
and if it's missing, install it with one of:
```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y libxml2-utils

# Fedora
sudo dnf install -y libxml2

# Arch Linux
sudo pacman -Sy --needed libxml2
```

### 3.2 Required for the CLI (`cli/`) and core engine (`core/`) -- optional

**Python 3.8 or newer.** Check with:
```bash
python3 --version
```
This should print something like `Python 3.10.12`. If the number after
"Python 3." is 8 or higher, you're set. If Python 3 isn't installed at
all, install it with:
```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv

# Fedora
sudo dnf install -y python3 python3-pip

# Arch Linux
sudo pacman -Sy --needed python python-pip
```

**`pip`** (Python's package installer) usually comes with Python 3.
Check with:
```bash
python3 -m pip --version
```
If that fails, it means `pip` wasn't bundled with your Python install; use
the same package-manager commands as above (they include it).

On some newer distributions (Debian 12+, Ubuntu 23.04+, Arch), `pip`
refuses to install packages system-wide by default (this is intentional,
called "PEP 668 externally managed environment protection") and will show
an error mentioning this. If you see that error, there are two standard
fixes:
- **Recommended:** use a virtual environment (an isolated Python
  installation just for this project) -- see section 6 below, which uses
  this approach.
- **Alternative:** add `--break-system-packages` to the `pip install`
  command. Only do this if you understand it means the package is
  installed into your system's shared Python environment rather than
  isolated to this project.

### 3.3 Required for the GUI (`gui/`) -- optional

**A web browser.** Any reasonably modern one (Firefox, Chrome, Chromium,
Edge, Safari) -- released in roughly the last 5 years -- works. Nothing
else is required: no installation, no server, no internet connection.

**Node.js** is needed *only* if you want to run the GUI's automated test
suite yourself (not needed just to use the GUI). Check with:
```bash
node --version
```
Version 18 or newer is recommended. If you don't have it and want it,
see <https://nodejs.org> for installers, or use your distribution's
package manager (`sudo apt-get install nodejs npm`, `sudo dnf install
nodejs npm`, `sudo pacman -Sy nodejs npm`).

### 3.4 Required for building distributable packages -- optional, advanced

`git`, `python3 -m build` (`pip install build`), and (if you plan to build
actual `.deb`/`.rpm`/Arch packages rather than just Python wheels)
`dpkg-deb`, `rpmbuild`, or `makepkg` respectively, each specific to the
distribution you're packaging for. See `packaging/README.md`.

---

## 4. Getting the KeyboardForge files onto your computer

If you were given a `.zip` file (e.g. `keyboardforge_phaseN_....zip`):

```bash
# Replace the filename and path with your actual downloaded file.
cd ~/Downloads
unzip keyboardforge_phase7_docs_qa.zip -d ~/
cd ~/keyboardforge
```

If `unzip` isn't installed:
```bash
# Debian/Ubuntu
sudo apt-get install -y unzip
# Fedora
sudo dnf install -y unzip
# Arch Linux
sudo pacman -Sy --needed unzip
```

If instead you're cloning from a Git repository:
```bash
git clone <the repository URL> keyboardforge
cd keyboardforge
```

From here on, this guide assumes your terminal's current directory is the
`keyboardforge` folder you just created (containing `linux/`, `core/`,
`cli/`, `gui/`, `docs/`, etc. as subfolders). Confirm with:
```bash
ls
# You should see: core  cli  gui  linux  docs  packaging  tests  layouts
# README.md  LICENSE  VERSION  ... (exact list may vary by phase zip)
```

---

## 5. Option A: Install the bundled example layout as-is

The fastest path if you just want to see the system work, or genuinely
want the bundled example (French, customized) layout.

```bash
cd linux
chmod +x install.sh uninstall.sh test.sh modules/*.sh
sudo ./install.sh
```

**What `chmod +x` does:** marks these files as "executable" (allowed to be
run as programs). Downloaded/extracted files don't always keep this
permission, so this step ensures the scripts can actually be run.

**What happens when you run `sudo ./install.sh`:**
1. It asks you to confirm before making any changes (type `y` and press
   Enter, or re-run with `--yes` to skip this prompt).
2. It detects your Linux distribution automatically.
3. It installs `xmllint` if missing (see section 3.1).
4. It backs up every system file it's about to touch, with a
   `.bak_fr_custom` suffix, so everything can be reverted later.
5. It copies the layout's XKB symbol definitions into
   `/usr/share/X11/xkb/symbols/`.
6. It registers the layout in `/usr/share/X11/xkb/rules/evdev.xml` (the
   file your Desktop Environment reads to know which layouts exist),
   validating the XML both before and after to make sure nothing is
   corrupted -- if validation fails, it automatically rolls back.
7. It applies distribution-specific configuration (e.g. editing
   `/etc/default/keyboard` on Debian/Ubuntu, or using `localectl` on
   Fedora/Arch).
8. It detects whether you're running X11 or Wayland, and which Desktop
   Environment (GNOME, KDE Plasma, or XFCE) you're using, and configures
   the layout there too, using the correct mechanism for each (see
   `docs/troubleshooting.md` if a step doesn't apply to your setup).

You can preview all of this without changing anything on your system by
adding `--dry-run`:
```bash
sudo ./install.sh --dry-run
```

When it finishes, **log out and log back in, or reboot** -- most Desktop
Environments only re-read the list of available keyboard layouts at
session start.

---

## 6. Option B: Install the command-line interface (CLI)

This gives you the `keyboardforge` command, for creating layouts,
editing individual keys, validating them, and importing your operating
system's own real layouts (see `docs/cli-manual.md` for the complete
command reference).

### 6.1 Using a virtual environment (recommended)

A virtual environment keeps this project's Python packages separate from
the rest of your system -- nothing is installed system-wide, and nothing
here can conflict with or be affected by other Python software on your
machine.

```bash
cd keyboardforge          # the folder from section 4
python3 -m venv .venv
source .venv/bin/activate
```

Your terminal prompt should now show `(.venv)` at the start of the line,
indicating the virtual environment is active. From here on in this
section, run commands in this same terminal (or re-run
`source .venv/bin/activate` in any new terminal window before using
`keyboardforge`).

```bash
pip install -e core/
pip install -e cli/
```

Confirm it worked:
```bash
keyboardforge --help
```
This should print a list of available subcommands (`new`, `set-key`,
`validate`, `export`, `import`, `import-system`, `system-layouts`, `list`,
`install`, `uninstall`).

### 6.2 Without a virtual environment

If you understand the tradeoffs (see the PEP 668 note in section 3.2) and
prefer not to use a virtual environment:
```bash
pip install --user -e core/
pip install --user -e cli/
```
(`--user` installs into your own home directory rather than system-wide,
which avoids needing `sudo`/root for this step and avoids most PEP 668
restrictions, though very new distributions may still require
`--break-system-packages` in addition.)

### 6.3 Your first layout via the CLI

```bash
# Create a blank layout
keyboardforge new my_custom custom my_layouts/my_custom.json \
    --description "My Custom Layout" --language eng

# Set a key: AE01 is the "1" key; give it '1' unshifted, '!' shifted
keyboardforge set-key my_layouts/my_custom.json AE01 1 exclam

# Check it's valid before doing anything else with it
keyboardforge validate my_layouts/my_custom.json

# Preview what installing it would do, without changing anything
keyboardforge install my_layouts/my_custom.json --dry-run

# Install it for real (this needs root -- keyboardforge will prompt for
# your password via sudo automatically if you aren't already root)
keyboardforge install my_layouts/my_custom.json
```

**Starting from your operating system's own real layout instead of a
blank one:**
```bash
# See every layout your OS actually has installed
keyboardforge system-layouts

# See the variants of one specific layout (e.g. French)
keyboardforge system-layouts fr

# Import your system's real French layout (AZERTY variant) into JSON
keyboardforge import-system fr my_layouts/my_french.json --variant azerty

# Now edit/validate/install it exactly like any other layout
keyboardforge set-key my_layouts/my_french.json AE01 1 exclam
keyboardforge install my_layouts/my_french.json
```
See `docs/user-guide.md` and `docs/cli-manual.md` for the full explanation
of what "importing a system layout" does and doesn't capture.

---

## 7. Option C: Use the graphical editor (GUI)

No installation needed at all.

1. In your file manager, navigate to the `keyboardforge/gui/` folder.
2. Double-click `index.html` (or right-click it and choose "Open with" ->
   your web browser). Alternatively, from a terminal:
   ```bash
   xdg-open keyboardforge/gui/index.html
   ```
3. Click **New Layout**, or **Load JSON** to open an existing layout file
   (e.g. `layouts/fr_custom.json`, or one you created/imported with the
   CLI as in section 6.3).
4. Click any key on the visual keyboard to select it, then edit its
   Level 1-4 symbols in the panel on the right. Changes apply
   immediately.
5. Click **Save JSON** to download the edited layout.

The GUI itself cannot install anything on your system (it's a static
webpage with no access to your files beyond what you explicitly load/
save) -- after saving, go back to section 6 and run:
```bash
keyboardforge install ~/Downloads/my_custom.json
```
See `docs/gui-manual.md` for the complete feature walkthrough.

---

## 8. Verifying your layout was installed correctly

After installing (section 5 or 6) and logging out/back in (or rebooting):

**On X11:**
```bash
setxkbmap -print -verbose 10
```
Look for your layout's `xkb_name` in the output.

**On X11 or Wayland (via systemd):**
```bash
localectl status
```

**Checking the installer's own log** (with timestamps, useful for
troubleshooting):
```bash
cat linux/logs/install.log
```

**In your Desktop Environment's own settings:** GNOME: Settings -> Keyboard
-> Input Sources. KDE Plasma: System Settings -> Input Devices -> Keyboard
-> Layouts. XFCE: Settings -> Keyboard -> Layout. Your layout's description
(the `description` field from its JSON, e.g. "My Custom Layout") should
appear in the list of available layouts, ready to be selected/added as an
input source alongside your existing ones.

If it doesn't appear, see `docs/troubleshooting.md`.

---

## 9. Uninstalling / reverting

```bash
cd linux
sudo ./uninstall.sh
sudo reboot
```
or, equivalently, if you installed via the CLI:
```bash
keyboardforge uninstall
```

This restores every file the installer touched from its `.bak_fr_custom`
backup (or removes it entirely if it didn't exist before you installed
anything) and resets your system's keyboard configuration to `us`
(the universal US QWERTY default).

---

## 10. Building distributable packages

For turning the Python components into installable wheels, or using the
`.deb`/`.rpm`/Arch `PKGBUILD` templates for the Linux installer itself,
see `packaging/README.md` and `packaging/pip/README.md`.

---

## 11. Getting help

1. `docs/troubleshooting.md` -- common problems and their exact fixes.
2. `docs/faq.md` -- frequently asked questions.
3. If neither covers your situation, open an issue on the project's GitHub
   repository (see the repository's main page for the link) including:
   which component (`linux`/`core`/`cli`/`gui`), your Linux
   distribution and Desktop Environment (run `cat /etc/os-release` and
   `echo $XDG_CURRENT_DESKTOP`), the exact command you ran, and its
   complete output.
