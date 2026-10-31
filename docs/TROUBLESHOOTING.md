# Troubleshooting

Start here:

```sh
craft-rice doctor
craft-rice status
```

`doctor` checks your session and ends with either **“No blocking problems
found.”** or a red `✗` line telling you what is wrong. `status` shows what was
installed and where.

The full install log is at:

```
~/.local/state/craft-rice/craft-rice.log
```

For more detail while running a command, add `--verbose`.

---

## `craft-rice: command not found`

The command lives in `~/.local/bin`, which your shell may not have loaded yet.

```sh
# run the copy in the repo instead
./install.sh doctor

# or reload your shell config
exec $SHELL -l
```

If you kept a shell other than fish, the installer added `~/.local/bin` to your
PATH. Open a new terminal; existing terminals keep their old PATH.

---

## I installed it but the desktop did not change

The dotfiles only take effect after Niri restarts.

1. Log out.
2. At the login screen, pick **Niri** as the session.
3. Log in.

If there is no “Niri” entry, you need a display manager (SDDM, GDM, LightDM,
greetd) or you need to start Niri from a TTY:

```sh
niri-session
```

Already inside Niri? Reload without logging out:

```sh
niri msg action reload-config
```

If the config is invalid, Niri keeps the old one and prints an error. Validate
it yourself:

```sh
niri validate -c ~/.config/niri/config.kdl
```

---

## Black screen or Niri refuses to start

Run Niri from a TTY so you can see the error:

```sh
niri-session 2>&1 | tee /tmp/niri.log
```

Common causes:

- **A stale Niri config** — move it aside and test:
  ```sh
  mv ~/.config/niri ~/.config/niri.bak
  niri-session
  ```
  If that works, the rice config needs fixing (see the validation step above).
- **No GPU / VM without acceleration** — Niri needs a working Mesa driver.
  Check `glxinfo -B` or `eglinfo`.
- **Missing `xwayland-satellite`** — X11 apps will not start. Install it and
  rerun `craft-rice doctor`.
- **Running inside a container** — Niri cannot start without a real GPU and
  seat. The dotfiles still install fine.

Niri's own log usually lands in the system journal:

```sh
journalctl --user -b -u niri
```

---

## Niri works, but there is no bar / no launcher

Noctalia is probably missing or not running.

```sh
command -v noctalia
noctalia --version
```

If it is not installed, see [DISTROS.md](DISTROS.md) — it is not packaged on
every distro. Then install the dotfiles again:

```sh
./install.sh --no-packages
```

Start it by hand to see errors:

```sh
noctalia
```

Check that the settings file exists and is valid:

```sh
ls ~/.config/noctalia/settings.toml
```

---

## No wallpaper

The wallpapers are installed to:

```
~/.local/share/backgrounds/craft-rice/
```

Noctalia points at that directory. If the screen is black:

1. Right-click the bar or press `Super+Alt+W` for the wallpaper panel.
2. Pick any image.
3. If no images appear, confirm the files exist, then restart Noctalia:
   ```sh
   pkill noctalia; noctalia &
   ```

If you moved your home directory after installing, the absolute paths in
`~/.config/noctalia/settings.toml` are stale. Re-run:

```sh
./install.sh --no-packages --force
```

To use your own wallpapers, copy them into that folder — Noctalia rotates
through the directory.

---

## Wrong monitor layout, resolution or scale

Snapshot the current session's real outputs:

```sh
craft-rice outputs
niri msg action reload-config
```

That rewrites `~/.config/niri/outputs.kdl`. It only works from inside a running
Niri session.

To edit by hand, look at `~/.config/niri/outputs.kdl`:

```kdl
output "eDP-1" {
    mode "2560x1600@60.002"
    scale 1.4
}
```

Use `niri msg outputs` to see the names (`eDP-1`, `DP-1`, `HDMI-A-1`, ...).

---

## Everything is huge or tiny

That is the output scale. Change it in `~/.config/niri/outputs.kdl`:

```kdl
output "eDP-1" {
    scale 1.0
}
```

For HiDPI screens, 1.25–1.5 is common. Reload with
`niri msg action reload-config`.

Font size is separate: edit `~/.config/kitty/kitty.conf` (`font_size`) and
`~/.config/noctalia/settings.toml`.

---

## Icons, cursors or font did not change

The files are installed, but apps cache theme settings.

```sh
fc-cache -f
gsettings set org.gnome.desktop.interface icon-theme 'Pixel-Theme'
gsettings set org.gnome.desktop.interface cursor-theme 'JuxCursor'
gsettings set org.gnome.desktop.interface font-name 'Monocraft 10'
```

Then log out and back in. GTK apps pick the cursor up on restart; some apps
need a full session restart.

If `gsettings` is not installed, the rice files still work, but GTK apps keep
their old theme. Install `glib` / `gsettings-desktop-schemas` for your distro.

Check the files:

```sh
ls ~/.local/share/fonts/Monocraft.ttc
ls ~/.local/share/icons/Pixel-Theme/index.theme
ls ~/.local/share/icons/JuxCursor/cursors/left_ptr
```

---

## Blur does not work

Blur needs **Niri 26.04 or newer**. On older versions the installer removes the
blur blocks automatically so the config stays valid.

Check your version:

```sh
niri --version
```

Force the behaviour if detection is wrong:

```sh
CRAFT_RICE_NIRI_BLUR=1 ./install.sh --no-packages --force   # keep blur
CRAFT_RICE_NIRI_BLUR=0 ./install.sh --no-packages --force   # strip blur
```

---

## The terminal opens the wrong shell

Niri keybinds contain the shell chosen at install time. If you changed shells
afterwards, re-render the config:

```sh
CRAFT_RICE_SHELL=fish ./install.sh --no-packages --force    # or zsh / bash
niri msg action reload-config
```

Check what was rendered:

```sh
grep 'spawn.*kitty' ~/.config/niri/config.kdl | head
```

The installer never runs `chsh` for you. To change your login shell:

```sh
chsh -s "$(command -v fish)"
```

---

## Package installation failed

The installer tries the whole batch, then retries one package at a time so a
single bad name does not block the rest. If some still fail, install them
manually with your package manager and re-run:

```sh
./install.sh --no-packages
```

The complete list is in [DISTROS.md](DISTROS.md), or run:

```sh
craft-rice doctor
```

`doctor` marks optional tools (playerctl, wl-clipboard, btop, ...) with `!`
instead of `✗`. Those do not block the desktop.

To skip packages entirely from the start:

```sh
./install.sh --no-packages
```

---

## “Interrupted install detected”

An install was killed or the machine lost power. Just run:

```sh
craft-rice recover
```

It reads the backup manifest from the unfinished run, removes the half-written
files, and puts your originals back. Then install again:

```sh
./install.sh
```

If `recover` says there is nothing to do, you are already clean.

---

## Uninstall says a file was “preserved” or “moved aside”

You edited a rice-managed file after installing. Uninstall will not delete your
work. Instead it moves the file here:

```
~/.local/state/craft-rice/conflicts/
```

Look inside, keep what you want, and delete the folder when you are done.

Your pre-install originals are always in:

```
~/.local/state/craft-rice/backups/<timestamp>/
```

Each backup contains a `manifest.tsv` (what was there before) and a generated
`restore.sh` you can run by hand:

```sh
~/.local/state/craft-rice/backups/<timestamp>/restore.sh
```

---

## “craft-rice is not installed”

Uninstall only runs when `~/.local/state/craft-rice/installed.tsv` exists. If
that file is gone, you can still restore a backup manually with its
`restore.sh`, or simply delete the rice files you no longer want.

---

## “Do not run craft-rice as root”

Correct. Run it as your normal user. It asks for `sudo` only when installing
packages. Running as root would write files owned by root into your home and
break your session.

---

## HOME has spaces

Supported. Paths are quoted everywhere, but a few upstream tools are not as
careful. If something specific breaks, move the relevant config to a
space-free path and symlink it.

---

## NixOS warning

craft-rice writes plain files under `$HOME`, which conflicts with a
declarative Home Manager setup. Either:

- manage these paths with Home Manager and do not use this installer, or
- make sure the paths are not declared in Nix, then run:
  ```sh
  ./install.sh --force --no-packages
  ```

---

## Start over from scratch

```sh
craft-rice uninstall          # restores originals, keeps backups
./install.sh                  # install again
```

To also throw away every backup:

```sh
craft-rice uninstall --purge-state
```

To also remove the rice's packages (asks twice):

```sh
craft-rice uninstall --purge-packages
```

Both purge flags are deliberately noisy. Read the prompts.

---

## Nothing here helped

Collect this and open an issue:

```sh
craft-rice doctor --verbose > /tmp/craft-rice-doctor.txt 2>&1
craft-rice status > /tmp/craft-rice-status.txt 2>&1
cp ~/.local/state/craft-rice/craft-rice.log /tmp/ 2>/dev/null
niri --version
noctalia --version
cat /etc/os-release
```

The test suite is also a quick sanity check:

```sh
./tests/run.sh
```
