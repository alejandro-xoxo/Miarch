#!/usr/bin/env bash
# Miarch · instala los paquetes (pacman + AUR) y activa los servicios. Se puede ejecutar varias veces.
set -euo pipefail
set -E
trap 'echo "[ERROR] El script se detuvo en la línea $LINENO: $BASH_COMMAND" >&2' ERR   # dice dónde falló, nunca se detiene en silencio

if [ "$EUID" -eq 0 ]; then
    echo "[ERROR] No ejecutes este script como root. Usa tu usuario normal (se pedirá sudo)."
    exit 1
fi

USER="${USER:-$(id -un)}"; export USER   # en una terminal mínima puede venir vacío y con set -u el script se detendría

# barra de progreso total y animación mientras trabaja cada comando
source "$(dirname "${BASH_SOURCE[0]}")/lib/ui.sh"

# =========================
# PAQUETES OFICIALES (pacman: repositorios firmados de Arch)
# =========================
PAQUETES=(
    # Escritorio (Hyprland + utilidades; la barra, el lanzador y los paneles son Quickshell)
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit   # el portal gtk avisa a Chrome y a las apps de que el sistema es oscuro
    awww                      # fondos animados (antes se llamaba swww)
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
# AUR (paquetes de la comunidad: no están firmados por Arch)
AUR_PAQUETES=(
    quickshell-git
    google-chrome
    visual-studio-code-bin
    claude-code
    claude-desktop
    antigravity-cli
    antigravity                  # app de escritorio de Antigravity 2.0 (Google; se descarga de sus servidores)
    antigravity-ide              # el IDE de Antigravity (Google; se descarga de sus servidores)
    openai-chatgpt               # app de escritorio de ChatGPT con Codex (vista previa oficial de OpenAI; reempaqueta su .deb, ~350 MB)
    protonup-qt                  # instala y actualiza Proton-GE con clics (mejor compatibilidad de juegos de Windows)
)

# =========================
# JUEGOS: Steam y lo necesario. Steam es de 32 bits, así que necesita el repositorio multilib.
# =========================
gpu_juegos() {   # controladores Vulkan (64 y 32 bits) según la tarjeta gráfica del equipo (Intel, AMD, NVIDIA)
    local f v pk=()
    for f in "${MIARCH_DRM_DIR:-/sys/class/drm}"/card[0-9]*/device/vendor; do
        [ -r "$f" ] || continue
        v="$(cat "$f")"
        case "$v" in
            0x8086) pk+=(vulkan-intel lib32-vulkan-intel) ;;
            0x1002) pk+=(vulkan-radeon lib32-vulkan-radeon) ;;
            0x10de) pk+=(nvidia-utils lib32-nvidia-utils) ;;
        esac
    done
    [ "${#pk[@]}" -gt 0 ] || pk=(vulkan-swrast lib32-vulkan-swrast)   # tarjeta no reconocida (por ejemplo máquina virtual): por software
    printf '%s\n' "${pk[@]}" | sort -u
}
mapfile -t JUEGOS_GPU < <(gpu_juegos)
JUEGOS=(
    steam                                       # Steam (multilib); trae las reglas udev de los mandos
    vulkan-icd-loader lib32-vulkan-icd-loader   # cargador de Vulkan (64 y 32 bits)
    lib32-mesa lib32-pipewire lib32-libpulse    # gráficos y audio de 32 bits para los juegos
    ttf-liberation                              # tipografías que Steam necesita
    gamemode lib32-gamemode                     # sube la prioridad del juego y pone el modo de energía "rendimiento"
    mangohud lib32-mangohud                     # contador de FPS y temperaturas (Shift derecho + F12)
    gamescope                                   # reescalado FSR para tarjetas integradas (ver docs/juegos.md)
    xorg-xwayland                               # los juegos de Steam corren sobre XWayland
    "${JUEGOS_GPU[@]}"                          # controladores Vulkan de TU tarjeta
)

# setup.sh pregunta cuántas etapas tiene este script para dibujar la barra del total
# Paquetes que Miarch instaló antes y ya no usa: se quitan en cada equipo al actualizar (solo si están instalados)
OBSOLETOS=(
    hermes-webui-desktop-bin       # era solo una ventana de un servidor WebUI, no la app oficial de Hermes
    hermes-webui-desktop-appimage
    dunst                          # las notificaciones ahora las dibuja Quickshell; dunst competiría por el servicio
    alpaka-desktop-bin             # cliente de terceros de Ollama: Ollama no tiene app oficial para Linux (solo CLI y servicio)
)
ETAPAS=$(( 9 + ${#AUR_PAQUETES[@]} ))
[ "${1:-}" = "--etapas" ] && { echo "$ETAPAS"; exit 0; }
# miarch-update pregunta qué paquetes de esta lista aún no están instalados (no instala ni cambia nada)
if [ "${1:-}" = "--faltantes" ]; then
    for paquete in "${PAQUETES[@]}" "${JUEGOS[@]}" "${AUR_PAQUETES[@]}"; do pacman -Q "$paquete" >/dev/null 2>&1 || echo "$paquete"; done
    [ -x "$HOME/.local/bin/hermes" ] || command -v hermes >/dev/null 2>&1 || echo "hermes-desktop"
    exit 0
fi
# miarch-update y la nube preguntan qué paquetes obsoletos siguen instalados (no cambia nada)
if [ "${1:-}" = "--sobran" ]; then
    for paquete in "${OBSOLETOS[@]}"; do pacman -Q "$paquete" >/dev/null 2>&1 && echo "$paquete"; done
    exit 0
fi

habilitar_multilib() {
    local conf="${MIARCH_PACMAN_CONF:-/etc/pacman.conf}"             # la variable solo se usa en las pruebas
    grep -q '^\[multilib\]' "$conf" && return 0
    ui_info "Activando el repositorio multilib (paquetes de 32 bits que necesita Steam)"
    sudo cp -n "$conf" "$conf.miarch-bak"                            # copia de seguridad, solo la primera vez
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' "$conf"
    grep -q '^\[multilib\]' "$conf"
}

configurar_juegos() {
    # GameMode necesita que tu usuario esté en el grupo "gamemode" para subir la prioridad del juego
    if getent group gamemode >/dev/null && ! id -nG "$USER" | tr ' ' '\n' | grep -qx gamemode; then
        sudo usermod -aG gamemode "$USER" && ui_info "Entraste al grupo gamemode: cierra sesión y vuelve a entrar para que se aplique."
    fi
    # ntsync: sincronización de hilos del kernel que Proton usa para ir más rápido (kernel 6.14 o más nuevo)
    if modinfo ntsync >/dev/null 2>&1; then
        echo ntsync | sudo tee /etc/modules-load.d/ntsync.conf >/dev/null
        sudo modprobe ntsync 2>/dev/null || true
        [ -e /dev/ntsync ] && ui_ok "ntsync activo (Proton sincroniza más rápido)"
    fi
    # Memoria comprimida (zram) si el equipo no tiene ningún swap: evita cierres bruscos de juegos grandes
    if [ -z "$(swapon --noheadings 2>/dev/null)" ]; then
        ui_info "El equipo no tiene swap: se activa zram (memoria comprimida)"
        sudo pacman -S --needed --noconfirm zram-generator >/dev/null 2>&1 || true
        if [ ! -f /etc/systemd/zram-generator.conf ]; then
            printf '[zram0]\nzram-size = min(ram / 2, 4096)\ncompression-algorithm = zstd\n' | sudo tee /etc/systemd/zram-generator.conf >/dev/null
        fi
        sudo systemctl daemon-reload && sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || ui_aviso "No se pudo activar zram (se activará al reiniciar)"
    fi
    # lanzador de Steam con el tamaño de interfaz según la escala de tu pantalla
    bash "$(dirname "${BASH_SOURCE[0]}")/scripts/miarch-steam" --instalar-lanzador || true
    # NVIDIA: este script instala las bibliotecas Vulkan pero no el módulo del kernel
    printf '%s\n' "${JUEGOS_GPU[@]}" | grep -q nvidia && ui_aviso "Tarjeta NVIDIA: instala también el módulo del kernel (nvidia-open o nvidia-dkms) para jugar."
    return 0
}

ui_total "$ETAPAS"
[ -n "${MIARCH_UI_SUB:-}" ] || ui_banner "paquetes"   # solo si no lo lanza setup.sh
ui_sudo
ui_etapa "Actualizando el sistema e instalando los paquetes oficiales"
JUEGOS_OK=1; habilitar_multilib || JUEGOS_OK=0     # antes del -Syu, para que se sincronice multilib
ui_ejecutar "Actualizando el sistema (pacman -Syu)" sudo pacman -Syu --noconfirm
ui_ejecutar "Instalando ${#PAQUETES[@]} paquetes oficiales" sudo pacman -S --noconfirm --needed "${PAQUETES[@]}"

ui_etapa "Preparando el equipo para jugar (Steam)"
if [ "$JUEGOS_OK" = 1 ]; then
    ui_ejecutar "Instalando Steam y las herramientas para jugar (${#JUEGOS[@]} paquetes)" sudo pacman -S --noconfirm --needed "${JUEGOS[@]}" \
        || ui_aviso "No se pudo instalar Steam y sus herramientas (revisa el registro). El resto de la instalación sigue."
    configurar_juegos
else
    ui_aviso "No se pudo activar multilib: se omite Steam. Actívalo a mano y vuelve a ejecutar packages.sh."
fi

# =========================
# DOCKER Y OLLAMA
# =========================
configurar_docker_ollama() {

    # Las imágenes de Docker y los modelos de Ollama pesan muchos GB. Si la raíz (/) es pequeña y /home es
    # otra partición, se guardan en /home. Solo se hace si todavía no hay datos (antes del primer arranque).
    local raiz_gb datos
    raiz_gb="$(df -BG --output=size / | tail -1 | tr -dc '0-9')"
    datos="/home/.datos-pesados"
    if [ "${raiz_gb:-0}" -lt 100 ] && [ "$(findmnt -n -o SOURCE --target /home)" != "$(findmnt -n -o SOURCE --target /)" ]; then
        ui_info "La raíz tiene ${raiz_gb} GB: Docker y Ollama guardarán sus datos en $datos (partición /home)."
        sudo install -d -m 755 "$datos"
        if [ ! -s /etc/docker/daemon.json ] && [ -z "$(ls -A /var/lib/docker 2>/dev/null)" ]; then
            sudo install -d -m 711 "$datos/docker"
            sudo install -d -m 755 /etc/docker   # el paquete docker no crea esta carpeta
            printf '{\n  "data-root": "%s/docker"\n}\n' "$datos" | sudo tee /etc/docker/daemon.json >/dev/null
        else
            ui_info "Docker ya tiene datos o configuración: no se mueve su carpeta."
        fi
        if getent passwd ollama >/dev/null; then
            sudo install -d -o ollama -g ollama -m 755 "$datos/ollama"
            sudo install -d /etc/systemd/system/ollama.service.d
            printf '[Service]\nEnvironment="OLLAMA_MODELS=%s/ollama"\n' "$datos" \
                | sudo tee /etc/systemd/system/ollama.service.d/miarch-modelos.conf >/dev/null
            sudo systemctl daemon-reload
        else
            ui_info "No se encontró el usuario 'ollama': los modelos quedarán en la ubicación por defecto."
        fi
    fi

    # Docker arranca por socket (solo cuando lo usas, no gasta memoria al encender); Ollama queda activo.
    sudo systemctl enable --now docker.socket ollama.service \
        || ui_aviso "No se pudo activar docker o ollama (revisa: systemctl status docker.socket ollama)"

    # Estar en el grupo docker equivale a tener acceso de administrador (root) sobre el equipo.
    # Se añade tu usuario para usar docker sin sudo; si prefieres no hacerlo, quita estas líneas.
    if [[ " $(id -nG "$USER") " != *" docker "* ]]; then   # sin tuberías: con pipefail, grep -q puede dar falsos errores
        sudo usermod -aG docker "$USER"
        ui_info "Entraste al grupo docker: cierra sesión y vuelve a entrar para usarlo sin sudo."
    fi
}

# =========================
# SERVICIOS
# =========================
ui_etapa "Activando servicios (Wi-Fi, Bluetooth, modos de energía)"
sudo systemctl enable --now iwd.service bluetooth.service power-profiles-daemon.service \
    || ui_aviso "No se pudo activar algún servicio (revisa: systemctl status iwd bluetooth power-profiles-daemon)"
ui_etapa "Configurando Docker y Ollama"
configurar_docker_ollama

# =========================
# ZSH + OH MY ZSH (se clona el repositorio; NO se ejecuta ningún script descargado)
# =========================
ui_etapa "Configurando Zsh y Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    ui_ejecutar "Descargando Oh My Zsh" git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    sudo chsh -s /usr/bin/zsh "$USER" || ui_aviso "No se pudo cambiar el shell predeterminado"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search; do
    if [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]; then
        ui_ejecutar "Descargando el plugin $plugin" git clone --depth=1 "https://github.com/zsh-users/$plugin" "$ZSH_CUSTOM/plugins/$plugin" \
            || ui_aviso "No se pudo clonar $plugin"
    else
        ui_ok "Plugin $plugin ya instalado"
    fi
done

# =========================
# AUR (paquetes de la comunidad: no están firmados por Arch)
# =========================
instalar_yay() {
    local tmp; tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}
ui_etapa "Preparando AUR (yay)"
if ! command -v yay &>/dev/null; then
    ui_ejecutar "Instalando yay (ayudante de AUR)" instalar_yay
else
    ui_ok "yay ya está instalado"
fi

# Nota de seguridad: --noconfirm instala sin que veas el PKGBUILD de cada paquete.
# Si prefieres revisarlos, quita --noconfirm (yay te los mostrará uno por uno).
ui_etapa "Quitando paquetes que Miarch ya no usa"
mapfile -t SOBRAN < <(for p in "${OBSOLETOS[@]}"; do pacman -Q "$p" >/dev/null 2>&1 && echo "$p"; done)
if [ "${#SOBRAN[@]}" -gt 0 ]; then
    ui_ejecutar "Quitando ${SOBRAN[*]}" sudo pacman -Rns --noconfirm "${SOBRAN[@]}" || ui_aviso "No se pudo quitar: ${SOBRAN[*]}"
else
    ui_ok "No hay paquetes obsoletos"
fi
AUR_FALLIDOS=()
for paquete in "${AUR_PAQUETES[@]}"; do
    ui_etapa "Instalando $paquete (AUR)"
    ui_ejecutar "$paquete" yay -S --noconfirm --needed "$paquete" || AUR_FALLIDOS+=("$paquete")
done
if [ "${#AUR_FALLIDOS[@]}" -gt 0 ]; then
    ui_aviso "No se pudieron instalar estos paquetes de AUR: ${AUR_FALLIDOS[*]}"
    ui_info "Reintenta uno con:  yay -S ${AUR_FALLIDOS[0]}   (te mostrará el error completo)"
fi

# =========================
# HERMES DESKTOP (app oficial de Nous Research; no está en AUR, se instala con su script, en ~/.hermes)
# =========================
ui_etapa "Hermes Desktop (app oficial)"
if [ -x "$HOME/.local/bin/hermes" ] || command -v hermes >/dev/null 2>&1; then
    ui_ok "Hermes ya está instalado"
else
    HERMES_SH="$(mktemp -d)/install.sh"
    if curl -fsSL --max-time 60 -o "$HERMES_SH" https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh; then
        ui_ejecutar "Instalando Hermes Desktop (compila la app: tarda)" bash "$HERMES_SH" --non-interactive --include-desktop \
            || ui_aviso "No se pudo instalar Hermes Desktop. Reintenta con:  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --include-desktop"
    else
        ui_aviso "No se pudo descargar el instalador de Hermes (¿sin internet?). Se reintentará al actualizar."
    fi
    rm -rf "$(dirname "$HERMES_SH")"
fi

# =========================
# JAVA 21 POR DEFECTO
# =========================
ui_etapa "Dejando Java 21 como versión por defecto"
sudo archlinux-java set java-21-openjdk || ui_aviso "No se pudo fijar Java 21 (revisa: archlinux-java status)"

if [ -z "${MIARCH_UI_SUB:-}" ]; then     # solo si no lo lanza setup.sh o miarch-update (que muestra su propio resumen)
    ui_resumen "Paquetes instalados"
    ui_info "Siguiente paso:  ./install.sh"
    ui_info "La primera vez, inicia sesión en cada herramienta:  claude  |  codex  |  agy  |  gh auth login"
    ui_info "Docker: cierra sesión y vuelve a entrar para usarlo sin sudo.   Ollama: ollama pull llama3.2"
fi
