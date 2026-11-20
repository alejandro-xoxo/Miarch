# Map of a Miarch system

Miarch is Arch Linux + Hyprland with its own desktop written in Quickshell (QML). The repository (`~/Miarch`) is installed into `$HOME` by `install.sh`; the same repository updates it through `miarch-update` (the cloud icon in the bar).

## Where things live
| Thing | In the repo | Installed to |
|---|---|---|
| Hyprland (Lua) | `config/hypr/hyprland.lua` | `~/.config/hypr/` |
| Desktop: bar, launcher, lock, settings panel, power menu | `config/quickshell/miarch/shell.qml` | `~/.config/quickshell/miarch/` |
| Terminal | `config/kitty/kitty.conf` | `~/.config/kitty/` |
| Shell | `home/.zshrc` | `~/.zshrc` |
| Neovim / Chrome flags / VS Code font | `config/nvim`, `config/chrome`, `config/vscode` | `~/.config/...` |
| Tools | `scripts/*` | `~/.local/bin/` |
| Packages | `packages.sh` (arrays `PAQUETES`, `JUEGOS`, `AUR_PAQUETES`) | installed by `packages.sh` |
| Install / update UI | `setup.sh`, `install.sh`, `lib/ui.sh` | run from the repo |
| What changed, in Spanish | `NOVEDADES.md` | shown by `miarch-update` |
| Docs | `docs/` (`paquetes/` lists must match `packages.sh`) | |

## What survives an update, and what does not
- **Survives:** everything in `~/.config/miarch/personal/` (`hyprland.lua`, `kitty.conf`, `zshrc`, created with commented examples by `install.sh` and never overwritten), the values set from the Ajustes panel or `miarch-set`, and `~/.config/miarch/ajustes.json`.
- **Replaced:** any edit made directly in the installed copies of files that come from the repo (`hyprland.lua`, `shell.qml`, `kitty.conf`, `.zshrc`). The old version is kept as `NAME.bak-DATE` (the two most recent). So personal taste goes in the personal folder, not in those files.
- The three personal files are loaded at the end of the managed ones (Hyprland `dofile`, kitty `include`, zsh `source`). In `personal/hyprland.lua` write `"SUPER"` literally (the managed file's `mainMod` variable is not visible there). An error in it shows in `hyprctl configerrors` and does not break the rest.

## Knobs (all reversible, applied with `miarch-set KEY VALUE` or the Ajustes panel, `Super + Esc`)
| Key | Valid values | Effect |
|---|---|---|
| `anim` | `slide zoom suave elastico original` | window animation style |
| `blur` | `ninguno suave medio fuerte extremo` | background blur strength |
| `escala` | `auto 1 1.25 1.5 2` | screen scale |
| `teclado` | `latam us es` | keyboard layout |
| `scrollnat` | `on off` | natural touchpad scrolling |
| `tap` | `on off` | tap to click |
| `sens` | `-0.5 -0.25 0 0.25 0.5` | pointer speed |
| `cursor` | `24 32 40 48` | cursor size |
| `movimiento` | `on off` | animations on or off (accessibility) |
| `barra` | `ninguna fundido deslizar rebote` | bar entrance animation |
| `texto` | `1 1.15 1.3 1.5` | text size of the desktop |
| `contraste` | `on off` | high contrast |
| `gif` | `on off` | animated wallpapers (off = still image, lighter) |
| `perfil` | `power-saver balanced performance` | power profile |

Other commands: `wallpaper.sh [file]` or `Super + W` (changes the wallpaper and the whole color palette, derived from it), `miarch-update [--forzar]`, `miarch-chrome-tema`, `miarch-steam`, `miarch-modo-juego`, `packages.sh --faltantes` (which declared packages are missing here). Shortcuts: `Super + Shift + Esc`, tab "Atajos", lists them all.

## Project rules to follow when changing the repository
- GitFlow: branch `feat/*` or `fix/*` from `develop`, small commits, merge with `--no-ff`. Conventional Commits, subject up to about 50 characters, no AI attribution lines. Never `--force` unless the user asked for that exact thing.
- Releases (merge to `main` plus a tag) only for big milestones or when the user asks, not per change.
- A change the user will notice gets a short Spanish entry at the top of `NOVEDADES.md` (`## YYYY-MM-DD.NN · Title`, then one or two lines).
- Palette is matte (no neon); the browser is Chrome only; replies to the user are short.
- Never touch the user's open windows or capture their screen while testing: use an empty workspace and crop screenshots to your own window.
