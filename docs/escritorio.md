# El escritorio

## Hyprland (`config/hypr/hyprland.lua`)
Configuración en **Lua** (Hyprland 0.57). Al inicio del archivo hay variables que el panel de Ajustes cambia con `miarch-set`: escala, teclado, scroll natural, tap del touchpad, velocidad del ratón, cursor, movimiento reducido, preset de animaciones (`slide`, `zoom`, `suave`, `elastico`, `original`) y desenfoque (`ninguno` … `extremo`). También define las reglas de ventana (Dolphin ligeramente translúcido, desenfoque de los paneles) y los [atajos](atajos.md).

## Quickshell (`config/quickshell/miarch/shell.qml`)
Todo el escritorio propio, en un solo archivo organizado por secciones:

| Sección | Qué es |
|---|---|
| Escritorio | Reloj, fecha, anillos de CPU/RAM/batería y tarjeta de música sobre el fondo |
| Barra | Escritorios, música, actualizaciones, Bluetooth, Wi‑Fi, volumen, batería, ajustes y bloqueo |
| Lanzador | `Super + Espacio`: búsqueda instantánea con abreviaturas, ordena por uso |
| Conexiones | Paneles de Wi‑Fi y Bluetooth (clic en la barra) |
| Ajustes | `Super + Esc`: red, sonido, pantalla, apariencia, teclado y ratón, accesibilidad, energía y sistema |
| Bloqueo | `Super + L`: wallpaper desenfocado, reloj, anillos, música y contraseña |

## Colores del wallpaper
`wallpaper.sh` cambia el fondo y llama a `miarch-colors`, que saca una paleta mate y la escribe para: Quickshell (`colors.json`), kitty, Dolphin y las apps de Qt (`kdeglobals` y `qt6ct`). Se adapta a fondos claros u oscuros. Los GIF se muestran como imagen fija salvo que actives GIF en Ajustes.

## Terminal (`config/kitty/kitty.conf`)
kitty con los colores del wallpaper (`color16` acento, `color17` neutro), la misma tipografía y un poco de transparencia.

## Neovim (`config/nvim/init.lua`)
Configuración con Lazy.nvim; `install.sh` sincroniza los plugins.

## Chrome (`config/chrome/chrome-flags.conf`)
Flags para Wayland y aceleración de video (VA-API).

## Pantalla de inicio de sesión (`config/greeter/`)
`greetd` + una pantalla Quickshell con el mismo estilo del bloqueo. Opcional: `./scripts/miarch-greeter-install`.

## Waybar (`config/waybar/`)
Tema anterior, conservado como respaldo. No se usa.
