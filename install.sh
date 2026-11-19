#!/usr/bin/env bash
# Miarch · copia las configuraciones y scripts del repo a tu $HOME. Se puede ejecutar varias veces.
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "❌ No ejecutes este script como root."
    exit 1
fi

echo "🚀 Instalando dotfiles de Miarch..."

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"
STAMP="$(date +%Y%m%d-%H%M%S)"
echo "📍 Repositorio: $DOTFILES_DIR"

# =========================
# FUNCIONES AUXILIARES
# =========================
backup() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        echo "📦 Copia de seguridad: $1 → $1.bak-$STAMP"
        mv "$1" "$1.bak-$STAMP"
    fi
}

copy_config() {
    local src="$1" dest="$2"
    if [ -e "$src" ]; then
        backup "$dest"
        echo "📋 $src → $dest"
        mkdir -p "$(dirname "$dest")"
        cp -r "$src" "$dest"
    else
        echo "⚠️  $src no existe, se omite"
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
echo "⚙️  Instalando scripts..."
for f in wallpaper.sh miarch-colors miarch-set miarch-wifi miarch-info miarch-fetch; do
    [ -f "$DOTFILES_DIR/scripts/$f" ] && install -Dm755 "$DOTFILES_DIR/scripts/$f" "$HOME/.local/bin/$f"
done

# =========================
# CONFIGURACIONES
# =========================
echo "🔧 Aplicando configuraciones..."
copy_config "$CONFIG_DIR/hypr"              "$HOME/.config/hypr"
copy_config "$CONFIG_DIR/kitty"             "$HOME/.config/kitty"
copy_config "$CONFIG_DIR/nvim"              "$HOME/.config/nvim"
copy_config "$CONFIG_DIR/quickshell/miarch" "$HOME/.config/quickshell/miarch"
copy_config "$DOTFILES_DIR/home/.zshrc"     "$HOME/.zshrc"
install -Dm644 "$CONFIG_DIR/chrome/chrome-flags.conf" "$HOME/.config/chrome-flags.conf"

# =========================
# WALLPAPERS
# =========================
if [ -d "$DOTFILES_DIR/wallpapers" ]; then
    echo "🖼️  Copiando wallpapers a $WALL_DIR"
    cp -rn "$DOTFILES_DIR/wallpapers/." "$WALL_DIR/"
fi

# =========================
# NEOVIM (Lazy.nvim instala los plugins solo)
# =========================
if command -v nvim &>/dev/null; then
    echo "💤 Sincronizando plugins de Neovim..."
    nvim --headless "+Lazy! sync" +qa &>/dev/null || echo "⚠️  Neovim terminó con avisos (normal en el primer arranque)"
fi

# =========================
# INICIO AUTOMÁTICO DE HYPRLAND EN tty1
# (si luego instalas la pantalla de inicio de sesión gráfica, esto deja de hacer falta)
# =========================
if ! grep -q "Miarch - Inicio automático" "$HOME/.zprofile" 2>/dev/null; then
    echo "⚙️  Inicio automático de Hyprland en tty1..."
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
"$HOME/.local/bin/wallpaper.sh" || true
# kitty toma sus colores de un archivo que genera miarch-colors a partir del wallpaper
[ -s "$HOME/.cache/miarch-wallpaper" ] && "$HOME/.local/bin/miarch-colors" "$(cat "$HOME/.cache/miarch-wallpaper")" >/dev/null || true

echo ""
echo "✅ ¡Listo!"
echo "   Dentro de Hyprland recarga con: hyprctl reload   (y reinicia el escritorio: qs kill -c miarch; qs -c miarch &)"
echo "   Si no, reinicia e inicia sesión en tty1."
echo "   Opcional, pantalla de inicio de sesión gráfica:  ./scripts/miarch-greeter-install"
