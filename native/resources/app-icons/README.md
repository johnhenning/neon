# Neon app icons

`light.png` and `dark.png` are the original, unmodified user-supplied artwork.
Run `python3 native/scripts/generate_app_icons.py` from the repository root on
macOS with Xcode installed to regenerate all platform PNGs.

- iPhone/iPad: opaque 1024px light and dark artwork in the iOS catalog. The OS
  applies its Home Screen mask and the asset compiler generates device sizes.
- Mac: 1024px transparent canvas with an 824px inset continuous rounded square
  and subtle shadow. The catalog includes every 16–512pt size at 1x and 2x.
  This legacy `.icns` packaging also supports our macOS 14 minimum target.
- Finder and the inactive Mac application use the light icon. While running,
  the Dock icon follows Neon's effective appearance, using the same rounded
  artwork for both light and dark. The originals are not used as Dock images.

The Swift renderer preserves the artwork; it only applies platform framing.
