# Instalación en detalle

## Un comando
Desde un Arch mínimo, con un usuario con `sudo` e internet (también está en el [README](../README.md)):

```bash
sudo pacman -S --needed --noconfirm git && git clone https://github.com/alejandro-xoxo/Miarch ~/Miarch && ~/Miarch/setup.sh
```

`setup.sh` comprueba internet, pide `sudo` una sola vez (lo mantiene activo mientras dura), instala `git` y `base-devel`, y ejecuta `packages.sh` e `install.sh`. Tarda unos 30 minutos porque compila Quickshell. Después: `sudo reboot`.

> **¿Descargaste el ZIP de GitHub?** El ZIP borra los permisos de ejecución y `./setup.sh` da "permiso denegado". Usa `bash setup.sh` (con `git clone` no pasa).

## Por pasos
1. `./packages.sh`: paquetes ([lista](paquetes/README.md)), servicios ([lista](servicios.md)), Oh My Zsh ([zsh](zsh.md)), `yay` y los paquetes de AUR.
2. `./install.sh`: copia configuraciones y scripts a tu `$HOME`, con copia de seguridad (`*.bak-FECHA`) de lo que reemplaza; sincroniza Neovim; añade el inicio automático de Hyprland en tty1; aplica el wallpaper y los colores.

Los tres se pueden ejecutar varias veces.

## Sin internet (Wi‑Fi)
En un Arch mínimo el Wi‑Fi lo maneja `iwd`:

```bash
iwctl station wlan0 connect "NOMBRE_DE_TU_RED"
```

Si tu tarjeta no se llama `wlan0`: `iwctl station list`. Con cable ya debería haber conexión. Después de instalar, el Wi‑Fi se maneja con un panel de clics.

## Pantalla de inicio de sesión gráfica (opcional)
```bash
./scripts/miarch-greeter-install
```
Instala `greetd`, copia la pantalla y la deja lista para el **próximo arranque**. Si algo falla y no puedes entrar: `Ctrl + Alt + F2`, inicia sesión y ejecuta

```bash
sudo systemctl disable greetd && sudo systemctl enable getty@tty1
```

y reinicia: vuelves al inicio de sesión de texto.

## Actualizar
```bash
cd ~/Miarch && git pull && ./setup.sh
```

`git pull` solo baja los archivos. Los **paquetes nuevos** los instala `packages.sh` y las **configuraciones** las copia `install.sh`; `setup.sh` ejecuta los dos (pide `sudo` una vez). Si solo cambiaron configuraciones, basta `./install.sh`. Si agregaron un paquete (por ejemplo Hermes) y no te aparece, es porque falta ejecutar `packages.sh`.

Para instalar un solo paquete de AUR sin repetir todo: `yay -S hermes-webui-desktop-bin`.

## Seguridad
- **pacman:** repositorios firmados de Arch.
- **AUR (`yay`):** `quickshell-git`, `google-chrome`, `visual-studio-code-bin`, `claude-code`, `claude-desktop`, `antigravity-cli`, `hermes-webui-desktop-bin`. Son de la comunidad y **no están firmados por Arch**; el script los instala con `--noconfirm`, sin mostrarte el PKGBUILD. Quita esa opción en `packages.sh` si prefieres revisarlos uno a uno.
- **Oh My Zsh:** se clona con `git`; no se ejecuta ningún script descargado.
- **Docker:** estar en el grupo `docker` equivale a ser administrador (ver [desarrollo](paquetes/desarrollo.md)).

## Requisitos
Arch Linux (instalación mínima) con `sudo` y red. Probado en un portátil con Intel Core i5 de 8.ª generación; con otra GPU cambia `intel-media-driver` en `packages.sh`.

## Consumo
Medido en ese portátil con Chrome, VS Code, Spotify y Claude abiertos: **Quickshell ≈ 9 % de un núcleo y ≈ 400 MB**; Hyprland ≈ 10 % y ≈ 230 MB. Lo que más consume son las apps que abres, no el escritorio.
