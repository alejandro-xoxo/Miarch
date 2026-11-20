# Juegos en Miarch (Steam)

`packages.sh` deja el equipo listo para jugar con Steam. Los juegos son opcionales: en una instalación interactiva nueva `setup.sh` te pregunta si quieres instalarlos, y en cualquier momento puedes omitirlos creando `touch ~/.config/miarch/sin-juegos` (así ni `packages.sh` ni el actualizador intentarán instalarlos ni requerirán multilib). Esta guía explica qué hace por ti, cómo empezar y qué opciones de lanzamiento conviene usar, con atención especial a las **gráficas integradas** (el equipo de pruebas tiene una Intel UHD 620).

## Qué hace Miarch por ti
| Qué | Para qué |
|---|---|
| Activa el repositorio **multilib** (guarda una copia `pacman.conf.miarch-bak`) | Steam y los juegos de Windows usan bibliotecas de 32 bits |
| Instala **Steam** y los controladores Vulkan de **tu** tarjeta (Intel, AMD o NVIDIA, en 64 y 32 bits) | Los juegos de Proton usan Vulkan; sin el controlador de 32 bits muchos no abren |
| **GameMode**: al empezar un juego pone el perfil de energía "rendimiento" y al terminar devuelve el que tenías | Más rendimiento sin acordarte de cambiarlo |
| **MangoHud** con la paleta de Miarch | Contador de FPS, tiempo por cuadro y temperaturas (`Shift derecho + F12`) |
| **Gamescope** | Dibuja el juego a menor resolución y lo reescala (FSR): clave en tarjetas integradas |
| **ProtonUp-Qt** (AUR) | Instala y actualiza Proton-GE con clics |
| **ntsync** (si tu kernel lo trae, 6.14 o más nuevo) | Sincronización de hilos más rápida para Proton |
| **zram** si el equipo no tiene ningún swap | Evita cierres bruscos cuando un juego usa mucha memoria |
| Regla de Hyprland para las ventanas de juegos | Sin desenfoque, sombras ni animaciones en el juego, y la pantalla no se bloquea ni se apaga mientras está a pantalla completa |
| `miarch-steam` | Abre Steam con el tamaño de interfaz según la escala de tu pantalla (con escala 1.5 su ventana se ve diminuta) |
| Te añade al grupo `gamemode` | GameMode puede subir la prioridad del juego (**cierra sesión y entra de nuevo** para que se aplique) |

La lista de paquetes está en [paquetes/juegos](paquetes/juegos.md).

## Primer uso
1. Abre **Steam** desde el lanzador (`Super + Espacio`) e inicia sesión.
2. **Steam → Configuración → Compatibilidad →** activa **Habilitar Steam Play para todos los demás títulos**. Así los juegos de Windows corren con Proton.
3. Antes de comprar o instalar un juego, mira su nota en [ProtonDB](https://www.protondb.com): dice si funciona en Linux y con qué ajustes.
4. Si un juego va mal con el Proton por defecto, abre **ProtonUp-Qt**, instala la última versión de **Proton-GE** y elígela en el juego: **clic derecho → Propiedades → Compatibilidad → Forzar una herramienta de compatibilidad específica**.

## Opciones de lanzamiento recomendadas
En Steam: **clic derecho en el juego → Propiedades → General → Opciones de lanzamiento**.

| Para | Opción |
|---|---|
| Rendimiento y contador de FPS | `gamemoderun mangohud %command%` |
| **Gráfica integrada** (por ejemplo Intel UHD 620): dibujar a 720p y reescalar a 1080p con FSR | `gamescope -w 1280 -h 720 -W 1920 -H 1080 -F fsr -f -- gamemoderun %command%` |
| Limitar los FPS (menos calor y ruido) | `MANGOHUD_CONFIG=fps_limit=60 mangohud %command%` |
| Si con gamescope en Intel los colores salen corruptos | añade `INTEL_DEBUG=noccs` delante: `INTEL_DEBUG=noccs gamescope ...` (usa algo más de memoria de la gráfica) |

En `gamescope`, `-w` y `-h` son la resolución a la que se dibuja el juego, `-W` y `-H` la de salida, `-F fsr` activa el reescalado FSR y `-f` pone pantalla completa. Baja `-w` y `-h` si necesitas más FPS. Si un juego falla con `gamescope`, quítalo y prueba solo `gamemoderun %command%`.

## Consejos para un portátil con gráfica integrada
- **Conéctalo a la corriente.** En batería, el procesador y la gráfica rinden mucho menos.
- **No esperes juegos recientes en ultra.** Una UHD 620 va bien con juegos ligeros, indies y títulos de hace unos años a 720p o con FSR; para lo demás, baja la resolución y los detalles.
- **Vigila la temperatura** con MangoHud (`cpu_temp`, `gpu_temp`). Si sube mucho, limita los FPS.
- **Instala los juegos en `/home`**, que es donde Steam guarda su biblioteca (`~/.local/share/Steam`). La raíz (`/`) suele ser pequeña. Para usar otro disco: **Steam → Configuración → Almacenamiento**.
- **Cierra Chrome y otras apps pesadas** mientras juegas: comparten la memoria y la gráfica.
- El perfil de energía lo cambia GameMode solo; también puedes verlo en `Super + Esc → Energía`.

## Si algo no funciona
- **Steam no abre:** ejecuta `miarch-steam` en una terminal para ver el error. Comprueba que `multilib` está activo (`grep -A1 '^\[multilib\]' /etc/pacman.conf`).
- **Sin sonido en un juego:** comprueba que están instalados `lib32-pipewire` y `lib32-libpulse` (`packages.sh` los instala).
- **Un juego no arranca con Proton:** prueba otra versión de Proton (la de Valve, Proton Experimental o Proton-GE) y revisa ProtonDB.
- **Tarjeta NVIDIA:** `packages.sh` instala las bibliotecas Vulkan, pero no el módulo del kernel: instala `nvidia-open` (o `nvidia-dkms`) y reinicia.
- **Quitar lo que hizo Miarch:** `sudo cp /etc/pacman.conf.miarch-bak /etc/pacman.conf` deja la configuración de pacman como estaba; los demás ajustes son archivos sueltos que puedes borrar (`~/.config/gamemode.ini`, `~/.config/MangoHud/`, `/etc/modules-load.d/ntsync.conf`).

## Fuentes
Guías y páginas consultadas: la página de [Gamescope en la Arch Wiki](https://wiki.archlinux.org/title/Gamescope), la de [Steam en la Arch Wiki](https://wiki.archlinux.org/title/Steam), la guía de [EndeavourOS Gaming 101](https://discovery.endeavouros.com/gaming/gaming-101/2022/01) y la de [Linuxiac sobre Steam en Arch](https://linuxiac.com/how-to-play-games-on-arch-linux-using-steam/). Los nombres de paquetes se comprobaron contra los repositorios oficiales de Arch.
