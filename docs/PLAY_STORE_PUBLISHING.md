# Google Play publishing checklist

This is a practical release checklist, not legal advice. Google Play requirements change; check the current Play Console documentation before each release.

## 1. Create and verify the Android runner

```bash
flutter create --platforms=android,ios .
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

Set a permanent, reverse-domain `applicationId` in `android/app/build.gradle` (or `.kts`). Choose a human-readable app name, launcher icon, and version in `pubspec.yaml`. Never change the application ID after publishing. Confirm min/target SDK requirements for the current Play policy and the plugin set you ship.

## 2. Signing and release build

Create an upload key and keep the keystore/passwords outside Git (use a secure password manager or CI secret store). Configure the Android Gradle signing properties without committing secrets. Verify the signing certificate fingerprint and enroll in Play App Signing.

```bash
flutter build appbundle --release
```

Upload the resulting `.aab` to an internal testing track first. Test installation, drawing, autosave/restore, export, rotation, dark mode, low-memory behavior, and large canvases on real devices and tablets.

## 3. Store listing and policy

Prepare a concise description, app icon, phone/tablet screenshots, feature graphic, support email, and privacy policy URL. Complete the Data safety form truthfully. This starter stores projects locally and has no cloud account; update the disclosure if you later add crash analytics, cloud sync, advertising, or external sharing. Provide an account/data deletion path if accounts or server-side data are introduced.

Declare only permissions that are actually used. Audio recording requires runtime microphone permission and clear user intent. File/image import and media export should use Android's system pickers / Storage Access Framework where possible. Never request broad storage access just to write into app-private storage.

Check content rating, target audience, ads declaration, app access instructions, privacy disclosures, and current target API requirements. Review codec and font licenses, third-party notices, and the Google Play Developer Program policies before a public launch.

## 4. Release process

1. Run unit/widget tests and `flutter analyze`; inspect the release bundle.
2. Test on the internal track across the supported Android API range and screen sizes.
3. Capture genuine screenshots; do not show features that are still stubs.
4. Roll out gradually, monitor Android vitals and user feedback, and keep a rollback-ready version.
5. Increment `version: x.y.z+buildNumber` for every upload and archive the exact source/tag for each release.

The repository intentionally does not include signing credentials, store assets, or generated native runner projects.
