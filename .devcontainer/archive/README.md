# Archived dev containers

Dev container configurations that are no longer offered when you create a
codespace (GitHub lists only `.devcontainer/devcontainer.json` and
`.devcontainer/<name>/devcontainer.json`, one level deep), kept for
reference.

- [MortgageHub/](MortgageHub/): the original Mortgage Hub dev container,
  the one the others were copied from. It started only Mortgage Hub. The
  repository's default dev container, [../devcontainer.json](../devcontainer.json),
  replaced it: it starts every demo with `./start-all.sh`, Mortgage Hub
  among them, and is what the Mortgage Hub badges open.
  Its scripts still name `.devcontainer/MortgageHub/`, their original
  location, so it does not run from here as it is.
