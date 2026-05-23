---
description: Build a production AAB with env baked in, obfuscation on, and symbols saved.
---

Run the release build by executing `./tools/build_release.sh` from the
project root. The script handles the full pipeline:

1. `flutter clean`
2. `flutter pub get`
3. `flutter build appbundle --release --dart-define-from-file=env/prod.json --obfuscate --split-debug-info=build/symbols`

Before running, do a sanity check:

- Confirm `env/prod.json` exists. If not, abort and tell me to create
  it from `env/example.json`.
- Read the current `version:` in `pubspec.yaml` and ask whether to bump
  `versionCode` (the `+N` suffix) — Play Console rejects re-uploads with
  the same code. If they say yes, edit `pubspec.yaml` first.

After the build finishes, report:

- The full path to `build/app/outputs/bundle/release/app-release.aab`
- File size in MB
- Reminder that `build/symbols/` should NOT be committed — keep a copy
  somewhere accessible so future Crashlytics reports can be symbolised
  via `flutter symbolize`.

If the build fails, print the last 20 lines of stderr and stop. Do NOT
try to "fix" the build by changing dependencies or build settings
without my confirmation.
