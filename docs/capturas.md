# Regenerar las capturas

Dentro de Hyprland, con el escritorio en marcha: `./scripts/tomar-capturas`. Tarda unos 3 minutos y al terminar deja todo como estaba.

- Usa el **escritorio 5** (debe estar vacío) y **aborta** si cambias de escritorio mientras se toman, para no fotografiar tu trabajo. No cambies de escritorio mientras corre.
- Modo demo: oculta el nombre de tu red, tu usuario y el nombre del equipo. **No** captura los paneles de Wi‑Fi, Bluetooth ni la página Sistema, porque muestran redes, dispositivos y datos del equipo.
- Los anillos de CPU y RAM salen del momento. Por defecto espera a que la CPU baje del 18 %; con `SIN_ESPERA=1` toma el consumo real del instante.
- Música: sale lo que esté sonando. Con `PLAYER_FALSO="comando"` se usa un reproductor MPRIS de prueba.
