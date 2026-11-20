# Servicios que activa `packages.sh`

| Servicio | Para qué |
|---|---|
| `iwd.service` | Wi‑Fi |
| `bluetooth.service` | Bluetooth |
| `power-profiles-daemon.service` | Modos de energía |
| `docker.socket` | Docker arranca solo cuando lo usas (no gasta memoria al encender) |
| `ollama.service` | Modelos de IA locales |

`greetd` (pantalla de inicio de sesión gráfica): lo instala y activa `setup.sh` y el actualizador, con `./scripts/miarch-greeter-install`. Si no lo quieres, crea `~/.config/miarch/sin-greeter`. Ver [instalación](instalacion.md#pantalla-de-inicio-de-sesión-gráfica-greeter).
