#!/usr/bin/env bash
# Miarch · instalación completa desde un Arch mínimo: paquetes + configuraciones.
# Uso:  ./setup.sh      (usuario normal con sudo; pide la contraseña una sola vez)
set -euo pipefail
set -E
trap 'echo "[ERROR] El script se detuvo en la línea $LINENO: $BASH_COMMAND" >&2' ERR   # dice dónde falló, nunca se detiene en silencio

if [ "$EUID" -eq 0 ]; then
    echo "[ERROR] Ejecútalo con tu usuario normal, no como root (pedirá sudo)."
    exit 1
fi
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Comprobando internet..."
if ! curl -fsS --max-time 8 -o /dev/null https://archlinux.org; then
    echo "[ERROR] No hay internet. Conéctate y vuelve a ejecutar ./setup.sh"
    echo "   Wi-Fi:  iwctl station wlan0 connect \"NOMBRE_DE_TU_RED\"    (con cable ya debería funcionar)"
    exit 1
fi

echo "==> Pidiendo sudo una vez (se mantiene activo mientras dure la instalación)..."
sudo -v
( while true; do sudo -n true; sleep 45; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE=$!
trap 'kill "$KEEPALIVE" 2>/dev/null || true' EXIT

echo "==> Herramientas base (git y compiladores para los paquetes de AUR)..."
sudo pacman -S --needed --noconfirm git base-devel

# bash directo: funciona aunque se haya descargado el ZIP de GitHub, que borra los permisos de ejecución
bash ./packages.sh
bash ./install.sh

echo ""
echo "[OK] ¡Todo listo! Reinicia con:  sudo reboot"
echo "   Después inicia sesión en la terminal (tty1) y el escritorio arranca solo."
