# Export guide

## Available in this starter

`ExportService.exportPngSequence` renders every frame at the project's native canvas dimensions to an app-managed directory. `ExportService.exportGif` encodes those renders as a looping GIF and honors each frame's hold duration. The shared renderer means layer visibility, opacity, the project background, and stroke geometry are consistent with the canvas.

The Flutter export screen saves PNG sequence/GIF files into the application documents directory and opens the native share sheet through `share_plus`. Direct social-network SDK integrations are not included. For a polished public-file workflow, add Android's Storage Access Framework / the iOS document picker as appropriate; avoid broad storage permissions or writing directly to public storage without user consent.

## MP4 and WebM

MP4/WebM are **not wired up in this MVP**. A Dart-only canvas cannot encode H.264/VP9 video. The old `flutter_ffmpeg` package has been retired; do not pin an abandoned FFmpeg binary or silently bundle codecs with unclear licensing. Choose a maintained, license-compatible approach and verify it on supported Android/iOS versions:

1. Render the frames to a temporary app-private directory using `ExportService`.
2. Encode on-device with Android `MediaCodec` / `MediaMuxer` and iOS `AVAssetWriter`, exposed through a platform channel or a maintained plugin; or choose a maintained FFmpeg distribution after legal and store-policy review.
3. Feed frames in timestamp order. The timestamp for frame `i` is the sum of earlier `holdFrames / fps` durations.
4. For opaque MP4 use a broadly compatible H.264 profile and `yuv420p`. MP4 does not preserve alpha. For transparency, use a format/codec such as VP9 WebM only after verifying target-player support.
5. Save to a user-selected destination and clean temporary images after success or cancellation.

## Useful desktop FFmpeg commands

These illustrate encoding only; they are not commands the mobile Flutter app runs itself.

```bash
# MP4 from a numbered PNG sequence
ffmpeg -framerate 24 -i frame_%04d.png -c:v libx264 -pix_fmt yuv420p -movflags +faststart animation.mp4

# Transparent WebM, if the target player supports VP9 alpha
ffmpeg -framerate 24 -i frame_%04d.png -c:v libvpx-vp9 -pix_fmt yuva420p animation.webm

# High-quality GIF using a generated palette
ffmpeg -framerate 12 -i frame_%04d.png -vf "palettegen" palette.png
ffmpeg -framerate 12 -i frame_%04d.png -i palette.png -lavfi "paletteuse" animation.gif
```

For 480p/720p/1080p/2K presets, scale the output while preserving aspect ratio and make the selected dimensions explicit in the export UI. Transparent PNG sequence is the safest option for full alpha fidelity.
