# craft-rice

A pixel-art **Niri + Noctalia** desktop that installs on almost any Linux
distribution.

One script. It backs up every file it touches. Uninstall puts your originals
back.

---

## Install (3 steps)

```sh
git clone https://github.com/RanXom/craft-rice.git
cd craft-rice
./install.sh
```

**Then log out, choose “Niri” at the login screen, and log in.**

> Replace the clone URL with wherever you got this project from.

That is the whole install. The script:

1. scans your system and lists missing packages,
2. asks once before installing them (needs `sudo`),
3. backs up the files it is about to replace,
4. writes the rice into your home directory.

No root shell. No Nix. No system-wide config.

---

## Want a look first?

```sh
./install.sh preview
```

It writes two PNGs to `~/.cache/craft-rice/preview/` and prints their paths:

- `font-monocraft.png` — the bundled font in every weight
- `cursors-sheet.png` — the cursor theme, with hotspots marked

**Nothing is installed.** The files are read straight out of `assets/`.

Want one PNG per cursor too?

```sh
./install.sh preview cursor --individual
```

Preview needs `python3` and the Pillow package. If it is missing, install
`python-pillow` / `python3-pil` with your distro's package manager. If you only
want to see the font and cannot install Pillow, `pango-view` can render it:

```sh
printf '<fontconfig><dir>%s/assets/fonts</dir></fontconfig>' "$PWD" > /tmp/craft-fonts.conf
FONTCONFIG_FILE=/tmp/craft-fonts.conf pango-view --no-display \
  --font='Monocraft 32' --text='Monocraft 0123 != ->' --output=/tmp/monocraft.png
```

---

## If it asks about your shell

You will only see this if your login shell is **zsh** or **bash**:

```
Keep bash instead of switching to Fish? [Y/n]
```

- **`Y` (default)** — keep bash/zsh. The rice is still installed, and every
  Niri keybind uses your shell.
- **`n`** — configure **Fish** instead. Afterwards, run `chsh -s $(command -v fish)`
  if you want Fish as your login shell.

Already using Fish? It just installs. To skip the question entirely:

```sh
CRAFT_RICE_SHELL=bash ./install.sh     # or zsh, or fish
```

Your previous Fish setup is not lost: the rice config sources
`~/.fish_profile` if that file exists.

---

## Check that it worked

Open a terminal inside Niri and run:

```sh
craft-rice doctor     # looks for problems
craft-rice status     # shows what is installed
```

`doctor` ends with **“No blocking problems found.”** when you are good.

---

## Undo everything

```sh
craft-rice uninstall
```

Every original dotfile comes back. Your backups stay in
`~/.local/state/craft-rice/backups/` in case you want them again.

Want the backups gone too?

```sh
craft-rice uninstall --purge-state
```

---

## What you get

| Thing | What it is |
|---|---|
| Niri | Tiling Wayland compositor, pixel animations, blur, rounded corners |
| Noctalia | Bar, launcher, control center, notifications, wallpaper daemon |
| Kitty | Terminal, themed by Noctalia |
| Fastfetch | Greeting when a terminal opens |
| Starship | Prompt for fish, zsh and bash |
| Fonts | Monocraft, already patched |
| Icons | Pixel-Theme |
| Cursors | JuxCursor |
| Wallpapers | 10 pixel-art images, installed and wired up |
| `oniri` | Workspace/monitor helper for Niri (x86_64) |

Keybinds worth remembering:

| Keys | Action |
|---|---|
| `Super+Return` | Terminal |
| `Super+Space` | Launcher |
| `Super+S` | Control center |
| `Super+Shift+O` | Overview |
| `Super+Q` | Close window |
| `Super+Shift+Slash` | Show every keybind |

Everything is plain text under `~/.config`. Edit it with your editor.

---

## Requirements

- Linux, x86_64 or aarch64 (oniri is x86_64 only; skipped elsewhere)
- A normal user account — **do not run this as root**
- `sudo` if packages are missing (optional; `--no-packages` skips this)
- Internet for the first run if packages are missing

Works on Arch, Fedora, Debian/Ubuntu, openSUSE, Void, Alpine, Gentoo, Solus
and friends. Per-distro notes: [docs/DISTROS.md](docs/DISTROS.md).

NixOS mostly works, but you probably want Home Manager instead — the installer
will warn you.

---

## Common flags

```sh
./install.sh --dry-run        # show the plan, change nothing
./install.sh --no-packages    # dotfiles only, never call the package manager
./install.sh --yes            # answer yes to every prompt (CI, scripts)
./install.sh --verbose        # show every command
./install.sh --force          # continue on NixOS / unsupported setups
```

Full reference: [docs/MANUAL.md](docs/MANUAL.md).

---

## Where things live

```
~/.config/niri                 Niri config, animations, outputs
~/.config/noctalia             Noctalia settings and 7 bundled plugins
~/.config/kitty                Terminal config and theme
~/.config/fastfetch            Greeting
~/.config/starship.toml        Prompt
~/.config/craft-rice           zsh/bash helper (fish uses config.fish)
~/.local/share/fonts           Monocraft
~/.local/share/icons           Pixel-Theme, JuxCursor
~/.local/share/backgrounds     Wallpapers
~/.local/share/craft-rice      Installed copy of this tool
~/.local/bin/craft-rice        The command
~/.local/state/craft-rice      Install record, logs, backups
```

The GUI font/icon/cursor settings are applied through `gsettings` when it is
available. Uninstall puts the previous values back.

---

## Something looks wrong?

Read [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — it covers the usual
suspects, from “command not found” to a black screen.

If an install was killed halfway through:

```sh
craft-rice recover
```

That rolls the half-finished install back and restores your originals.

Logs are at `~/.local/state/craft-rice/craft-rice.log`.

---

## Documentation

- [docs/DISTROS.md](docs/DISTROS.md) — package names per distribution
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — fixes for common problems
- [docs/MANUAL.md](docs/MANUAL.md) — commands, flags, backups, internals
- [docs/CREDITS.md](docs/CREDITS.md) — upstream projects and asset licenses
- [tests/run.sh](tests/run.sh) — the test suite (`./tests/run.sh`)

---

## Safety, in one paragraph

Before craft-rice changes a path, it copies the original into a timestamped
backup folder and records what it did. Uninstall replays that record in reverse:
our files are removed, your files come back, and anything you changed after
installing is moved to
`~/.local/state/craft-rice/conflicts/` instead of being deleted. If an install
fails or is interrupted, the same manifest is used to undo it. Nothing outside
your home directory is modified, except packages you explicitly agreed to
install.

---

## License

MIT for the installer and configs. Bundled fonts, icons, cursors, binaries and
wallpapers keep their own licenses — see [docs/CREDITS.md](docs/CREDITS.md).
