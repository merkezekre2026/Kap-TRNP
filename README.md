# Kap-TRNP

Kap-TRNP builds the Mesa Turnip Vulkan driver for Android arm64 and packages it for AdrenoTools-compatible apps and emulators.

The GitHub Actions workflow clones Mesa, cross-compiles Turnip with the Android NDK, creates an AdrenoTools driver package, uploads it as a workflow artifact, and publishes the zip file to GitHub Releases.

## Release Download

Successful non-PR workflow runs create a GitHub Release named `Turnip Android <run number>`.

Download this file from the latest release:

```text
turnip-adrenotools-arm64-v8a.zip
```

This zip is the AdrenoTools-compatible package. It contains:

```text
meta.json
vulkan.ad07xx.so
```

## Build Target

The workflow currently targets:

- Android ABI: `arm64-v8a`
- Android API: `26` by default
- Mesa Vulkan driver: `freedreno`
- Freedreno backend: `kgsl`
- Additional GPU entries: Adreno 710, 720, and 722
- Output package: `turnip-adrenotools-arm64-v8a.zip`

OpenGL/GLES is intentionally disabled. This repository builds Turnip only.

## Mesa Patch

During each build, the workflow clones Mesa and then runs `scripts/add_710_720_722.py` inside the Mesa source tree before Meson configuration.

The patch updates `src/freedreno/common/freedreno_devices.py` idempotently to add Adreno 710, 720, and 722 GPU entries.

## Manual Workflow Run

Open the `Build Turnip Android` workflow in GitHub Actions and run it manually.

Available inputs:

- `mesa_ref`: Mesa branch, tag, or commit to build. Default: `main`
- `android_api`: Android API level. Default: `26`

## Local Build

Install the Android NDK and required build tools, then run:

```bash
ANDROID_NDK_HOME=/path/to/android-ndk \
MESA_REF=main \
scripts/build-turnip-android.sh
```

The script writes outputs to:

```text
work/artifacts/libvulkan_freedreno.so
work/artifacts/turnip-adrenotools-arm64-v8a.zip
```

## Configuration

The build script supports these environment variables:

- `MESA_REPO`: Mesa repository URL
- `MESA_REF`: Mesa branch, tag, or commit
- `ANDROID_API`: Android API level
- `ANDROID_ABI`: Android ABI, currently only `arm64-v8a`
- `WORK_DIR`: Working directory for Mesa, build files, and artifacts
- `ADRENOTOOLS_NAME`: Driver name written to `meta.json`
- `ADRENOTOOLS_DESCRIPTION`: Driver description written to `meta.json`
- `ADRENOTOOLS_AUTHOR`: Driver author written to `meta.json`
- `ADRENOTOOLS_PACKAGE_VERSION`: Package version written to `meta.json`
- `ADRENOTOOLS_DRIVER_VERSION`: Driver version written to `meta.json`

## Notes

This project only automates building and packaging Mesa Turnip. Compatibility depends on the target device, emulator, app, Android version, and Mesa revision being built.
