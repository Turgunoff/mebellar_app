---
description: Decode an obfuscated Dart stack trace using build/symbols/.
---

Take an obfuscated stack trace from a Crashlytics crash and decode it
into real file paths + line numbers. Steps:

1. Ask me to paste the obfuscated trace, OR detect that I just pasted
   one in the previous message (look for lines matching
   `#\d+\s+\S+\s+\(\S+:\d+\)` or `?\?:??`).
2. Write the trace verbatim to `/tmp/crash_stack.txt`.
3. Detect the architecture from the trace if possible (it includes
   `os: android` and the abi). Default to `arm64` if unclear.
4. Run:

   ```bash
   flutter symbolize \
     -i /tmp/crash_stack.txt \
     -d build/symbols/app.android-arm64.symbols
   ```

   Try other arch files (`app.android-arm.symbols`,
   `app.android-x64.symbols`, `app.ios.symbols`) if the first fails.
5. Print the decoded trace inline. Highlight the first
   non-flutter-framework frame — that's almost always the actual
   bug location.

If `build/symbols/` is missing or empty, tell me: the symbols belong
to a specific release build and must match the `app-release.aab`
version that produced the crash. Without them no decode is possible —
warn me to keep a copy of `build/symbols/` for every release uploaded
to Play Console.

Do NOT push or commit anything from `/tmp/`.
