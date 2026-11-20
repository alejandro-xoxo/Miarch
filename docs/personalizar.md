# Personalizar Miarch a tu gusto

Miarch se actualiza con la nube de la barra, y una actualización reemplaza sus archivos. Para que tus cambios **no se pierdan**, hay un sitio solo tuyo:

```
~/.config/miarch/personal/
├── hyprland.lua   atajos, reglas de ventanas y variables de Hyprland
├── kitty.conf     la terminal (tipografía, transparencia…)
└── zshrc          alias y variables de Zsh
```

`install.sh` crea esos archivos con ejemplos comentados la primera vez y **nunca los pisa**. Escribe ahí lo tuyo; el resto de Miarch no hay que tocarlo.

## Qué se cambia dónde
| Quieres cambiar | Dónde |
|---|---|
| Animaciones, desenfoque, escala, teclado, ratón, cursor, tamaño de texto, contraste, fondos animados, perfil de energía | El panel de **Ajustes** (`Super + Esc`), o `miarch-set`. Se conservan al actualizar |
| Un atajo nuevo o una regla de ventana | `personal/hyprland.lua` (usa `SUPER` tal cual) y `hyprctl reload` |
| La terminal | `personal/kitty.conf` |
| Alias o variables del shell | `personal/zshrc` |
| Colores del sistema | Cambia el fondo (`Super + W`): los colores salen de él |
| Más programas | Añádelos a `packages.sh` (y a `docs/paquetes/`) |

Si algo falla, `hyprctl configerrors` dice la línea del error de Hyprland. Un error en `personal/hyprland.lua` no rompe el resto de la configuración.

## Ejemplos
```lua
-- personal/hyprland.lua
hl.bind("SUPER + G", hl.dsp.exec_cmd("steam"))                                   -- Super+G abre Steam
hl.window_rule({ name = "mpv-flotante", match = { class = "^mpv$" }, float = true })
```
```
# personal/kitty.conf
font_size 13
```
