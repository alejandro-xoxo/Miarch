# Paquetes que instala Miarch

El script `packages.sh` instala todo lo siguiente (se puede ejecutar varias veces). Cada archivo lista sus paquetes con el origen (pacman o AUR) y para qué sirven:

| Módulo | Contenido |
|---|---|
| [escritorio](escritorio.md) | Hyprland, portales, fondos, notificaciones, capturas, Quickshell |
| [sistema](sistema.md) | Gráficos, audio, Wi‑Fi, Bluetooth, energía, fuentes |
| [terminal](terminal.md) | kitty, zsh, neovim, eza, fastfetch, btop, Python |
| [desarrollo](desarrollo.md) | Git, Java, Node, Docker, Ollama, bases de datos y las CLI de IA |
| [aplicaciones](aplicaciones.md) | Dolphin, Spotify, Chrome, VS Code, Claude Desktop |

Además, `packages.sh` clona **Oh My Zsh** y sus plugins ([zsh](../zsh.md)), instala `yay` (ayudante de AUR) y activa los [servicios](../servicios.md).
