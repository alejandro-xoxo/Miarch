# Recipes for common requests

Each recipe follows the workflow: look first, choose the best way, ask before anything risky, put it where it lasts, verify. Run `scripts/check.sh` after config changes.

## Install a program
1. `pacman -Qi NAME` (already there?), `pacman -Si NAME` (official?). If not official, read `references/choose-the-best-way.md` (AUR, Flatpak...).
2. Ask before `sudo`; then `sudo pacman -S --needed NAME`.
3. On Miarch make it reproducible: add it to the right array in `packages.sh` (`PAQUETES`, or `AUR_PAQUETES`) and a row to the matching file in `docs/paquetes/`; check with `packages.sh --faltantes`.
4. Launch it (on an empty workspace) to confirm it opens. Tell the user how to remove it: `sudo pacman -Rns NAME` plus the line you added.

## Add a keyboard shortcut
In `~/.config/miarch/personal/hyprland.lua`:
```lua
hl.bind("SUPER + G", hl.dsp.exec_cmd("steam"))
```
Then `hyprctl reload` and `hyprctl configerrors`. Check the key is free first (`hyprctl binds -j`; Miarch's own list is in the "Atajos" tab of `Super + Shift + Esc`).

## Make a program open floating, or set other window rules
Find its class: `hyprctl clients -j` (field `class`). In the personal file:
```lua
hl.window_rule({ name = "mpv-flotante", match = { class = "^mpv$" }, float = true })
```

## Start a program at login
In the personal file (copied from the managed config; takes effect at the next login):
```lua
hl.on("hyprland.start", function ()
    hl.exec_cmd("discord")
end)
```

## Terminal look
`~/.config/miarch/personal/kitty.conf`, for example `font_size 13` or `background_opacity 0.9`. New windows pick it up. Colors come from the wallpaper; do not hard-code them unless the user wants a fixed scheme.

## Shell aliases and variables
`~/.config/miarch/personal/zshrc`, for example `alias gs="git status"`. Open a new terminal to apply.

## "Make it faster / lighter"
1. Find what costs resources (`ps -eo pcpu,rss,comm --sort=-pcpu | head`).
2. Cheap, reversible visual wins: `miarch-set anim original`, `miarch-set blur suave` or `ninguno`, `miarch-set gif off`, `miarch-set movimiento off`.
3. Power: `miarch-set perfil performance` (plugged in) or `power-saver` (battery).
4. Offer two presets and what each trades away; apply the one the user picks; give the undo.
5. If a specific app is the cause, consider a lighter alternative and measure (see `choose-the-best-way.md`).

## "Change how it looks"
Colors: change the wallpaper (`Super + W` or `wallpaper.sh FILE`); the palette follows. Text size, contrast, cursor, scale and animations are knobs in the table of `references/miarch.md`. Anything beyond that means editing `shell.qml` in the repository: do it on a branch, keep it small, and tell the user such edits are replaced by updates unless they are committed to their own branch.

## Games
Steam and its tools are installed by `packages.sh`; guide, launch options and integrated-graphics tips are in `docs/juegos.md`. For weak GPUs prefer `gamescope -w 1280 -h 720 -W 1920 -H 1080 -F fsr -f -- gamemoderun %command%` as a launch option, and keep the machine plugged in.

## Remove something
Ask first. `sudo pacman -Rns NAME` (and its AUR leftovers), remove it from `packages.sh` and `docs/paquetes/`, and check nothing else depends on it (`pacman -Qi NAME` "Required By").

## On a system that is not Miarch
Keep the same shape: look first, choose by the ladder, ask before `sudo`, record what you changed in a script or note so it can be redone, verify, and report what you could not test. Use the distro's own package manager and its wiki instead of the Miarch-specific paths.
