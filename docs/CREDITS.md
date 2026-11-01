# Credits and asset licenses

craft-rice is an installer and a configuration set. Most of what you see on
screen was made by other people.

---

## Upstream software

| Project | Author / source | License |
|---|---|---|
| [Niri](https://github.com/YaLTeR/niri) | Ivan Fedorov (YaLTeR) and contributors | GPL-3.0 |
| [Noctalia](https://github.com/noctalia-dev/noctalia) | noctalia-dev and contributors | MIT |
| [Kitty](https://github.com/kovidgoyal/kitty) | Kovid Goyal | GPL-3.0 |
| [Starship](https://github.com/starship/starship) | Starship contributors | ISC |
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | Fastfetch contributors | MIT |
| [oniri](https://github.com/Antiz96/oniri) | Antiz96 | GPL-3.0 |
| [Nirimation](https://github.com/Xansidev/nirimation) | Xansidev and contributors | MIT |
| Niri shaders | liixini ([shaders](https://github.com/liixini/shaders)) | MIT |

Niri animations in `config/niri/animations/` keep their original headers and
attribution comments. Most come from Nirimation or liixini's shader collection
(MIT). Two of them (`energize_b_niri.kdl`, `incinerate.kdl`) say they are
adapted from [Burn My Windows](https://github.com/Schneegans/Burn-My-Windows)
by Simon Schneegans; check that project's GPL-3.0 terms before redistributing
those files.

---

## Bundled assets

| Asset | Source | License |
|---|---|---|
| **Monocraft** (Nerd Fonts patched) | [IdreesInc/Monocraft](https://github.com/IdreesInc/Monocraft), patched by [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) | SIL Open Font License 1.1 — [text](../assets/fonts/OFL.txt) |
| **JuxCursor** | Juxtopposed, from [juxtopposed/cosmic](https://github.com/juxtopposed/cosmic) | no license upstream — [read this](../assets/cursors/NOTICE.md) |
| **Pixel-Theme** 0.6.2 | [gnome-look.org/p/1205412](https://www.gnome-look.org/p/1205412) | not stated upstream — [read this](../assets/icons/NOTICE.md) |
| **oniri** v1.3.5 binary | [Antiz96/oniri releases](https://github.com/Antiz96/oniri/releases) | GPL-3.0 — [text](../assets/bin/LICENSE-GPL-3.0.txt) |
| **Wallpapers** | curated pixel-art collection; individual artists unknown | not stated upstream — [read this](../assets/WALLPAPERS-NOTICE.md) |

The Monocraft font is distributed under the SIL OFL 1.1, which permits bundling
and redistribution with software. The license text ships in
`assets/fonts/OFL.txt` and is installed to
`~/.local/share/doc/craft-rice/Monocraft-OFL.txt`.

The JuxCursor, Pixel-Theme and wallpaper files are included so the rice works
out of the box. Their upstream terms are **not** explicitly stated, and the
wallpaper artists are not identified. Do not publish a public fork containing
these files until you have written permission from the authors or have replaced
them with assets you can redistribute. Each asset directory has a `NOTICE.md`
explaining the exact status.

The bundled `oniri` binary is unmodified and covered by GPL-3.0. To satisfy the
license's source requirement, the matching upstream source is included as
`assets/bin/oniri-1.3.5-source.tar.gz` (from the `v1.3.5` tag). The license
text ships in `assets/bin/LICENSE-GPL-3.0.txt`.

---

## Noctalia plugins

The plugins under `config/noctalia/plugins/` are third-party Noctalia plugins,
copied as-is with their own `README.md`, `LICENSE` and translation files:

| Plugin | Purpose |
|---|---|
| `cloudflare-warp` | WARP status in the bar |
| `kde-connect` | Phone integration |
| `mawaqit` | Prayer times |
| `noctalia-calculator` | Calculator |
| `screen-toolkit` | Screenshot, record, OCR, color picker |
| `slowbongo` | Bongo cat |
| `usb-drive-manager` | USB drive management |

Only `kde-connect` and `noctalia-calculator` ship a license file in this
bundle. The upstream plugin repository does not declare a repository-wide
license, so the other five plugins need their author's permission before you
redistribute them. Check the individual plugin folder and upstream source.

These plugins target Noctalia 4.x (QML). The upstream repository is now
archived as
[`noctalia-dev/legacy-v4-plugins`](https://github.com/noctalia-dev/legacy-v4-plugins).
Noctalia 5 uses Luau plugins with `plugin.toml` manifests and only scans its own
plugin directories, so it **ignores** everything in
`~/.config/noctalia/plugins/`. Current Noctalia 5 users should install plugins
from the built-in store instead. Because of that, removing this legacy bundle
before a public release is recommended: it is dead weight on Noctalia 5 and
most of it has no redistribution license.

---

## This project

The installer, templates and documentation are MIT licensed — see
[../LICENSE](../LICENSE).
