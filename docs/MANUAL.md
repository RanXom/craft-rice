# Manual

Reference for everything craft-rice does. For the 30-second version, read the
[README](../README.md).

---

## Synopsis

```
./install.sh [command] [flags]
craft-rice [command] [flags]        # after installing
```

`install` is the default command, so `./install.sh --dry-run` and
`./install.sh install --dry-run` are the same.

Flags go **after** the command. If you omit the command, put flags first and
nothing after them:

```
craft-rice doctor --verbose      # correct
craft-rice --dry-run             # correct (install is implied)
craft-rice --verbose doctor      # wrong: "doctor" is parsed as a flag
```

---

## Commands

| Command | What it does |
|---|---|
| `install` | Scan packages, back up originals, write the rice. The default. |
| `uninstall` | Remove what was installed and restore the backups. |
| `status` | Print version, install state, paths and the selected shell. Exit 0 even when not installed. |
| `doctor` | Check the live session: Niri, Noctalia, Kitty, fonts, icons, cursors, helper binaries, config syntax. **Exit 1** if anything blocking is wrong. |
| `recover` | Roll back an interrupted install using its backup manifest. Safe to run when nothing is wrong. |
| `outputs` | Read the current Niri outputs and rewrite `outputs.kdl` with the real mode and scale. Requires a running Niri session. |
| `version` | Print `craft-rice <version>`. |
| `help` | Usage text. |

### `install` flow

1. Preflight: Linux, not root, `$HOME` exists, architecture, distro, Niri
   version, Noctalia version.
2. Detect the shell (see below).
3. Scan packages and print one table. Missing **required** packages are grouped
   into a single yes/no prompt before `sudo` is called. Missing **optional**
   packages are only listed.
4. Show the plan and ask for confirmation.
5. Create the backup directory and write `manifest.tsv`.
6. Copy configs, browse assets, generate `outputs.kdl`, install the CLI.
7. Apply GTK icon/cursor/font settings with `gsettings` when available.
8. Finalise `installed.tsv`, remove the journal, print next steps.

If any step fails, the backup manifest is replayed in reverse and the install
directory is removed. See [failure handling](#failure-handling).

### `uninstall` flow

1. Read `~/.local/state/craft-rice/installed.tsv`.
2. Show the plan and ask once.
3. Remove craft-rice-managed files; for shell rc files, remove only the marked
   block.
4. Restore every path in the backup, moving anything that still exists to
   `~/.local/state/craft-rice/conflicts/`.
5. Revert `gsettings` values.
6. Prune directories that are now empty, but only inside `$HOME`.
7. Keep backups, unless `--purge-state`.

Uninstall refuses to run when `installed.tsv` is missing.

---

## Flags

| Flag | Effect |
|---|---|
| `--dry-run` | Print every action, change nothing. No backups, no packages, no writes. |
| `--yes`, `-y` | Answer yes to every prompt, including package installation and confirmation. Use with care. |
| `--no-packages` | Never call the package manager. Still prints the scan. |
| `--minimal` | Reserved; currently has no effect. |
| `--force` | Continue on NixOS or an unsupported setup. Also re-renders configs over an existing install without asking. |
| `--purge-packages` | On uninstall, also remove the rice's own packages. Asks twice and never removes shared dependencies. |
| `--purge-state` | On uninstall, delete `~/.local/state/craft-rice` including **all** backups. Asks again. |
| `--verbose`, `-v` | Print debug detail and every command that is run. |
| `--help`, `-h` | Show usage. |

`--dry-run` and `--yes` together are safe: the dry run never prompts.

---

## Environment variables

| Variable | Meaning |
|---|---|
| `CRAFT_RICE_SHELL=fish\|zsh\|bash` | Skip shell detection and the keep/switch question. Also controls what is rendered into Niri keybinds. |
| `CRAFT_RICE_NIRI_BLUR=0` | Strip blur blocks even if Niri is new enough. `=1` keeps them. |
| `XDG_CONFIG_HOME` | Where configs go. Default: `~/.config`. |
| `XDG_DATA_HOME` | Where fonts/icons/wallpapers/tool copy go. Default: `~/.local/share`. |
| `XDG_STATE_HOME` | Where the install record, log and backups go. Default: `~/.local/state`. |
| `XDG_CACHE_HOME` | Respected but not written to. |
| `NO_COLOR` | Disable colours. |
| `HOME` | Everything is installed relative to this. Must be a real directory. |

All paths are quoted, so `HOME` may contain spaces.

---

## Shell selection

Order of precedence:

1. `CRAFT_RICE_SHELL`, if set.
2. The login shell (`$SHELL`), if it is fish, zsh or bash.
3. If the login shell is zsh or bash **and** fish is installed, craft-rice asks
   whether to keep the current shell or switch to fish. Default: keep.
4. If the login shell is something else, craft-rice lists the installed
   shells and asks.
5. If no supported shell exists, bash is used.

What each choice installs:

| Shell | Integration |
|---|---|
| fish | Replaces `~/.config/fish/config.fish` (backed up first). The shipped file sources `~/.fish_profile` when present. |
| zsh | Writes `~/.config/craft-rice/shell.zsh` and appends a marked block to `~/.zshrc`. |
| bash | Writes `~/.config/craft-rice/shell.bash` and appends a marked block to `~/.bashrc`. |

The marked block is:

```sh
# >>> craft-rice >>>
# Added by craft-rice. Remove with: craft-rice uninstall
[ -f "$HOME/.config/craft-rice/shell.bash" ] && . "$HOME/.config/craft-rice/shell.bash"
# <<< craft-rice <<<
```

Uninstall removes only those three lines. Edits outside the block are kept.

`chsh` is never run for you.

---

## What gets written

Paths use the XDG roots.

| Path | Kind |
|---|---|
| `~/.config/niri/config.kdl` | Managed file, rendered from a template |
| `~/.config/niri/animations/` | Directory tree |
| `~/.config/niri/outputs.kdl` | Generated from the live session, or copied sample |
| `~/.config/niri/extras.kdl`, `noctalia.kdl` | Managed files |
| `~/.config/noctalia/settings.toml` | Rendered (paths and wallpaper) |
| `~/.config/noctalia/plugins/` | 7 bundled plugins |
| `~/.config/noctalia/{config.toml,plugins.json,templates.toml,templates/niri.kdl}` | Managed files |
| `~/.config/kitty/kitty.conf`, `themes/noctalia.conf` | Kitty config + fallback theme |
| `~/.config/fastfetch/config.jsonc`, `logo.txt` | Rendered + logo |
| `~/.config/starship.toml` | Prompt |
| `~/.config/craft-rice/shell.{zsh,bash}` | Only for zsh/bash |
| `~/.config/fish/config.fish` | Only for fish |
| `~/.local/share/fonts/Monocraft.ttc` | Font |
| `~/.local/share/icons/Pixel-Theme/` | Icon theme |
| `~/.local/share/icons/JuxCursor/` | Cursor theme |
| `~/.local/share/backgrounds/craft-rice/` | 10 wallpapers |
| `~/.local/bin/craft-rice-oniri` | Wrapper for the bundled `oniri` |
| `~/.local/bin/craft-rice-polkit` | Polkit agent wrapper |
| `~/.local/share/craft-rice/` | Installed copy of this tool |
| `~/.local/bin/craft-rice` | Symlink to the installed copy |
| `~/.local/state/craft-rice/` | Record, log, backups, conflicts |
| `~/Pictures/Screenshots` | Created if missing; screenshots go here |

When `gsettings` exists, these keys are recorded and changed:

```
org.gnome.desktop.interface  icon-theme         Pixel-Theme
org.gnome.desktop.interface  cursor-theme       JuxCursor
org.gnome.desktop.interface  cursor-size        24
org.gnome.desktop.interface  font-name          Monocraft 10
org.gnome.desktop.interface  monospace-font-name Monocraft 10
```

---

## Backups

### Layout

```
~/.local/state/craft-rice/
├── installed.tsv          what this install owns
├── craft-rice.log         append-only log
├── repo.path              path to the repo (for reinstall)
├── journal.tsv            present only during an install
├── backups/
│   ├── current -> 20261101-123456-7890
│   └── 20261101-123456-7890/
│       ├── manifest.tsv
│       ├── meta.env
│       ├── restore.sh
│       └── files/1,2,3...
└── conflicts/
    ├── restore-.../       files replaced during a restore
    └── uninstall-.../     modified rice files preserved on uninstall
```

### `manifest.tsv`

Tab-separated: `index`, `action`, `path`.

| Action | Meaning |
|---|---|
| `absent` | The path did not exist. Uninstall/rollback removes it. |
| `file` | A regular file was moved into `files/<index>`. |
| `dir` | A whole directory was moved. |
| `symlink` | A symlink was moved. |

Paths are escaped so tabs and newlines cannot break the format.

### `restore.sh`

Generated into every backup directory. It is standalone: it needs nothing but
bash and the backup folder.

```sh
~/.local/state/craft-rice/backups/<id>/restore.sh
```

It reads the manifest, moves current paths into
`~/.local/state/craft-rice/conflicts/restore-<timestamp>/`, and puts the
originals back.

### Reinstall

Installing over an existing install would otherwise back up craft-rice's own
files as if they were yours. Instead craft-rice:

1. asks before touching an existing install (unless `--force`),
2. finds the previous backup,
3. merges manifests: any path the old install already knew about keeps the
   **old** original, including `absent` verdicts.

Result: uninstall after any number of reinstalls still restores what you had
before the very first install.

---

## Install record

`installed.tsv` uses the same tab-separated shape. Kinds:

| Kind | Meaning |
|---|---|
| `meta` | `backup_id`, `backup_dir`, `version`, `shell`, `distro` |
| `managed` | A file owned by craft-rice |
| `generated` | A file generated from the live system |
| `tree` | A directory owned by craft-rice |
| `dir` | A directory craft-rice may have created |
| `symlink` | A symlink owned by craft-rice |
| `block` | A shell rc file with a marked block |
| `gsetting` | A schema/key and its previous value |

Uninstall walks this record; the manifest tells it what to restore.

---

## Failure handling

Every install writes a journal and a backup manifest before touching paths.

**Normal failure (non-zero exit, signal caught):**

1. `gsettings` values from the partial install are reverted.
2. Every `absent` path in the manifest is deleted.
3. Every recorded original is moved back; anything craft-rice wrote over it is
   moved into `conflicts/restore-...`.
4. The failed backup directory, `current`, journal and install record are
   removed.

**Hard kill / power loss:** run

```sh
craft-rice recover
```

`recover` detects `journal.tsv` or `installed.tsv.new`, takes the stale lock,
and performs the same manifest-based rollback. If no backup exists, it removes
the stale record only and says so.

**Stale lock:** a lock directory under `~/.local/state/craft-rice/lock` holds
the PID. If that process is gone, `recover` takes it over.

---

## Uninstall details

- Managed files are deleted.
- Shell rc blocks are removed with a line-accurate filter, preserving all other
  content and the file's inode.
- Restored paths that still exist are moved to `conflicts/`, never deleted.
- Directories are pruned only if empty and only under `$HOME`.
- Backups are kept by default.
- `--purge-state` deletes the whole state directory after a second prompt.
- `--purge-packages` removes `niri`, `kitty`, `noctalia`,
  `xwayland-satellite`, `starship`, `fastfetch` and fish (if used), after two
  prompts. Shared libraries and services are never removed.

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success, including a cancelled prompt and `status` on a clean system. |
| `1` | Error: bad flag, failed install, `doctor` found blocking problems, uninstall with nothing installed, recovery failed. |
| `130` | Interrupted with Ctrl-C (the rollback still runs). |

---

## Tests

```sh
./tests/run.sh        # 13 scenarios, ~1 minute
./tests/run.sh -v     # keep temp dirs and print logs
```

The suite uses throwaway `HOME` and XDG directories under
`/tmp/craft-rice-tests`, never installs packages, and covers: syntax,
fresh install, uninstall/restore, reinstall, dry run, zsh block editing, fish,
paths with spaces, symlinked config dirs, failed-install rollback, interrupted
install + recovery, blur stripping, and uninstall-when-absent.

---

## Repository layout

```
bin/craft-rice        entry point and flag parsing
lib/common.sh         paths, colours, logging, prompts, lock
lib/detect.sh         distro, arch, shell, Niri/Noctalia, preflight
lib/packages.sh       package maps, scan, install
lib/backup.sh         backup, merge, restore, rollback, journal
lib/render.sh         template rendering
lib/shell.sh          fish/zsh/bash integration
lib/assets.sh         fonts, icons, cursors, wallpapers, helpers
lib/install.sh        install orchestration
lib/uninstall.sh      uninstall orchestration
lib/commands.sh       status, doctor, recover, outputs, help
lib/outputs.py        Niri output → KDL
config/               shipped dotfiles and templates
assets/               fonts, cursors, icons, wallpapers, oniri
tests/run.sh          test suite
```

Templates use `@TOKEN@` placeholders. `render.sh` substitutes `@SHELL@`,
`@HOME@`, paths and wallpaper names; it fails loudly if a token survives.

---

## Customisation

The installed files are ordinary files. Edit them freely.

- `~/.config/niri/config.kdl` — keybinds, gaps, layout
- `~/.config/niri/animations/` — one file per animation
- `~/.config/kitty/kitty.conf` — terminal
- `~/.config/noctalia/settings.toml` — bar, wallpaper, theme

Reinstalling overwrites managed files but backs up your edited version first.
The backup remains available under `backups/`.

`craft-rice outputs` is the supported way to update monitor layout after
plugging in a display.
