#!/bin/sh
# Lo ejecuta greetd como el usuario "greeter": abre la pantalla de inicio de sesión gráfica.
# Si falla nada más arrancar, cae a un inicio de sesión de texto (agreety) para no dejarte sin entrar.
export XDG_SESSION_TYPE=wayland
t0=$(date +%s)
start-hyprland -- -c /usr/share/miarch/greeter/hyprland.lua
rc=$?
if [ "$rc" -ne 0 ] && [ $(( $(date +%s) - t0 )) -lt 8 ]; then
    exec agreety --cmd "zsh -lc 'exec start-hyprland'"
fi
exit 0
