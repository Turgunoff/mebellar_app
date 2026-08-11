# Release checklist — things the repo cannot verify

Everything below lives in a console, not in code. `flutter analyze`,
`flutter test` and CI will all pass with any of these mis-set, and the
failure mode is silent in every case — so walk the list before each store
submission.

For the build commands themselves see `CLAUDE.md` (§Build & run) and
`tools/build_release.sh` / `tools/shorebird.sh`.

---

## iOS — App Store / TestFlight

### APNs production key (Firebase Console)

**Why it matters:** `ios/Runner/RunnerRelease.entitlements` sets
`aps-environment = production` for the Release configuration (Debug and
Profile stay on `development` via `ios/Runner/Runner.entitlements`; the
split is wired per build configuration through `CODE_SIGN_ENTITLEMENTS` in
`ios/Runner.xcodeproj/project.pbxproj`). That entitlement only tells iOS
which APNs gateway to register the device token against. Firebase still
needs a credential that can *send* to that gateway. If the credential is
missing or sandbox-only, FCM accepts the send and every push is dropped —
no error surfaces in the app, in Crashlytics, or in the Firebase console's
success counters.

Order-status notifications are Woody's main retention channel, so this
failing quietly is the worst case.

**Verify:** Firebase Console → Project settings → **Cloud Messaging** →
*Apple app configuration* for `com.mebellar.app`:

- An **APNs Authentication Key** (`.p8`) is uploaded, with the correct Key
  ID and Team ID (`LQ278UVP2Y`). A single auth key covers both sandbox and
  production — this is the preferred setup and needs no yearly renewal.
- If APNs **certificates** are used instead of a key, a *Production* APNs
  certificate must be present and unexpired (certificates expire annually
  — check the date, not just the presence).
- Push Notifications capability is enabled on the App ID in the Apple
  Developer portal, and the distribution provisioning profile was
  regenerated after it was enabled.

**Smoke test after upload:** install the TestFlight build (not a local
`flutter run` — that build signs with the development entitlement), then
send a test message from Firebase Console → Messaging → *Send test
message* using the device's FCM token. A token that registers but never
receives is the classic sandbox/production mismatch.

### App Store Connect privacy questionnaire

`ios/Runner/PrivacyInfo.xcprivacy` and the App Store Connect *App Privacy*
answers must agree — Apple compares them. The manifest currently declares
tracking `true` plus Device ID (tracking), User ID, Purchase History,
Product Interaction, Crash Data and Performance Data. If the Meta Advanced
Matching flag (`kMetaAdvancedMatchingEnabled`) is ever shipped enabled,
Phone Number / Name / Email Address must be added to **both** the manifest
and the questionnaire in that same release, and the privacy policy updated
to match.

`NSPrivacyTrackingDomains` is intentionally empty — FBSDKCoreKit declares
`ep1.facebook.com` in its own bundled manifest and Meta's docs advise
against restating it. See the comment in the manifest for the citation.

---

## Android — Play Console

### Advertising ID declaration

**Why it matters:** the app requests
`com.google.android.gms.permission.AD_ID` (merged in from
`play-services-measurement-api` and `facebook-core` — it is not declared in
`android/app/src/main/AndroidManifest.xml`; see the comment there). Play
policy requires that any app requesting it declares Advertising ID use in
**App content → Advertising ID**. A mismatch between the permission and the
declaration blocks the release, and the console reports it as a policy
issue rather than a build error.

**Verify per release:**

- Play Console → App content → **Advertising ID**: declared as used, with
  the purposes that match reality — *Advertising or marketing* and
  *Analytics*. Woody does not use it for fraud prevention or personalisation
  beyond ad attribution.
- **Data safety** section agrees with the same set the iOS privacy manifest
  declares (device/advertising ID, purchase history, app interactions, crash
  logs, diagnostics), and states that collection is optional — the in-app
  "Foydalanish statistikasi" toggle and the ATT-equivalent choice let users
  opt out.
- If `kMetaAdvancedMatchingEnabled` ever ships enabled, Data safety must add
  personal identifiers (phone, name, email) shared with a third party for
  advertising, and the privacy policy must say so first.

**Re-verify the permission after any dependency bump** — it comes from
transitive libraries, so a Firebase or Facebook SDK upgrade can change it:

```bash
flutter build apk --debug --dart-define-from-file=env/prod.json
grep -n "AD_ID" build/app/outputs/logs/manifest-merger-debug-report.txt
```
