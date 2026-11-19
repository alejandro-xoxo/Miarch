#!/usr/bin/env bash
# Miarch · instala los paquetes (pacman + AUR) y activa los servicios. Se puede ejecutar varias veces.
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "❌ No ejecutes este script como root. Usa tu usuario normal (se pedirá sudo)."
    exit 1
fi

echo "🚀 Instalando paquetes de Miarch..."

# =========================
# PAQUETES OFICIALES (pacman: repositorios firmados de Arch)
# =========================
PAQUETES=(
    # Escritorio (Hyprland + utilidades; la barra, el lanzador y los paneles son Quickshell)
    hyprland xdg-desktop-portal-hyprland polkit
    awww                      # fondos animados (antes se llamaba swww)
    dunst                     # notificaciones
    rofi                      # lanzador de respaldo (Super+Shift+Espacio)
    grim slurp wl-clipboard   # capturas y portapapeles
    brightnessctl playerctl xdg-user-dirs

    # Gráficos y audio
    mesa intel-media-driver pipewire pipewire-pulse wireplumber

    # Red, Bluetooth y energía
    iwd bluez bluez-utils power-profiles-daemon
    pacman-contrib            # checkupdates (contador de actualizaciones de la barra)

    # Fuentes
    ttf-jetbrains-mono-nerd   # incluye los íconos de la barra
    noto-fonts-emoji noto-fonts   # emojis y letras de respaldo (sin esto los emojis no se ven)

    # Terminal y herramientas
    kitty zsh neovim eza fastfetch btop
    python python-pillow      # scripts de Miarch (colores del wallpaper, Wi-Fi, información)
    qt6-imageformats          # imágenes webp en Quickshell

    # Desarrollo
    git github-cli curl base-devel
    dbeaver jdk21-openjdk nodejs-lts-jod npm
    docker docker-compose docker-buildx   # contenedores
    ollama                                # modelos de IA locales (CPU; ollama-vulkan es la variante para GPU)
    openai-codex

    # Aplicaciones
    dolphin qt6ct breeze-icons   # gestor de archivos + tema de Qt (qt6ct) e íconos
    spotify-launcher
)
echo "📦 Actualizando el sistema e instalando paquetes oficiales..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm --needed "${PAQUETES[@]}"

# =========================
# DOCKER Y OLLAMA
# =========================
configurar_docker_ollama() {
    echo "🐳 Configurando Docker y Ollama..."

    # Las imágenes de Docker y los modelos de Ollama pesan muchos GB. Si la raíz (/) es pequeña y /home es
    # otra partición, se guardan en /home. Solo se hace si todavía no hay datos (antes del primer arranque).
    local raiz_gb datos
    raiz_gb="$(df -BG --output=size / | tail -1 | tr -dc '0-9')"
    datos="/home/.datos-pesados"
    if [ "${raiz_gb:-0}" -lt 100 ] && [ "$(findmnt -n -o SOURCE --target /home)" != "$(findmnt -n -o SOURCE --target /)" ]; then
        echo "💾 La raíz tiene ${raiz_gb} GB: Docker y Ollama guardarán sus datos en $datos (partición /home)."
        sudo install -d -m 755 "$datos"
        if [ ! -s /etc/docker/daemon.json ] && [ -z "$(ls -A /var/lib/docker 2>/dev/null)" ]; then
            sudo install -d -m 711 "$datos/docker"
            printf '{\n  "data-root": "%s/docker"\n}\n' "$datos" | sudo tee /etc/docker/daemon.json >/dev/null
        else
            echo "ℹ️  Docker ya tiene datos o configuración: no se mueve su carpeta."
        fi
        if getent passwd ollama >/dev/null; then
            sudo install -d -o ollama -g ollama -m 755 "$datos/ollama"
            sudo install -d /etc/systemd/system/ollama.service.d
            printf '[Service]\nEnvironment="OLLAMA_MODELS=%s/ollama"\n' "$datos" \
                | sudo tee /etc/systemd/system/ollama.service.d/miarch-modelos.conf >/dev/null
            sudo systemctl daemon-reload
        else
            echo "ℹ️  No se encontró el usuario 'ollama': los modelos quedarán en la ubicación por defecto."
        fi
    fi

    # Docker arranca por socket (solo cuando lo usas, no gasta memoria al encender); Ollama queda activo.
    sudo systemctl enable --now docker.socket ollama.service \
        || echo "⚠️  No se pudo activar docker o ollama (revisa: systemctl status docker.socket ollama)"

    # Estar en el grupo docker equivale a tener acceso de administrador (root) sobre el equipo.
    # Se añade tu usuario para usar docker sin sudo; si prefieres no hacerlo, quita estas líneas.
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
        sudo usermod -aG docker "$USER"
        echo "ℹ️  Entraste al grupo docker: cierra sesión y vuelve a entrar para usarlo sin sudo."
    fi
}

# =========================
# SERVICIOS
# =========================
echo "⚙️  Activando servicios (Wi-Fi, Bluetooth, modos de energía)..."
sudo systemctl enable --now iwd.service bluetooth.service power-profiles-daemon.service \
    || echo "⚠️  No se pudo activar algún servicio (revisa: systemctl status iwd bluetooth power-profiles-daemon)"
configurar_docker_ollama

# =========================
# ZSH + OH MY ZSH (se clona el repositorio; NO se ejecuta ningún script descargado)
# =========================
echo "🐚 Configurando Zsh y Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    sudo chsh -s /usr/bin/zsh "$USER" || echo "⚠️  No se pudo cambiar el shell predeterminado"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search; do
    if [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]; then
        echo "📥 Plugin: $plugin"
        git clone --depth=1 "https://github.com/zsh-users/$plugin" "$ZSH_CUSTOM/plugins/$plugin" \
            || echo "⚠️  No se pudo clonar $plugin"
    else
        echo "✅ Plugin $plugin ya instalado"
    fi
done

# =========================
# AUR (paquetes de la comunidad: no están firmados por Arch)
# =========================
if ! command -v yay &>/dev/null; then
    echo "🔧 Instalando yay (ayudante de AUR)..."
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

# Nota de seguridad: --noconfirm instala sin que veas el PKGBUILD de cada paquete.
# Si prefieres revisarlos, quita --noconfirm (yay te los mostrará uno por uno).
echo "📥 Instalando paquetes de AUR (uno por uno: si uno falla, los demás siguen)..."
AUR_PAQUETES=(
    quickshell-git
    google-chrome
    visual-studio-code-bin
    claude-code
    claude-desktop
    antigravity-cli
    hermes-webui-desktop-bin     # ventana de escritorio de Hermes WebUI (necesita un servidor hermes-webui local o remoto)
)
AUR_FALLIDOS=()
for paquete in "${AUR_PAQUETES[@]}"; do
    echo "   → $paquete"
    yay -S --noconfirm --needed "$paquete" || AUR_FALLIDOS+=("$paquete")
done
if [ "${#AUR_FALLIDOS[@]}" -gt 0 ]; then
    echo ""
    echo "⚠️  No se pudieron instalar estos paquetes de AUR: ${AUR_FALLIDOS[*]}"
    echo "   Reintenta uno con:  yay -S ${AUR_FALLIDOS[0]}   (te mostrará el error completo)"
    echo ""
fi

# =========================
# JAVA 21 POR DEFECTO
# =========================
echo "☕ Dejando Java 21 como versión por defecto..."
sudo archlinux-java set java-21-openjdk || echo "⚠️  No se pudo fijar Java 21 (revisa: archlinux-java status)"

echo ""
if [ "${#AUR_FALLIDOS[@]}" -gt 0 ]; then
    echo "⚠️  Paquetes instalados, salvo los de AUR que fallaron (arriba)."
else
    echo "✅ ¡Paquetes instalados!"
fi
echo "   Siguiente paso:  ./install.sh"
echo ""
echo "   La primera vez, inicia sesión en cada herramienta:"
echo "     claude   |   codex   |   agy   |   gh auth login"
echo ""
echo "   Docker: cierra sesión y vuelve a entrar para usarlo sin sudo.  Ollama: ollama pull llama3.2"
