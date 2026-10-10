# AnimPro architecture

## Principles

- **Local-first:** the editor works offline; project JSON is stored in the app documents directory.
- **User controlled:** drawing and edits are direct actions; there is no AI service, generation flow, or required account.
- **One renderer:** the canvas and exports use the same `FrameRenderer`, avoiding visual differences between editing and output.
- **Normalized strokes:** stroke points are stored in 0–1 canvas coordinates, so projects can be previewed at different display sizes.

## Data model

`AnimationProject` owns a fixed canvas size, FPS, background color, layer order, animation frames, and optional audio metadata. Each frame owns a map from layer ID to that frame's vector strokes. Layer visibility, lock, opacity, and blend mode are project-level properties. A frame's `holdFrames` value lets it stay on screen for multiple playback ticks without duplicating drawing data.

Undo/redo currently uses full JSON snapshots. This is straightforward and reliable for an MVP but consumes memory for large projects. A production version should move to a command/delta history with configurable memory limits and periodic checkpoints while preserving unlimited logical undo.

## Main modules

- `EditorController`: editor state, frame/layer operations, playback timer, pointer input, undo/redo.
- `AnimationCanvas` / `FrameRenderer`: CustomPainter presentation, onion skinning, mirror/grid overlays, normalized pointer mapping.
- `FrameTimeline`: frame selection, add/duplicate/delete, drag reorder, playback controls, FPS presets.
- `ProjectRepository`: local JSON persistence. Autosave runs every 30 seconds while the editor is open and once more when it closes.
- `ExportService`: deterministic PNG sequence/GIF rendering from the shared renderer.
- `AppStrings`: small, built-in translation table for the requested starter locales. Expand/review all copy with native speakers before release.

## Product screens

1. Splash / first-run onboarding (three short tutorial pages)
2. Project list with search and create
3. Editor with canvas, tools, layers, and frame timeline
4. Export sheet / export settings
5. Settings (theme and language)
6. About

## Extending toward the full brief

Recommended order: (1) draw engine QA on finger/stylus devices, (2) project serialization migrations and thumbnails, (3) canvas selection/fill/text/transform tools, (4) audio tracks and permissions, (5) platform MP4/WebM encoder, (6) opt-in cloud backup. Keep media imports and backups sandboxed; validate file size, duration, and format before decoding. Add integration tests and accessibility labels as features land.
