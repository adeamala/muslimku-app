# 3D art (Diorama Senja)

`images/3d/*.webp` is rendered from real 3D models, not drawn by hand or by AI:

- `gen3d.html`: three.js scenes for the floating mosque island, the crescent, the Kaaba and the clay icon set (palette A: `#5A45FE` purple and `#D2F801` lime).
- `render.cjs`: opens the page in headless Chromium (SwiftShader), trims the transparent margins and writes WebP files. Each file is up to 288 px for icons, 840 px for the island, and 560 px for the large tasbih.

Re-render after changing a model:

```sh
cd assets_src/3d
npm install --no-save three@0.180.0 playwright-core
CHROMIUM_PATH=/usr/bin/chromium-browser node render.cjs
```

`test/assets_test.dart` keeps `images/` under its size budget.
