# Paquetes · Juegos

Instalados por `packages.sh` (etapa "Preparando el equipo para jugar"). Necesitan el repositorio **multilib**, que `packages.sh` activa. Guía de uso: [juegos](../juegos.md).

| Paquete | Origen | Para qué sirve |
|---|---|---|
| `steam` | multilib | Steam; trae las reglas de los mandos (`steam-devices`) |
| `vulkan-icd-loader` · `lib32-vulkan-icd-loader` | extra · multilib | Cargador de Vulkan (64 y 32 bits) |
| `vulkan-intel` · `lib32-vulkan-intel` | extra · multilib | Vulkan de las gráficas Intel (se elige según tu tarjeta) |
| `vulkan-radeon` · `lib32-vulkan-radeon` | extra · multilib | Vulkan de las gráficas AMD (si tienes una) |
| `nvidia-utils` · `lib32-nvidia-utils` | extra · multilib | Bibliotecas de NVIDIA (si tienes una; el módulo del kernel va aparte) |
| `vulkan-swrast` · `lib32-vulkan-swrast` | extra · multilib | Vulkan por software, solo si no se reconoce ninguna tarjeta (máquina virtual) |
| `lib32-mesa` · `lib32-pipewire` · `lib32-libpulse` | multilib | Gráficos y audio de 32 bits para los juegos |
| `ttf-liberation` | extra | Tipografías que Steam necesita |
| `gamemode` · `lib32-gamemode` | extra · multilib | Prioridad del juego y perfil de energía "rendimiento" |
| `mangohud` · `lib32-mangohud` | extra · multilib | Contador de FPS y temperaturas |
| `gamescope` | extra | Reescalado FSR y pantalla completa controlada |
| `xorg-xwayland` | extra | Los juegos de Steam corren sobre XWayland |
| `protonup-qt` | AUR | Gestor gráfico de Proton-GE |
| `zram-generator` | extra | Solo si el equipo no tiene swap: memoria comprimida |

`packages.sh --faltantes` indica cuáles de estos faltan en tu equipo. Si existe `~/.config/miarch/sin-juegos`, este grupo se omite por completo y `--faltantes` no los solicita.
