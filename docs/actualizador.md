# Actualizador del sistema (miarch-update)

El actualizador de Miarch (`miarch-update`) mantiene el entorno al día en dos fases: una revisión previa que no cambia nada y la aplicación de solo lo que hace falta, tras una única confirmación. Se invoca desde la barra gráfica mediante el componente de Quickshell o directamente desde la terminal.

## Flujo de ejecución

```mermaid
flowchart TD
    Start["miarch-update (clic en la nube)"] --> F1

    subgraph Fase1["Fase 1: revisión (no cambia nada)"]
        F1["git fetch"] --> F2["Configuraciones pendientes"]
        F2 --> F3["Paquetes que faltan o sobran"]
        F3 --> F4["Actualizaciones del sistema y de AUR"]
        F4 --> F5["Pantalla de inicio de sesión"]
        F5 --> FTapa["Tapa del portátil (opcional)"]
        FTapa --> FServ["Servicios (Bluetooth e iwd)"]
        FServ --> F6["Novedades y áreas que cambian"]
    end

    F6 --> Conf{"Una confirmación"}
    Conf -- "No" --> Fin0["Termina sin cambios"]
    Conf -- "Sí" --> Sudo["sudo una vez, renovado cada 45 s"]

    subgraph Fase2["Fase 2: aplicación, solo lo necesario"]
        A1["1. git pull --ff-only"] --> A2["2. install.sh"]
        A2 --> A3["3. Paquetes: instalar y quitar"]
        A3 --> A4["4. Pantalla de inicio de sesión"]
        A4 --> ATapa["5. Tapa del portátil"]
        ATapa --> A5["6. yay -Syu"]
        A5 --> A6["7. Reparando servicios"]
        A6 --> A7["8. Recargar Hyprland y Quickshell"]
    end

    Sudo --> A1
    A7 --> Resumen["Resumen con duraciones"]
```

## Número de la nube

El número que muestra la nube de la barra es la suma de lo pendiente:

| Concepto | Cuándo cuenta |
| :--- | :--- |
| Cambios nuevos | Commits disponibles en GitHub tras `git fetch`. |
| Configuraciones sin aplicar | Cambió algo que se instala (`config/`, `scripts/`, `home/`, `lib/`, `install.sh`, `setup.sh`, `packages.sh`, `skills/`, `AGENTS.md`) desde el commit guardado en `~/.cache/miarch/configs-aplicadas`. Un commit solo de documentación no cuenta. |
| Paquetes que faltan | `packages.sh --faltantes` devuelve algo. |
| Paquetes que sobran | `packages.sh --sobran` devuelve algo. |
| Pantalla de inicio de sesión | `greetd` no está activo, o cambiaron los archivos del login. |

Clic izquierdo en la nube ejecuta `miarch-update`; clic derecho ejecuta `miarch-update --forzar`, que vuelve a aplicar las configuraciones aunque no haya cambios nuevos.

## Fase 1: Revisión

La primera fase inspecciona el estado del sistema sin modificar archivos ni instalar paquetes:

1. **Sincronización remota:** Ejecuta `git fetch` para consultar novedades en el repositorio.
2. **Filtrado de rutas para configuraciones:** Compara el último commit registrado en el marcador `~/.cache/miarch/configs-aplicadas` con el commit actual. Solo se consideran pendientes cambios que impacten en las siguientes rutas del repositorio:
   - `config/`
   - `scripts/`
   - `home/`
   - `lib/`
   - `install.sh`
   - `setup.sh`
   - `packages.sh`
   - `skills/`
   - `AGENTS.md`
3. **Inspección de paquetería:**
   - Detecta dependencias faltantes u obsoletas del repositorio mediante flags de `packages.sh`.
   - Consulta actualizaciones del sistema oficiales mediante `checkupdates` y paquetes AUR mediante `yay -Qua`.
4. **Inspección de login:** Comprueba si el greeter gráfico está activo en systemd o si sus fuentes han cambiado.
5. **Inspección de tapa del portátil:** En equipos portátiles con la marca de activación `~/.config/miarch/tapa-sin-suspender`, comprueba si falta el archivo de sistema o difiere (`miarch-tapa --pendiente`). Si la marca no existe pero el archivo de sistema sí, avisa con una línea informativa.
6. **Detección de bloqueos de pacman (db.lck):** Si existe un bloqueo con un proceso vivo (`pacman`, `yay`, `paru`, `pamac`) de más de 5 minutos, emite un aviso preventivo indicando el comando, tiempo y terminal (`pts/...`) antes de pedir confirmación.
7. **Inspección de servicios:** Detecta si `bluetooth` está desactivado o si está activo pero no responde a `bluetoothctl show` (solo si hay adaptador presente), y si el servicio Wi-Fi `iwd` se encuentra inactivo.
8. **Informe previo:** Imprime las áreas del sistema sujetas a modificación, los servicios a reparar y despliega hasta 3 títulos de entradas no leídas del archivo `NOVEDADES.md`.
9. **Confirmación:** Solicita una única aprobación interactiva antes de proceder.

## Fase 2: Aplicación y orden de ejecución

Si el usuario aprueba la operación, `miarch-update` aplica exclusivamente los pasos requeridos en un orden estricto para evitar inconsistencias:

1. **Descarga de código:** Ejecuta `git pull --ff-only`. Si tienes cambios locales sin guardar, no descarga nada y te avisa, para no pisarlos.
2. **Aplicación de configuraciones:** Invoca `install.sh`, copiando los archivos de `config/` y `scripts/` a `$HOME`.
3. **Gestión de paquetes:** Instala dependencias nuevas y remueve paquetes declarados obsoletos. Antes de modificar paquetes invoca la función compartida `esperar_pacman` (`lib/pacman.sh`).
4. **Pantalla de inicio de sesión:** Configura `greetd` y sincroniza assets de `/usr/share/miarch/greeter` y `/var/lib/miarch-greeter`. Si `greetd` ya está instalado (`pacman -Q greetd`), no ejecuta `pacman -S`. Si no lo está, consulta `esperar_pacman` antes de instalar.
5. **Tapa del portátil:** Si está pendiente, ejecuta `miarch-tapa --aplicar` para instalar `/etc/systemd/logind.conf.d/50-miarch-tapa.conf` y recargar `systemd-logind` con señal HUP (sin cerrar sesiones). Un fallo en esta etapa avisa y no detiene la actualización.
6. **Actualización de paquetes del sistema:** Comprueba `esperar_pacman` y ejecuta `yay -Syu --noconfirm`. Si hay un bloqueo no resuelto, omite la actualización del sistema avisando al usuario y continúa.
7. **Reparación de servicios:** Ejecuta `sudo systemctl restart bluetooth` (o `enable --now`) y `sudo systemctl start iwd`, esperando hasta 8 segundos para validar que Bluetooth responde adecuadamente. Un fallo en este paso no detiene el resto de la actualización.
8. **Reinicio del entorno gráfico:** Como última acción del proceso, recarga Hyprland y reinicia Quickshell cuando los paquetes ya están actualizados, para que no quede corriendo un binario viejo.
9. **Avisos finales:** Si en la ejecución cambiaron archivos de aplicaciones Electron (`config/applications/`, `config/claude-desktop/`, `config/electron/`, `config/vscode/` o `ELECTRON_OZONE_PLATFORM_HINT`), imprime un aviso recordando cerrar y reabrir ChatGPT, Claude Desktop y Antigravity para verlas nítidas. Todo el proceso corre bajo la confirmación única inicial.

## Gestión de bloqueos de pacman (db.lck)

Para evitar bloqueos o fallos si el usuario tiene otra terminal ejecutando un paquete a medias:
- **Sin bloqueo:** La operación continúa de inmediato sin demoras.
- **Proceso vivo activo:** Si `pacman`, `yay`, `paru` o `pamac` están en ejecución (excluyendo procesos hijos de la propia actualización y `checkupdates`), espera hasta 90 segundos mostrando el tiempo transcurrido. Si el proceso termina durante la espera, la actualización sigue con normalidad.
- **Bloqueo persistente:** Si agota el tiempo y el proceso sigue vivo, no falla con un error crudo: informa con claridad en español indicando el proceso, su tiempo vivo y su terminal (ej. `Hay una instalación abierta desde hace 1 h 27 min (yay -S peaclock, terminal pts/3). Respóndele o ciérrala (Ctrl+C) y vuelve a pulsar la nube.`), saltando la tarea pendiente y recordando que se reintentará en la siguiente ejecución.
- **Bloqueo huérfano:** Si existe `/var/lib/pacman/db.lck` sin procesos activos asociados, se verifica dos veces con 2 segundos de separación para descartar carreras, se elimina con `sudo rm -f` y se emite un aviso informativo.

## Gestión de privilegios (sudo)

Para evitar interrupciones o fallos durante compilaciones prolongadas en AUR:
- El actualizador pide la contraseña de `sudo` una sola vez, justo después de la confirmación y solo si algún paso la necesita.
- Inicia un temporizador en segundo plano que renueva la validez de las credenciales cada 45 segundos mientras la ejecución continúa activa.

## Preservación del entorno y personalizaciones

El proceso de actualización protege el estado definido por el usuario:

- **Variables del panel:** Durante la ejecución de `install.sh` se conservan los valores asignados a `ESCALA`, `KB`, `NATURAL`, `TAP`, `SENS`, `CURSOR`, `MOVIMIENTO`, `ANIM` y `BLUR`.
- **Fondos y paleta de colores:** No modifica el fondo de pantalla activo ni los esquemas de color generados previamente.
- **Configuraciones personales:** El directorio `~/.config/miarch/personal/` (`hyprland.lua`, `kitty.conf`, `zshrc`) es ignorado por las actualizaciones y nunca se sobreescribe.
- **Respaldos incrementales:** Toda sustitución de archivos en `$HOME` genera respaldos con formato `*.bak-DATE`. El sistema purga automáticamente versiones antiguas, manteniendo únicamente los 2 respaldos más recientes.
- **Árbol Git:** `git pull --ff-only` nunca fusiona ni pisa cambios locales.

## Exclusiones voluntarias (Opt-outs)

Para prescindir de la pantalla de inicio de sesión gráfica (`greetd`), el usuario puede crear el archivo marcador:

```bash
touch ~/.config/miarch/sin-greeter
```

Si dicho archivo existe, tanto `setup.sh` como `miarch-update` omiten la instalación, configuración y activación del greeter.

## Inclusiones voluntarias (Opt-in)

Para que el portátil no se suspenda al cerrar la tapa, el usuario activa la opción en Ajustes → Energía o crea el marcador:

```bash
touch ~/.config/miarch/tapa-sin-suspender
```

El actualizador detecta la marca en equipos portátiles, aplica la configuración en `/etc/systemd/logind.conf.d/50-miarch-tapa.conf` y recarga `systemd-logind` con `kill -s HUP`. Para revertir:

```bash
rm -f ~/.config/miarch/tapa-sin-suspender
miarch-tapa --quitar
```

## Salida por terminal y registros

- **Biblioteca `lib/ui.sh`:** Controla la presentación en consola mediante tres modos según el entorno (ASCII, consola estándar y modo enriquecido con paleta morada, spinner animado, barras de progreso y cajas de resumen con duración de tareas).
- **Archivo de log:** Toda la salida detallada y posibles errores de ejecución se registran en:
  ```text
  ~/.cache/miarch/instalacion.log
  ```

## Forzado de actualización

Vuelve a aplicar las configuraciones y los scripts (`install.sh`) aunque no haya cambios nuevos:

```bash
miarch-update --forzar
```

También puede dispararse de manera gráfica haciendo clic derecho sobre el icono de la nube en la barra de Quickshell.

## Diagnóstico y resolución de incidencias

### Error en `git pull` por cambios locales
- **Causa:** Existen archivos locales modificados que impiden realizar una fusión rápida (`--ff-only`).
- **Solución:** Confirmar los cambios locales o revertirlos antes de volver a ejecutar `miarch-update`.

### Fallo en el inicio de sesión gráfico (`greetd`)
Si la interfaz gráfica de inicio no carga y no permite ingresar al sistema:
1. Cambiar a una terminal virtual alternativa mediante `Ctrl+Alt+F2`.
2. Iniciar sesión con las credenciales de usuario.
3. Deshabilitar `greetd` y restaurar la consola estándar en tty1:
   ```bash
   sudo systemctl disable greetd && sudo systemctl enable getty@tty1
   ```
4. El respaldo previo del archivo de configuración se encuentra disponible en `/etc/greetd/config.toml.miarch-bak`.
5. Si `greetd` falla en menos de 8 segundos, el sistema tiene configurado el retorno automático a login en texto (`agreety`).

### Errores en instalación de paquetes o scripts
Revisar el archivo de registro con:
```bash
cat ~/.cache/miarch/instalacion.log
```
- **Hermes Desktop:** Ante cortes de red, comprueba conectividad hasta 4 veces y reintenta la instalación hasta 3 veces antes de posponerla a la próxima actualización.
