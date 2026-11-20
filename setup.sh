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

# barra del avance TOTAL de toda la instalación: 2 etapas de setup.sh + las de packages.sh + las de install.sh
ETAPAS_PAQUETES="$(bash ./packages.sh --etapas)"
ETAPAS_INSTALL="$(bash ./install.sh --etapas)"
export MIARCH_UI_TOTAL=$(( 2 + ETAPAS_PAQUETES + ETAPAS_INSTALL ))
export MIARCH_UI_ACTUAL=0
source ./lib/ui.sh

ui_etapa "Comprobando internet"
if ! curl -fsS --max-time 8 -o /dev/null https://archlinux.org; then
    echo "[ERROR] No hay internet. Conéctate y vuelve a ejecutar ./setup.sh"
    echo "   Wi-Fi:  iwctl station wlan0 connect \"NOMBRE_DE_TU_RED\"    (con cable ya debería funcionar)"
    exit 1
fi

echo "[i] Se pide la contraseña de sudo una sola vez (se mantiene activa mientras dure la instalación)."
sudo -v
( while true; do sudo -n true; sleep 45; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE=$!
trap 'kill "$KEEPALIVE" 2>/dev/null || true' EXIT

ui_etapa "Herramientas base (git y compiladores para los paquetes de AUR)"
ui_ejecutar "Instalando git y base-devel" sudo pacman -S --needed --noconfirm git base-devel

# bash directo: funciona aunque se haya descargado el ZIP de GitHub, que borra los permisos de ejecución
# los scripts hijos continúan la misma barra; el sudo ya está activo
export MIARCH_SUDO_VIVO=1
export MIARCH_UI_ACTUAL=2
bash ./packages.sh
export MIARCH_UI_ACTUAL=$(( 2 + ETAPAS_PAQUETES ))
bash ./install.sh

echo ""
echo "[OK] ¡Todo listo! Reinicia con:  sudo reboot"
echo "   Después inicia sesión en la terminal (tty1) y el escritorio arranca solo."
