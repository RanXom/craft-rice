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
| [Nirimation](https://github.com/XansiVA/nirimation) | XansiVA and contributors | see repository |
| Niri shaders | liixini ([shaders](https://github.com/liixini/shaders)) | see repository |

Niri animations in `config/niri/animations/` keep their original headers and
attribution comments.

---

## Bundled assets

| Asset | Source | License |
|---|---|---|
| **Monocraft** (Nerd Fonts patched) | [IdreesInc/Monocraft](https://github.com/IdreesInc/Monocraft), patched by [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) | SIL Open Font License 1.1 |
| **JuxCursor** | Juxtopposed, from [juxtopposed/cosmic](https://github.com/juxtopposed/cosmic) | no license file upstream — check before redistributing |
| **Pixel-Theme** 0.6.2 | [gnome-look.org/p/1205412](https://www.gnome-look.org/p/1205412) | not stated upstream — check before redistributing |
| **oniri** v1.3.5 binary | [Antiz96/oniri releases](https://github.com/Antiz96/oniri/releases) | GPL-3.0 |
| **Wallpapers** | curated pixel-art collection; individual artists unknown | not stated — check before redistributing |

The Monocraft font is distributed under the SIL OFL 1.1, which permits bundling
and redistribution with software. The full license text is available at
<https://scripts.sil.org/OFL>.

The JuxCursor, Pixel-Theme and wallpaper files are included so the rice works
out of the box. Their upstream terms are not explicitly stated. If you plan to
publish or sell a fork, verify the licenses with the original authors first.

The bundled `oniri` binary is unmodified and covered by GPL-3.0. Its source is
available from the upstream repository above.

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

Each plugin directory retains the license file shipped by its author where one
exists. Check the individual plugin folder for details.

---

## This project

The installer, templates and documentation are MIT licensed — see
[../LICENSE](../LICENSE).
