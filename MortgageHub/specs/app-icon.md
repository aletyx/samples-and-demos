# App icon

A house with a dollar sign, in the Gruvbox palette: a yellow (`#FABD2F`)
house with a chimney on the dark background (`#32302F`), and a bold dollar
sign cut out of it in the background color. Solid shapes, so it still reads
as a 16 px favicon.

- **Masters:** SVGs in
  [mortgagehub_app/assets/icon/](../mortgagehub_app/assets/icon), rendered
  to 1024×1024 PNGs with headless Chrome.
  - `icon.png` is the full, opaque icon, used for iOS, web and legacy
    Android.
  - `icon_foreground.png` is the art on transparency, used for Android's
    adaptive-icon foreground layer.
- **Generated** by `flutter_launcher_icons` (configured in `pubspec.yaml`;
  rerun with `dart run flutter_launcher_icons` after editing the masters):
  - **Web:** `favicon.png`, `Icon-192/512` and their maskable variants, and
    the manifest's background and theme colors (`#32302F`).
  - **Android:** `mipmap-*/launcher_icon.png`, plus an adaptive icon
    (background `#32302F`). Flutter's default `ic_launcher.png` icons were
    removed.
  - **iOS:** the whole `AppIcon.appiconset`, with alpha removed.

## Known limitations

- The Android and iOS icons haven't been seen on a device.
