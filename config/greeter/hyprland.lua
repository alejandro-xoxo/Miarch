-- SPDX-License-Identifier: GPL-3.0-or-later
-- Miarch · Hyprland mínimo, SOLO para la pantalla de inicio de sesión (greetd).
-- Arranca Quickshell con el greeter y, cuando este termina, cierra Hyprland para que greetd abra tu sesión.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.config({
    general    = { gaps_in = 0, gaps_out = 0, border_size = 0 },
    decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } },
    animations = { enabled = false },
    misc       = { disable_hyprland_logo = true, force_default_wallpaper = 0 },
    input      = { kb_layout = "__KB__" },
})

hl.env("XCURSOR_SIZE", "24")

hl.on("hyprland.start", function ()
    hl.exec_cmd("sh -c 'qs -p /usr/share/miarch/greeter; hyprctl dispatch \"hl.dsp.exit()\"'")
end)
