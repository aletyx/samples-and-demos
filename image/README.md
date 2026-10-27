# The dev container image

Every dev container in [.devcontainer/](../.devcontainer) uses one
published image, `ghcr.io/aletyx/samples-and-demos-devcontainer`, built
from [Containerfile](Containerfile): Flutter, the GitHub CLI,
process-compose, the packages the demos depend on, and **every demo's
release web build**, so a codespace restores the builds and starts the
demos in seconds. GitHub's prebuilds and Actions are switched off for
this organization, so the image is built on a laptop and pushed.

## Building and pushing it

On a clean checkout of the commit the image is for (usually `main`),
with Docker running and devbox installed:

```bash
gh auth refresh -h github.com -s write:packages          # once
gh auth token | docker login ghcr.io -u <your-user> --password-stdin
bash image/build-image.sh
```

[build-image.sh](build-image.sh) runs `./build-all.sh` (the demos'
release builds, natively), stages the builds, the pubspecs and a manifest
of each demo's git tree hash in `image/context/` (git-ignored), builds
the image for `linux/amd64` (the Codespaces machines; through Docker's
emulation on Apple silicon, a few minutes for the Flutter steps) and
pushes it tagged with the commit and as `latest`. `PUSH=0` builds without
pushing. The package must be public for Codespaces to pull it: the first
push creates it private; make it public once, under the organization's
Packages.

## What a codespace does with it

- [restore-builds.sh](restore-builds.sh), run by `on-create.sh`, copies
  the build of every demo whose folder still has the manifest's tree hash
  into the workspace; a demo that changed since the image was made is
  skipped and builds itself (`scripts/build.sh`, about a minute on 4
  cores), so an old image slows that demo down but breaks nothing.
- The APIs' binaries are not in the image: `scripts/build.sh` compiles
  them in a few seconds, natively.
- `DEMOS_TOOLCHAIN=image` (set by `devcontainer.json`) makes
  `start-all.sh`, `stop-all.sh` and `build-all.sh` use the image's
  Flutter and process-compose instead of devbox.

Rebuild and push the image after merging changes to `main` when you want
the fast path back for the demos that changed; nothing breaks if you
don't.
