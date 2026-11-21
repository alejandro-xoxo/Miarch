# Servicios que activa `packages.sh`

| Servicio | Para qué |
|---|---|
| `iwd.service` | Wi‑Fi |
| `bluetooth.service` | Bluetooth |
| `power-profiles-daemon.service` | Modos de energía |
| `docker.socket` | Docker arranca solo cuando lo usas (no gasta memoria al encender) |
| `ollama.service` | Modelos de IA locales |

`greetd` (pantalla de inicio de sesión gráfica): lo instala y activa `setup.sh` y el actualizador, con `./scripts/miarch-greeter-install`. Si no lo quieres, crea `~/.config/miarch/sin-greeter`. Ver [instalación](instalacion.md#pantalla-de-inicio-de-sesión-gráfica-greeter).

## Reparación automática en el actualizador (`miarch-update`)

Durante la revisión inicial, el actualizador detecta servicios que requieren atención y los repara con la confirmación única de la actualización:
- **`bluetooth.service`**: Si hay un adaptador Bluetooth pero el servicio no está habilitado, lo habilita e inicia (`enable --now`). Si está activo en systemd pero el demonio no responde (`bluetoothctl show` falla o tarda más de 6 s), ejecuta `sudo systemctl restart bluetooth` y aguarda hasta 8 segundos confirmando que vuelva a responder (`✔ Bluetooth responde`).
- **`iwd.service`**: Si el servicio Wi-Fi no está activo, lo inicia automáticamente (`sudo systemctl start iwd`).
