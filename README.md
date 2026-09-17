# ARDA AAOS 16 reproducible source release

This repository reproduces the audited ARDA AAOS 16 source state frozen on **2026-09-17**.

The release intentionally separates the immutable upstream/Raspberry source lock
from ARDA-specific repositories. `frameworks/base` is reproduced from an exact
AOSP parent using the deterministic overlay recipe persisted in `vendor/arda`.

## One-command bootstrap

After this repository is published as `Deadknight/arda-aaos-manifest`:

```bash
curl -fsSL https://raw.githubusercontent.com/Deadknight/arda-aaos-manifest/main/bootstrap.sh | \
  bash -s -- "$HOME/aosp-rpi-aaos16"
```

The command:

1. installs the Android `repo` launcher inside the target tree;
2. initializes AOSP manifest at exact commit `15128c9e27cfa599c48d294babd39286ee8f1426`;
3. installs the audited Raspberry Pi local manifests;
4. runs the initial source sync;
5. pins the non-ARDA project set to the audited 1003-project snapshot;
6. restores every ARDA fork at its exact SHA;
7. clones the independent `packages/apps/Car/Media`, `vendor/arda`,
   `vendor/arda/ardaplatform`, and `vendor/arda/proprietary` repositories;
8. reproduces the exact local `frameworks/base` commit through
   `vendor/arda/release/overlays/frameworks-base/apply.sh`;
9. verifies the complete source state.

It **does not start a build**.

## Build targets

Pi 5:

```bash
cd "$HOME/aosp-rpi-aaos16"
source build/envsetup.sh
lunch aosp_rpi5_car-bp4a-userdebug
m -j"$(nproc)"
```

Pi 4:

```bash
cd "$HOME/aosp-rpi-aaos16"
source build/envsetup.sh
lunch aosp_rpi4_car-bp4a-userdebug
m -j"$(nproc)"
```

## Verify an existing release tree

```bash
"$HOME/aosp-rpi-aaos16/.arda-release/verify.sh" "$HOME/aosp-rpi-aaos16"
```

Expected final line:

```text
ARDA_RELEASE_VERIFY=PASS
```

## Reapply after a manual sync

A later manual `repo sync` can put repo-managed projects back on their upstream
manifest revisions. To restore this exact release snapshot:

```bash
BUNDLE_ROOT="$HOME/aosp-rpi-aaos16/.arda-release" \
  "$HOME/aosp-rpi-aaos16/.arda-release/scripts/reapply.sh" \
  "$HOME/aosp-rpi-aaos16"
```

`reapply.sh` is intentionally destructive to tracked source state: it resets the
release projects to the exact locked SHAs. Use it only when restoring this release.

## Canonical ARDA state

| Path | SHA |
| --- | --- |
| `device/brcm/rpi4` | `5fedcf315589f95e89852cfc47c38cea04480928` |
| `device/brcm/rpi5` | `a3b85e89ab65c27aae98bb0a33ef14209d1540c6` |
| `external/drm_hwcomposer` | `85e7a88dacf4af1783e5e88b42a2c4a6fb109013` |
| `external/v4l2_codec2` | `99f85153d805c6ed7aa09fab869a965ce4c65b43` |
| `frameworks/base` | `a34531ec673c811c6faf9fedb490142337cbf2f7` |
| `frameworks/av` | `43f12cbd16344fa660cb1a80da3cd69af946bf32` |
| `frameworks/native` | `417e0d7199c7a4c01834f3f9adf5f379cbaea372` |
| `packages/apps/Car/Launcher` | `bcf9edaf3544f3cc1aa618ad7f8013d49961c77a` |
| `packages/apps/Car/Media` | `f48f17d8c19937b17b4bffa43579bea30d5058e5` |
| `packages/apps/Car/MediaPrebuilt` | `9339f974018c3fc5b9454b16f0a5019b60da7de8` |
| `packages/apps/Car/SystemUI` | `1f92ac2142bc78c22fc3acd0e772afb02d0766fd` |
| `system/sepolicy` | `a5a0f70b11c4c002c7458623b33cb781e41c0c2d` |
| `vendor/arda` | `02a00f5135b4969d2b6ea287aef9c22a09ec4143` |
| `vendor/arda/ardaplatform` | `830ab5b6a8f60af7725d61eccd00474b72797e83` |
| `vendor/arda/proprietary` | `5e49784ec611bee0ae10cafd156debb77c12cbee` |

## Release integrity

- AOSP manifest commit: `15128c9e27cfa599c48d294babd39286ee8f1426`
- `frameworks/base` parent: `45034f0663f960d9ee5fb0a101a4732b71f6e2f4`
- `frameworks/base` canonical commit: `a34531ec673c811c6faf9fedb490142337cbf2f7`
- `vendor/arda`: `02a00f5135b4969d2b6ea287aef9c22a09ec4143`
- audited old identity commits in release-used Deadknight remotes: **0**
- final custom worktrees at freeze time: **clean**
- source project lock rows: **1003**

## Repository layout

```text
bootstrap.sh
verify.sh
manifests/
  10-remove_projects.xml
  20-manifest_brcm_rpi.xml
locks/
  base-projects.tsv
  final-managed-projects.tsv
  custom-repos.tsv
  source-audit-all-projects.tsv
metadata/
  release.env
  identity-audit.tsv
scripts/
  bootstrap-inner.sh
  reapply.sh
  verify-inner.sh
publish_to_github.sh
```

## Publishing this release repository

The helper requires an authenticated GitHub CLI.

If `Deadknight/arda-aaos-manifest` does not yet exist, choose visibility explicitly:

```bash
VISIBILITY=public ./publish_to_github.sh
```

or:

```bash
VISIBILITY=private ./publish_to_github.sh
```

If it already exists, simply run:

```bash
./publish_to_github.sh
```
