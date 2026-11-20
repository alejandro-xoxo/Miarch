# Scripts (`scripts/`)

`install.sh` copia estos a `~/.local/bin`, salvo los dos últimos.

| Script | Qué hace |
|---|---|
| `wallpaper.sh` | Cambia el fondo (aleatorio o uno concreto) y regenera los colores |
| `miarch-colors` | Saca una paleta mate del wallpaper y colorea Quickshell, kitty, Dolphin y apps de Qt |
| `miarch-set` | Aplica un ajuste del panel (animaciones, blur, escala, teclado, accesibilidad, energía, brillo…) |
| `miarch-wifi` | Puente con `iwd`: la contraseña se la da a `iwctl` por una terminal virtual, nunca como argumento de un comando |
| `miarch-info` | Información del equipo para la página Sistema |
| `miarch-fetch` | fastfetch que se adapta al tamaño de la ventana (logo grande, pequeño o ninguno) |
| `miarch-update` | Actualizador semiautomático: baja los cambios de Miarch, los aplica conservando tus ajustes y tu fondo, y pregunta antes de instalar paquetes o actualizar el sistema (ver [instalación](instalacion.md#actualizar)) |
| `miarch-chrome-tema` | Quita de Chrome el tema de color propio del perfil (por ejemplo uno rojo que se ve marrón) para que siga el tema oscuro del sistema. Chrome debe estar cerrado; guarda una copia de `Preferences` antes de cambiar nada |
| `miarch-modo-juego` | Lo llama GameMode: al empezar un juego guarda tu perfil de energía y pone "performance"; al terminar lo restaura |
| `miarch-steam` | Abre Steam con el tamaño de interfaz según la escala de tu pantalla (`--instalar-lanzador` crea su entrada en el lanzador) |
| `miarch-greeter-install` | Instala la pantalla de inicio de sesión gráfica (pide sudo; no se activa hasta reiniciar) |
| `tomar-capturas` | Regenera las capturas del README (ver [capturas](capturas.md)) |
