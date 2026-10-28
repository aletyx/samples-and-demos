# The dev container image

Every dev container in [.devcontainer/](../.devcontainer) uses one
published image, `docker.io/aletyxcode/samples-and-demos-devcontainer`, built
from [Containerfile](Containerfile): Flutter, the GitHub CLI,
process-compose, the packages the demos depend on, and **every demo's
release web build**, so a codespace restores the builds and starts the
demos in seconds. GitHub's prebuilds and Actions are switched off for
this organization, so the image is built on a laptop and pushed. It lives
on Docker Hub, public, because a codespace created by anyone (a user
outside the organization included) must be able to pull it, and the
organization's GHCR packages can't be made public.

## Building and pushing it

On a clean checkout of the commit the image is for (usually `main`),
with Docker running and devbox installed:

```bash
docker login -u aletyxcode          # once; a Read & Write access token
bash image/build-image.sh
```

[build-image.sh](build-image.sh) runs `./build-all.sh` (the demos'
release builds, natively), stages the builds, the pubspecs and a manifest
of each demo's build key ([build-key.sh](build-key.sh): the git ids of
what its web build is made from: the app package, the version files,
`scripts/` and `devbox.lock`) in `image/context/` (git-ignored), builds
the image for `linux/amd64` (the Codespaces machines; through Docker's
emulation on Apple silicon, a few minutes for the Flutter steps) and
pushes it tagged with the commit and as `latest`. `PUSH=0` builds without
pushing. `IMAGE=<registry/name>` pushes somewhere else, say a private
registry while trying an image out; the dev containers pull whatever
`image` their `devcontainer.json` names.

## What a codespace does with it

- [restore-builds.sh](restore-builds.sh), run by `on-create.sh`, copies
  the build of every demo whose build key is still the manifest's into
  the workspace; a demo whose app changed since the image was made is
  skipped and builds itself (`scripts/build.sh`, about a minute on 4
  cores), so an old image slows that demo down but breaks nothing. A
  change elsewhere in the demo (its README, its API) keeps the build.
- The APIs' binaries are not in the image: `scripts/build.sh` compiles
  them in a few seconds, natively.
- `DEMOS_TOOLCHAIN=image` (set by `devcontainer.json`) makes
  `start-all.sh`, `stop-all.sh` and `build-all.sh` use the image's
  Flutter and process-compose instead of devbox.

Rebuild and push the image after merging changes to `main` when you want
the fast path back for the demos that changed; nothing breaks if you
don't.
