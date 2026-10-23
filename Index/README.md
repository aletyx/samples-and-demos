# Index

The index of the demos: one page, in the aityx palette, with a card per
sample (what it shows, its technology, **Open** when it is running
locally, **Source** on GitHub, and **Codespace**), and which demos are up
right now.

- [www/index.html](www/index.html): the page. The cards' text is in it;
  the ports and the status come from the server.
- [bin/server.dart](bin/server.dart): a plain Dart server (no packages).
  `GET /` is the page (`/app/` too, so `start-all.sh` checks it like a
  demo); `GET /api/demos` lists every folder beside this one with a
  `process-compose.yaml`, the web and API ports it defaults to, and whether
  its web app and API answer right now and the API has its aityx key; the
  page polls it every 10 s. `GET /api/health` answers `{"ok": true}`.
- Port **8800** (`INDEX_PORT`), bound to 127.0.0.1 (`INDEX_BIND_HOST`).

## Run it

From this folder, with [Devbox](https://www.jetify.com/devbox):

```bash
devbox services up            # the index on http://localhost:8800/
devbox run serve              # the same, in the foreground
```

or, with Dart on the PATH, `dart bin/server.dart`. From the root of the
repository, `./start-all.sh` starts it with every demo and prints its
link last; `./stop-all.sh` stops it.
