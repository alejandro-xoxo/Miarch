# Tarea para agy: aplicaciones Electron/Chromium borrosas (pixeladas)

Problema real: apps como ChatGPT/Codex App (`chatgpt`), Claude Desktop, Antigravity, Hermes Desktop y VS Code se ven pixeladas o borrosas en el escritorio de este usuario (Arch + Hyprland, pantalla con escala configurable en la variable ESCALA de `config/hypr/hyprland.lua`). Casi seguro corren por XWayland o con la escala mal aplicada. Objetivo: que se vean nítidas, nativas en Wayland.

## Reglas del proyecto (obligatorias)
- GitFlow: rama `fix/electron-nitido` desde `develop`, commits pequeños con Conventional Commits en inglés, fusión `--no-ff` en `develop`, `git push origin develop`. Nada de `--force`. NO hagas release, ni etiquetas, ni toques `main`.
- NUNCA pongas marcas de IA en commits (ni `Co-Authored-By`, ni "Generated with", ni mencionar herramientas de IA). El commit debe parecer escrito por el usuario.
- Entrada nueva en español al principio de `NOVEDADES.md` (`## AAAA-MM-DD.NN · Título`, NN sube, 1-3 líneas).
- No captures la pantalla del usuario y no abras ventanas de apps solo para probar.
- No instales ni quites paquetes.

## Pasos
1. Diagnóstico con datos reales: ejecuta `hyprctl clients -j` y lista, por ventana abierta, `class`, `xwayland` (true/false) y `pid`. Mira `hyprctl monitors -j` (campo `scale`). Anota qué apps abiertas son XWayland.
2. Mira `config/hypr/hyprland.lua`: variables de entorno ya definidas (busca `hl.env`), bloque `xwayland`, escala. Y lee `config/chrome/chrome-flags.conf` y cómo lo instala `install.sh`.
3. Averigua cómo lee cada app sus flags, mirando los archivos instalados en el sistema (por ejemplo `cat /usr/bin/chatgpt`, `cat /usr/bin/claude-desktop`, `cat /usr/bin/antigravity`, `cat /usr/bin/code`, los `.desktop` en `/usr/share/applications`) y busca si leen `~/.config/<nombre>-flags.conf`, `~/.config/electron-flags.conf` o variables como `ELECTRON_OZONE_PLATFORM_HINT`. No inventes: solo usa lo que veas en esos archivos.
4. Aplica la solución en el REPOSITORIO (no solo en el sistema), de forma que `install.sh` la despliegue:
   - En `hyprland.lua`: variable de entorno `ELECTRON_OZONE_PLATFORM_HINT=wayland` (con `hl.env`, como las otras si existen) para que Electron use Wayland nativo.
   - En el bloque `xwayland` de Hyprland: `force_zero_scaling = true` si la sintaxis del archivo lo permite (comprueba cómo están escritas las demás opciones y copia el estilo). Esto evita el borroso de las apps que sigan en XWayland.
   - Archivos de flags para las apps que sí los lean (según el paso 3) con `--ozone-platform=wayland --enable-features=WaylandWindowDecorations,UseOzonePlatform` y `--enable-wayland-ime` cuando corresponda, en `config/` y copiados por `install.sh` con el mismo mecanismo que `chrome-flags.conf` (con copia de seguridad, sin pisar nada que el usuario haya cambiado a mano sin avisar).
5. Verifica sin abrir ventanas: `hyprctl reload` y `hyprctl configerrors` deben dar vacío; `bash -n install.sh`; prueba `install.sh` en un HOME temporal (`HOME=$(mktemp -d)`) con `hyprctl`, `awww`, `nvim`, `gsettings`, `kwriteconfig6` simulados por scripts que hagan `exit 0`, y comprueba que los archivos nuevos quedan en su sitio.
6. Documenta en `docs/escritorio.md` (sección corta "Apps Electron nítidas") y añade la entrada en `NOVEDADES.md`.
7. Di al final, en pocas líneas: qué apps eran XWayland, qué cambiaste, y que el usuario debe cerrar y volver a abrir esas apps (o reiniciar sesión) para ver el efecto.
