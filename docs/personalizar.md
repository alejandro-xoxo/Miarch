# Personalizar Miarch a tu gusto

Miarch se actualiza con la nube de la barra, y una actualización reemplaza sus archivos. Para que tus cambios **no se pierdan**, hay un sitio solo tuyo:

```
~/.config/miarch/personal/
├── hyprland.lua   atajos, reglas de ventanas y variables de Hyprland
├── kitty.conf     la terminal (tipografía, transparencia…)
└── zshrc          alias y variables de Zsh
```

`install.sh` crea esos archivos con ejemplos comentados la primera vez y **nunca los pisa**. Escribe ahí lo tuyo; el resto de Miarch no hay que tocarlo.

## Con ayuda de un agente de IA
Si usas un agente como Claude Code, `install.sh` le instala la skill **`instalar-configurar`** (está en `skills/instalar-configurar/`). Con ella, cuando le pidas "instala X", "configura Y" u "optimiza mi sistema", el agente busca la forma mejor y más ligera de hacerlo en Linux (un ajuste que ya existe, el paquete oficial, AUR o Flatpak, midiendo cuando importa el consumo), te pide permiso antes de `sudo`, deja el cambio en la carpeta personal o en `packages.sh` para que sobreviva a las actualizaciones, y comprueba que funciona. Es una copia gestionada por Miarch: se refresca al actualizar, así que no la edites en `~/.claude/skills/`.

## Con ayuda de un agente de IA
Si usas un agente (Claude Code, Codex, Antigravity…), `install.sh` le instala la skill **`instalar-configurar`** (está en `skills/instalar-configurar/`, en el formato abierto de skills, así que sirve igual en todos). Con ella, cuando le pidas "instala X", "configura Y" u "optimiza mi sistema", el agente busca la forma mejor y más ligera de hacerlo en Linux (un ajuste que ya existe, el paquete oficial, AUR o Flatpak, midiendo cuando importa el consumo), te pide permiso antes de `sudo`, deja el cambio en la carpeta personal o en `packages.sh` para que sobreviva a las actualizaciones, y comprueba que funciona.

| Agente | Carpeta donde se instala |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Antigravity (`agy`) | `~/.gemini/config/skills/` |

Es una copia gestionada por Miarch: se refresca al actualizar, así que no la edites ahí. Para cualquier otro agente, `AGENTS.md` (en la raíz del repositorio) le da las mismas indicaciones si trabaja dentro de `~/Miarch`.

## Qué se cambia dónde
| Quieres cambiar | Dónde |
|---|---|
| Animaciones, desenfoque, escala, teclado, ratón, cursor, tamaño de texto, contraste, fondos animados, perfil de energía | El panel de **Ajustes** (`Super + Esc`), o `miarch-set`. Se conservan al actualizar |
| Un atajo nuevo o una regla de ventana | `personal/hyprland.lua` (usa `SUPER` tal cual) y `hyprctl reload` |
| La terminal | `personal/kitty.conf` |
| Alias o variables del shell | `personal/zshrc` |
| Colores del sistema | Cambia el fondo (`Super + W`): los colores salen de él |
| Más programas | Añádelos a `packages.sh` (y a `docs/paquetes/`) |
| Icono de Crunchyroll | `~/.config/miarch/personal/crunchyroll.png` (o `.svg`, `.jpg`, `.webp`): imagen propia para el icono de Crunchyroll; se aplica al ejecutar `install.sh` o al actualizar. Puedes usar la imagen que quieras (se queda en tu equipo, no se sube al repositorio) |

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

## Cosas que puedes apagar
| Archivo | Efecto |
|---|---|
| `~/.config/miarch/sin-greeter` | Miarch no instala ni actualiza la pantalla de inicio de sesión gráfica; entras por la terminal. Se crea con `mkdir -p ~/.config/miarch && touch ~/.config/miarch/sin-greeter`. |
| `~/.config/miarch/sin-juegos` | Miarch no instala Steam, controladores Vulkan de 32 bits, multilib ni herramientas de juego (GameMode, MangoHud, Gamescope). En una instalación interactiva, `setup.sh` pregunta si quieres instalarlos; también se crea con `mkdir -p ~/.config/miarch && touch ~/.config/miarch/sin-juegos`. |
