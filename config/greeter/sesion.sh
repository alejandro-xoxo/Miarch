#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Lo ejecuta greetd, como el usuario que acaba de entrar, para arrancar su escritorio.
# Entre el login y el escritorio hay un momento en que se ve la consola de texto: aquí se borra, se oculta el cursor y la
# salida de start-hyprland va a un registro en vez de pintarse en pantalla (~/.cache/miarch/sesion.log).
# NOTA: greetd une los argumentos de la orden con espacios y sin comillas, por eso la orden del login es solo este archivo.
{ printf '\033[2J\033[H\033[?25l' > /dev/tty; } 2>/dev/null
mkdir -p "$HOME/.cache/miarch" 2>/dev/null
# se conserva el shell de login de zsh para cargar el entorno (~/.zprofile, PATH) como en un inicio normal
exec zsh -lc 'exec start-hyprland' >> "$HOME/.cache/miarch/sesion.log" 2>&1
