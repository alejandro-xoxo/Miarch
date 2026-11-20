# Regenerar las capturas

Dentro de Hyprland, con el escritorio en marcha: `./scripts/tomar-capturas`. Tarda unos 3 minutos y al terminar deja todo como estaba (fondo, escritorio y escritorio de trabajo).

- Usa el **escritorio 5** (debe estar vacío) y **aborta** si cambias de escritorio mientras se toman, para no fotografiar tu trabajo. No cambies de escritorio mientras corre.
- Modo demo: oculta el nombre de tu red, tu usuario y el nombre del equipo. **No** captura los paneles de Wi‑Fi, Bluetooth ni la página Sistema, porque muestran redes, dispositivos y datos del equipo.
- Los anillos de CPU y RAM salen del momento. Por defecto espera a que la CPU baje del 18 %; con `SIN_ESPERA=1` toma el consumo real del instante.
- Música: sale lo que esté sonando. Con `PLAYER_FALSO="comando"` se usa un reproductor MPRIS de prueba.

## Capturas generadas en `docs/screenshots/`
El script guarda las imágenes en formato JPEG reducidas a 1280 px:
- `escritorio-oscuro.jpg` y `escritorio-claro.jpg`: escritorios limpios con fondos de prueba.
- `terminal.jpg` y `terminal-adaptacion.jpg`: terminal Kitty con fastfetch y ajuste automático.
- `dolphin.jpg`: gestor de archivos sobre el tema del sistema.
- `lanzador.jpg`: lanzador de aplicaciones de Quickshell.
- `ajustes-apariencia.jpg`, `ajustes-accesibilidad.jpg`, `ajustes-energia.jpg`: páginas del panel de configuración.
- `menu-ia.jpg`: menú de herramientas de IA (`qs -c miarch ipc call ia open`).
- `notificaciones.jpg`: ejemplo de notificación emergente del escritorio (`notify-send`).
- `volumen.jpg`: barra de volumen OSD en pantalla (`qs -c miarch ipc call osd mostrar 60 "60%" 0`).
- `bloqueo.jpg`: pantalla de bloqueo con estilo cine.
- `inicio-de-sesion.jpg`: pantalla de acceso de greetd.
