#!/usr/bin/env bash
# Icono del reproductor activo para la isla de música (vacío = isla oculta)
status="$(playerctl status 2>/dev/null)" || { echo '{"text":""}'; exit 0; }
player="$(playerctl -l 2>/dev/null | head -n1)"

case "$player" in
    spotify*)            icon="󰓇" ;;
    firefox*|chrom*)     icon="󰖟" ;;
    mpv*|vlc*)           icon="󰕼" ;;
    *)                   icon="󰎆" ;;
esac

cls="playing"; [ "$status" != "Playing" ] && cls="paused"
printf '{"text":"%s","class":"%s"}\n' "$icon" "$cls"
