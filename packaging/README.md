# Packaging

KeyboardForge ships as two kinds of package:

1. **Python packages** (`keyboardforge-core`, `keyboardforge-cli`) -- built
   from `core/pyproject.toml` and `cli/pyproject.toml` with standard
   `setuptools`/`pip` tooling. See `pip/README.md`.
2. **OS-level installer packages** for the `linux/` component -- `.deb`,
   `.rpm`, and Arch `PKGBUILD` templates below. These package the shell
   installer itself (`linux/install.sh` + friends), not the Python tooling.

| Template            | Distro family     | Status                                    |
|----------------------|---------------------|----------------------------------------------|
| `deb/control`           | Debian/Ubuntu           | Metadata template (see note below)                |
| `rpm/keyboardforge.spec`  | Fedora/RHEL                | Metadata template (see note below)                    |
| `pkgbuild/PKGBUILD`         | Arch Linux                     | Metadata template (see note below)                        |

**Note:** these are metadata templates documenting dependencies and
versioning, matching how the project's very first prototype shipped them.
They are not yet wired to a build pipeline that produces a signed,
installable `.deb`/`.rpm`/pacman package automatically -- see the comments
inside `pkgbuild/PKGBUILD` for what a real `package()` step would look
like. Automating `.deb`/`.rpm` builds from these templates is tracked as
future work (the root `Makefile` has a `package-linux` target stub for
this).
