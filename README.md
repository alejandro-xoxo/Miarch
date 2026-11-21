# Demo personal de Miarch

Rama **personal**, aparte de Miarch: no está en `main` ni en `develop`, así que el actualizador (que sigue `main`) **no la entrega a nadie**.
Guarda los guiones para grabar el vídeo de Miarch y dos comandos (`tux-arch` y `mimusic`), para no perderlos al cambiar de equipo.

## Qué hay
- `demo-v9.sh`: la demo en una sola toma (login, música, fondos, terminales, paneles, actualizador simulado y bloqueo final). Graba solo un monitor.
- `bin/tux-arch`: dibuja el Tux de letras con "Miarch / By / alejandro-xoxo" (`tux-arch --ventana` lo abre en una terminal normal).
- `bin/mimusic`: se instala como `mimusic` (y como alias `m:music`); **ya forma parte de Miarch** (`scripts/mimusic`, lo instala `install.sh`) y esta copia solo la guarda; abre la página de música adaptada al monitor (cava, letra, peaclock, cbonsai y pipes.sh).
- `prog/`, `actualizador-sim.py`, `tux.png`: lo que usan los anteriores.
- `crear-musica.py`: genera una canción **original** de ambiente club (128 BPM, numpy, sin copyright): `python3 crear-musica.py salida.wav`. Se usa con `MIARCH_DEMO_MUSICA` en `demo.env`.
- `paquetes.txt`: los programas necesarios (oficiales y de AUR). **No** están en `packages.sh`.
- `demo.env.ejemplo`: plantilla de los ajustes privados (la contraseña va vacía).

## El Tux se adapta a la ventana
El pingüino tiene prioridad: cuando la ventana es pequeña se encoge primero el texto (grande → mediano → normal → sin texto) y el pingüino conserva al menos el 75 % de su alto máximo.

## Qué pasa con la terminal desde la que los escribes
`mimusic` y `tux-arch --ventana` **cierran la terminal en la que los escribiste** al terminar (la localizan por la cadena de procesos padre, no por "la ventana activa"). Si en esa terminal corre algo importante (`claude`, `node`, `ssh`, editores, `tmux`…) no se cierra y avisan. `--quedarme` evita el cierre y `--seco` muestra qué harían sin hacerlo.

## Restaurar en otro equipo
```
git clone -b personal/demo --single-branch https://github.com/alejandro-xoxo/Miarch.git ~/miarch-demo
bash ~/miarch-demo/restaurar.sh --paquetes
```
`restaurar.sh` copia todo a `~/demo-miarch` y los comandos a `~/.local/bin`, crea `~/.config/miarch/personal/demo.env` (permisos 600, sin contraseña) solo si no existe, y con `--paquetes` instala los programas pidiendo confirmación (los de AUR los revisa `yay`). `--seco` muestra qué haría sin cambiar nada.

## Privacidad
- La contraseña de la demo vive solo en `~/.config/miarch/personal/demo.env`, fuera de cualquier repositorio. Nunca la subas.
- La demo oculta los datos de red y no muestra tu usuario de sistema.

## Licencias
Los scripts son GPL-3.0-or-later como Miarch. El Tux (`tux.png`) es de Larry Ewing, Simon Budig y Garrett LeSage (licencia "Attribution", ver `TUX-LICENCIA.txt`); "Tux" es una marca asociada a Linux.
