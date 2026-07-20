"""keyboardforge_cli -- the `keyboardforge` command-line interface.

A thin client over keyboardforge_core: every command reads/writes the same
JSON layout model the GUI uses, and the install/uninstall commands shell
out to the tested linux/install.sh and linux/uninstall.sh scripts rather
than reimplementing OS-level logic in Python.
"""

__version__ = "0.1.0"
