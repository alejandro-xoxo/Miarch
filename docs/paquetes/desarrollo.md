# Paquetes · Desarrollo e IA

| Paquete | Origen | Para qué sirve |
|---|---|---|
| `git` · `github-cli` | pacman | Git y `gh` |
| `curl` · `base-devel` | pacman | Descargas y compiladores (necesarios para AUR) |
| `jdk21-openjdk` | pacman | Java 21, fijado como versión por defecto |
| `nodejs-lts-jod` · `npm` | pacman | Node.js (LTS) |
| `dbeaver` | pacman | Cliente de bases de datos |
| `docker` · `docker-compose` · `docker-buildx` | pacman | Contenedores |
| `ollama` | pacman | Modelos de IA locales (CPU; `ollama-vulkan` es la variante para GPU) |
| `openai-codex` | pacman | CLI de Codex |
| `claude-code` | AUR | CLI de Claude Code |
| `alpaka-desktop-bin` | AUR | App de escritorio para Ollama (Tauri, ligera) |
| `antigravity-cli` | AUR | CLI de Antigravity (`agy`) |

## Detalles

- **Grupo `docker`:** el script añade tu usuario para usar Docker sin `sudo`. Estar en ese grupo equivale a ser administrador del equipo. Cierra sesión y vuelve a entrar. Si no lo quieres, quita esas líneas de `packages.sh`.
- **Espacio en disco:** las imágenes de Docker y los modelos de Ollama pesan muchos GB. Si tu raíz (`/`) tiene menos de 100 GB y `/home` es otra partición, sus datos van a `/home/.datos-pesados`, **solo si todavía no tienen datos**. Si ya usabas Docker, no se mueve nada.
- **Ollama:** `ollama pull llama3.2` descarga un modelo.
- **Hermes Desktop:** la app oficial de Nous Research no está en AUR: `packages.sh` ejecuta su script oficial (`--include-desktop`, instala en `~/.hermes` y compila la app, tarda) solo si Hermes no está instalado. Miarch ya no instala `hermes-webui-desktop-bin` (era solo una ventana de un servidor WebUI) y lo quita al actualizar.
- **Primer inicio de sesión:** `claude`, `codex`, `agy` y `gh auth login`.
