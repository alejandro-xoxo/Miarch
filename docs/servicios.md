# Servicios que activa `packages.sh`

| Servicio | Para qué |
|---|---|
| `iwd.service` | Wi‑Fi |
| `bluetooth.service` | Bluetooth |
| `power-profiles-daemon.service` | Modos de energía |
| `docker.socket` | Docker arranca solo cuando lo usas (no gasta memoria al encender) |
| `ollama.service` | Modelos de IA locales |

Opcional: `greetd` (pantalla de inicio de sesión gráfica), con `./scripts/miarch-greeter-install`. Ver [instalación](instalacion.md).
