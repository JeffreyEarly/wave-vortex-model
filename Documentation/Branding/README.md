# WaveVortexModel branding

The project mark is a Kelvin–Helmholtz roll-up: cyan flow contours connect a small left billow to a dominant coral eddy on a navy field. Use the same mark across software versions. The square icon carries the symbol; the horizontal wordmarks include the project name.

## Source artwork

- `kelvin-helmholtz-concept.png` preserves the selected imagegen concept at its original 1254 × 1254 resolution. Its white exterior corners are part of the exploration, so use the SVG-derived exports for production.
- `icon-rounded.svg` is the editable vector master with transparent exterior corners.
- `icon-square.svg` uses an opaque square background for system-masked shortcuts.
- `icon-small.svg` reduces the roll-up to one coral hook and two broad cyan contours for tiny displays.
- `flow-mark.svg` contains only the colored flow contours on a transparent background.
- `flow-mark-monochrome.svg` uses `currentColor`; set the root SVG's `color` or use it inline to select a single color.
- `logo-horizontal-light.svg` and `logo-horizontal-dark.svg` combine the full icon with outlined Avenir Next Medium lettering. The suffix names describe the intended background: navy lettering on light surfaces, pale lettering on dark surfaces.
- `social-card.svg` is the editable 1200 × 630 sharing layout.
- `generation-prompt.md` records the selected concept's prompt and reference roles.

The SVG files contain native paths and gradients, with no embedded raster images or runtime font dependency. Font files are not distributed with the artwork.

## Published exports

The canonical website assets live in `Documentation/WebsiteDocumentation/assets/branding/`. The documentation build copies them into the committed `docs/assets/branding/` directory. Edit sources and rebuild instead of changing the generated `docs` tree.

| File | Dimensions | Use |
| --- | --- | --- |
| `icon-512.png`, `icon-1024.png` | 512 × 512, 1024 × 1024 | Website illustrations and external link cards; transparent exterior corners |
| `icon-rounded.svg`, `icon-square.svg` | Scalable | Full icon in rounded or opaque square form |
| `icon-small.svg` | Scalable | Simplified small-display artwork |
| `favicon-16.png`, `favicon-32.png`, `favicon-48.png`, `favicon-96.png` | Named pixel sizes | Browser and search icons |
| `favicon.ico` | 16, 32, and 48 px images | Browser compatibility |
| `apple-touch-icon.png` | 180 × 180 | Opaque square shortcut icon |
| `logo-horizontal-light.svg`, `logo-horizontal-dark.svg` | 536 × 100 | Website header and scalable wordmarks |
| `logo-horizontal-light.png`, `logo-horizontal-dark.png` | 1072 × 200 | Wordmark raster fallback at twice the SVG dimensions |
| `social-card.png`, `social-card.svg` | 1200 × 630 | Link-sharing preview |
| `flow-mark.svg`, `flow-mark.png` | Scalable, 1600 × 791 | Standalone colored flow mark |
| `flow-mark-monochrome.svg`, `flow-mark-monochrome.png` | Scalable, 1600 × 791 | Single-color mark; PNG is black |

The website configuration uses the light horizontal logo and ICO favicon. The custom Sass selects the pale wordmark when the theme's sidebar is dark. The head include adds the 96 px PNG and Apple-touch icon, and Jekyll SEO Tag uses the configured social-card defaults. Keep `title: WaveVortexModel` for metadata and accessibility.

## Re-exporting

`export-assets.mjs` copies the vector masters, outlines the wordmark and sharing-card lettering, and renders the PNG and ICO exports. It requires Node.js, `sharp` 0.35.4, `@napi-rs/canvas` 0.1.100, and the local Avenir Next font. These are graphics-authoring tools, not MATLAB runtime dependencies. Pass `--modules-dir` if the Node packages are outside the usual module search path.

```sh
node Documentation/Branding/export-assets.mjs --font '/System/Library/Fonts/Avenir Next.ttc' --modules-dir /path/to/node_modules
```

For a TTC font collection the exporter selects `AvenirNext-Medium` by PostScript name; `--font-face` can select another named face deliberately. For a single-face TTF/OTF, supply the medium font directly. Font glyphs are converted to paths in the exported SVGs.

After exporting, run the normal documentation build and check described in `Documentation/README.md`. Register each new source image and canonical/published asset, including its generated `docs` copy, as an exact-path `published-asset` entry in `.github/artifact-inputs.json`.

The palette uses a navy gradient (`#136bb8` → `#020a2c`), cyan contours (`#d8fbff` → `#41c8f0`), and coral contours (`#ffe5a0` → `#fa627c`). Horizontal wordmarks use `#122e50` or `#edf6ff` lettering. Preserve these relationships when preparing another layout.
