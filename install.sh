#!/usr/bin/env bash
# Miarch · copia las configuraciones y scripts del repo a tu $HOME. Se puede ejecutar varias veces.
set -euo pipefail
set -E
trap 'echo "[ERROR] El script se detuvo en la línea $LINENO: $BASH_COMMAND" >&2' ERR   # dice dónde falló, nunca se detiene en silencio

if [ "$EUID" -eq 0 ]; then
    echo "[ERROR] No ejecutes este script como root."
    exit 1
fi

# barra de progreso total y animación mientras trabaja cada comando
source "$(dirname "${BASH_SOURCE[0]}")/lib/ui.sh"
ETAPAS=7   # setup.sh pregunta cuántas etapas tiene este script para dibujar la barra del total
[ "${1:-}" = "--etapas" ] && { echo "$ETAPAS"; exit 0; }
ui_total "$ETAPAS"
[ -n "${MIARCH_UI_SUB:-}" ] || ui_banner "configuraciones"   # solo si no lo lanza setup.sh

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"
STAMP="$(date +%Y%m%d-%H%M%S)"
ui_info "Repositorio: $DOTFILES_DIR"

# =========================
# FUNCIONES AUXILIARES
# =========================
backup() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        echo "==> Copia de seguridad: $1 -> $1.bak-$STAMP"
        mv "$1" "$1.bak-$STAMP"
        # solo se conservan las 2 copias más recientes (cada actualización crea una nueva)
        ls -d "$1".bak-* 2>/dev/null | sort | head -n -2 | while read -r vieja; do rm -rf "$vieja"; done
    fi
}

copy_config() {
    local src="$1" dest="$2"
    if [ -e "$src" ]; then
        backup "$dest"
        echo "==> $src -> $dest"
        mkdir -p "$(dirname "$dest")"
        cp -r "$src" "$dest"
    else
        ui_aviso "$src no existe, se omite"
    fi
}

# =========================
# CARPETAS DEL USUARIO
# =========================
command -v xdg-user-dirs-update &>/dev/null && xdg-user-dirs-update
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
WALL_DIR="$PICTURES_DIR/Wallpapers"
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$WALL_DIR"

# =========================
# SCRIPTS (van a ~/.local/bin)
# =========================
ui_etapa "Instalando los scripts de Miarch"
for f in wallpaper.sh miarch-colors miarch-set miarch-wifi miarch-info miarch-fetch miarch-update miarch-chrome-tema miarch-modo-juego miarch-steam miarch-volumen; do
    [ -f "$DOTFILES_DIR/scripts/$f" ] && install -Dm755 "$DOTFILES_DIR/scripts/$f" "$HOME/.local/bin/$f"
done

# =========================
# CONFIGURACIONES
# =========================
ui_etapa "Aplicando las configuraciones"
# tema oscuro del sistema: lo leen Chrome, Dolphin y las apps GTK (por el portal y por GTK). No se pisa nada que ya exista.
if command -v gsettings &>/dev/null; then
    [ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" = "'prefer-dark'" ] \
        || gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
fi
# juegos: GameMode pone el perfil de energía "rendimiento" mientras juegas y MangoHud usa la paleta de Miarch. Solo si no existen.
if [ ! -f "$HOME/.config/gamemode.ini" ]; then
    printf '[custom]\nstart=%s/.local/bin/miarch-modo-juego start\nend=%s/.local/bin/miarch-modo-juego end\n' "$HOME" "$HOME" > "$HOME/.config/gamemode.ini"
fi
if [ ! -f "$HOME/.config/MangoHud/MangoHud.conf" ]; then
    mkdir -p "$HOME/.config/MangoHud"
    cat > "$HOME/.config/MangoHud/MangoHud.conf" <<'MANGO'
# Miarch · MangoHud con la paleta morada. Mostrar u ocultar: Shift derecho + F12
legacy_layout=false
position=top-left
font_size=20
round_corners=10
background_alpha=0.40
background_color=0B0F1A
text_color=E6E9F0
engine_color=8892A6
gpu_color=6F65D6
cpu_color=C4B5FD
frametime_color=A7F3D0
fps_color_change
fps_value=30,60
fps_color=E8809F,FBCFE8,A7F3D0
fps
frametime
cpu_stats
cpu_temp
gpu_stats
gpu_temp
ram
toggle_hud=Shift_R+F12
MANGO
fi
"$HOME/.local/bin/miarch-steam" --instalar-lanzador 2>/dev/null || true     # lanzador de Steam con la escala de tu pantalla (si Steam está instalado)

for v in gtk-3.0 gtk-4.0; do
    if [ ! -f "$HOME/.config/$v/settings.ini" ]; then
        mkdir -p "$HOME/.config/$v"
        printf '[Settings]\ngtk-application-prefer-dark-theme=1\n' > "$HOME/.config/$v/settings.ini"
    fi
done
# los ajustes del panel (animaciones, blur, escala, teclado...) viven en variables de este archivo: se conservan al reaplicar
AJUSTES_HYPR="$(grep -E '^local (ESCALA|KB|NATURAL|TAP|SENS|CURSOR|MOVIMIENTO|ANIM|BLUR)[[:space:]]*=' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null || true)"
copy_config "$CONFIG_DIR/hypr"              "$HOME/.config/hypr"
if [ -n "$AJUSTES_HYPR" ] && [ -f "$HOME/.config/hypr/hyprland.lua" ]; then
    AJUSTES_HYPR="$AJUSTES_HYPR" python3 -I - "$HOME/.config/hypr/hyprland.lua" <<'PY'
import os, re, sys
ruta = sys.argv[1]
txt = open(ruta, encoding="utf-8").read()
for ln in os.environ["AJUSTES_HYPR"].splitlines():
    nombre = re.match(r"local (\w+)", ln).group(1)
    valor = re.match(r"local \w+\s*=\s*(\"[^\"]*\")", ln)
    if valor:
        txt = re.sub(r'(?m)^(local %s\s*=\s*)"[^"]*"' % nombre, lambda m: m.group(1) + valor.group(1), txt)
open(ruta, "w", encoding="utf-8").write(txt)
PY
fi
# carpeta de cambios personales (fuera de las que se reemplazan): solo se crea lo que falte, nunca se pisa nada
PERSONAL="$HOME/.config/miarch/personal"
mkdir -p "$PERSONAL"
[ -f "$PERSONAL/hyprland.lua" ] || cat > "$PERSONAL/hyprland.lua" <<'EJ'
-- Tus cambios personales de Hyprland. Se cargan al final de hyprland.lua y NO los borra ninguna actualización.
-- Usa "SUPER" tal cual. Recarga con: hyprctl reload   · Errores: hyprctl configerrors
-- Ejemplos (quita los -- del principio para activarlos):
-- hl.bind("SUPER + G", hl.dsp.exec_cmd("steam"))                        -- un atajo propio: Super+G abre Steam
-- hl.window_rule({ name = "mi-regla", match = { class = "^mpv$" }, float = true })   -- que mpv abra flotante
EJ
[ -f "$PERSONAL/kitty.conf" ] || cat > "$PERSONAL/kitty.conf" <<'EJ'
# Tus cambios personales de la terminal kitty. Se cargan al final y NO los borra ninguna actualización.
# Ejemplos (quita el # del principio):
# font_size 13
# background_opacity 0.9
EJ
# skill para agentes de IA: enseña al agente a instalar y configurar cosas en este sistema de la mejor forma.
# Sigue el estándar abierto "Agent Skills" (una carpeta con SKILL.md), así que sirve igual en todos: solo cambia la carpeta.
# Se copia a la de cada agente que exista en este equipo (por su comando o por su carpeta). Es una copia gestionada por Miarch:
# se refresca en cada instalación y sin copias de seguridad, porque dentro de una carpeta de skills una copia extra se leería
# como una skill repetida.
if [ -d "$DOTFILES_DIR/skills/instalar-configurar" ]; then
    for agente in "claude:$HOME/.claude/skills" "codex:$HOME/.codex/skills" "agy:$HOME/.gemini/config/skills"; do
        cmd="${agente%%:*}"; destino="${agente#*:}"
        if command -v "$cmd" &>/dev/null || [ -d "$(dirname "$destino")" ]; then
            mkdir -p "$destino"
            rm -rf "$destino/instalar-configurar"
            cp -r "$DOTFILES_DIR/skills/instalar-configurar" "$destino/instalar-configurar"
        fi
    done
fi
[ -f "$PERSONAL/zshrc" ] || cat > "$PERSONAL/zshrc" <<'EJ'
# Tus cambios personales de Zsh (alias, variables). Se cargan al final y NO los borra ninguna actualización.
# Ejemplos (quita el # del principio):
# alias gs="git status"
EJ
copy_config "$CONFIG_DIR/kitty"             "$HOME/.config/kitty"
copy_config "$CONFIG_DIR/nvim"              "$HOME/.config/nvim"
copy_config "$CONFIG_DIR/quickshell/miarch" "$HOME/.config/quickshell/miarch"
copy_config "$DOTFILES_DIR/home/.zshrc"     "$HOME/.zshrc"
install -Dm644 "$CONFIG_DIR/chrome/chrome-flags.conf" "$HOME/.config/chrome-flags.conf"

# =========================
# VS CODE: la terminal necesita la fuente con íconos (sin ella el prompt y el logo se deforman)
# Se fusiona con tus ajustes: solo se tocan las claves de config/vscode/settings.json y nunca se borra nada tuyo.
# =========================
ui_etapa "Ajustando la fuente de la terminal de VS Code"
python3 -I - "$CONFIG_DIR/vscode/settings.json" "$HOME/.config/Code/User/settings.json" <<'PY' || ui_aviso "No se pudo ajustar la fuente de la terminal de VS Code"
import json, os, sys
origen, destino = sys.argv[1:3]
nuevos = json.load(open(origen, encoding="utf-8"))
actual = {}
if os.path.exists(destino):
    try:
        actual = json.load(open(destino, encoding="utf-8"))
    except ValueError:
        print("[!] settings.json de VS Code tiene comentarios o errores: no se toca. Pon a mano terminal.integrated.fontFamily = 'JetBrainsMono Nerd Font Mono'")
        sys.exit(0)
if all(actual.get(k) == v for k, v in nuevos.items()):
    sys.exit(0)
actual.update(nuevos)
os.makedirs(os.path.dirname(destino), exist_ok=True)
tmp = destino + ".tmp"
json.dump(actual, open(tmp, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
open(tmp, "a").write("\n")
os.replace(tmp, destino)
print("VS Code: fuente de la terminal ajustada")
PY

# =========================
# WALLPAPERS
# =========================
ui_etapa "Copiando los wallpapers"
if [ -d "$DOTFILES_DIR/wallpapers" ]; then
    ui_info "Destino de los wallpapers: $WALL_DIR"
    cp -rn "$DOTFILES_DIR/wallpapers/." "$WALL_DIR/"
fi

# =========================
# NEOVIM (Lazy.nvim instala los plugins solo)
# =========================
ui_etapa "Sincronizando los plugins de Neovim"
if command -v nvim &>/dev/null; then
    ui_ejecutar "Plugins de Neovim (Lazy.nvim)" nvim --headless "+Lazy! sync" +qa || ui_aviso "Neovim terminó con avisos (normal en el primer arranque)"
fi

# =========================
# INICIO AUTOMÁTICO DE HYPRLAND EN tty1
# (si luego instalas la pantalla de inicio de sesión gráfica, esto deja de hacer falta)
# =========================
ui_etapa "Configurando el inicio automático de Hyprland en tty1"
if ! grep -q "Miarch - Inicio automático" "$HOME/.zprofile" 2>/dev/null; then
    cat >> "$HOME/.zprofile" << 'EOF'

# Miarch - Inicio automático de Hyprland (solo en tty1)
if [[ -z "$WAYLAND_DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then
    exec start-hyprland
fi
EOF
fi

# =========================
# WALLPAPER Y COLORES (solo si ya estás dentro de Hyprland)
# =========================
ui_etapa "Aplicando el wallpaper y los colores"
# al actualizar (miarch-update) no se cambia tu fondo: solo se vuelven a calcular los colores del actual
[ -n "${MIARCH_ACTUALIZANDO:-}" ] || "$HOME/.local/bin/wallpaper.sh" || true
# kitty toma sus colores de un archivo que genera miarch-colors a partir del wallpaper
# las notificaciones las dibuja Quickshell: si dunst sigue vivo (sesión anterior) ocupa el servicio y se cierra
pkill -x dunst 2>/dev/null || true
[ -s "$HOME/.cache/miarch-wallpaper" ] && "$HOME/.local/bin/miarch-colors" "$(cat "$HOME/.cache/miarch-wallpaper")" >/dev/null || true

# anota el commit cuyas configuraciones se aplicaron (miarch-update y la nube de la barra lo usan para saber si hay algo pendiente)
if git -C "$DOTFILES_DIR" rev-parse HEAD >/dev/null 2>&1; then
    mkdir -p "$HOME/.cache/miarch"; git -C "$DOTFILES_DIR" rev-parse HEAD > "$HOME/.cache/miarch/configs-aplicadas"
fi
# una instalación nueva no necesita ver las novedades anteriores: se anota la última como vista (solo si aún no hay marca)
if [ ! -s "$HOME/.cache/miarch/novedades-vistas" ] && [ -f "$DOTFILES_DIR/NOVEDADES.md" ]; then
    mkdir -p "$HOME/.cache/miarch"; grep -m1 '^## ' "$DOTFILES_DIR/NOVEDADES.md" | awk '{print $2}' > "$HOME/.cache/miarch/novedades-vistas"
fi

if [ -z "${MIARCH_UI_SUB:-}" ]; then     # solo si no lo lanza setup.sh o miarch-update (que muestra su propio resumen)
    ui_resumen "Configuraciones aplicadas"
    ui_info "Dentro de Hyprland recarga con: hyprctl reload   (y reinicia el escritorio: qs kill -c miarch; qs -c miarch &)"
    ui_info "Si no, reinicia e inicia sesión en tty1."
    ui_info "Opcional, pantalla de inicio de sesión gráfica:  ./scripts/miarch-greeter-install"
fi
