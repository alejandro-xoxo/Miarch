# Estructura del repositorio

| Ruta | Qué es |
|---|---|
| `setup.sh` | Instalación completa en un paso |
| `NOVEDADES.md` | Lo que trae cada novedad, en español: la ventana de actualización muestra las que aún no has visto |
| `packages.sh` | Paquetes (pacman y AUR), servicios, Oh My Zsh |
| `install.sh` | Copia configuraciones y scripts a tu `$HOME` |
| `config/hypr/` | Hyprland (Lua) |
| `config/quickshell/miarch/` | El escritorio: `shell.qml` |
| `config/greeter/` | Pantalla de inicio de sesión |
| `config/kitty/` · `config/nvim/` · `config/chrome/` | Terminal, Neovim, Chrome |
| `config/waybar/` | Tema anterior (respaldo) |
| `home/.zshrc` | Configuración de zsh |
| `skills/instalar-configurar/` | Skill para agentes de IA (Claude Code): cómo instalar y configurar cosas en este sistema de la mejor forma. `install.sh` la copia a `~/.claude/skills/` si el agente existe |
| `skills/instalar-configurar/` | Skill para agentes de IA (Claude Code, Codex, Antigravity…): cómo instalar y configurar cosas en este sistema de la mejor forma. `install.sh` la copia a la carpeta de skills de cada agente que tengas |
| `AGENTS.md` | Instrucciones para cualquier agente de IA que trabaje dentro del repositorio (`CLAUDE.md` lo importa) |
| `config/dunst/` | Notificaciones (dunst): forma y tamaño. Los colores los genera `miarch-colors` desde el fondo de pantalla |
| `lib/ui.sh` | Barra de progreso y animación de los scripts de instalación |
| `scripts/` | Herramientas ([lista](scripts.md)) |
| `wallpapers/` | Fondos |
| `docs/` | Esta documentación y las capturas (`docs/screenshots/`) |
