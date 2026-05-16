# Distribution Guide

ThoughtStream now has three separate distribution layers:

1. local development install
2. signed release packaging
3. optional notarization

## Local Development

For local testing, keep using:

```bash
./scripts/install_app.sh
```

This builds a debug app bundle, installs it to `/Applications`, and launches it.

## Release Artifacts

For a release build, use:

```bash
APP_VERSION=0.1.0 APP_BUILD=1 ./scripts/package_release.sh
```

This produces:

- `dist/ThoughtStream.app`
- `dist/ThoughtStream.zip`
- `dist/ThoughtStream.dmg`

The DMG is built as a drag-install volume containing:

- `ThoughtStream.app`
- an `Applications` shortcut

## Signed Release

If you have a Developer ID Application certificate, pass it in with:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
APP_VERSION=0.1.0 \
APP_BUILD=1 \
./scripts/package_release.sh
```

This signs the app bundle with hardened runtime before generating release artifacts.

## Notarization

If you already configured a notarytool keychain profile, you can notarize the ZIP artifact:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="thoughtstream-notary" \
APP_VERSION=0.1.0 \
APP_BUILD=1 \
./scripts/package_release.sh
```

The script will:

1. build the release app
2. sign the app
3. validate the bundle
4. create a ZIP
5. submit the ZIP with `notarytool`
6. staple the app
7. rebuild the ZIP from the stapled app

## Validation

To inspect a built app bundle:

```bash
./scripts/validate_release.sh
```

Or point it at a specific bundle:

```bash
./scripts/validate_release.sh ./dist/ThoughtStream.app
```

By default, the validation script allows ad hoc local builds to fail Gatekeeper assessment without failing the script.

If you want Gatekeeper rejection to fail validation:

```bash
STRICT_GATEKEEPER=1 ./scripts/validate_release.sh
```

## First-Run Guidance

Unsigned or ad hoc local builds may be blocked by Gatekeeper on first launch.

If that happens:

1. open `ThoughtStream.app` from Finder with `Open`
2. or go to `System Settings -> Privacy & Security`
3. then use `Open Anyway`

Signed and notarized releases should not need this extra step.
