#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Miarch - Cambia el wallpaper a uno aleatorio con awww (antes swww) y aplica colores con pywal.
set -uo pipefail

# Carpeta de imágenes según el idioma del sistema (~/Imágenes, ~/Pictures, ...)
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
WALLPAPERS_DIR="${WALLPAPERS_DIR:-$PICTURES_DIR/Wallpapers}"

# awww es el nuevo nombre de swww; se acepta cualquiera de los dos
if command -v awww &>/dev/null; then
    WW=awww
elif command -v swww &>/dev/null; then
    WW=swww
else
    echo "[ERROR] No se encontró awww ni swww. Instálalo con: sudo pacman -S swww"
    exit 1
fi

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "[!] No hay sesión Wayland activa; el wallpaper se aplicará al iniciar Hyprland."
    exit 0
fi

# ======================
# ASEGURAR QUE EL DAEMON ESTÉ CORRIENDO
# ======================
if ! "$WW" query &>/dev/null; then
    echo "==> Iniciando ${WW}-daemon..."
    setsid -f "${WW}-daemon" --format xrgb &>/dev/null
    for _ in {1..20}; do
        "$WW" query &>/dev/null && break
        sleep 0.25
    done
fi

if ! "$WW" query &>/dev/null; then
    echo "[ERROR] No se pudo iniciar ${WW}-daemon"
    exit 1
fi

# ======================
# SELECCIONAR Y APLICAR WALLPAPER
# ======================
WALL="$(find "$WALLPAPERS_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' \) 2>/dev/null | grep -vxF "$(cat "$HOME/.cache/miarch-wallpaper" 2>/dev/null)" | shuf -n 1)"

if [ -z "$WALL" ]; then  # (si solo hay una imagen, se queda con ella)
    WALL="$(cat "$HOME/.cache/miarch-wallpaper" 2>/dev/null)"
fi
if [ -z "$WALL" ]; then
    echo "[ERROR] No hay imágenes en $WALLPAPERS_DIR"
    exit 1
fi

# Si se pasa una imagen como argumento (desde el panel de Ajustes), se usa esa
if [ -n "${1:-}" ] && [ -f "$1" ]; then WALL="$1"; fi

# Fondos animados (GIF): cuestan MUCHA fluidez (cada fotograma obliga a repintar la pantalla y recalcular
# el desenfoque detrás de las ventanas). Por defecto un GIF se muestra como imagen fija (su primer fotograma);
# se activa en Ajustes -> Apariencia -> Fondos animados.
IMG="$WALL"
case "${WALL,,}" in
    *.gif)
        ANIMADO="$(python3 -I -c "import json,os;print(json.load(open(os.path.expanduser('~/.config/miarch/ajustes.json'))).get('gif','off'))" 2>/dev/null || echo off)"
        if [ "$ANIMADO" != "on" ]; then
            ESTATICO="$HOME/.cache/miarch/estaticos/$(basename "${WALL%.*}").png"
            if [ ! -s "$ESTATICO" ] || [ "$WALL" -nt "$ESTATICO" ]; then
                mkdir -p "$(dirname "$ESTATICO")"
                python3 -I -c "
import sys
from PIL import Image
im = Image.open(sys.argv[1]); im.seek(0); im.convert('RGB').save(sys.argv[2])" "$WALL" "$ESTATICO" 2>/dev/null || ESTATICO=""
            fi
            [ -n "$ESTATICO" ] && [ -s "$ESTATICO" ] && IMG="$ESTATICO"
        fi ;;
esac

echo "==> Aplicando wallpaper: $(basename "$WALL")$([ "$IMG" != "$WALL" ] && echo " (fijo)")"
"$WW" img "$IMG" \
    --transition-type grow \
    --transition-pos 0.5,0.5 \
    --transition-step 90 \
    --transition-fps 60 \
    --transition-duration 2

# Paleta mate de Miarch (la lee el escritorio de Quickshell y la pantalla de bloqueo)
mkdir -p "$HOME/.cache"
printf '%s\n' "$WALL" > "$HOME/.cache/miarch-wallpaper"
# Ruta completa: Hyprland no incluye ~/.local/bin en el PATH al lanzar atajos
if [ -x "$HOME/.local/bin/miarch-colors" ]; then
    "$HOME/.local/bin/miarch-colors" "$WALL" >/dev/null || echo "[!] miarch-colors falló"
fi

# Fondo y colores para la pantalla de inicio de sesión (si está instalada: /var/lib/miarch-greeter)
G=/var/lib/miarch-greeter
if [ -d "$G" ] && [ -w "$G" ]; then
    cp -f "$WALL" "$G/wallpaper.tmp" 2>/dev/null && mv -f "$G/wallpaper.tmp" "$G/wallpaper" && chmod 644 "$G/wallpaper"
    [ -f "$HOME/.cache/miarch/colors.json" ] && cp -f "$HOME/.cache/miarch/colors.json" "$G/colors.json" && chmod 644 "$G/colors.json"
fi

# Colores con pywal (opcional)
if command -v wal &>/dev/null; then
    if wal -i "$WALL" --saturate 0.8 -q -n; then
        # Waybar recarga su estilo sola al cambiar colors.css (reload_style_on_change)
        if [ -f "$HOME/.cache/wal/colors-waybar.css" ] && [ -d "$HOME/.config/waybar" ]; then
            cp "$HOME/.cache/wal/colors-waybar.css" "$HOME/.config/waybar/colors.css"
        fi
        echo "==> Colores aplicados"
    else
        echo "[!] pywal falló al generar colores"
    fi
fi
