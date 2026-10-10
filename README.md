# AnimPro

**A simple, user-controlled 2D animation studio.** AnimPro is local-first, works offline, and contains no AI features or AI-generated content. Draw directly on the canvas, organize your work into layers, and build motion one frame at a time.

This repository is a Flutter MVP foundation plus a browser-based interaction preview in [`preview/`](preview/). The Flutter source contains the real drawing, layers, frame timeline, local project storage, theme, onboarding, and PNG/GIF export paths. MP4/WebM encoding needs a native media encoder and is documented separately.

## Start the browser preview

```bash
python3 -m http.server 4173 --bind 0.0.0.0 --directory preview
```

Open `http://localhost:4173`. The preview is an interaction mock for quickly exploring the editor UI; the production app source of truth is the Flutter project under `lib/`.

## Run the Flutter app

You need Flutter stable (Dart 3.5 or newer) and an Android/iOS toolchain.

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter analyze
flutter test
flutter run
```

`flutter create` generates the native runner folders (Android and iOS) for your local Flutter SDK. They are intentionally not hand-copied into this starter. The first launch shows a three-step, non-AI onboarding flow; its default appearance is light mode. Use Settings to switch to dark mode.

## GitHub Actions APK build

`.github/workflows/build-apk.yml` runs on pushes to `main` and `arena/**`, and can also be started from **GitHub → Actions → Build Android APK → Run workflow**. It generates the Android runner, runs `flutter analyze` and `flutter test`, builds `app-release.apk`, and uploads it as the `animpro-release-apk` artifact for 14 days. Download it from the successful workflow run's **Artifacts** section. This CI artifact is for testing; configure a private release keystore and signing secrets before distributing a Play Store build.

## What is implemented

- Pressure-aware CustomPainter canvas, normalized vector strokes, Pencil/Pen/Marker/Airbrush/Calligraphy/Crayon, eraser, line/rectangle/ellipse tools, mirror mode, and grid.
- Project-level layers with visibility, lock, opacity, blend-mode metadata, add/delete/reorder, and selection.
- Frame-by-frame editing with onion skins, frame duplication/deletion/reordering, FPS presets, looping and reverse playback, plus unlimited snapshot-based undo/redo.
- Local JSON project persistence and 30-second editor autosave.
- First-run onboarding, project list/search, light/dark settings, and language selection (English, Amharic, Tigrinya, Oromo).
- PNG sequence and GIF rendering from the same drawing renderer used by the canvas.

## Deliberate MVP boundaries

This is a complete starter for the drawing/layer/frame workflow, not yet a Play-Store-ready substitute for every item in the long product brief. Native audio recording/import, zoom/pan/rotate gestures in the Flutter canvas, reference-media import, eyedropper, polygon/fill/selection/text/transform tools, soft/hard/pixel eraser presets, true stylus tilt calibration, cloud sync, MP4/WebM native encoding, and generated Android/iOS runner files still need implementation and device QA. (The browser preview demonstrates zoom/pan/rotate interactions; those controls are not yet in the Flutter editor.) The UI must not claim these features are ready until their platform code and permissions have been added. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`docs/EXPORT_GUIDE.md`](docs/EXPORT_GUIDE.md), and [`docs/PLAY_STORE_PUBLISHING.md`](docs/PLAY_STORE_PUBLISHING.md).

## Project layout

```text
lib/
  main.dart
  core/
    frame_renderer.dart
    l10n/app_strings.dart
    theme/app_theme.dart
  models/drawing_models.dart
  controllers/editor_controller.dart
  services/project_repository.dart
  services/export_service.dart
  widgets/
    animation_canvas.dart
    frame_timeline.dart
    layer_panel.dart
  screens/
    splash_screen.dart
    onboarding_screen.dart
    project_home_screen.dart
    editor_screen.dart
    export_screen.dart
    settings_screen.dart
    about_screen.dart
docs/
preview/
test/
```

## Privacy and product principles

- No accounts are required to draw.
- Projects are stored on-device by default; nothing is uploaded.
- Cloud backup should be an explicit, opt-in feature only.
- The app contains no AI functionality.
- Keep export/share actions under the user's control, and request only the permissions needed for the feature being used.
