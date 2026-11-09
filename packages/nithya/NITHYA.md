# Picked from Nithya

- Kit: Studio (`studio`), runtime Flutter
- Themes: lagoon, daylight, dusk, ember, graphite, ink (default: lagoon)
- Source: github.com/sudharamachandranrajeev/nithya at `aa2a7df`, 2026-11-09
- Licence: Apache-2.0 (see LICENSE)

This folder is a copy. Change it freely; to take later Nithya changes, pick again into a
new folder and compare.

## Next steps

1. Add to pubspec.yaml:  nithya: { path: packages/nithya/flutter }
2. Apply a theme:  MaterialApp(theme: nithyaTheme(nithyaPalettes['lagoon']))
3. Change tokens in packages/nithya/tokens/nithya.tokens.json, then run  node packages/nithya/tokens/build.mjs
