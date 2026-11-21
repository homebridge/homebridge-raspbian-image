# Release workflows

## Release streams

- The image is built for three streams: `stable`, `beta` and `alpha`.
- Each stream has a `<stream>/package.json`, which holds the versions of `@homebridge/homebridge-apt-pkg` and `ffmpeg-for-homebridge` it is built with. **homebridge/dependency-bot** (`.github/homebridge-dependency-bot-<stream>.json`) updates it every day.
- A beta image installs Homebridge from the `beta` apt channel, and an alpha image from the `alpha` channel.
- Release tags: stable is numbered (`v2.0.26`). Beta and alpha are dated (`beta-2026-11-21`, `alpha-2026-11-21`), so they never move the stable number on.
- Only a stable image is published to the Raspberry Pi Imager registry (`rpi-image-repo.json` on homebridge.io). Beta and alpha are GitHub pre-releases only, and are never marked as the latest release.
- Only the newest 5 beta and 5 alpha releases are kept.

## The stages

1. **Release Stage 1** (`release-stage-1_update_dependencies.yml`): runs daily, lets the dependency bot update each stream, and starts Stage 2 for a stream whose versions changed.
2. **Release Stage 2** (`create_raspbian_pi-gen.yml`): builds the 32-bit and 64-bit images with pi-gen, then starts Stage 3.
3. **Release Stage 3** (`release-stage-3_package_release.yml`): creates the GitHub release, and for stable publishes it to the registry.

## Pre-release branches (beta and alpha only)

- By default every stream builds from the `latest` branch.
- To ship unmerged work to beta or alpha without touching stable, create a branch named `<stream>-YYYY.M.D` from `latest` (date it was created, dots, no zero padding, e.g. `beta-2026.11.18`) and merge the feature PR into it with a normal merge (not squash), so the release notes list its commits.
- Stage 1 picks the newest branch matching `<stream>-YYYY.M.D` (by `sort -V`), points the dependency bot at it (`base_branch`) and runs Stage 2 on it. Stage 2 runs Stage 3 on the same branch. With no such branch, the stream uses `latest`.
- Dots, not dashes: release tags are `beta-YYYY-MM-DD`, and a branch with the same name would make git refs ambiguous.
- Stage 2 and Stage 3 refuse to build stable from anything but `latest`, and refuse beta/alpha from any branch other than `latest` or `<stream>-YYYY.M.D`.
- Stage 1 only starts a build when the dependency bot changed something. To ship a new branch straight away, run Stage 2 by hand on that branch.
- Keep the branch current by merging `latest` into it from time to time. While the branch exists, `<stream>/package.json` updates land on the branch, not on `latest`.
- Retire it (feature merged into `latest`, or abandoned) by renaming it to `archive/<stream>-YYYY.M.D`. It then stops matching and the stream returns to `latest`, while the history stays browsable. Don't archive as a tag: the cleanup action prunes old beta/alpha tags.
- The branch needs the same ruleset bypass as `latest` so the dependency bot App can push to it.
