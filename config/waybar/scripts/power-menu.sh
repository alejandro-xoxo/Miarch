#!/usr/bin/env bash
# Miarch - Menú de energía con rofi
choice="$(printf '󰌾  Bloquear\n󰍃  Cerrar sesión\n󰜉  Reiniciar\n⏻  Apagar\n' \
    | rofi -dmenu -i -p "Energía" -theme-str 'window {width: 260px;} listview {lines: 4;}')"

case "$choice" in
    *Bloquear*)      command -v hyprlock &>/dev/null && hyprlock || loginctl lock-session ;;
    *"Cerrar sesión"*) hyprctl dispatch 'hl.dsp.exit()' ;;
    *Reiniciar*)     systemctl reboot ;;
    *Apagar*)        systemctl poweroff ;;
esac
