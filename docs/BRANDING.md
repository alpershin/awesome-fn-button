# App icon

Source asset: [`Resources/AppIcon.png`](../Resources/AppIcon.png), 1024 × 1024 RGBA. The build script creates all required `.iconset` sizes and packages `AppIcon.icns`. The same asset is used in the README and app window.

Created with the built-in image generator. The supplied glove image was used as a drawing-style reference only. The chosen artwork has a white glove, lavender forearm, rich apricot key, nearly neutral tile, and black outlined impact bursts. Discarded variants are not included in the repository.

## Final generation prompt

Preserve the approved forceful vertical fist slam, top-center lavender forearm, squashed fn key, exact lowercase “fn” letters, and thick cartoon outlines. The glove and cuff are white with soft light-grey shading. Impact bursts are hollow black outlines; speed and vibration lines are black. The rounded tile is almost-neutral cool off-white. Increase only the key's saturation to warm apricot: front #F59D68, top #F8AB78, side #D38259, rich but not neon. Preserve the geometry, pose, and linework. Transparent outside the tile. No face or extra objects.

## Installer

[`Resources/InstallerFist.png`](../Resources/InstallerFist.png) was created with the built-in image generator. It uses the app icon's white glove, lavender cuff, apricot motion lines, and charcoal outline. The fist is turned sideways with its knuckles facing right, directing the user from the app to Applications.

Final prompt: preserve a horizontal rightward punch in side profile, white glove with soft grey cel shading, lavender cuff on the left, four curled knuckles forming the right contact edge, thumb folded over the upper fingers, and three apricot motion strokes trailing left. Remove all background, outer glow, haze, and drop shadow; keep transparent surroundings and crisp outlines. No text, arrow, key, or folder.

`scripts/render-installer.swift` places the illustration between the two native Finder icons and draws the English instructions on a pale neutral background with peach-outlined pads. It emits a Retina-aware TIFF for the DMG and a PNG preview into `build/installer/`.
