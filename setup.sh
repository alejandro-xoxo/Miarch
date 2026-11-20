#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
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
# punto de entrada: empieza de cero aunque haya heredado variables de otra ejecución
unset MIARCH_UI_INICIO MIARCH_UI_TOTAL MIARCH_UI_ACTUAL MIARCH_UI_SUB MIARCH_UI_COMPACTO MIARCH_SUDO_VIVO MIARCH_STATS

source ./lib/ui.sh

ui_banner "instalador"

# Selección de juegos opcionales
if [ -t 0 ] && [ ! -e "$HOME/.config/miarch/sin-juegos" ] && [ ! -e "$HOME/.config/miarch/juegos-decidido" ]; then
    mkdir -p "$HOME/.config/miarch"
    read -rp "¿Instalar Steam y las herramientas para jugar? [S/n] " resp
    if [[ "$resp" =~ ^[nN] ]]; then
        touch "$HOME/.config/miarch/sin-juegos"
    fi
    touch "$HOME/.config/miarch/juegos-decidido"
fi

# barra del avance TOTAL de toda la instalación: 2 etapas de setup.sh + las de packages.sh + las de install.sh
ETAPAS_PAQUETES="$(bash ./packages.sh --etapas)"
ETAPAS_INSTALL="$(bash ./install.sh --etapas)"
export MIARCH_UI_TOTAL=$(( 3 + ETAPAS_PAQUETES + ETAPAS_INSTALL ))
UI_TOTAL="$MIARCH_UI_TOTAL"
export MIARCH_UI_ACTUAL=0
export MIARCH_UI_SUB=1   # los scripts que lanza setup.sh no repiten el logo ni el resumen
ui_etapa "Comprobando internet"
if ! curl -fsS --max-time 8 -o /dev/null https://archlinux.org; then
    ui_error "No hay internet. Conéctate y vuelve a ejecutar ./setup.sh"
    ui_info "Wi-Fi:  iwctl station wlan0 connect \"NOMBRE_DE_TU_RED\"    (con cable ya debería funcionar)"
    exit 1
fi

ui_info "Se pide la contraseña de sudo una sola vez (se mantiene activa mientras dure la instalación)."
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

# Pantalla de inicio de sesión gráfica por defecto (se ve en el próximo arranque). Para no tenerla: touch ~/.config/miarch/sin-greeter
export MIARCH_UI_ACTUAL=$(( 2 + ETAPAS_PAQUETES + ETAPAS_INSTALL ))
GREETER_OK=0
if [ ! -e "$HOME/.config/miarch/sin-greeter" ]; then
    ui_etapa "Pantalla de inicio de sesión"
    if ui_ejecutar "Instalando greetd y la pantalla de Miarch" bash ./scripts/miarch-greeter-install; then GREETER_OK=1
    else ui_aviso "No se pudo instalar la pantalla de inicio de sesión: entrarás por la terminal. Reintenta con ./scripts/miarch-greeter-install"; fi
fi

ui_resumen "Instalación completa"
if [ "$GREETER_OK" = 1 ]; then
    ui_caja "Reinicia con:  sudo reboot" "Verás la pantalla de inicio de sesión de Miarch: escribe tu contraseña y entra." "" "github.com/alejandro-xoxo/Miarch"
else
    ui_caja "Reinicia con:  sudo reboot" "Después inicia sesión en la terminal (tty1) y el escritorio arranca solo." "" "github.com/alejandro-xoxo/Miarch"
fi
echo
