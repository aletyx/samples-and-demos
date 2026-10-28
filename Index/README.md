# Index

The index of the demos: one page, in the aityx palette, with a card per
sample (what it shows, its technology, **Open** for its app on its port
here or, in a codespace, its forwarded URL, **Source** on GitHub, and
**Codespace**).

- [www/index.html](www/index.html): the page. The cards' text and each
  app's web port are in it; it does not say which demos are up.
- [bin/server.dart](bin/server.dart): a plain Dart server (no packages).
  `GET /` is the page (`/app/` too, so `start-all.sh` checks it like a
  demo); `GET /api/demos` lists every folder beside this one with a
  `process-compose.yaml`, the web and API ports it defaults to, and whether
  its web app and API answer right now and the API has its aityx key, for
  scripts; the page no longer reads it. `GET /api/aityx` says whether an
  aityx key is set (`AITYX_API_KEY` in its environment, else the repo's
  `.env`) and whether aityx accepts it (an empty `POST
  /v1/systemone`, which aityx rejects as invalid only after it accepts the key,
  so no model runs), kept for a minute and never with the key. The page
  shows a warning across the top when there's no key, and a light top right:
  green when aityx accepts the key, red otherwise (hover for why).
  `GET /api/health` answers `{"ok": true}`.
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
