# ARDA AAOS manifest overlay

ARDA source overlay for the AAOS 16 Raspberry Pi 4 tree.

## Captured base manifest

Base manifest repository:

`https://android.googlesource.com/platform/manifest`

Base manifest branch:

`default`

Base manifest HEAD:

`15128c9e27cfa599c48d294babd39286ee8f1426`

The exact resolved Repo project revisions from the working tree are stored at:

`pinned/current-aosp.xml`

## Apply to an initialized Raspberry Vanilla AAOS tree

Clone this repository outside the AOSP tree, then install the local manifest:

```bash
mkdir -p .repo/local_manifests

cp /path/to/arda-aaos-manifest/local_manifests/arda.xml \
    .repo/local_manifests/arda.xml

repo sync \
    device/brcm/rpi4 \
    external/v4l2_codec2 \
    vendor/arda
```

Then materialize the private GAS payload:

```bash
vendor/arda/scripts/sync-proprietary.sh
```

Build:

```bash
source build/envsetup.sh
lunch aosp_rpi4_car-bp4a-userdebug
m
```

The proprietary payload repository is deliberately not referenced by the Repo
manifest.
