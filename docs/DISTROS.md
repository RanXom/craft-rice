# Distribution notes

craft-rice detects your distribution from `/etc/os-release` and picks the first
package manager it finds. Nothing is hardcoded to one distro.

The install itself is identical everywhere:

```sh
./install.sh
```

This page only explains what happens to **packages** on each family.

---

## The short version

- If a package is missing, the installer shows it and asks before running the
  package manager with `sudo`.
- If a feature has no package name on your distro, you get a manual
  instruction instead of an install command that cannot work.
- If no supported package manager is found, the installer prints the list and
  continues with the dotfiles.
- `--no-packages` skips all of this. Useful when you manage packages yourself.

**The dotfiles never depend on package installation succeeding.** Nothing in
`~/.config` needs `sudo`.

---

## Supported package managers

| Family | Detected via | Install command used |
|---|---|---|
| Arch, CachyOS, EndeavourOS, Manjaro, Garuda, Artix | `pacman` | `sudo pacman -S --needed --noconfirm` |
| Fedora, RHEL, CentOS, Rocky, Alma, Nobara | `dnf` | `sudo dnf install -y` |
| Debian, Ubuntu, Mint, Pop!_OS, elementary, Zorin, Kali | `apt-get` | `sudo apt-get update && sudo apt-get install -y` |
| openSUSE, SLES | `zypper` | `sudo zypper --non-interactive install` |
| Void Linux | `xbps-install` | `sudo xbps-install -y` |
| Alpine, Chimera | `apk` | `sudo apk add` |
| Gentoo, Funtoo | `emerge` | `sudo emerge --noreplace` |
| Solus | `eopkg` | `sudo eopkg install -y` |
| NixOS | `nix-env` | none — see below |

---

## Arch and Arch-based

Everything is in the official repositories, including Noctalia.

```sh
sudo pacman -S niri kitty noctalia xwayland-satellite lxqt-policykit \
  playerctl brightnessctl wl-clipboard fontconfig adwaita-icon-theme \
  breeze-icons pipewire wireplumber networkmanager bluez \
  xdg-desktop-portal xdg-desktop-portal-gtk mesa starship fastfetch
```

Optional extras: `grim slurp btop zoxide fzf eza bat`.

---

## Fedora and Fedora-based

```sh
sudo dnf install niri kitty noctalia xwayland-satellite polkit-gnome \
  playerctl brightnessctl wl-clipboard fontconfig adwaita-icon-theme \
  breeze-icon-theme pipewire wireplumber NetworkManager bluez \
  xdg-desktop-portal xdg-desktop-portal-gtk mesa starship fastfetch
```

Nobara, RHEL, CentOS Stream, Rocky and Alma are treated as the same family. On
older RHEL-family systems some of these are only in EPEL; enable it first if
the install fails.

---

## Debian, Ubuntu and derivatives

Debian and Ubuntu package Niri and the surrounding tools in newer releases, but
Noctalia is **not** in the Debian archive. Add the official Noctalia APT
repository first:

<https://docs.noctalia.dev/noctalia/getting-started/installation/>

Then install the rest:

```sh
sudo apt-get update
sudo apt-get install niri kitty xwayland-satellite lxqt-policykit \
  playerctl brightnessctl wl-clipboard fontconfig adwaita-icon-theme \
  breeze-icon-theme pipewire wireplumber network-manager bluez \
  xdg-desktop-portal xdg-desktop-portal-gtk mesa-utils starship fastfetch
```

If your release does not have `niri` yet, the installer will say so. You can
still install the dotfiles with `./install.sh --no-packages` once Niri is
available.

---

## openSUSE

```sh
sudo zypper install niri kitty noctalia xwayland-satellite polkit-gnome \
  playerctl brightnessctl wl-clipboard fontconfig adwaita-icon-theme \
  breeze5-icons pipewire wireplumber NetworkManager bluez \
  xdg-desktop-portal xdg-desktop-portal-gtk Mesa starship fastfetch
```

Tumbleweed moves faster than Leap. On Leap, check the Niri version with
`niri --version`; blur is stripped automatically below 26.04.

---

## Void Linux

```sh
sudo xbps-install -S niri kitty noctalia xwayland-satellite polkit-gnome \
  playerctl brightnessctl wl-clipboard fontconfig adwaita-icon-theme \
  breeze-icons pipewire wireplumber NetworkManager bluez \
  xdg-desktop-portal xdg-desktop-portal-gtk Mesa starship fastfetch
```

Some packages live in `void-repo-nonfree` or `void-repo-multilib`. Enable the
repositories with `xbps-install -S void-repo-nonfree` if a package is missing.

---

## Alpine and Chimera

Alpine is musl, and most prebuilt Wayland tooling works, but a few upstreams
ship only glibc binaries. The bundled `oniri` binary is glibc and will be
skipped there.

```sh
sudo apk add niri kitty xwayland-satellite polkit-gnome \
  playerctl brightnessctl wl-clipboard fontconfig adwaita-icon-theme \
  breeze-icons pipewire wireplumber networkmanager bluez \
  xdg-desktop-portal xdg-desktop-portal-gtk mesa starship fastfetch \
  gtk+3.0
```

Niri and Noctalia may be in `testing`. If they are not packaged for your
release, install the dotfiles with `--no-packages` and build them yourself.

---

## Gentoo and Funtoo

Gentoo uses category/package atoms:

| Feature | Atom |
|---|---|
| Niri | `gui-wm/niri` |
| Kitty | `x11-terms/kitty` |
| Xwayland satellite | `gui-apps/xwayland-satellite` |
| Policy agent | `gnome-extra/polkit-gnome` |
| Playerctl | `media-sound/playerctl` |
| Brightness | `app-misc/brightnessctl` |
| Clipboard | `gui-apps/wl-clipboard` |
| Fontconfig | `media-libs/fontconfig` |
| GTK 3 | `x11-libs/gtk+:3` |
| Adwaita icons | `x11-themes/adwaita-icon-theme` |
| Breeze icons | `kde-frameworks/breeze-icons` |
| PipeWire | `media-video/pipewire` |
| WirePlumber | `media-video/wireplumber` |
| NetworkManager | `net-misc/networkmanager` |
| BlueZ | `net-wireless/bluez` |
| Portals | `sys-apps/xdg-desktop-portal`, `gui-libs/xdg-desktop-portal-gtk` |
| Mesa | `media-libs/mesa` |
| Starship | `app-shells/starship` |
| Fastfetch | `app-misc/fastfetch` |

Noctalia is not in the Gentoo tree. Build it from source or use a binary
release, then run `./install.sh --no-packages`.

The installer uses `portageq` when available, so already-installed atoms are
detected without merging anything.

---

## Solus

```sh
sudo eopkg install niri kitty noctalia xwayland-satellite polkit-gnome \
  playerctl brightnessctl wl-clipboard fontconfig adwaita-icon-theme \
  breeze-icons pipewire wireplumber networkmanager bluez \
  xdg-desktop-portal xdg-desktop-portal-gtk mesa starship fastfetch \
  libgtk-3
```

---

## NixOS

craft-rice writes plain files under `$HOME`. That works, but it fights with
Home Manager, which is how most NixOS users manage Niri and Noctalia.

The installer warns and asks before continuing. Use `--force` only if you are
sure those paths are not declared in your Nix configuration.

```sh
./install.sh --force --no-packages
```

Package installation is skipped on NixOS. Add the packages to your
`configuration.nix` or `home.nix` instead.

---

## Unknown distributions

If `/etc/os-release` does not match any known family:

- package scan still runs,
- features with no known package name are reported as manual,
- no package manager is called,
- the dotfiles install normally.

That is a supported outcome, not an error. Once the dependencies exist,
`craft-rice doctor` confirms everything.

---

## Manual package checklist

If you install packages yourself, these are the required features:

```
niri kitty noctalia xwayland-satellite polkit-agent playerctl
brightnessctl wl-clipboard fontconfig gtk3 adwaita-icons breeze-icons
pipewire wireplumber networkmanager bluez xdg-portal xdg-portal-gtk mesa
starship fastfetch
```

Plus your chosen shell (`fish`, `zsh` or `bash`).

Optional, used by the config when present:

```
grim slurp btop zoxide fzf eza bat
```

Then run:

```sh
./install.sh --no-packages
craft-rice doctor
```
