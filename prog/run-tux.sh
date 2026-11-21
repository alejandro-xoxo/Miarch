#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Terminal de la demo: Tux hecho con letras de terminal, centrado. Si falla, el pingüino de letras de fastfetch.
python3 "$HOME/demo-miarch/prog/tux-texto.py" || { clear; fastfetch --logo linux --structure OS:Kernel:Uptime:Packages:Shell:WM:Memory:Battery; exec sleep 100000; }
