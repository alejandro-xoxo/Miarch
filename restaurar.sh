#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Restaura la demo en un equipo nuevo: copia esta carpeta a ~/demo-miarch y los comandos tux-arch y m:music a ~/.local/bin.
# No pisa tu demo.env si ya existe y nunca guarda contraseñas.
#   restaurar.sh               copia la demo y los comandos
#   restaurar.sh --paquetes    además instala los programas de paquetes.txt (pide confirmación; los de AUR los revisa yay)
#   restaurar.sh --seco        solo muestra qué haría
set -eu
PAQ=0; SECO=0
for a in "$@"; do case "$a" in --paquetes) PAQ=1;; --seco) SECO=1;; *) echo "restaurar.sh: opción desconocida: $a" >&2; exit 2;; esac; done
AQUI=$(cd "$(dirname "$0")" && pwd)
DEST="$HOME/demo-miarch"; BIN="$HOME/.local/bin"; ENV="$HOME/.config/miarch/personal/demo.env"
if [ "$SECO" = 1 ]; then echo "modo seco: copiaría la demo a $DEST, tux-arch y m:music a $BIN y crearía $ENV si falta"; else
mkdir -p "$DEST/prog" "$BIN" "$(dirname "$ENV")"
cp "$AQUI"/demo-v9.sh "$AQUI"/actualizador-sim.py "$AQUI"/crear-musica.py "$AQUI"/tux.png "$DEST/"
cp "$AQUI"/prog/* "$DEST/prog/"
chmod +x "$DEST"/demo-v9.sh "$DEST"/prog/*.sh
install -m755 "$AQUI/bin/tux-arch" "$BIN/tux-arch"
install -m755 "$AQUI/bin/mimusic" "$BIN/mimusic"; ln -sf mimusic "$BIN/m:music"
echo "✔ Demo copiada a $DEST"
echo "✔ Comandos instalados: tux-arch y mimusic (también como m:music) (en $BIN)"
if [ -e "$ENV" ]; then echo "• $ENV ya existe: no se toca"
else install -m600 "$AQUI/demo.env.ejemplo" "$ENV"; echo "✔ Creado $ENV (vacío): pon tu contraseña ahí si quieres que la demo la escriba sola"; fi
fi
if [ "$PAQ" = 1 ]; then
  OFI=$(awk '$1=="pacman"{printf "%s ", $2}' "$AQUI/paquetes.txt"); AUR=$(awk '$1=="aur"{printf "%s ", $2}' "$AQUI/paquetes.txt")
  echo "Con pacman: $OFI"; echo "Desde AUR (paquetes de la comunidad, no los revisa Arch; yay te enseña el PKGBUILD): $AUR"
  if [ "$SECO" = 1 ]; then echo "modo seco: sudo pacman -S --needed $OFI && yay -S --needed $AUR"
  else read -r -p "¿Instalar? [s/N] " r; case "$r" in [sSyY]*) sudo pacman -S --needed $OFI; yay -S --needed $AUR;; *) echo "no se instaló nada";; esac; fi
fi
[ "$SECO" = 1 ] && exit 0
FALTAN=(); for c in cava sptlrx peaclock cbonsai pipes.sh wtype gpu-screen-recorder fastfetch kitten playerctl ffmpeg; do command -v "$c" >/dev/null 2>&1 || FALTAN+=("$c"); done
if [ "${#FALTAN[@]}" -gt 0 ]; then
  echo "▲ Faltan programas: ${FALTAN[*]}"
  echo "  Instálalos con: bash $AQUI/restaurar.sh --paquetes"
fi
echo "Para ver el Tux: tux-arch · Para la página de música: mimusic · Para la demo: ~/demo-miarch/demo-v9.sh /tmp/demo.log"
