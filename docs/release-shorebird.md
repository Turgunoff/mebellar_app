# Release & Shorebird OTA

> Companion to the root [`README.md`](../README.md) §7. Where the operational brain [`CLAUDE.md`](../CLAUDE.md) disagrees, it wins.

## No client migrations

This is a Flutter client with **no database and no migrations**. The DB schema + Alembic migrations live in the separate **`woody_backend`** repo (run `woody migrate` there). The app speaks only REST + WebSocket. The app's own version is managed in `pubspec.yaml` (`1.0.26+26`); its "version ledger" equivalent is the Shorebird release ledger ([`../tools/shorebird/releases.md`](../tools/shorebird/releases.md), latest `1.0.26+26`, SHA `4c945889c331`, 2026-06-24).

## Store builds

```bash
# Preferred wrapper (env + signing preflight, obfuscate, split-debug-info):
./tools/build_release.sh

# Equivalent App Bundle:
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json

# APK (sideload):
flutter build apk --release --dart-define-from-file=env/prod.json

# iOS IPA:
flutter build ipa --release \
  --obfuscate --split-debug-info=build/symbols/ \
  --dart-define-from-file=env/prod.json
```

> The env file is **mandatory** — `flutter build` without `--dart-define-from-file=env/prod.json` produces a silently unusable build. Bump `version` (`+N`) in `pubspec.yaml` before any Play Console / App Store push.

## iOS caveats

- **Flutter Swift Package Manager (SPM) MUST be DISABLED** — otherwise Firebase module redefinition breaks the build.
- **`Podfile.lock` pinned to Firebase `12.17.0`** — keep it aligned.

## Shorebird OTA (code push)

Shorebird hot-fixes shipped builds **without store review** — but **only Dart code rides a patch**. Native (`android/`, `ios/`), bundled `assets/`, `pubspec` dependency, and Flutter-version changes all require a brand-new release (Shorebird's CLI warns that `--allow-native-diffs` / `--allow-asset-diffs` can crash the app).

`tools/shorebird.sh` is the wrapper (mirrors `build_release.sh`'s env/signing preflight + `--obfuscate --split-debug-info`):

```bash
./tools/shorebird.sh check                 # "what changed since the last release — patch-safe or not?"
./tools/shorebird.sh release android|ios   # patchable store build + ledger entry
./tools/shorebird.sh patch android|ios     # preflight-gated Dart-only patch to the live release
./tools/shorebird.sh log                   # release history
```

### Invariants

- A patchable store build **MUST** come from `shorebird release`, not `flutter build` / `build_release.sh` — plain builds can't receive patches.
- `patch` is **preflight-gated**: it runs `check` first and aborts on a native/asset/Flutter blocker so you can't ship a crashing patch. `--force` bypasses (not recommended).
- The **ledger** ([`../tools/shorebird/releases.md`](../tools/shorebird/releases.md)) is the append-only history file (markdown table: `sana | versiya | git_sha | platforma | izoh`, committed to git). `check`/`patch` diff today's tree against the recorded SHA. `release` appends automatically.
- **No Shorebird secret in the repo** — `shorebird.yaml`'s `app_id` (`c1639a0d-e4a4-4606-bf14-4b4195fa061e`) is public by design; auth is the developer's `shorebird login` on the build machine.

### Rule of thumb — patch vs full release

| Change | Ships via |
| --- | --- |
| Dart-only fix (logic, UI, copy) | Shorebird **patch** |
| `pubspec.yaml` dependency change | full **release** |
| Native code (`android/`, `ios/`), e.g. `ar_flutter_plugin_plus` | full **release** |
| Bundled `assets/` change | full **release** |
| Flutter/Dart version bump | full **release** |
